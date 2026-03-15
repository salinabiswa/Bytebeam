import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BB {
  static const bg      = Color(0xFF07090F);
  static const bg2     = Color(0xFF0D111C);
  static const bg3     = Color(0xFF131927);
  static const bg4     = Color(0xFF1A2236);
  static const border  = Color(0xFF1E2D45);
  static const border2 = Color(0xFF243451);
  static const accent  = Color(0xFF00CFFF);
  static const accentD = Color(0x1F00CFFF);
  static const green   = Color(0xFF00E87A);
  static const greenD  = Color(0x1900E87A);
  static const amber   = Color(0xFFFFB640);
  static const red     = Color(0xFFFF4F5E);
  static const text    = Color(0xFFDCE6F5);
  static const text2   = Color(0xFF7A8FB0);
  static const text3   = Color(0xFF3D5070);
  static const mono    = 'monospace';
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: BB.bg,
  colorScheme: const ColorScheme.dark(primary: BB.accent, surface: BB.bg2, onSurface: BB.text),
  appBarTheme: const AppBarTheme(
    backgroundColor: BB.bg2, foregroundColor: BB.text, elevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light)),
  dividerColor: BB.border,
);
