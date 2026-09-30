import 'package:flame_audio/flame_audio.dart';

class GameAudio {
  GameAudio._();

  static AudioPool? _jumpPool;
  static AudioPlayer? _gameOverPlayer;
  static AudioPlayer? _bgmPlayer;
  static String? _currentBgm;
  static bool _gameOverPlaying = false;

  static Future<void> init() async {
    FlameAudio.audioCache.prefix = 'assets/music/';
    await FlameAudio.audioCache.loadAll([
      'jump.mp3',
      'gameover.mp3',
      'menu.mp3',
      'nature.mp3',
    ]);

    _jumpPool = await FlameAudio.createPool(
      'jump.mp3',
      maxPlayers: 2,
      minPlayers: 2,
    );

    final player = AudioPlayer()..audioCache = FlameAudio.audioCache;
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setPlayerMode(PlayerMode.lowLatency);
    await player.setSource(AssetSource('gameover.mp3'));
    _gameOverPlayer = player;

    _bgmPlayer = AudioPlayer()..audioCache = FlameAudio.audioCache;
    await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
  }

  static void playJump() => _jumpPool?.start();

  static Future<void> playMenuMusic() => _playBgm('menu.mp3', volume: 0.42);

  static Future<void> playGameplayMusic() =>
      _playBgm('nature.mp3', volume: 0.32);

  static Future<void> _playBgm(String file, {required double volume}) async {
    final player = _bgmPlayer;
    if (player == null) return;
    if (_currentBgm == file && player.state == PlayerState.playing) return;

    try {
      await player.stop();
      await player.setVolume(volume);
      await player.setSource(AssetSource(file));
      await player.resume();
      _currentBgm = file;
    } catch (_) {
      // Sessiz başarısızlık — SFX çalışmaya devam eder.
    }
  }

  static Future<void> stopBgm() async {
    _currentBgm = null;
    await _bgmPlayer?.stop();
  }

  /// Reklam tam ekran kapattıktan sonra ses oturumunu tazeler.
  static Future<void> prepareGameOver() async {
    final player = _gameOverPlayer;
    if (player == null) return;
    _gameOverPlaying = false;
    await player.stop();
    await player.setSource(AssetSource('gameover.mp3'));
  }

  static void playGameOver() {
    if (_gameOverPlaying) return;
    _gameOverPlaying = true;

    final player = _gameOverPlayer;
    if (player == null) {
      FlameAudio.play('gameover.mp3');
      Future.delayed(const Duration(seconds: 2), () => _gameOverPlaying = false);
      return;
    }

    player.stop().then((_) async {
      await player.setSource(AssetSource('gameover.mp3'));
      await player.resume();
    }).whenComplete(
      () => Future.delayed(const Duration(seconds: 2), () {
        _gameOverPlaying = false;
      }),
    );
  }

  static Future<void> stopAll() async {
    _gameOverPlaying = false;
    await _gameOverPlayer?.stop();
    await stopBgm();
  }
}
