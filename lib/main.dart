import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'alarm_bridge.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmBridge.init();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0C0A24),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const SleepifyApp());
}

class SleepifyApp extends StatelessWidget {
  const SleepifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sleepify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0C0A24),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7B5BFF)),
      ),
      home: const SleepifyShell(),
    );
  }
}

class SleepifyShell extends StatefulWidget {
  const SleepifyShell({super.key});

  @override
  State<SleepifyShell> createState() => _SleepifyShellState();
}

class _SleepifyShellState extends State<SleepifyShell> with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0C0A24))
      ..addJavaScriptChannel('Sleepify', onMessageReceived: _onWebMessage)
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) async {
          if (!mounted) return;
          setState(() => _ready = true);
          await _deliverFiredAlarm();
        }),
      )
      ..loadFlutterAsset('assets/web/index.html');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ready) _deliverFiredAlarm();
  }

  /// Web'den gelen mesajlar
  void _onWebMessage(JavaScriptMessage message) async {
    try {
      final msg = jsonDecode(message.message) as Map<String, dynamic>;
      switch (msg['type']) {
        case 'sync':
          final n = await AlarmBridge.sync(msg['alarms'] as List<dynamic>);
          debugPrint('Sleepify: $n alarm sisteme yazıldı');
          break;
        case 'wakelock':
          msg['on'] == true
              ? await WakelockPlus.enable()
              : await WakelockPlus.disable();
          break;
        case 'dismissed':
          await AlarmBridge.clearNotifications();
          break;
      }
    } catch (e) {
      debugPrint('Sleepify köprü hatası: $e');
    }
  }

  /// Arka planda çalan alarmı web arayüzünde de aç
  Future<void> _deliverFiredAlarm() async {
    final id = await AlarmBridge.takeFired();
    if (id == null) return;
    await _controller.runJavaScript('window.SleepifyFire && window.SleepifyFire($id)');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (!_ready)
                const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF2B6BFF),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
