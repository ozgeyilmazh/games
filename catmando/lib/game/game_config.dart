import 'package:flame/extensions.dart';

/// Shared physics / layout constants (Forge2D world units).
class GameConfig {
  static const double zoom = 58;

  static final Vector2 gravity = Vector2(0,30);

  /// İpten bırakılınca yatay hız çarpanı (düşük = daha yumuşak iniş).
  static const double releaseVelocityScale = 0.52;

  /// Düşüş sırasında hava sönümü.
  static const double fallingLinearDamping = 0.85;
  static const double fallingAngularDamping = 4.0;

  static const int catSpriteCount = 21;

  /// Görsel kedi ölçeği (1 = tam boy). Yeni PNG’ler büyük olduğu için düşük tutulur.
  static const double catDisplayScale = 2.2;

  /// PNG piksel → dünya birimi (yüksek = kediler küçük görünür).
  static const double catPixelsPerWorldUnit = 161 / catDisplayScale;

  /// Oturan kedi: alttaki kedinin omuz/sırt hattı (üstten oran).
  static const double catStackSupportSittingFromTop = 0.08;

  /// Yatan kedi: alttaki kedinin sırt hattı.
  static const double catStackSupportLyingFromTop = 0.16;

  /// Oturan kedi: üst kedinin pati hattı (üstten oran).
  static const double catStackFeetSittingFromTop = 0.84;

  /// Yatan kedi: üst kedinin pati hattı.
  static const double catStackFeetLyingFromTop = 0.78;

  /// Yerleşince ek dikey boşluk (dünya birimi + kedi yüksekliği oranı).
  static const double catStackVerticalGap = 0.04;
  static const double catStackVerticalGapRatio = 0.06;

  /// İp bağlantısı: oturan kedi — üst kenardan aşağı (içerik yüksekliği oranı).
  static const double ropeHookInsetSittingRatio = 0.22;

  /// İp bağlantısı: yatan kedi — sırt hattı.
  static const double ropeHookInsetLyingRatio = 0.36;

  /// İp pivotu: görünür alanın üstünden (HUD altı).
  static const double ropeTopInset = 1.4;

  /// İp uzunluğu: ekran yüksekliğinin oranı (viewport üzerinden hesaplanır).
  static const double ropeScreenHeightRatio = 0.34;

  /// Yatay sallanma genliği (dünya birimi) — biraz dar = nişan kolay.
  static const double swingHorizontal = 2.25;
  static const double swingOmegaBase = 1.72;

  /// Skor arttıkça ip hızı belirgin artsın (kolay başlangıç → hızlanan ritim).
  static const double speedFactorAt0 = 1.0;
  static const double speedFactorAt10 = 1.18;
  static const double speedFactorAt20 = 1.38;
  static const double speedFactorAt30 = 1.55;

  static double speedFactorForScore(int score) {
    if (score >= 30) return speedFactorAt30;
    if (score >= 20) {
      final t = (score - 20) / 10.0;
      return speedFactorAt20 + (speedFactorAt30 - speedFactorAt20) * t;
    }
    if (score >= 10) {
      final t = (score - 10) / 10.0;
      return speedFactorAt10 + (speedFactorAt20 - speedFactorAt10) * t;
    }
    final t = score / 10.0;
    return speedFactorAt0 + (speedFactorAt10 - speedFactorAt0) * t;
  }

  static double swingOmegaForScore(int score) =>
      swingOmegaBase * speedFactorForScore(score);

  /// Bırakış yatay hızı — skorla biraz artsın ama aşırı fırlatmasın.
  static double releaseVelocityScaleForScore(int score) =>
      releaseVelocityScale *
      (1.0 + (speedFactorForScore(score) - 1.0) * 0.28);

  /// Kule ekran kenarından taşınca kamera kayar (görünür yarıçap oranı).
  static const double cameraEdgeMarginRatio = 0.12;

  static const double cameraPanMaxRatio = 0.55;
  /// Kamera kule tepesini hızlı takip etsin (sağa kayınca ortalanmayı kaçırmasın).
  static const double cameraPanSmooth = 0.14;

  static const double settleSpeed = 0.65;
  static const int settleFrames = 10;
  static const double missTimeout = 5.5;

  /// Kule sallanması bitene kadar beklenir.
  static const double stackStableSpeed = 0.5;
  static const double stackStableAngular = 0.55;
  static const int stackStableFrames = 4;

  /// Bu kadar eğimden az ise kedi direkt oturur (radyan, ~26°).
  static const double quickSettleMaxAngleRad = 0.45;

