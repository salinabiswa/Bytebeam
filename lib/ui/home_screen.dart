import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import 'theme.dart';
import 'transfer_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (ctx, state, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (state.pendingIncoming != null) _showIncoming(context, state);
        if (state.activeTransfer != null && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransferScreen()));
        }
      });
      return Scaffold(
        backgroundColor: BB.bg,
        body: SafeArea(child: Column(children: [
          _buildAppBar(state),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _MyDeviceCard(state: state),
              const SizedBox(height: 16),
              _NearbySection(state: state),
              if (state.selectedFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                _FileQueueCard(state: state),
              ],
              const SizedBox(height: 16),
              _HowItWorks(),
            ]),
          )),
        ])),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: state.pickFiles,
          backgroundColor: BB.accent, foregroundColor: Colors.black,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Select Files', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
    });
  }

  Widget _buildAppBar(AppState state) => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: const BoxDecoration(color: BB.bg2, border: Border(bottom: BorderSide(color: BB.border))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      RichText(text: const TextSpan(children: [
        TextSpan(text: 'BYTE', style: TextStyle(color: BB.accent, fontFamily: BB.mono, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2)),
        TextSpan(text: 'BEAM ⚡', style: TextStyle(color: BB.text2, fontFamily: BB.mono, fontSize: 16, letterSpacing: 2)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: BB.bg3, border: Border.all(color: BB.border), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state.nearbyDevices.isNotEmpty ? BB.green : BB.text3,
            boxShadow: state.nearbyDevices.isNotEmpty ? [const BoxShadow(color: Color(0x6600E87A), blurRadius: 6)] : null,
          )),
          const SizedBox(width: 7),
          Text(
            state.nearbyDevices.isNotEmpty ? '${state.nearbyDevices.length} nearby' : 'searching…',
            style: const TextStyle(color: BB.text2, fontSize: 12, fontFamily: BB.mono)),
        ]),
      ),
    ]),
  );

  void _showIncoming(BuildContext context, AppState state) {
    showDialog(context: context, barrierDismissible: false,
      builder: (_) => _IncomingDialog(transfer: state.pendingIncoming!, state: state));
  }
}

// ── My Device ─────────────────────────────────────────────────

class _MyDeviceCard extends StatelessWidget {
  final AppState state;
  const _MyDeviceCard({required this.state});
  @override
  Widget build(BuildContext context) => _Card(child: Row(children: [
    Container(width: 40, height: 40,
      decoration: BoxDecoration(color: BB.accentD, border: Border.all(color: BB.accent.withOpacity(.3)), borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.phone_android_rounded, color: BB.accent, size: 20)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(state.deviceName, style: const TextStyle(color: BB.text, fontWeight: FontWeight.w600, fontSize: 15)),
      Text(state.localIp ?? 'getting IP…', style: const TextStyle(color: BB.text2, fontFamily: BB.mono, fontSize: 12)),
    ])),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: BB.greenD, border: Border.all(color: BB.green.withOpacity(.2)), borderRadius: BorderRadius.circular(999)),
      child: const Text('This device', style: TextStyle(color: BB.green, fontSize: 11, fontFamily: BB.mono)),
    ),
  ]));
}

// ── Nearby ────────────────────────────────────────────────────

class _NearbySection extends StatelessWidget {
  final AppState state;
  const _NearbySection({required this.state});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('Nearby Devices', style: TextStyle(color: BB.text, fontWeight: FontWeight.w600, fontSize: 15)),
      Text('${state.nearbyDevices.length} found', style: const TextStyle(color: BB.text3, fontSize: 12, fontFamily: BB.mono)),
    ]),
    const SizedBox(height: 10),
    if (state.nearbyDevices.isEmpty)
      _Card(child: Column(children: const [
        SizedBox(height: 8),
        Icon(Icons.wifi_find_rounded, color: BB.text3, size: 32),
        SizedBox(height: 8),
        Text('No devices found yet', style: TextStyle(color: BB.text2)),
        SizedBox(height: 4),
        Text('Open ByteBeam on the other device\non the same WiFi', textAlign: TextAlign.center,
          style: TextStyle(color: BB.text3, fontSize: 12, height: 1.5)),
        SizedBox(height: 8),
      ]))
    else
      ...state.nearbyDevices.map((d) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _DeviceCard(device: d, state: state))),
  ]);
}

class _DeviceCard extends StatelessWidget {
  final Device device; final AppState state;
  const _DeviceCard({required this.device, required this.state});
  @override
  Widget build(BuildContext context) => _Card(child: Row(children: [
    Container(width: 36, height: 36,
      decoration: BoxDecoration(color: BB.bg4, border: Border.all(color: BB.border), borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.devices_rounded, color: BB.text2, size: 18)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(device.name, style: const TextStyle(color: BB.text, fontWeight: FontWeight.w500, fontSize: 14)),
      Text(device.ip, style: const TextStyle(color: BB.text2, fontFamily: BB.mono, fontSize: 11)),
    ])),
    GestureDetector(
      onTap: () {
        if (state.selectedFiles.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Tap + to select files first'), backgroundColor: BB.bg3));
          return;
        }
        state.sendTo(device);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: state.selectedFiles.isEmpty ? BB.bg3 : BB.accent,
          border: Border.all(color: state.selectedFiles.isEmpty ? BB.border : BB.accent),
          borderRadius: BorderRadius.circular(7)),
        child: Text(
          state.selectedFiles.isEmpty ? 'Select files' : 'Send ↗',
          style: TextStyle(color: state.selectedFiles.isEmpty ? BB.text3 : Colors.black,
            fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    ),
  ]));
}

