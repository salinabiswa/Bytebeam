import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';
import '../models/models.dart';

// ── CRC32 ────────────────────────────────────────────────────
int computeCrc32(List<int> data) {
  const table = [
    0x00000000, 0x77073096, 0xEE0E612C, 0x990951BA, 0x076DC419, 0x706AF48F,
    0xE963A535, 0x9E6495A3, 0x0EDB8832, 0x79DCB8A4, 0xE0D5E91B, 0x97D2D988,
    0x09B64C2B, 0x7EB17CBF, 0xE7B82D08, 0x90BF1D9C
  ];
  int crc = 0xFFFFFFFF;
  for (final b in data) {
    crc = (crc >>> 4) ^ table[(crc ^ (b >>> 0)) & 0xF];
    crc = (crc >>> 4) ^ table[(crc ^ (b >>> 4)) & 0xF];
  }
  return crc ^ 0xFFFFFFFF;
}

// ── Chunk header ─────────────────────────────────────────────
Uint8List buildHeader(int fileId, int chunkIdx, int dataSize, int crc) {
  final h = ByteData(Config.chunkHeaderSize);
  h.setUint32(0,  Config.magicNumber, Endian.little);
  h.setUint32(4,  fileId,             Endian.little);
  h.setUint32(8,  chunkIdx,           Endian.little);
  h.setUint32(12, dataSize,           Endian.little);
  h.setUint32(16, crc,                Endian.little);
  return h.buffer.asUint8List();
}

class _ParsedHeader {
  final int magic, fileId, chunkIdx, dataSize, crc;
  _ParsedHeader(this.magic, this.fileId, this.chunkIdx, this.dataSize, this.crc);
  bool get isEof => fileId == 0xFFFFFFFF;
  bool get valid => magic == Config.magicNumber;
}

_ParsedHeader parseHeader(Uint8List d) {
  final h = ByteData.sublistView(d);
  return _ParsedHeader(
    h.getUint32(0, Endian.little), h.getUint32(4, Endian.little),
    h.getUint32(8, Endian.little), h.getUint32(12, Endian.little),
    h.getUint32(16, Endian.little));
}

// ── Chunk task queue ─────────────────────────────────────────
class _Queue {
  final _items = <_Task>[];
  bool paused = false;
  bool cancelled = false;
  void add(_Task t) => _items.add(t);
  _Task? next() => _items.isEmpty ? null : _items.removeAt(0);
  bool get isEmpty => _items.isEmpty;
}

class _Task {
  final int fileId, chunkIdx, totalChunks, fileSize;
  final String filePath;
  _Task(this.fileId, this.chunkIdx, this.totalChunks, this.filePath, this.fileSize);
}

// ── Update event ─────────────────────────────────────────────
class TransferUpdate {
  final String transferId;
  final int fileId, bytesChunk;
  TransferUpdate(this.transferId, this.fileId, this.bytesChunk);
}

// ── Engine ───────────────────────────────────────────────────
class TransferEngine {
  ServerSocket? _ctrlServer;
  _Queue? _sendQueue;

  void Function(Transfer)?                            onIncomingTransfer;
  void Function(TransferUpdate)?                      onUpdate;
  void Function(String, List<String>)?                onReceiveComplete;
  void Function(String)?                              onSendComplete;
  void Function(String, String)?                      onError;

  final _accepters = <String, Completer<bool>>{};

  // ── Listen ───────────────────────────────────────────────
  Future<void> startListening() async {
    try {
      _ctrlServer = await ServerSocket.bind(InternetAddress.anyIPv4, Config.controlPort);
      _ctrlServer!.listen(_handleControl);
    } catch (_) {}
  }

  void stopListening() { _ctrlServer?.close(); }

