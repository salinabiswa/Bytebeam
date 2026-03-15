import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../core/discovery_service.dart';
import '../core/transfer_engine.dart';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  late String deviceId;
  late String deviceName;
  String?     localIp;

  List<Device>   nearbyDevices = [];
  List<Transfer> transfers     = [];
  Transfer?      activeTransfer;
  Transfer?      pendingIncoming;
  List<PlatformFile> selectedFiles = [];

  late DiscoveryService _discovery;
  late TransferEngine   _engine;
  final _uuid = const Uuid();
  bool _initialized = false;
  bool get isInitialized => _initialized;

  int    _lastBytes = 0;
  int    _lastMs    = 0;

  Future<void> init() async {
    await _requestPermissions();
    _generateIdentity();

    _discovery = DiscoveryService(deviceId: deviceId, deviceName: deviceName);
    _engine    = TransferEngine();

    _discovery.onDeviceFound = (d) {
      if (!nearbyDevices.any((x) => x.id == d.id)) {
        nearbyDevices = [...nearbyDevices, d];
        notifyListeners();
      }
    };
    _discovery.onDeviceLost = (d) {
      nearbyDevices = nearbyDevices.where((x) => x.id != d.id).toList();
      notifyListeners();
    };

    _engine.onIncomingTransfer = (t) {
      pendingIncoming = t;
      transfers.add(t);
      notifyListeners();
    };
    _engine.onUpdate = (u) {
      final t = _findTransfer(u.transferId);
      if (t != null) { _updateSpeed(t, u.bytesChunk); notifyListeners(); }
    };
    _engine.onReceiveComplete = (tid, _) {
      final t = _findTransfer(tid);
      if (t != null) t.status = TransferStatus.completed;
      activeTransfer = null;
      notifyListeners();
    };
    _engine.onSendComplete = (tid) {
      final t = _findTransfer(tid);
      if (t != null) t.status = TransferStatus.completed;
      activeTransfer = null;
      notifyListeners();
    };
    _engine.onError = (tid, err) {
      final t = _findTransfer(tid);
      if (t != null) { t.status = TransferStatus.failed; t.errorMessage = err; }
      activeTransfer = null;
      notifyListeners();
    };

    localIp = await _discovery.getLocalIp();
    await _discovery.start();
    await _engine.startListening();
    _initialized = true;
    notifyListeners();
  }

  void _updateSpeed(Transfer t, int newBytes) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastMs == 0) { _lastMs = now; _lastBytes = t.transferredBytes; return; }
    final dt = (now - _lastMs) / 1000.0;
    if (dt >= 0.2) {
      t.speedBps  = (t.transferredBytes - _lastBytes) / dt;
      _lastMs     = now;
      _lastBytes  = t.transferredBytes;
    }
  }

  Transfer? _findTransfer(String id) {
    try { return transfers.firstWhere((t) => t.id == id); } catch (_) { return null; }
  }

  Future<void> pickFiles() async {
    final r = await FilePicker.platform.pickFiles(allowMultiple: true, withData: false);
    if (r != null) { selectedFiles = r.files.where((f) => f.path != null).toList(); notifyListeners(); }
  }
  void removeFile(int i) { selectedFiles = [...selectedFiles]..removeAt(i); notifyListeners(); }
  void clearFiles()      { selectedFiles = []; notifyListeners(); }

  Future<void> sendTo(Device target) async {
    if (selectedFiles.isEmpty) return;
    final tid = _uuid.v4();
    final t   = Transfer(id: tid, peer: target, isSending: true, files: [], status: TransferStatus.active);
    transfers.add(t);
    activeTransfer = t;
    _lastMs = 0; _lastBytes = 0;
    notifyListeners();
    await _engine.sendFiles(
      target: target, transferId: tid, transfer: t, senderName: deviceName,
      files: selectedFiles.map((f) => (path: f.path!, name: f.name, size: f.size ?? 0)).toList());
  }

  void acceptIncoming() {
    if (pendingIncoming == null) return;
    pendingIncoming!.status = TransferStatus.active;
    activeTransfer = pendingIncoming;
    _lastMs = 0; _lastBytes = 0;
    _engine.acceptTransfer(pendingIncoming!.id);
    pendingIncoming = null;
    notifyListeners();
  }
  void declineIncoming() {
    if (pendingIncoming == null) return;
    _engine.declineTransfer(pendingIncoming!.id);
    transfers.remove(pendingIncoming);
    pendingIncoming = null;
    notifyListeners();
  }

  void pauseActive()  { _engine.pauseTransfer();  activeTransfer?.status = TransferStatus.paused;    notifyListeners(); }
  void resumeActive() { _engine.resumeTransfer(); activeTransfer?.status = TransferStatus.active;    notifyListeners(); }
  void cancelActive() { _engine.cancelTransfer(); activeTransfer?.status = TransferStatus.cancelled; activeTransfer = null; notifyListeners(); }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt >= 33) {
        await [Permission.photos, Permission.videos, Permission.audio].request();
      } else {
        await [Permission.storage].request();
      }
    } catch (_) {}
  }

  void _generateIdentity() {
    const adj  = ['Fast','Bold','Neon','Volt','Apex','Nova','Flux','Zap','Swift','Peak'];
    const noun = ['Hawk','Wolf','Ray','Bolt','Core','Edge','Link','Node','Beam','Byte'];
    final rng  = Random();
    deviceId   = _uuid.v4();
    deviceName = '${adj[rng.nextInt(adj.length)]}-${noun[rng.nextInt(noun.length)]}';
  }

  static String fmtBytes(int n) {
    if (n < 1024)       return '$n B';
    if (n < 1048576)    return '${(n/1024).toStringAsFixed(1)} KB';
    if (n < 1073741824) return '${(n/1048576).toStringAsFixed(1)} MB';
    return '${(n/1073741824).toStringAsFixed(2)} GB';
  }
  static String fmtSpeed(double bps) => '${fmtBytes(bps.toInt())}/s';
  static String fmtEta(double s) {
    if (s <= 0 || !s.isFinite) return '—';
    if (s < 60)   return '${s.ceil()}s';
    if (s < 3600) return '${(s/60).floor()}m ${(s%60).ceil()}s';
    return '${(s/3600).floor()}h ${((s%3600)/60).ceil()}m';
  }

  @override
  void dispose() { _discovery.stop(); _engine.dispose(); super.dispose(); }
}
