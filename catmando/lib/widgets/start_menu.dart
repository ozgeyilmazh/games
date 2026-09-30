import 'package:flutter/material.dart';

import '../game/cat_stack_game.dart';
import '../l10n/app_strings.dart';
import '../l10n/locale_storage.dart';

/// Ready screen: game world visible, START button begins play.
class StartMenu extends StatefulWidget {
  const StartMenu(this.game, {super.key});

  static const id = 'StartMenu';

  final CatStackGame game;

  @override
  State<StartMenu> createState() => _StartMenuState();
}

class _StartMenuState extends State<StartMenu> {
  Future<void> _pickLanguage() async {
    final selected = await showModalBottomSheet<AppLocale>(
      context: context,
      backgroundColor: const Color(0xFF3E2723),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  AppStrings.language,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              for (final locale in AppLocale.values)
                ListTile(
                  title: Text(
                    AppStrings.labelFor(locale),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: locale == LocaleStorage.locale
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: locale == LocaleStorage.locale
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                  onTap: () => Navigator.pop(context, locale),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected != null && mounted) {
      await LocaleStorage.setLocale(selected);
      setState(() {});
      widget.game.onStateChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 12),
                  child: TextButton.icon(
                    onPressed: _pickLanguage,
                    icon: const Icon(Icons.language, color: Colors.white),
                    label: Text(
                      AppStrings.labelFor(LocaleStorage.locale),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.appTitle,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(blurRadius: 6, color: Colors.black54),
                    Shadow(blurRadius: 12, color: Colors.black38),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 72),
                child: FilledButton(
                  onPressed: widget.game.startGame,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF5D4037),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    AppStrings.start,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
