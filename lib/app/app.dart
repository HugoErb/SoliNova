import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/screens/home_shell.dart';
import 'game_controller.dart';
import 'providers.dart';

/// Application SoliNova.
class SoliNovaApp extends ConsumerStatefulWidget {
  const SoliNovaApp({super.key});

  @override
  ConsumerState<SoliNovaApp> createState() => _SoliNovaAppState();
}

class _SoliNovaAppState extends ConsumerState<SoliNovaApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final game = ref.read(gameProvider.notifier);
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(game.setForeground(true));
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Sauvegarde immédiate : la partie reprendra exactement ici.
        unawaited(game.setForeground(false));
        unawaited(ref.read(profileProvider.notifier).flush());
    }
  }

  @override
  void didChangePlatformBrightness() {
    ref
        .read(platformBrightnessProvider.notifier)
        .set(WidgetsBinding.instance.platformDispatcher.platformBrightness);
  }

  @override
  Widget build(BuildContext context) {
    final look = ref.watch(lookProvider);
    final dark = look.theme.isDark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
    );
    return MaterialApp(
      title: 'SoliNova',
      debugShowCheckedModeBanner: false,
      theme: look.theme.toMaterial(),
      themeAnimationDuration: const Duration(milliseconds: 450),
      themeAnimationCurve: Curves.easeOutCubic,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeShell(),
    );
  }
}
