import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'player_data.g.dart';

// This class stores the player progress presistently.
@HiveType(typeId: 0)
class PlayerData extends ChangeNotifier with HiveObjectMixin {
  static const int maxLives = 3;

  @HiveField(1)
  int highScore = 0;

  int _lives = maxLives;

  int get lives => _lives;
  set lives(int value) {
    if (value <= maxLives && value >= 0) {
      _lives = value;
      notifyListeners();
    }
  }

  int _currentScore = 0;

  int get currentScore => _currentScore;
  set currentScore(int value) {
    _currentScore = value;

    if (highScore < _currentScore) {
      highScore = _currentScore;
    }

    notifyListeners();
  }

  /// Disk yazımı — oyun sırasında değil, tur bitince çağır.
  void persistProgress() {
    save();
  }
}