// ── File Queue ────────────────────────────────────────────────

class _FileQueueCard extends StatelessWidget {
  final AppState state;
  const _FileQueueCard({required this.state});
  @override
  Widget build(BuildContext context) {
    final total = state.selectedFiles.fold(0, (s, f) => s + (f.size ?? 0));
    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Ready to Send', style: TextStyle(color: BB.text, fontWeight: FontWeight.w600, fontSize: 14)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: BB.accentD, border: Border.all(color: BB.accent.withOpacity(.25)), borderRadius: BorderRadius.circular(999)),
          child: Text('${state.selectedFiles.length} files · ${AppState.fmtBytes(total)}',
            style: const TextStyle(color: BB.accent, fontSize: 11, fontFamily: BB.mono))),
      ]),
      const SizedBox(height: 10),
      ...state.selectedFiles.asMap().entries.map((e) {
        final f = e.value;
        final ext = f.name.contains('.') ? f.name.split('.').last.toUpperCase() : '—';
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: BB.bg3, border: Border.all(color: BB.border), borderRadius: BorderRadius.circular(7)),
          child: Row(children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(color: BB.bg4, border: Border.all(color: BB.border), borderRadius: BorderRadius.circular(6)),
              child: Center(child: Text(ext.length > 4 ? ext.substring(0,4) : ext,
                style: const TextStyle(color: BB.accent, fontSize: 9, fontFamily: BB.mono, fontWeight: FontWeight.w700)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: BB.text, fontSize: 13, fontWeight: FontWeight.w500)),
              Text(AppState.fmtBytes(f.size ?? 0), style: const TextStyle(color: BB.text2, fontSize: 11, fontFamily: BB.mono)),
            ])),
            GestureDetector(onTap: () => state.removeFile(e.key),
              child: const Icon(Icons.close_rounded, color: BB.text3, size: 16)),
          ]),
        );
      }),
      const SizedBox(height: 4),
      GestureDetector(onTap: state.clearFiles,
        child: const Text('Clear all', style: TextStyle(color: BB.text3, fontSize: 12))),
    ]));
  }
}

// ── How it works ──────────────────────────────────────────────

class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('HOW IT WORKS', style: TextStyle(color: BB.text3, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
    const SizedBox(height: 12),
    _step('1', 'Open ByteBeam on both devices on the same WiFi'),
    _step('2', 'Devices find each other automatically — no codes needed'),
    _step('3', 'Tap + to select files, then tap a device name to send'),
    _step('4', 'Files go directly device-to-device. Nothing touches the internet.'),
  ]));

  Widget _step(String n, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 18, height: 18,
        decoration: BoxDecoration(color: BB.accentD, borderRadius: BorderRadius.circular(999)),
        child: Center(child: Text(n, style: const TextStyle(color: BB.accent, fontSize: 11)))),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(color: BB.text2, fontSize: 13, height: 1.5))),
    ]));
}

// ── Incoming dialog ───────────────────────────────────────────

class _IncomingDialog extends StatelessWidget {
  final Transfer transfer; final AppState state;
  const _IncomingDialog({required this.transfer, required this.state});
  @override
  Widget build(BuildContext context) {
    final count = transfer.totalOriginalFiles;
    return Dialog(
      backgroundColor: BB.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: BB.border)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 50, height: 50,
          decoration: BoxDecoration(color: BB.accentD, border: Border.all(color: BB.accent.withOpacity(.3)), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.download_rounded, color: BB.accent, size: 26)),
        const SizedBox(height: 14),
        const Text('Incoming Transfer', style: TextStyle(color: BB.text, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('${transfer.peer.name} wants to send you', style: const TextStyle(color: BB.text2, fontSize: 13)),
        const SizedBox(height: 4),
        Text('$count file${count>1?"s":""} · ${AppState.fmtBytes(transfer.totalBytes)}',
          style: const TextStyle(color: BB.accent, fontFamily: BB.mono, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _outlineBtn('Decline', () { Navigator.pop(context); state.declineIncoming(); })),
          const SizedBox(width: 10),
          Expanded(child: _primaryBtn('Accept ↓', () { Navigator.pop(context); state.acceptIncoming(); })),
        ]),
      ])),
    );
  }
}

// ── Shared ────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: BB.bg2, border: Border.all(color: BB.border), borderRadius: BorderRadius.circular(10)),
    child: child);
}

Widget _primaryBtn(String label, VoidCallback onTap) => GestureDetector(onTap: onTap,
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(color: BB.accent, borderRadius: BorderRadius.circular(8)),
    child: Center(child: Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14)))));

Widget _outlineBtn(String label, VoidCallback onTap) => GestureDetector(onTap: onTap,
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(border: Border.all(color: BB.border2), borderRadius: BorderRadius.circular(8)),
    child: Center(child: Text(label, style: const TextStyle(color: BB.text2, fontWeight: FontWeight.w500, fontSize: 14)))));
