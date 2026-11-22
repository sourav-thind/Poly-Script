// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:window_manager/legacy.dart';

import 'widgets/subtitle_overlay.dart';

const Size _kWindowSize = Size(800, 160);
const Size _kMinimumWindowSize = Size(420, 160);
const double _kBottomMargin = 48;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: _kWindowSize,
    center: false,
    alwaysOnTop: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions);

  // Frameless, transparent, always-on-top overlay.
  await windowManager.setAsFrameless();
  await windowManager.setAlwaysOnTop(true);
  await windowManager.setBackgroundColor(Colors.transparent);

  await windowManager.setMinimumSize(_kMinimumWindowSize);
  await windowManager.setMaximumSize(Size.zero);
  await windowManager.setResizable(true);

  // Place it near the bottom of the current display.
  final bottomPosition =
      await calcWindowPosition(_kWindowSize, Alignment.bottomCenter);
  await windowManager.setPosition(
    Offset(bottomPosition.dx, bottomPosition.dy - _kBottomMargin),
  );

  await windowManager.show();
  await windowManager.focus();

  runApp(const PolyCriptApp());
}

class PolyCriptApp extends StatelessWidget {
  const PolyCriptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'poly_cript',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const SubtitleOverlay(),
    );
  }
}
