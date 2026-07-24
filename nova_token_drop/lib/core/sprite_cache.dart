import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'assets.dart';

/// Decodes and caches [ui.Image]s so the game painter can blit them each frame.
class SpriteCache {
  SpriteCache._();
  static final SpriteCache instance = SpriteCache._();

  final Map<String, ui.Image> _images = {};

  ui.Image? get(String path) => _images[path];

  ui.Image? sprite(String cat, int i) => _images[A.sprite(cat, i)];

  Future<ui.Image> _load(String path) async {
    if (_images.containsKey(path)) return _images[path]!;
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _images[path] = frame.image;
    return frame.image;
  }

  /// Preload all gameplay sprites and background images.
  /// [onProgress] is called with a 0..1 fraction.
  Future<void> preloadAll(void Function(double) onProgress) async {
    final paths = <String>[
      ...A.allSprites(),
      for (var i = 1; i <= 6; i++) A.location(i),
    ];
    var done = 0;
    for (final p in paths) {
      try {
        // Per-image timeout so a single asset that fails to decode (or a
        // platform-side hiccup) can never freeze the loading screen.
        await _load(p).timeout(const Duration(seconds: 5));
      } catch (_) {}
      done++;
      onProgress(done / paths.length);
    }
  }
}
