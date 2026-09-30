import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  AdManager._();

  static final AdManager instance = AdManager._();

  RewardedAd? _rewardedAd;
  bool _isLoaded = false;
  bool _isLoading = false;

  static String get rewardedAdUnitId {
    if (kDebugMode) {
      // Test ad units (used while debugging to avoid invalid traffic).
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313';
    }
    // Production ad units.
    return Platform.isAndroid
        ? 'ca-app-pub-9860622398244947/8877060694'
        : 'ca-app-pub-3940256099942544/1712485313';
  }

  static String get bannerAdUnitId {
    if (kDebugMode) {
      // Test ad units (used while debugging to avoid invalid traffic).
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    }
    // Production ad units.
    return Platform.isAndroid
        ? 'ca-app-pub-9860622398244947/4106429839'
        : 'ca-app-pub-3940256099942544/2934735716';
  }

  Future<void> init() async {
    await MobileAds.instance.initialize();
    loadRewardedAd();
  }

  bool get isRewardedAdLoaded => _isLoaded;

  void loadRewardedAd() {
    if (_isLoading || _isLoaded) {
      return;
    }
    _isLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(nonPersonalizedAds: true),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoaded = true;
          _isLoading = false;
        },
        onAdFailedToLoad: (_) {
          _rewardedAd = null;
          _isLoaded = false;
          _isLoading = false;
        },
      ),
    );
  }

  Future<bool> _waitForLoad({Duration timeout = const Duration(seconds: 8)}) async {
    if (_isLoaded) {
      return true;
    }
    loadRewardedAd();
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_isLoaded) {
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return _isLoaded;
  }

  Future<void> watchRewardedAd({
    required VoidCallback onRewardGranted,
    required VoidCallback onClosedWithoutReward,
    VoidCallback? onFailed,
  }) async {
    final loaded = await _waitForLoad();
    if (!loaded) {
      if (kDebugMode) {
        debugPrint('AdManager: using debug ad simulation.');
        await Future.delayed(const Duration(milliseconds: 800));
        onRewardGranted();
        return;
      }
      (onFailed ?? onClosedWithoutReward)();
      return;
    }

    final ad = _rewardedAd!;
    var rewardEarned = false;
    var adWasShown = false;
    Timer? dismissTimer;

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
      },
      onAdDismissedFullScreenContent: (ad) {
        cleanup(ad);
        dismissTimer?.cancel();
        dismissTimer = Timer(const Duration(milliseconds: 500), () {
          if (rewardEarned) {
            return;
          }
          if (adWasShown) {
            onRewardGranted();
            return;
          }
          onClosedWithoutReward();
        });
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        dismissTimer?.cancel();
        cleanup(ad);
        if (!rewardEarned) {
          (onFailed ?? onClosedWithoutReward)();
        }
      },
    );

    ad.show(onUserEarnedReward: (_, __) {
      rewardEarned = true;
      dismissTimer?.cancel();
      onRewardGranted();
    });
  }
}
