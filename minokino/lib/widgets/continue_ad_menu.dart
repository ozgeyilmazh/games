import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/game/ad_manager.dart';
import '/game/dino_run.dart';
import '/models/player_data.dart';

class ContinueAdMenu extends StatefulWidget {
  static const id = 'ContinueAdMenu';

  final DinoRun game;

  const ContinueAdMenu(this.game, {super.key});

  @override
  State<ContinueAdMenu> createState() => _ContinueAdMenuState();
}

class _ContinueAdMenuState extends State<ContinueAdMenu> {
  bool _isBusy = false;

  static final _buttonStyle = ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    minimumSize: const Size(280, 56),
  );

  @override
  void initState() {
    super.initState();
    AdManager.instance.loadRewardedAd();
  }

  Future<void> _watchAdAndContinue() async {
    if (_isBusy) {
      return;
    }

    setState(() => _isBusy = true);

    await AdManager.instance.watchRewardedAd(
      onRewardGranted: widget.game.onAdContinueReward,
      onClosedWithoutReward: widget.game.onAdContinueCancelled,
      onFailed: widget.game.onAdContinueCancelled,
    );

    if (mounted && !widget.game.adSessionRewardHandled) {
      setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.game.playerData,
      child: Center(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: Colors.black.withAlpha(100),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 24,
                horizontal: 28,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Game Over',
                      style: TextStyle(fontSize: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Selector<PlayerData, int>(
                      selector: (_, playerData) => playerData.currentScore,
                      builder: (_, score, __) {
                        return Text(
                          'Score: $score',
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.game.adRevivesRemaining > 0
                          ? 'Watch one ad to continue.\n${widget.game.adRevivesRemaining} left this run.'
                          : 'No continues left.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: _buttonStyle,
                      onPressed: _isBusy ? null : _watchAdAndContinue,
                      child: Text(
                        _isBusy ? 'Loading ad...' : 'Watch Ad & Continue',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: _buttonStyle,
                      onPressed: widget.game.showFinalGameOver,
                      child: const Text(
                        'Quit',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