  // ── Send ─────────────────────────────────────────────────
  Future<void> sendFiles({
    required Device target,
    required List<({String path, String name, int size})> files,
    required String transferId,
    required Transfer transfer,
    required String senderName,
  }) async {
    _sendQueue = _Queue();
    Socket? ctrl;
    try {
      // Bundle small files
      final small = files.where((f) => f.size <= Config.smallFileThreshold).toList();
      final large = files.where((f) => f.size  > Config.smallFileThreshold).toList();
      final xfer  = <FileItem>[];

      if (small.isNotEmpty) {
        final bp = await _bundle(small);
        final bs = await File(bp).length();
        final fi = FileItem(id: 0, name: Config.bundleName, size: bs, path: bp,
          isBundle: true, bundledNames: small.map((f) => f.name).toList());
        xfer.add(fi);
      }
      for (int i = 0; i < large.length; i++) {
        xfer.add(FileItem(id: small.isEmpty ? i : i + 1,
          name: large[i].name, size: large[i].size, path: large[i].path));
      }

      transfer.files..clear()..addAll(xfer);
      transfer.totalBytes = xfer.fold(0, (s, f) => s + f.size);

      ctrl = await Socket.connect(target.ip, Config.controlPort)
          .timeout(const Duration(seconds: 10));

      // Send manifest
      final manifest = {
        'protocol': Config.protocolVersion, 'transferId': transferId,
        'senderName': senderName,
        'files': xfer.map((f) => f.toJson()).toList(),
        'totalBytes': transfer.totalBytes, 'totalOrigFiles': files.length,
      };
      ctrl.write(jsonEncode(manifest) + '\n');
      await ctrl.flush();

      // Wait for ACK
      final ack = jsonDecode(await _readLine(ctrl).timeout(const Duration(seconds: 30)))
          as Map<String, dynamic>;
      if (ack['accepted'] != true) {
        onError?.call(transferId, 'Transfer declined');
        ctrl.destroy(); return;
      }

      // Build queue
      final resumeRaw = ack['resumeMap'] as Map<String, dynamic>? ?? {};
      final resume = resumeRaw.map((k, v) =>
        MapEntry(int.parse(k), Set<int>.from((v as List).cast<int>())));

      for (final f in xfer) {
        final done = resume[f.id] ?? {};
        for (int ci = 0; ci < f.totalChunks; ci++) {
          if (!done.contains(ci)) {
            _sendQueue!.add(_Task(f.id, ci, f.totalChunks, f.path!, f.size));
          } else {
            f.doneChunks++;
            onUpdate?.call(TransferUpdate(transferId, f.id, 0));
          }
        }
      }

      // Parallel senders
      await Future.wait(List.generate(Config.numParallelChannels,
        (ch) => _sendChannel(ch, target.ip, _sendQueue!, transferId, xfer, transfer)));

      if (!_sendQueue!.cancelled) {
        ctrl.write('DONE\n');
        await ctrl.flush();
        onSendComplete?.call(transferId);
      } else {
        onError?.call(transferId, 'Cancelled');
      }
    } catch (e) {
      onError?.call(transferId, e.toString());
    } finally { ctrl?.destroy(); }
  }

  Future<void> _sendChannel(int ch, String ip, _Queue queue,
      String tid, List<FileItem> xfer, Transfer transfer) async {
    Socket? sock;
    try {
      sock = await Socket.connect(ip, Config.dataPortBase + ch)
          .timeout(const Duration(seconds: 10));
      sock.write('DATA $ch\n');
      await sock.flush();

      while (!queue.isEmpty && !queue.cancelled) {
        while (queue.paused && !queue.cancelled) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (queue.cancelled) break;
        final task = queue.next();
        if (task == null) break;
        await _sendChunk(sock, task, tid, xfer, transfer);
      }
      sock.add(buildHeader(0xFFFFFFFF, 0xFFFFFFFF, 0, 0));
      await sock.flush();
    } catch (_) {} finally { sock?.destroy(); }
  }

  Future<void> _sendChunk(Socket sock, _Task task, String tid,
      List<FileItem> xfer, Transfer transfer) async {
    final offset = task.chunkIdx * Config.chunkSize;
    final length = (task.fileSize - offset).clamp(0, Config.chunkSize).toInt();
    if (length <= 0) return;
    final raf = await File(task.filePath).open();
    await raf.setPosition(offset);
    final data = await raf.read(length);
    await raf.close();
    final crc = computeCrc32(data);
    sock.add(buildHeader(task.fileId, task.chunkIdx, data.length, crc));
    sock.add(data);
    if (task.chunkIdx % 4 == 0) await sock.flush();
    final fi = xfer.firstWhere((f) => f.id == task.fileId);
    fi.doneChunks++;
    transfer.transferredBytes += data.length;
    onUpdate?.call(TransferUpdate(tid, task.fileId, data.length));
  }

