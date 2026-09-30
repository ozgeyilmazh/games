import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/widgets/hud.dart';
import '/game/dino_run.dart';
import '/models/dino_character_ids.dart';
import '/models/settings.dart';
import '/widgets/settings_menu.dart';
import '/widgets/banner_ad_widget.dart';

// This represents the main menu overlay.
class MainMenu extends StatelessWidget {
  // An unique identified for this overlay.
  static const id = 'MainMenu';

  // Reference to parent game.
  final DinoRun game;

  const MainMenu(this.game, {super.key});

  static const _labels = {
    'doux': 'Dino',
    'mort': 'Mino',
    'tard': 'Kino',
    'vita': 'Cino',
  };

  /// Same grid as [Dino]: one row, 24×24 frames (`dino.dart`).
  static const double _sheetW = 576;
  static const double _sheetH = 24;

  /// One 24×24 frame from the 576×24 PNG strip (`clipLeft` = column in `dino.dart`).
  static Widget _spriteSheetStill(String pngPath, {required double clipLeft}) {
    return FittedBox(
      fit: BoxFit.contain,
      child: ClipPath(
        clipper: _SpriteFrameClipper(clipLeft: clipLeft),
        child: Image.asset(
          pngPath,
          width: _sheetW,
          height: _sheetH,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }

  /// Animated GIF for all four; PNG strip tile if GIF fails (Vita uses x=96 — idle empty).
  static Widget _previewFor(String id) {
    final pngPath = 'assets/images/${DinoCharacterIds.assetFileName(id)}';
    final clipLeft = DinoCharacterIds.menuPreviewClipLeftX(id);
    final gifPath = 'assets/images/${DinoCharacterIds.previewGifFileName(id)}';
    return Image.asset(
      gifPath,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          _spriteSheetStill(pngPath, clipLeft: clipLeft),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: game.settings,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: const ColoredBox(
                  color: Color(0x66000000),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        color: Colors.black.withAlpha(120),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Minoki Run',
                                style: TextStyle(fontSize: 32, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Select Character',
                                style: TextStyle(fontSize: 15, color: Colors.white70),
                              ),
                              const SizedBox(height: 10),
                              Consumer<Settings>(
                                builder: (context, settings, _) {
                                  final selected = settings.selectedDino;
                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: DinoCharacterIds.all.map((id) {
                                      final isSel = selected == id;
                                      return GestureDetector(
                                        onTap: () {
                                          settings.selectedDino = id;
                                        },
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 150,
                                              ),
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isSel
                                                      ? Colors.amberAccent
                                                      : Colors.white24,
                                                  width: isSel ? 2.5 : 1,
                                                ),
                                                color: Colors.black26,
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: Padding(
                                                padding: const EdgeInsets.all(3),
                                                child: _previewFor(id),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _labels[id] ?? id,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isSel
                                                    ? Colors.amberAccent
                                                    : Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                              Theme(
                                data: Theme.of(context).copyWith(
                                  elevatedButtonTheme: ElevatedButtonThemeData(
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: Size.zero,
                                      fixedSize: const Size(158, 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () {
                                          game.startGamePlay();
                                          game.overlays.remove(MainMenu.id);
                                          game.overlays.add(Hud.id);
                                        },
                                        child: const Text(
                                          'Play',
                                          style: TextStyle(fontSize: 19),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton(
                                        onPressed: () {
                                          game.overlays.remove(MainMenu.id);
                                          game.overlays.add(SettingsMenu.id);
                                        },
                                        child: const Text(
                                          'Settings',
                                          style: TextStyle(fontSize: 19),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const BannerAdWidget(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One 24×24 tile from the sprite row (`clipLeft` usually 0; Vita uses 96).
class _SpriteFrameClipper extends CustomClipper<Path> {
  _SpriteFrameClipper({required this.clipLeft});

  final double clipLeft;

  @override
  Path getClip(Size size) {
    return Path()..addRect(Rect.fromLTWH(clipLeft, 0, 24, 24));
  }

  @override
  bool shouldReclip(covariant _SpriteFrameClipper oldClipper) =>
      oldClipper.clipLeft != clipLeft;
}
