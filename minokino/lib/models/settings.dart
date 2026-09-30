import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

import '/models/dino_character_ids.dart';

part 'settings.g.dart';

// This class stores the game settings persistently.
@HiveType(typeId: 1)
class Settings extends ChangeNotifier with HiveObjectMixin {
  Settings({bool bgm = false, bool sfx = false, String selectedDino = 'tard'}) {
    _bgm = bgm;
    _sfx = sfx;
    _selectedDino = selectedDino;
  }

  @HiveField(0)
  bool _bgm = false;

  bool get bgm => _bgm;
  set bgm(bool value) {
    _bgm = value;
    notifyListeners();
    save();
  }

  @HiveField(1)
  bool _sfx = false;

  bool get sfx => _sfx;
  set sfx(bool value) {
    _sfx = value;
    notifyListeners();
    save();
  }

  /// One of: doux, mort, tard, vita — matches `DinoSprites - {id}.png`.
  @HiveField(2)
  String _selectedDino = 'tard';

  String get selectedDino => _selectedDino;
  set selectedDino(String value) {
    if (!DinoCharacterIds.all.contains(value)) return;
    _selectedDino = value;
    notifyListeners();
    save();
  }
}

