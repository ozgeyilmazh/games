import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'game/ad_manager.dart';
import 'game/cat_stack_game.dart';
import 'game/score_storage.dart';
import 'l10n/app_strings.dart';
import 'l10n/locale_storage.dart';
import 'widgets/continue_ad_menu.dart';
import 'widgets/game_over_menu.dart';
import 'widgets/hud.dart';
import 'widgets/logo_shimmer_splash.dart';
import 'widgets/start_menu.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ScoreStorage.init();
  await LocaleStorage.init();
  if (!kIsWeb) {
    await AdManager.instance.init();
  }
  await _precacheLogo();
  runApp(const CatTowerApp());
}

Future<void> _precacheLogo() {
  final stream =
      const AssetImage('assets/images/logo.png').resolve(const ImageConfiguration());
  final completer = Completer<void>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (image, sync) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    },
    onError: (error, stackTrace) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

class CatTowerApp extends StatelessWidget {
  const CatTowerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppStrings.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const _StartupSplash(),
    );
  }
}

class _StartupSplash extends StatefulWidget {
  const _StartupSplash();

  @override
  State<_StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<_StartupSplash> {
  bool _showSplash = true;

  void _onSplashFinished() {
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSplash) return const GameScreen();
    return LogoShimmerSplash(onFinished: _onSplashFinished);
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<CatStackGame>.controlled(
        loadingBuilder: (context) => const ColoredBox(
          color: Colors.white,
          child: Center(
            child: SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFF213961),
                backgroundColor: Color(0xFFE8EDF3),
              ),
            ),
          ),
        ),
        overlayBuilderMap: {
          StartMenu.id: (context, game) => Positioned.fill(
                child: StartMenu(game),
              ),
          CatStackGame.hudOverlay: (context, game) => Hud(game),
          ContinueAdMenu.id: (context, game) => Positioned.fill(
                child: ContinueAdMenu(game),
              ),
          CatStackGame.gameOverOverlay: (context, game) =>
              GameOverMenu(game),
        },
        gameFactory: () {
          final game = CatStackGame();
          game.onStateChanged = () {
            if (mounted) setState(() {});
          };
          return game;
        },
      ),
    );
  }
}
