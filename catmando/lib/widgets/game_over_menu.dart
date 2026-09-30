import 'dart:ui';

import 'package:flutter/material.dart';

import '../game/cat_stack_game.dart';
import '../l10n/app_strings.dart';

class GameOverMenu extends StatelessWidget {
  const GameOverMenu(this.game, {super.key});

  final CatStackGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ModalBarrier(
          color: Colors.black.withValues(alpha: 0.35),
          dismissible: false,
        ),
        Center(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Card(
              color: Colors.black.withValues(alpha: 0.75),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.towerCollapsed,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${AppStrings.score}: ${game.score}',
                      style: const TextStyle(fontSize: 24, color: Colors.white70),
                    ),
                    Text(
                      '${AppStrings.best}: ${game.highScore}',
                      style: const TextStyle(fontSize: 18, color: Colors.white54),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: game.restart,
                      icon: const Icon(Icons.refresh),
                      label: Text(AppStrings.playAgain),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
