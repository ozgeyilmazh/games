import 'dart:ui';

import 'package:flutter/material.dart';

import '../game/ad_manager.dart';
import '../game/cat_stack_game.dart';
import '../l10n/app_strings.dart';

class ContinueAdMenu extends StatefulWidget {
  const ContinueAdMenu(this.game, {super.key});

  static const id = 'ContinueAdMenu';

  final CatStackGame game;

  @override
  State<ContinueAdMenu> createState() => _ContinueAdMenuState();
}

class _ContinueAdMenuState extends State<ContinueAdMenu> {
  bool _isBusy = false;
  String? _errorMessage;

  static final _buttonStyle = FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    minimumSize: const Size(280, 52),
  );

  Future<void> _watchAdAndContinue() async {
    if (_isBusy || widget.game.adSessionRewardHandled) return;

    _isBusy = true;
    _errorMessage = null;
    if (mounted) setState(() {});

    try {
      final started = await AdManager.instance.watchRewardedAd(
        onBeforeShow: widget.game.resumeForRewardedAd,
        onRewardGranted: widget.game.onAdContinueReward,
        onClosedWithoutReward: widget.game.onAdContinueCancelled,
        onFailed: () {
          widget.game.pauseForContinueMenu();
          if (mounted) {
            setState(() {
              _errorMessage =
                  AppStrings.adLoadFailed;
            });
          }
          AdManager.instance.loadRewardedAd(force: true);
        },
      );

      if (!started && mounted && !widget.game.adSessionRewardHandled) {
        widget.game.pauseForContinueMenu();
        setState(() {
          _errorMessage = AppStrings.pleaseWaitTapAgain;
        });
      }
    } finally {
      if (mounted && !widget.game.adSessionRewardHandled) {
        setState(() => _isBusy = false);
      }
    }
  }

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.towerCollapsed,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${AppStrings.score}: ${widget.game.score}',
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.game.adRevivesRemaining > 0
                            ? AppStrings.continuesLeft(
                                widget.game.adRevivesRemaining,
                              )
                            : AppStrings.noContinues,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        style: _buttonStyle,
                        onPressed: _isBusy ? null : _watchAdAndContinue,
                        child: Text(
                          _isBusy
                              ? AppStrings.loadingAd
                              : AppStrings.watchAdContinue,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white38),
                          minimumSize: const Size(280, 48),
                        ),
                        onPressed: widget.game.showFinalGameOver,
                        child: Text(AppStrings.quit),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