  // ── Receive ──────────────────────────────────────────────
  Future<void> _handleControl(Socket ctrl) async {
    try {
      final line = await _readLine(ctrl).timeout(const Duration(seconds: 15));
      final manifest = jsonDecode(line) as Map<String, dynamic>;
      final files = (manifest['files'] as List)
          .map((f) => FileItem.fromJson(f as Map<String, dynamic>)).toList();
      final transferId = manifest['transferId'] as String;
      final senderName = manifest['senderName'] as String? ?? 'Unknown';
      final senderIp   = ctrl.remoteAddress.address;

      final transfer = Transfer(
        id: transferId, isSending: false, files: files,
        peer: Device(id: transferId, name: senderName, ip: senderIp, lastSeen: DateTime.now()),
        status: TransferStatus.pending);
      transfer.totalBytes = manifest['totalBytes'] as int;

      onIncomingTransfer?.call(transfer);

      final accepted = await _waitAccept(transferId);
      if (!accepted) {
        ctrl.write(jsonEncode({'accepted': false}) + '\n');
        await ctrl.flush(); ctrl.destroy(); return;
      }

      final resumeMap = await _loadResume(transferId);
      ctrl.write(jsonEncode({
        'accepted': true,
        'resumeMap': resumeMap.map((k, v) => MapEntry(k.toString(), v.toList())),
      }) + '\n');
      await ctrl.flush();

      final saveDir = await _saveDir();
      final servers = <ServerSocket>[];

      await Future.wait(List.generate(Config.numParallelChannels, (ch) async {
        final srv = await ServerSocket.bind(InternetAddress.anyIPv4, Config.dataPortBase + ch);
        servers.add(srv);
        final sock = await srv.first.timeout(const Duration(seconds: 30));

        final rafs = <int, RandomAccessFile>{};
        for (final f in files) {
          final raf = await File('$saveDir/${f.name}').open(mode: FileMode.writeOnlyAppend);
          await raf.truncate(0);
          await raf.truncate(f.size.toInt());
          rafs[f.id] = raf;
        }

        await _readLine(sock).timeout(const Duration(seconds: 5));
        final buf = <int>[];
        await for (final chunk in sock) {
          buf.addAll(chunk);
          await _processBuffer(buf, rafs, files, transferId, transfer);
        }
        for (final r in rafs.values) { await r.close(); }
        await srv.close();
      }));

      try { await _readLine(ctrl).timeout(const Duration(seconds: 30)); } catch (_) {}

      final finalPaths = <String>[];
      for (final f in files) {
        final path = '$saveDir/${f.name}';
        if (f.isBundle) {
          finalPaths.addAll(await _unbundle(path, saveDir));
          try { File(path).deleteSync(); } catch (_) {}
        } else { finalPaths.add(path); }
      }
      await _deleteResume(transferId);
      onReceiveComplete?.call(transferId, finalPaths);
    } catch (_) {} finally { ctrl.destroy(); }
  }

  Future<void> _processBuffer(List<int> buf, Map<int, RandomAccessFile> rafs,
      List<FileItem> files, String tid, Transfer transfer) async {
    while (buf.length >= Config.chunkHeaderSize) {
      final hdr = parseHeader(Uint8List.fromList(buf.sublist(0, Config.chunkHeaderSize)));
      if (!hdr.valid) { buf.removeAt(0); continue; }
      if (hdr.isEof) { buf.removeRange(0, Config.chunkHeaderSize); return; }
      final total = Config.chunkHeaderSize + hdr.dataSize;
      if (buf.length < total) break;
      final data = Uint8List.fromList(buf.sublist(Config.chunkHeaderSize, total));
      buf.removeRange(0, total);
      if (computeCrc32(data) != hdr.crc) continue;
      final raf = rafs[hdr.fileId];
      if (raf != null) {
        await raf.setPosition(hdr.chunkIdx * Config.chunkSize);
        await raf.writeFrom(data);
      }
      final fi = files.firstWhere((f) => f.id == hdr.fileId);
      if (!fi.completedChunks.contains(hdr.chunkIdx)) {
        fi.completedChunks.add(hdr.chunkIdx);
        fi.doneChunks++;
        transfer.transferredBytes += data.length;
        onUpdate?.call(TransferUpdate(tid, hdr.fileId, data.length));
        if (fi.doneChunks % 10 == 0) await _saveResume(tid, files);
      }
    }
  }

