import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import 'theme.dart';

class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (ctx, state, _) {
      final t = state.activeTransfer ?? (state.transfers.isNotEmpty ? state.transfers.last : null);
      if (t == null) return Scaffold(backgroundColor: BB.bg, appBar: AppBar(title: const Text('Transfer')),
        body: const Center(child: Text('No transfer', style: TextStyle(color: BB.text2))));

      return WillPopScope(
        onWillPop: () async {
          if (t.status == TransferStatus.active || t.status == TransferStatus.paused) {
            return await _confirmCancel(context, state) ?? false;
          }
          return true;
        },
        child: Scaffold(
          backgroundColor: BB.bg,
          body: SafeArea(child: Column(children: [
            _appBar(context, t),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _PeerBanner(t: t),
                const SizedBox(height: 14),
                _OverallProgress(t: t),
                const SizedBox(height: 14),
                _StatsRow(t: t),
                const SizedBox(height: 14),
                _FilesList(t: t),
                if (t.status == TransferStatus.completed) ...[const SizedBox(height: 14), _CompleteBanner(t: t, state: state)],
                if (t.status == TransferStatus.failed)    ...[const SizedBox(height: 14), _ErrorBanner(t: t)],
              ]),
            )),
            if (t.status == TransferStatus.active || t.status == TransferStatus.paused)
              _ControlBar(t: t, state: state),
          ])),
        ),
      );
    });
  }

  Widget _appBar(BuildContext context, Transfer t) => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: const BoxDecoration(color: BB.bg2, border: Border(bottom: BorderSide(color: BB.border))),
    child: Row(children: [
      IconButton(icon: const Icon(Icons.arrow_back_rounded, color: BB.text2), onPressed: () => Navigator.pop(context)),
      RichText(text: const TextSpan(children: [
        TextSpan(text: 'BYTE', style: TextStyle(color: BB.accent, fontFamily: BB.mono, fontSize: 15, fontWeight: FontWeight.w800)),
        TextSpan(text: 'BEAM', style: TextStyle(color: BB.text2, fontFamily: BB.mono, fontSize: 15)),
      ])),
      const SizedBox(width: 8),
      _StatusChip(status: t.status),
    ]),
  );

  Future<bool?> _confirmCancel(BuildContext context, AppState state) => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: BB.bg2,
      title: const Text('Cancel transfer?', style: TextStyle(color: BB.text)),
      content: const Text('You can resume it later.', style: TextStyle(color: BB.text2)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep going', style: TextStyle(color: BB.accent))),
        TextButton(onPressed: () { state.cancelActive(); Navigator.pop(context, true); },
          child: const Text('Cancel', style: TextStyle(color: BB.red))),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final TransferStatus status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      TransferStatus.active    => ('● Live',      BB.accent, BB.accentD),
      TransferStatus.paused    => ('⏸ Paused',    BB.amber,  Color(0x1FFFB640)),
      TransferStatus.completed => ('✓ Done',       BB.green,  BB.greenD),
      TransferStatus.failed    => ('✕ Failed',     BB.red,    Color(0x1FFF4F5E)),
      TransferStatus.cancelled => ('✕ Cancelled',  BB.text3,  BB.bg3),
      _                        => ('… Pending',    BB.text3,  BB.bg3),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.3))),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontFamily: BB.mono)));
  }
}

class _PeerBanner extends StatelessWidget {
  final Transfer t;
  const _PeerBanner({required this.t});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: BB.greenD, border: Border.all(color: BB.green.withOpacity(.2)), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: BB.green,
        boxShadow: [BoxShadow(color: Color(0x6600E87A), blurRadius: 6)])),
      const SizedBox(width: 10),
      Text(t.isSending ? 'Sending to ${t.peer.name}' : 'Receiving from ${t.peer.name}',
        style: const TextStyle(color: Color(0xFF9EFFC8), fontSize: 13)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: BB.green.withOpacity(.12), border: Border.all(color: BB.green.withOpacity(.2)), borderRadius: BorderRadius.circular(999)),
        child: const Text('Direct · Encrypted', style: TextStyle(color: BB.green, fontSize: 10, fontFamily: BB.mono))),
    ]),
  );
}

class _OverallProgress extends StatelessWidget {
  final Transfer t;
  const _OverallProgress({required this.t});
  @override
  Widget build(BuildContext context) {
    final pct = (t.progress * 100).clamp(0.0, 100.0);
    return _Card(child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${t.isSending ? "Sending" : "Receiving"} ${t.totalOriginalFiles} file${t.totalOriginalFiles>1?"s":""}',
          style: const TextStyle(color: BB.text, fontWeight: FontWeight.w600, fontSize: 14)),
        Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(color: BB.accent, fontFamily: BB.mono, fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 10),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
        value: t.progress.clamp(0.0, 1.0), minHeight: 8, backgroundColor: BB.bg4,
        valueColor: AlwaysStoppedAnimation(t.status == TransferStatus.completed ? BB.green : BB.accent))),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(AppState.fmtBytes(t.transferredBytes), style: const TextStyle(color: BB.text2, fontSize: 12, fontFamily: BB.mono)),
        Text(AppState.fmtBytes(t.totalBytes), style: const TextStyle(color: BB.text3, fontSize: 12, fontFamily: BB.mono)),
      ]),
    ]));
  }
}

