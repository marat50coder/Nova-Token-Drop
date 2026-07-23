import 'dart:math' as math;
import 'dart:ui';
import 'models.dart';

enum AbilityType { slowmo, gravityFlip, nudge, magnetPulse }

const double kWorldWidth = 100.0;

class Level {
  final int id; // 1-based
  final int chapter; // 0..5
  final int bgIndex; // 1..6
  final double worldHeight;
  final List<Device> devices;
  final List<Reflector> reflectors;
  final List<Rect> walls;
  final int ballCount;
  final int moves; // pre-launch reflector rotations allowed
  final Map<AbilityType, int> abilities;
  final double launchX;
  final int star2;
  final int star3;

  Level({
    required this.id,
    required this.chapter,
    required this.bgIndex,
    required this.worldHeight,
    required this.devices,
    required this.reflectors,
    required this.walls,
    required this.ballCount,
    required this.moves,
    required this.abilities,
    required this.launchX,
    required this.star2,
    required this.star3,
  });

  int get reactorCount => devices.where((d) => d.mustCharge).length;
  int get crystalCount => devices.where((d) => d.kind == DeviceKind.crystal).length;
}

const List<String> kChapterNames = [
  'Orbital Stations',
  'Crystal Asteroids',
  'Magnetic Nebulae',
  'Quantum Labs',
  'Stellar Reactors',
  'Supernova Core',
];

/// Number of levels per chapter (sums to 40).
const List<int> kChapterSizes = [7, 7, 7, 7, 6, 6];

int chapterOf(int levelId) {
  var acc = 0;
  for (var c = 0; c < kChapterSizes.length; c++) {
    acc += kChapterSizes[c];
    if (levelId <= acc) return c;
  }
  return kChapterSizes.length - 1;
}

