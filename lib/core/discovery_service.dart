import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import '../core/constants.dart';
import '../models/models.dart';

class DiscoveryService {
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  String? _localIp;
  final String deviceId;
  final String deviceName;
  final Map<String, Device> _devices = {};
  void Function(Device)? onDeviceFound;
  void Function(Device)? onDeviceLost;

  DiscoveryService({required this.deviceId, required this.deviceName});

  Future<String?> getLocalIp() async {
    try {
      final ip = await NetworkInfo().getWifiIP();
      if (ip != null) return ip;
    } catch (_) {}
    for (final iface in await NetworkInterface.list()) {
      for (final addr in iface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) return addr.address;
      }
    }
    return null;
  }

  Future<void> start() async {
    _localIp = await getLocalIp();
    if (_localIp == null) return;
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, Config.discoveryPort, reuseAddress: true);
      _socket!.broadcastEnabled = true;
      _socket!.listen((e) {
        if (e == RawSocketEvent.read) {
          final dg = _socket!.receive();
          if (dg != null) _handlePacket(dg);
        }
      });
      _broadcastTimer = Timer.periodic(
        Duration(seconds: Config.discoveryIntervalSec), (_) => _broadcast());
      _cleanupTimer = Timer.periodic(const Duration(seconds: 3), (_) => _cleanup());
      _broadcast();
    } catch (_) {}
  }

  void _broadcast() {
    if (_socket == null || _localIp == null) return;
    final data = utf8.encode(jsonEncode({'id': deviceId, 'name': deviceName, 'ip': _localIp}));
    try { _socket!.send(data, InternetAddress('255.255.255.255'), Config.discoveryPort); } catch (_) {}
  }

  void _handlePacket(Datagram dg) {
    try {
      final d = Device.fromJson(jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>);
      if (d.id == deviceId) return;
      final isNew = !_devices.containsKey(d.id);
      _devices[d.id] = d;
      if (isNew) onDeviceFound?.call(d);
    } catch (_) {}
  }

  void _cleanup() {
    final cutoff = DateTime.now().subtract(Duration(seconds: Config.deviceTimeoutSec));
    final stale = _devices.entries.where((e) => e.value.lastSeen.isBefore(cutoff)).map((e) => e.key).toList();
    for (final id in stale) { final d = _devices.remove(id); if (d != null) onDeviceLost?.call(d); }
  }

  List<Device> get devices => _devices.values.toList();

  void stop() {
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _socket?.close();
  }
}
