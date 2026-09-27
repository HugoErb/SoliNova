import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/repositories.dart';
import 'data/storage.dart';
import 'engine/session/game_session.dart';
import 'ui/feedback/feedback_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final dir = await getApplicationSupportDirectory();
  final store = FileStore(Directory('${dir.path}/save'));
  final (profile, session) = await (
    ProfileRepository(store).load(),
    _loadSession(store),
  ).wait;

  final feedback = FeedbackService();
  runApp(
    ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(store),
        initialProfileProvider.overrideWithValue(profile),
        initialSessionProvider.overrideWithValue(session),
        feedbackProvider.overrideWithValue(feedback),
      ],
      child: const SoliNovaApp(),
    ),
  );
  // Les sons se chargent après le premier affichage.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(feedback.preload());
  });
}

Future<GameSession?> _loadSession(KeyValueStore store) async {
  try {
    return await GameRepository(store).loadOrNull();
  } on Object {
    return null;
  }
}
