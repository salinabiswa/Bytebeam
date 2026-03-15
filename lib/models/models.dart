class Device {
  final String id;
  final String name;
  final String ip;
  DateTime lastSeen;

  Device({required this.id, required this.name, required this.ip, required this.lastSeen});

  factory Device.fromJson(Map<String, dynamic> j) => Device(
    id: j['id'] as String, name: j['name'] as String,
    ip: j['ip'] as String, lastSeen: DateTime.now());

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'ip': ip};

  @override bool operator ==(Object o) => o is Device && o.id == id;
  @override int get hashCode => id.hashCode;
}

class FileItem {
  final int    id;
  final String name;
  final int    size;
  final String? path;
  final bool   isBundle;
  final List<String> bundledNames;
  int  doneChunks = 0;
  int  totalChunks = 0;
  final Set<int> completedChunks = {};

  FileItem({required this.id, required this.name, required this.size,
    this.path, this.isBundle = false, this.bundledNames = const []}) {
    totalChunks = (size / 4194304).ceil();
    if (totalChunks == 0) totalChunks = 1;
  }

  double get progress => totalChunks > 0 ? doneChunks / totalChunks : 0.0;
  bool   get isDone   => doneChunks >= totalChunks;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'size': size,
    'totalChunks': totalChunks, 'isBundle': isBundle, 'bundledNames': bundledNames,
  };

  factory FileItem.fromJson(Map<String, dynamic> j) {
    final f = FileItem(id: j['id'] as int, name: j['name'] as String,
      size: j['size'] as int, isBundle: j['isBundle'] as bool? ?? false,
      bundledNames: (j['bundledNames'] as List?)?.cast<String>() ?? []);
    f.totalChunks = j['totalChunks'] as int;
    return f;
  }
}

enum TransferStatus { pending, active, paused, completed, failed, cancelled }

class Transfer {
  final String id;
  final Device peer;
  final bool   isSending;
  final List<FileItem> files;
  TransferStatus status;
  final DateTime startTime = DateTime.now();
  int    totalBytes       = 0;
  int    transferredBytes = 0;
  double speedBps         = 0;
  String? errorMessage;

  Transfer({required this.id, required this.peer,
    required this.isSending, required this.files,
    this.status = TransferStatus.pending}) {
    totalBytes = files.fold(0, (s, f) => s + f.size);
  }

  double get progress    => totalBytes > 0 ? transferredBytes / totalBytes : 0.0;
  int    get elapsedSecs => DateTime.now().difference(startTime).inSeconds;
  double get etaSecs     => speedBps > 0 ? (totalBytes - transferredBytes) / speedBps : 0;
  int    get totalOriginalFiles =>
    files.fold(0, (s, f) => s + (f.isBundle ? f.bundledNames.length : 1));
}
