import 'package:audioplayers/audioplayers.dart';
import 'storage.dart';

/// Handles background music and a small pool of overlapping SFX players.
class Audio {
  Audio._();
  static final Audio instance = Audio._();

  final AudioPlayer _music = AudioPlayer(playerId: 'nova_music');
  final List<AudioPlayer> _sfxPool =
      List.generate(6, (i) => AudioPlayer(playerId: 'nova_sfx_$i'));
  int _sfxIndex = 0;
  String? _currentTrack;
  bool _pausedByLifecycle = false;

  // Music holds normal focus (so it behaves like a "main" audio source),
  // SFX request NO focus at all so rapid-fire hits don't spam focus-change
  // events or fight the music player for the audio session.
  static final _musicContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.gain,
      stayAwake: false,
    ),
  );

  static final _sfxContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.assistanceSonification,
      audioFocus: AndroidAudioFocus.none,
      stayAwake: false,
    ),
  );

  Future<void> init() async {
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.setVolume(0.45);
    await _music.setAudioContext(_musicContext);
    for (final p in _sfxPool) {
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setAudioContext(_sfxContext);
    }
  }

  bool get _musicOn => GameStorage.instance.musicOn;
  bool get _sfxOn => GameStorage.instance.sfxOn;

  Future<void> playMusic(String assetPath) async {
    // Avoid restarting the same track from zero if it's already playing
    // (e.g. redundant calls when several screens request the same theme).
    if (_currentTrack == assetPath && _musicOn && _music.state == PlayerState.playing) {
      return;
    }
    _currentTrack = assetPath;
    if (!_musicOn) {
      await _music.stop();
      return;
    }
    try {
      await _music.stop();
      await _music.play(AssetSource(assetPath), volume: 0.45);
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    _currentTrack = null;
    await _music.stop();
  }

  Future<void> refreshMusic() async {
    if (_musicOn) {
      if (_currentTrack != null) await playMusic(_currentTrack!);
    } else {
      await _music.stop();
    }
  }

  /// Called when the app is backgrounded (Home button, task switch, screen
  /// lock, etc.) so music/SFX don't keep playing while the game isn't visible.
  Future<void> pauseForBackground() async {
    for (final p in _sfxPool) {
      await p.stop();
    }
    if (_music.state == PlayerState.playing) {
      _pausedByLifecycle = true;
      await _music.pause();
    }
  }

  /// Called when the app returns to the foreground.
  Future<void> resumeFromBackground() async {
    if (_pausedByLifecycle) {
      _pausedByLifecycle = false;
      if (_musicOn) {
        await _music.resume();
      }
    }
  }

  Future<void> sfx(String assetPath, {double volume = 1.0}) async {
    if (!_sfxOn) return;
    final p = _sfxPool[_sfxIndex];
    _sfxIndex = (_sfxIndex + 1) % _sfxPool.length;
    try {
      await p.stop();
      await p.play(AssetSource(assetPath), volume: volume);
    } catch (_) {}
  }

  void dispose() {
    _music.dispose();
    for (final p in _sfxPool) {
      p.dispose();
    }
  }
}