  /// Yerleşince izin verilen max eğim (radyan, ~11°).
  static const double maxSettledAngleRad = 0.2;

  /// İp beklerken üstte dynamic kalacak kedi sayısı; alttakiler static.
  static const int dynamicStackHeadCount = 3;

  /// En fazla bu kadar saniye sallanma beklenir, sonra devam edilir.
  static const double maxStabilizeSeconds = 5.5;

  /// Düşen kedi kuleye oturdu mu? (oyuncuyu çeken affedici oturma)
  static const double stackLandHorizontalFactor = 1.78;

  /// Weld / destek aramasında yatay örtüşme toleransı.
  static const double stackSupportOverlapFactor = 1.45;

  /// Ayak ile alt kedinin üst yüzeyi arası max boşluk (dünya birimi).
  static const double stackSupportMaxFeetGap = 1.25;

  /// Kule kaçırıldı — yatayda üst kediden bu kadar uzakta (genişlik çarpanı).
  static const double stackMissHorizontalFactor = 1.28;

  /// Düşerken kuleye doğru hafif çekim menzili (land reach çarpanı).
  static const double landingAssistReachFactor = 1.55;

  /// Düşerken yatay yardımcı çekim gücü.
  static const double landingAssistStrength = 9.5;

  /// Taban kedisine göre nişan/ip max yatay sapma (genişlik çarpanı).
  /// Aşırı yana kayınca ip ortalanır; yamuk ayakta kule game over olmaz.
  static const double maxStackLeanFromBaseFactor = 2.1;

  /// Aynı seviyede yan yana durma eşiği (genişlik çarpanı).
  static const double stackBesideHorizontalFactor = 0.78;

  /// Kule kaçırıldı / düştü — platform üstünden bu kadar aşağıda.
  static const double fellBelowPlatformTop = 1.6;

  /// Yerleşmiş kediler ip sallanırken (kilitli).
  static const double settledLinearDamping = 2.0;
  static const double settledAngularDamping = 3.0;

  /// Yeni kedi düşünce kule sallanırken.
  static const double wakingLinearDamping = 0.9;
  static const double wakingAngularDamping = 1.2;

  /// Yerleşme sırasında üst kedi + düşen kedi için güçlü sönüm.
  static const double stabilizingLinearDamping = 3.2;
  static const double stabilizingAngularDamping = 4.5;

  /// Kule dağıldıktan sonra game over ekranı gecikmesi (sn).
  static const double collapseGraceSeconds = 0.2;

  /// Ses/iniş öncesi çöküşün bu kadar süre sürmesi gerekir (sn).
  static const double collapseConfirmSeconds = 0.28;

  /// Kule toparlanınca inişi iptal etmeden önce bekleme (sn).
  static const double collapseRecoverSeconds = 0.22;

  /// Reklam sonrası devam — çöküş sesi/kontrolü bu süre bekler (sn).
  static const double postContinueGraceSeconds = 0.85;

  /// Game over sesi — kedi belirgin eğilince (~32°).
  static const double tipSoundAngleRad = 0.56;

  /// Game over sesi — belirgin eğilme + bu açısal hız birlikte.
  static const double tipSoundAngularVel = 0.42;

  /// Yerleşmiş kedi bu kadar eğilirse devrilmiş sayılır (radyan, ~66°).
  static const double fallenAngleRad = 1.15;

  /// Kulenin parçası sayılması için üst sınır (radyan, ~72°).
  static const double stackLeanMaxRad = 1.25;

  static const double groundY = 9.8;
  static const double groundHalfH = 0.45;
  static const double groundWidth = 60;

  static const double cameraLeadAboveStack = 2.6;

  /// Game over sonrası kameranın zemine kayma süresi (sn).
  static const double gameOverPanDuration = 1.6;

  /// 0–1: zemin kadrajda ne kadar aşağıda kalsın (yüksek = daha çok aşağı kayar).
  static const double gameOverGroundViewportRatio = 0.55;

  /// İp sallanırken çöküş kontrolü kaç karede bir (1 = her kare).
  static const int collapseCheckIntervalFrames = 3;

  /// Game over sonrası kedilerin çabuk sakinleşmesi.
  static const double gameOverLinearDamping = 7.0;
  static const double gameOverAngularDamping = 9.0;

  /// Bu eğimin üstünde dikleştirme uygulanmaz (çöküş sallanması).
  static const double uprightCorrectionMaxAngleRad = 0.62;
}