/// Deterministically builds a level layout that scales in difficulty.
class LevelFactory {
  static Level build(int id) {
    final rnd = math.Random(id * 1013 + 17);
    final chapter = chapterOf(id);
    final bgIndex = chapter + 1;
    final t = (id - 1) / 39.0; // 0..1 global difficulty

    final worldHeight = 150.0 + chapter * 8.0;
    final devices = <Device>[];
    final reflectors = <Reflector>[];
    final walls = <Rect>[];

    final placed = <Offset>[]; // for spacing
    bool free(Offset p, double minDist) {
      for (final q in placed) {
        if ((p - q).distance < minDist) return false;
      }
      return true;
    }

    Offset? sample(double x0, double x1, double y0, double y1, double minDist) {
      for (var i = 0; i < 60; i++) {
        final p = Offset(x0 + rnd.nextDouble() * (x1 - x0), y0 + rnd.nextDouble() * (y1 - y0));
        if (free(p, minDist)) return p;
      }
      return null;
    }

    // ---- Central Core (always) ----
    final corePos = Offset(50, worldHeight - 16);
    devices.add(Device(
      kind: DeviceKind.core,
      pos: corePos,
      radius: 7.5,
      cat: 'reactor',
      spriteIndex: 8,
    ));
    placed.add(corePos);

    // ---- Reactors ----
    final reactorCount = (2 + (t * 7)).round().clamp(2, 9);
    final reactorSprites = [0, 2, 3, 1, 4, 7, 6, 5, 3];
    for (var i = 0; i < reactorCount; i++) {
      final p = sample(12, 88, 30, worldHeight - 34, 17) ??
          Offset(15.0 + i * 12.0 % 70, 34 + (i * 13 % 60));
      placed.add(p);
      devices.add(Device(
        kind: DeviceKind.reactor,
        pos: p,
        radius: 5.4,
        cat: 'reactor',
        spriteIndex: reactorSprites[i % reactorSprites.length],
      ));
    }

    // ---- Bumpers (obstacles) ----
    final bumperCount = (3 + t * 9).round();
    for (var i = 0; i < bumperCount; i++) {
      final p = sample(10, 90, 26, worldHeight - 26, 12);
      if (p == null) continue;
      placed.add(p);
      final useDecor = rnd.nextBool();
      devices.add(Device(
        kind: DeviceKind.bumper,
        pos: p,
        radius: 3.6 + rnd.nextDouble() * 1.2,
        cat: useDecor ? 'decor' : 'utility',
        spriteIndex: rnd.nextInt(useDecor ? 20 : 16),
      ));
    }

    // ---- Magnets (from chapter >= 1) ----
    if (chapter >= 1) {
      final n = 1 + (t * 2).round();
      for (var i = 0; i < n; i++) {
        final p = sample(15, 85, 40, worldHeight - 30, 16);
        if (p == null) continue;
        placed.add(p);
        devices.add(Device(
          kind: DeviceKind.magnet,
          pos: p,
          radius: 4.6,
          cat: 'magnet',
          spriteIndex: rnd.nextInt(9),
          fieldRadius: 26,
          fieldStrength: 210,
        ));
      }
    }

    // ---- Anti-gravity wells (from chapter >= 3) ----
    if (chapter >= 3) {
      final n = 1 + (t * 1.5).round();
      for (var i = 0; i < n; i++) {
        final p = sample(15, 85, 45, worldHeight - 34, 18);
        if (p == null) continue;
        placed.add(p);
        devices.add(Device(
          kind: DeviceKind.antigrav,
          pos: p,
          radius: 5.0,
          cat: 'gravity',
          spriteIndex: rnd.nextInt(10),
          fieldRadius: 24,
          fieldStrength: 260,
        ));
      }
    }

    // ---- Teleporter pair (from chapter >= 2) ----
    if (chapter >= 2 && rnd.nextDouble() < 0.85) {
      final p1 = sample(14, 46, 34, worldHeight - 40, 16);
      final p2 = sample(54, 86, 44, worldHeight - 30, 16);
      if (p1 != null && p2 != null) {
        placed.add(p1);
        placed.add(p2);
        final tpi = rnd.nextInt(4);
        devices.add(Device(kind: DeviceKind.teleporter, pos: p1, radius: 5.0, cat: 'teleporter', spriteIndex: tpi, linkId: 1));
        devices.add(Device(kind: DeviceKind.teleporter, pos: p2, radius: 5.0, cat: 'teleporter', spriteIndex: tpi + 4, linkId: 1));
      }
    }

    // ---- Boosters (from chapter >= 1) ----
    if (chapter >= 1) {
      final n = 1 + (t * 2).round();
      for (var i = 0; i < n; i++) {
        final p = sample(12, 88, 36, worldHeight - 26, 14);
        if (p == null) continue;
        placed.add(p);
        devices.add(Device(
          kind: DeviceKind.booster,
          pos: p,
          radius: 4.2,
          cat: 'booster',
          spriteIndex: rnd.nextInt(16),
          boostSpeed: 95,
        ));
      }
    }

    // ---- Crystals (bonus) ----
    final crystalCount = id <= 2 ? 1 : (2 + (t * 3).round());
    for (var i = 0; i < crystalCount; i++) {
      final p = sample(10, 90, 24, worldHeight - 24, 11);
      if (p == null) continue;
      placed.add(p);
      devices.add(Device(
        kind: DeviceKind.crystal,
        pos: p,
        radius: 3.0,
        cat: 'token',
        spriteIndex: 8, // crystal sphere
      ));
    }

    // ---- Reflectors (rotatable bars) ----
    final reflCount = (1 + t * 4).round();
    for (var i = 0; i < reflCount; i++) {
      final p = sample(16, 84, 34, worldHeight - 34, 15);
      if (p == null) continue;
      placed.add(p);
      reflectors.add(Reflector(
        center: p,
        length: 15 + rnd.nextDouble() * 8,
        angle: (rnd.nextDouble() - 0.5) * 1.4,
        rotatable: true,
      ));
    }

    // ---- Internal barrier walls (late chapters) ----
    if (chapter >= 4) {
      final wy = 34.0 + rnd.nextDouble() * 20;
      final left = rnd.nextBool();
      walls.add(left
          ? Rect.fromLTWH(0, wy, 30 + rnd.nextDouble() * 12, 3.2)
          : Rect.fromLTWH(58 - rnd.nextDouble() * 12, wy, 42, 3.2));
    }

    // ---- Difficulty knobs ----
    final ballCount = (9 - (t * 5)).round().clamp(4, 9);
    final moves = (1 + t * 4).round();
    final abilities = <AbilityType, int>{
      AbilityType.slowmo: 1 + (t * 2).round(),
      AbilityType.nudge: 2 + (t * 2).round(),
      if (chapter >= 2) AbilityType.gravityFlip: 1 + (t).round(),
      if (chapter >= 1) AbilityType.magnetPulse: 1 + (t).round(),
    };

    // ---- Star thresholds ----
    final base = reactorCount * 100 + 300; // reactors + core
    final crystalScore = crystalCount * 250;
    final star3 = base + crystalScore + bumperCount * 8;
    final star2 = base + (crystalScore * 0.45).round();

    return Level(
      id: id,
      chapter: chapter,
      bgIndex: bgIndex,
      worldHeight: worldHeight,
      devices: devices,
      reflectors: reflectors,
      walls: walls,
      ballCount: ballCount,
      moves: moves,
      abilities: abilities,
      launchX: 50,
      star2: star2,
      star3: star3,
    );
  }
}