class _StatsRow extends StatelessWidget {
  final Transfer t;
  const _StatsRow({required this.t});
  @override
  Widget build(BuildContext context) => Row(children: [
    _S('SPEED', AppState.fmtSpeed(t.speedBps)),
    const SizedBox(width: 8),
    _S('ETA',   AppState.fmtEta(t.etaSecs)),
    const SizedBox(width: 8),
    _S('TIME',  '${t.elapsedSecs}s'),
    const SizedBox(width: 8),
    _S('FILES', '${t.files.where((f)=>f.isDone).length}/${t.files.length}'),
  ]);
}

class _S extends StatelessWidget {
  final String label, value;
  const _S(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: BB.bg3, border: Border.all(color: BB.border), borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(value, style: const TextStyle(color: BB.accent, fontFamily: BB.mono, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(color: BB.text3, fontSize: 10, letterSpacing: 1)),
    ])));
}

class _FilesList extends StatelessWidget {
  final Transfer t;
  const _FilesList({required this.t});
  @override
  Widget build(BuildContext context) => _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Files', style: TextStyle(color: BB.text, fontWeight: FontWeight.w600, fontSize: 14)),
    const SizedBox(height: 10),
    ...t.files.map((f) {
      final name = f.isBundle ? '📦 ${f.bundledNames.length} small files (bundled)' : f.name;
      final ext  = f.name.contains('.') ? f.name.split('.').last.toUpperCase() : '—';
      final pct  = (f.progress * 100).clamp(0.0, 100.0);
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: BB.bg3, border: Border.all(color: BB.border), borderRadius: BorderRadius.circular(7)),
        child: Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: BB.bg4, border: Border.all(color: BB.border), borderRadius: BorderRadius.circular(6)),
            child: Center(child: Text(f.isBundle ? '📦' : (ext.length>4?ext.substring(0,4):ext),
              style: const TextStyle(color: BB.accent, fontSize: 9, fontFamily: BB.mono, fontWeight: FontWeight.w700)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: BB.text, fontSize: 12, fontWeight: FontWeight.w500)),
            Text(AppState.fmtBytes(f.size), style: const TextStyle(color: BB.text2, fontSize: 10, fontFamily: BB.mono)),
            const SizedBox(height: 5),
            ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(
              value: f.progress.clamp(0.0, 1.0), minHeight: 3, backgroundColor: BB.bg4,
              valueColor: AlwaysStoppedAnimation(f.isDone ? BB.green : BB.accent))),
          ])),
          const SizedBox(width: 8),
          Text('${pct.toStringAsFixed(0)}%', style: TextStyle(color: f.isDone ? BB.green : BB.text2, fontFamily: BB.mono, fontSize: 11)),
        ]),
      );
    }),
  ]));
}

class _ControlBar extends StatelessWidget {
  final Transfer t; final AppState state;
  const _ControlBar({required this.t, required this.state});
  @override
  Widget build(BuildContext context) {
    final paused = t.status == TransferStatus.paused;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(color: BB.bg2, border: Border(top: BorderSide(color: BB.border))),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: paused ? state.resumeActive : state.pauseActive,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: BB.accentD, border: Border.all(color: BB.accent.withOpacity(.3)), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: BB.accent, size: 18),
              const SizedBox(width: 6),
              Text(paused ? 'Resume' : 'Pause', style: const TextStyle(color: BB.accent, fontWeight: FontWeight.w600)),
            ])),
        )),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () async {
            final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
              backgroundColor: BB.bg2,
              title: const Text('Cancel?', style: TextStyle(color: BB.text)),
              content: const Text('You can resume later.', style: TextStyle(color: BB.text2)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep going', style: TextStyle(color: BB.accent))),
                TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Cancel', style: TextStyle(color: BB.red))),
              ],
            ));
            if (ok == true && context.mounted) { state.cancelActive(); Navigator.pop(context); }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0x1FFF4F5E), border: Border.all(color: BB.red.withOpacity(.3)), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.close_rounded, color: BB.red, size: 20)),
        ),
      ]),
    );
  }
}

class _CompleteBanner extends StatelessWidget {
  final Transfer t; final AppState state;
  const _CompleteBanner({required this.t, required this.state});
  @override
  Widget build(BuildContext context) {
    final avg = t.elapsedSecs > 0 ? AppState.fmtSpeed(t.totalBytes / t.elapsedSecs) : '—';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: BB.greenD, border: Border.all(color: BB.green.withOpacity(.2)), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(width: 50, height: 50,
          decoration: BoxDecoration(color: BB.green.withOpacity(.12), border: Border.all(color: BB.green.withOpacity(.3)), borderRadius: BorderRadius.circular(999)),
          child: const Icon(Icons.check_rounded, color: BB.green, size: 28)),
        const SizedBox(height: 12),
        const Text('Transfer Complete!', style: TextStyle(color: BB.text, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('${t.totalOriginalFiles} files · ${AppState.fmtBytes(t.totalBytes)} · ${t.elapsedSecs}s · avg $avg',
          style: const TextStyle(color: BB.green, fontFamily: BB.mono, fontSize: 12)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () { state.clearFiles(); Navigator.pop(context); },
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: BB.greenD, border: Border.all(color: BB.green.withOpacity(.3)), borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('Back to Home', style: TextStyle(color: BB.green, fontWeight: FontWeight.w600))))),
      ]),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final Transfer t;
  const _ErrorBanner({required this.t});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0x1FFF4F5E), border: Border.all(color: BB.red.withOpacity(.3)), borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: BB.red, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(t.errorMessage ?? 'Transfer failed', style: const TextStyle(color: BB.red, fontSize: 13))),
    ]));
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: BB.bg2, border: Border.all(color: BB.border), borderRadius: BorderRadius.circular(10)),
    child: child);
}
