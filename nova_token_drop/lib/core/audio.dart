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

  Future<void> stopMusic() async => _music.stop();

  Future<void> refreshMusic() async {
    if (_musicOn) {
      if (_currentTrack != null) await playMusic(_currentTrack!);
    } else {
      await _music.stop();
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
