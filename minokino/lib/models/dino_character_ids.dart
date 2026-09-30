/// Keys for the four playable dino sprite sheets under `assets/images/`.
abstract final class DinoCharacterIds {
  static const List<String> all = ['doux', 'mort', 'tard', 'vita'];

  static String assetFileName(String id) => 'DinoSprites - $id.png';

  /// Animated preview on the main menu (`minoki_doux.gif`, …).
  static String previewGifFileName(String id) => 'minoki_$id.gif';

  /// Left edge of the menu still (PNG strip), in px. Matches `dino.dart` rows:
  /// Vita’s first “idle” frame is effectively empty; use first “run” frame at 4×24.
  static double menuPreviewClipLeftX(String id) => id == 'vita' ? 96 : 0;
}
