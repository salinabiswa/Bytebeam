import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'ui/theme.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF07090F),
  ));
  runApp(ChangeNotifierProvider(
    create: (_) => AppState()..init(),
    child: const ByteBeamApp(),
  ));
}

class ByteBeamApp extends StatelessWidget {
  const ByteBeamApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ByteBeam',
    theme: buildTheme(),
    debugShowCheckedModeBanner: false,
    home: Consumer<AppState>(builder: (_, state, __) =>
      state.isInitialized ? const HomeScreen() : const _Splash()),
  );
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF07090F),
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 72, height: 72,
        decoration: BoxDecoration(
          color: const Color(0x1F00CFFF),
          border: Border.all(color: const Color(0x6600CFFF)),
          borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.bolt_rounded, color: Color(0xFF00CFFF), size: 40)),
      const SizedBox(height: 20),
      RichText(text: const TextSpan(children: [
        TextSpan(text: 'BYTE', style: TextStyle(color: Color(0xFF00CFFF), fontFamily: 'monospace', fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 4)),
        TextSpan(text: 'BEAM', style: TextStyle(color: Color(0xFF7A8FB0), fontFamily: 'monospace', fontSize: 28, letterSpacing: 4)),
      ])),
      const SizedBox(height: 8),
      const Text('Fast P2P File Transfer', style: TextStyle(color: Color(0xFF3D5070), fontSize: 13, letterSpacing: 1)),
      const SizedBox(height: 32),
      const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF00CFFF), strokeWidth: 2)),
    ])),
  );
}
