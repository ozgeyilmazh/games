import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  AdManager._();

  static final AdManager instance = AdManager._();

  /// Cat Tower Android app ID.
  static const androidAppId = 'ca-app-pub-9860622398244947~7008531553';

  RewardedAd? _rewardedAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _watchInProgress = false;
  Timer? _watchdog;

  static String get rewardedAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313';
    }
    return Platform.isAndroid
        ? 'ca-app-pub-9860622398244947/5695449888'
        : 'ca-app-pub-3940256099942544/1712485313';
  }

  Future<void> init() async {
    await MobileAds.instance.initialize();
    loadRewardedAd();
  }

  bool get isRewardedAdLoaded => _isLoaded;

  /// Continue menüsü açılırken takılı kalmış oturumu sıfırla.
  void resetWatchSession() {
    _watchdog?.cancel();
    _watchdog = null;
    _watchInProgress = false;
  }

  void loadRewardedAd({bool force = false}) {
    if (!force && (_isLoading || _isLoaded)) return;

    if (force) {
      _rewardedAd?.dispose();
      _rewardedAd = null;
      _isLoaded = false;
      _isLoading = false;
    }

    _isLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdManager: rewarded ad loaded.');
          _rewardedAd = ad;
          _isLoaded = true;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint(
            'AdManager: load failed — ${error.code}: ${error.message}',
          );
          _rewardedAd = null;
          _isLoaded = false;
          _isLoading = false;
        },
      ),
    );
  }

  Future<bool> _waitForLoad({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_isLoaded && _rewardedAd != null) return true;

    final deadline = DateTime.now().add(timeout);
    var reloadAttempts = 0;

    while (DateTime.now().isBefore(deadline)) {
      if (_isLoaded && _rewardedAd != null) return true;

      if (!_isLoading) {
        final force = reloadAttempts > 0;
        loadRewardedAd(force: force);
        reloadAttempts++;
      }

      await Future.delayed(const Duration(milliseconds: 250));
    }

    return _isLoaded && _rewardedAd != null;
  }

  /// Reklam gösterimini başlatır. `false` = zaten oynatılıyor.
  Future<bool> watchRewardedAd({
    required VoidCallback onRewardGranted,
    required VoidCallback onClosedWithoutReward,
    VoidCallback? onFailed,
    VoidCallback? onBeforeShow,
  }) async {
    if (_watchInProgress) {
      debugPrint('AdManager: watch skipped — session already active.');
      return false;
    }

    _watchInProgress = true;
    var sessionFinished = false;

    void finishWatch() {
      if (sessionFinished) return;
      sessionFinished = true;
      _watchdog?.cancel();
      _watchdog = null;
      _watchInProgress = false;
    }

    _watchdog = Timer(const Duration(seconds: 90), () {
      debugPrint('AdManager: watch watchdog timed out.');
      finishWatch();
    });

    final loaded = await _waitForLoad();
    if (!loaded) {
      debugPrint('AdManager: no ad available after wait.');
      (onFailed ?? onClosedWithoutReward)();
      finishWatch();
      return true;
    }

    final ad = _rewardedAd!;
    var userEarnedReward = false;
    var adWasShown = false;
    var resultDelivered = false;

    void deliverResult(VoidCallback action) {
      if (resultDelivered) return;
      resultDelivered = true;
      action();
      finishWatch();
    }

    void cleanup(RewardedAd ad) {
      ad.dispose();
      _rewardedAd = null;
      _isLoaded = false;
      _isLoading = false;
      loadRewardedAd();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        adWasShown = true;
        debugPrint('AdManager: ad showing.');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AdManager: ad dismissed.');
        cleanup(ad);
        if (userEarnedReward) {
          deliverResult(onRewardGranted);
        } else if (adWasShown) {
          deliverResult(onClosedWithoutReward);
        } else {
          deliverResult(onClosedWithoutReward);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdManager: show failed — ${error.message}');
        cleanup(ad);
        deliverResult(onFailed ?? onClosedWithoutReward);
      },
    );

    onBeforeShow?.call();

    try {
      debugPrint('AdManager: calling show().');
      ad.show(onUserEarnedReward: (_, _) {
        userEarnedReward = true;
        debugPrint('AdManager: user earned reward.');
      });
    } catch (error, stackTrace) {
      debugPrint('AdManager: show threw — $error\n$stackTrace');
      cleanup(ad);
      deliverResult(onFailed ?? onClosedWithoutReward);
    }

    return true;
  }
}