  // ── Accept/Decline ───────────────────────────────────────
  Future<bool> _waitAccept(String tid) {
    final c = Completer<bool>();
    _accepters[tid] = c;
    return c.future.timeout(const Duration(minutes: 2), onTimeout: () => false);
  }
  void acceptTransfer(String tid)  => _accepters.remove(tid)?.complete(true);
  void declineTransfer(String tid) => _accepters.remove(tid)?.complete(false);

  // ── Pause / Resume / Cancel ──────────────────────────────
  void pauseTransfer()  { _sendQueue?.paused    = true; }
  void resumeTransfer() { _sendQueue?.paused    = false; }
  void cancelTransfer() { _sendQueue?.cancelled = true; }

  // ── Bundle ───────────────────────────────────────────────
  Future<String> _bundle(List<({String path, String name, int size})> files) async {
    final archive = Archive();
    for (final f in files) {
      final bytes = await File(f.path).readAsBytes();
      archive.addFile(ArchiveFile(f.name, bytes.length, bytes));
    }
    final tmp = await getTemporaryDirectory();
    final out = '${tmp.path}/${Config.bundleName}';
    await File(out).writeAsBytes(ZipEncoder().encode(archive)!);
    return out;
  }

  Future<List<String>> _unbundle(String zipPath, String dest) async {
    final archive = ZipDecoder().decodeBytes(await File(zipPath).readAsBytes());
    final paths = <String>[];
    for (final f in archive) {
      if (f.isFile) {
        final p = '$dest/${f.name}';
        await File(p).writeAsBytes(f.content as List<int>);
        paths.add(p);
      }
    }
    return paths;
  }

  // ── Resume helpers ───────────────────────────────────────
  Future<Map<int, Set<int>>> _loadResume(String tid) async {
    try {
      final f = File('${(await getTemporaryDirectory()).path}/bb_resume_$tid.json');
      if (!f.existsSync()) return {};
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return j.map((k, v) => MapEntry(int.parse(k), Set<int>.from((v as List).cast<int>())));
    } catch (_) { return {}; }
  }
  Future<void> _saveResume(String tid, List<FileItem> files) async {
    try {
      final f = File('${(await getTemporaryDirectory()).path}/bb_resume_$tid.json');
      await f.writeAsString(jsonEncode({for (final fi in files) fi.id.toString(): fi.completedChunks.toList()}));
    } catch (_) {}
  }
  Future<void> _deleteResume(String tid) async {
    try { File('${(await getTemporaryDirectory()).path}/bb_resume_$tid.json').deleteSync(); } catch (_) {}
  }

  // ── Save dir ─────────────────────────────────────────────
  Future<String> _saveDir() async {
    Directory? dir;
    if (Platform.isAndroid) dir = await getExternalStorageDirectory();
    dir ??= await getApplicationDocumentsDirectory();
    final p = '${dir.path}/ByteBeam';
    await Directory(p).create(recursive: true);
    return p;
  }

  // ── Read line from socket ────────────────────────────────
  Future<String> _readLine(Socket sock) async {
    final buf = <int>[];
    await for (final chunk in sock) {
      buf.addAll(chunk);
      final nl = buf.indexOf(10);
      if (nl >= 0) {
        final line = utf8.decode(buf.sublist(0, nl)).trim();
        buf.removeRange(0, nl + 1);
        return line;
      }
    }
    return utf8.decode(buf).trim();
  }

  void dispose() {
    stopListening();
    _sendQueue?.cancelled = true;
  }
}
