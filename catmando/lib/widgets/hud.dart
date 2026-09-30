import 'package:flutter/material.dart';

import '../game/cat_stack_game.dart';
import '../game/game_state.dart';
import '../l10n/app_strings.dart';

class Hud extends StatelessWidget {
  const Hud(this.game, {super.key});

  final CatStackGame game;

  static const _scoreStyle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    shadows: [
      Shadow(blurRadius: 4, color: Colors.black54),
    ],
  );

  static const _hintStyle = TextStyle(
    fontSize: 16,
    color: Colors.white,
    shadows: [
      Shadow(blurRadius: 4, color: Colors.black54),
    ],
  );

  bool get _showDropHint =>
      game.score == 0 && game.phase == CatStackPhase.swinging;

  @override
  Widget build(BuildContext context) {
    if (game.phase == CatStackPhase.gameOver) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppStrings.best}: ${game.highScore}',
                  style: _scoreStyle,
                ),
                Text(
                  '${AppStrings.score}: ${game.score}',
                  style: _scoreStyle,
                ),
              ],
            ),
            if (_showDropHint || game.phase == CatStackPhase.stabilizing) ...[
              const SizedBox(height: 10),
              Text(
                game.phase == CatStackPhase.stabilizing
                    ? AppStrings.stabilizing
                    : AppStrings.tapToDrop,
                textAlign: TextAlign.center,
                style: _hintStyle.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
