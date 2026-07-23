import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../core/audio.dart';
import '../core/assets.dart';
import '../core/storage.dart';
import 'models.dart';
import 'level.dart';

enum GamePhase { aiming, simulating, won, lost }

extension _Vec on Offset {
  double dot(Offset o) => dx * o.dx + dy * o.dy;
  Offset get norm {
    final d = distance;
    return d == 0 ? Offset.zero : this / d;
  }
}

class Particle {
  Offset pos;
  Offset vel;
  double life;
  final double maxLife;
  final double size;
  final Color color;
  Particle(this.pos, this.vel, this.maxLife, this.size, this.color) : life = maxLife;
}

class GameController extends ChangeNotifier {
  final Level level;
  final int skin;

  GamePhase phase = GamePhase.aiming;

  // ball
  Offset ballPos = Offset.zero;
  Offset ballVel = Offset.zero;
  bool ballActive = false;
  double ballAge = 0;
  final List<Offset> trail = [];
  final double ballRadius = 2.6;

  // aiming
  double aimAngle = 0; // radians from straight down, positive = right
  final double launchSpeed = 47;

  // progress
  late int ballsLeft;
  int score = 0;
  int crystalsCollected = 0;
  int reactorsCharged = 0;
  int devicesActivated = 0;
  int chain = 0;
  int bestChain = 0;
  double _lastReactorTime = -10;
  double _elapsed = 0;

  // abilities & moves
  late Map<AbilityType, int> abilities;
  late int movesLeft;

  // active effects
  double gravitySign = 1;
  double _gravityFlipTimer = 0;
  double _slowmoTimer = 0;
  double _magnetPulseTimer = 0;

  // particles
  final List<Particle> particles = [];

  // sfx throttle
  double _lastReflectSfx = 0;
  double _lastBumpSfx = 0;

  // teleport cooldown
  double _teleportCooldown = 0;

  int stars = 0;
  int crystalsEarned = 0;

  GameController(this.level, this.skin) {
    ballsLeft = level.ballCount;
    abilities = Map.of(level.abilities);
    movesLeft = level.moves;
    _resetBall();
  }

  int get requiredReactors => level.reactorCount;

  void _resetBall() {
    ballActive = false;
    ballAge = 0;
    ballPos = Offset(level.launchX, 9);
    ballVel = Offset.zero;
    trail.clear();
    phase = GamePhase.aiming;
  }

  void setAim(double angle) {
    if (phase != GamePhase.aiming) return;
    aimAngle = angle.clamp(-1.15, 1.15);
    notifyListeners();
  }

  void launch() {
    if (phase != GamePhase.aiming || ballActive) return;
    ballVel = Offset(math.sin(aimAngle), math.cos(aimAngle)) * launchSpeed;
    ballActive = true;
    ballAge = 0;
    phase = GamePhase.simulating;
    Audio.instance.sfx(Sfx.launch, volume: 0.9);
    GameStorage.instance.addLifeBallsLaunched(1);
    notifyListeners();
  }

  bool rotateReflector(int index) {
    if (phase != GamePhase.aiming || movesLeft <= 0) return false;
    if (index < 0 || index >= level.reflectors.length) return false;
    if (!level.reflectors[index].rotatable) return false;
    level.reflectors[index].angle += math.pi / 12;
    level.reflectors[index].pulse = 1;
    movesLeft--;
    Audio.instance.sfx(Sfx.uiClick, volume: 0.6);
    notifyListeners();
    return true;
  }

  void useAbility(AbilityType type) {
    final n = abilities[type] ?? 0;
    if (n <= 0) return;
    switch (type) {
      case AbilityType.slowmo:
        if (!ballActive) return;
        _slowmoTimer = 3.5;
        break;
      case AbilityType.gravityFlip:
        if (!ballActive) return;
        gravitySign = -1;
        _gravityFlipTimer = 2.5;
        Audio.instance.sfx(Sfx.gravity, volume: 0.9);
        break;
      case AbilityType.magnetPulse:
        if (!ballActive) return;
        _magnetPulseTimer = 2.5;
        Audio.instance.sfx(Sfx.magnet, volume: 0.9);
        break;
      case AbilityType.nudge:
        if (!ballActive) return;
        // nudge toward center-of-remaining reactors
        final target = _nearestUncharged();
        if (target != null) {
          final dir = (target - ballPos).norm;
          ballVel += dir * 26;
        }
        Audio.instance.sfx(Sfx.booster, volume: 0.5);
        break;
    }
    abilities[type] = n - 1;
    notifyListeners();
  }

  Offset? _nearestUncharged() {
    Device? best;
    double bd = 1e9;
    for (final d in level.devices) {
      if (d.mustCharge && !d.charged) {
        final dist = (d.pos - ballPos).distance;
        if (dist < bd) {
          bd = dist;
          best = d;
        }
      }
    }
    return best?.pos;
  }

  // ---------------- main step ----------------
  void step(double dtReal) {
    // animate pulses & particles always
    _animateCosmetics(dtReal);

    if (phase != GamePhase.simulating || !ballActive) {
      notifyListeners();
      return;
    }

    var dt = dtReal.clamp(0.0, 1 / 30);
    // slow motion
    if (_slowmoTimer > 0) {
      _slowmoTimer -= dtReal;
      dt *= 0.4;
    }
    if (_gravityFlipTimer > 0) {
      _gravityFlipTimer -= dtReal;
      if (_gravityFlipTimer <= 0) gravitySign = 1;
    }
    if (_magnetPulseTimer > 0) _magnetPulseTimer -= dtReal;
    if (_teleportCooldown > 0) _teleportCooldown -= dtReal;

    _elapsed += dt;
    ballAge += dt;

    const substeps = 6;
    final h = dt / substeps;
    for (var s = 0; s < substeps; s++) {
      _integrate(h);
      if (!ballActive) break;
    }

    // trail
    trail.add(ballPos);
    if (trail.length > 16) trail.removeAt(0);

    if (ballActive && ballAge > 20) {
      _killBall();
    }

    notifyListeners();
  }

  void _integrate(double h) {
    // gravity
    ballVel = Offset(ballVel.dx, ballVel.dy + 62 * gravitySign * h);

    // force fields
    for (final d in level.devices) {
      if (d.kind == DeviceKind.magnet || (_magnetPulseTimer > 0 && d.mustCharge && !d.charged)) {
        final toDev = d.pos - ballPos;
        final dist = toDev.distance;
        final R = d.kind == DeviceKind.magnet ? d.fieldRadius : 30;
        final str = d.kind == DeviceKind.magnet ? d.fieldStrength : 180;
        if (dist < R && dist > 0.5) {
          final f = str * (1 - dist / R) / dist;
          ballVel += toDev * (f * h);
        }
      } else if (d.kind == DeviceKind.antigrav) {
        final fromDev = ballPos - d.pos;
        final dist = fromDev.distance;
        if (dist < d.fieldRadius && dist > 0.5) {
          final f = d.fieldStrength * (1 - dist / d.fieldRadius) / dist;
          ballVel += fromDev * (f * h);
        }
      }
    }

    // clamp speed
    final sp = ballVel.distance;
    const maxSp = 160.0;
    if (sp > maxSp) ballVel = ballVel * (maxSp / sp);

    // integrate position
    ballPos += ballVel * h;

    _collideWalls();
    _collideDevices();
    _collideReflectors();

    // bottom floor -> miss
    if (ballPos.dy > level.worldHeight + 4) {
      _killBall();
    }
  }

  void _collideWalls() {
    final r = ballRadius;
    if (ballPos.dx < r) {
      ballPos = Offset(r, ballPos.dy);
      ballVel = Offset(-ballVel.dx * 0.82, ballVel.dy);
      _reflectSfx();
    } else if (ballPos.dx > kWorldWidth - r) {
      ballPos = Offset(kWorldWidth - r, ballPos.dy);
      ballVel = Offset(-ballVel.dx * 0.82, ballVel.dy);
      _reflectSfx();
    }
    if (ballPos.dy < r) {
      ballPos = Offset(ballPos.dx, r);
      ballVel = Offset(ballVel.dx, -ballVel.dy * 0.82);
    }
    // internal walls
    for (final w in level.walls) {
      _collideRect(w);
    }
  }

  void _collideRect(Rect w) {
    final r = ballRadius;
    final closest = Offset(
      ballPos.dx.clamp(w.left, w.right),
      ballPos.dy.clamp(w.top, w.bottom),
    );
    final delta = ballPos - closest;
    final dist = delta.distance;
    if (dist < r && dist > 0) {
      final n = delta / dist;
      ballPos = closest + n * r;
      final vn = ballVel.dot(n);
      if (vn < 0) ballVel = (ballVel - n * (2 * vn)) * 0.82;
      _reflectSfx();
    }
  }

  void _collideDevices() {
    final r = ballRadius;
    for (final d in level.devices) {
      if (d.consumed) continue;
      final delta = ballPos - d.pos;
      final dist = delta.distance;

      if (d.kind == DeviceKind.crystal) {
        if (dist < r + d.radius) {
          d.consumed = true;
          crystalsCollected++;
          score += 250;
          d.pulse = 1;
          _spawnBurst(d.pos, kCrystalColor, 14);
          Audio.instance.sfx(Sfx.crystal, volume: 0.9);
          GameStorage.instance.addLifeCrystalsCollected(1);
          GameStorage.instance.addDailyProgress('crystals', 1);
        }
        continue;
      }

      final minD = r + d.radius;
      if (dist >= minD || dist == 0) continue;

      // teleporter: warp instead of bounce
      if (d.kind == DeviceKind.teleporter && _teleportCooldown <= 0) {
        final partner = level.devices.firstWhere(
          (o) => o.kind == DeviceKind.teleporter && o.linkId == d.linkId && !identical(o, d),
          orElse: () => d,
        );
        if (!identical(partner, d)) {
          final dir = ballVel.norm;
          ballPos = partner.pos + dir * (partner.radius + r + 1);
          _teleportCooldown = 0.4;
          d.pulse = 1;
          partner.pulse = 1;
          _spawnBurst(partner.pos, const Color(0xFF35E7FF), 12);
          Audio.instance.sfx(Sfx.teleport, volume: 0.8);
          continue;
        }
      }

      // resolve overlap + reflect
      final n = delta / dist;
      ballPos = d.pos + n * minD;
      final vn = ballVel.dot(n);
      if (vn < 0) ballVel = (ballVel - n * (2 * vn));

      d.pulse = 1;

      switch (d.kind) {
        case DeviceKind.reactor:
        case DeviceKind.core:
          ballVel *= 0.86;
          if (!d.charged) {
            d.charged = true;
            reactorsCharged++;
            devicesActivated++;
            final pts = d.kind == DeviceKind.core ? 300 : 100;
            // chain bonus
            final now = _elapsed;
            if (now - _lastReactorTime < 1.3) {
              chain++;
              if (chain > bestChain) bestChain = chain;
              score += pts + chain * 40;
              Audio.instance.sfx(Sfx.chain, volume: 0.8);
              GameStorage.instance.addDailyProgress('chains', 1);
            } else {
              chain = 1;
              score += pts;
              Audio.instance.sfx(
                  d.kind == DeviceKind.core ? Sfx.strongReactor : Sfx.reactor,
                  volume: 0.9);
            }
            _lastReactorTime = now;
            _spawnBurst(d.pos, _reactorColor(d.spriteIndex), 20);
            GameStorage.instance.addLifeReactors(1);
            GameStorage.instance.addDailyProgress('reactors', 1);
            _checkWin();
          } else {
            score += 5;
          }
          break;
        case DeviceKind.booster:
          final dir = ballVel.norm;
          ballVel = dir * d.boostSpeed;
          devicesActivated++;
          score += 15;
          _spawnBurst(d.pos, const Color(0xFF35E7FF), 12);
          Audio.instance.sfx(Sfx.booster, volume: 0.7);
          GameStorage.instance.addLifeBoosterUses(1);
          GameStorage.instance.addDailyProgress('booster', 1);
          break;
        case DeviceKind.magnet:
          ballVel *= 0.9;
          devicesActivated++;
          score += 8;
          _bumpSfx(Sfx.magnet);
          GameStorage.instance.addLifeMagnetUses(1);
          GameStorage.instance.addDailyProgress('magnet', 1);
          break;
        case DeviceKind.antigrav:
          ballVel *= 0.9;
          devicesActivated++;
          score += 8;
          _bumpSfx(Sfx.gravity);
          GameStorage.instance.addLifeMagnetUses(1);
          GameStorage.instance.addDailyProgress('magnet', 1);
          break;
        case DeviceKind.bumper:
          ballVel *= 0.92;
          score += 10;
          _bumpSfx(Sfx.metalHit);
          break;
        default:
          break;
      }
    }
  }

  void _collideReflectors() {
    final r = ballRadius;
    const thick = 1.4;
    for (final rf in level.reflectors) {
      final a = rf.a;
      final b = rf.b;
      final ab = b - a;
      final len2 = ab.dot(ab);
      if (len2 == 0) continue;
      var tt = (ballPos - a).dot(ab) / len2;
      tt = tt.clamp(0.0, 1.0);
      final closest = a + ab * tt;
      final delta = ballPos - closest;
      final dist = delta.distance;
      if (dist < r + thick && dist > 0) {
        final n = delta / dist;
        ballPos = closest + n * (r + thick);
        final vn = ballVel.dot(n);
        if (vn < 0) ballVel = (ballVel - n * (2 * vn)) * 0.94;
        rf.pulse = 1;
        _reflectSfx();
      }
    }
  }

  void _reflectSfx() {
    if (_elapsed - _lastReflectSfx > 0.08) {
      _lastReflectSfx = _elapsed;
      Audio.instance.sfx(Sfx.reflect, volume: 0.35);
    }
  }

  void _bumpSfx(String s) {
    if (_elapsed - _lastBumpSfx > 0.06) {
      _lastBumpSfx = _elapsed;
      Audio.instance.sfx(s, volume: 0.5);
    }
  }

  void _checkWin() {
    final remaining = level.devices.where((d) => d.mustCharge && !d.charged).length;
    if (remaining == 0) {
      _win();
    }
  }

  void _killBall() {
    ballActive = false;
    ballsLeft--;
    chain = 0;
    _spawnBurst(ballPos, const Color(0xFF7788AA), 8);
    if (level.devices.where((d) => d.mustCharge && !d.charged).isEmpty) {
      _win();
    } else if (ballsLeft <= 0) {
      phase = GamePhase.lost;
    } else {
      _resetBall();
    }
    notifyListeners();
  }

  void _win() {
    if (phase == GamePhase.won) return;
    ballActive = false;
    phase = GamePhase.won;
    // bonus for leftover balls
    score += ballsLeft * 120;
    stars = 1;
    if (score >= level.star2) stars = 2;
    if (score >= level.star3) stars = 3;

    crystalsEarned = crystalsCollected + reactorsCharged * 5 + stars * 15 + bestChain * 10;

    final store = GameStorage.instance;
    store.setStars(level.id, stars);
    store.setBest(level.id, score);
    store.addCrystals(crystalsEarned);
    store.reportChainBest(bestChain);
    store.addDailyProgress('levels', 1);
    if (level.id + 1 > store.unlockedLevel && level.id < 40) {
      store.unlockedLevel = level.id + 1;
    }

    Audio.instance.sfx(stars >= 3 ? Sfx.perfect : Sfx.levelComplete, volume: 1.0);
    notifyListeners();
  }

  // ---------------- cosmetics ----------------
  void _animateCosmetics(double dt) {
    for (final d in level.devices) {
      if (d.pulse > 0) d.pulse = math.max(0, d.pulse - dt * 2.5);
      d.spin += dt * 0.6;
    }
    for (final rf in level.reflectors) {
      if (rf.pulse > 0) rf.pulse = math.max(0, rf.pulse - dt * 3);
    }
    for (var i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.life -= dt;
      if (p.life <= 0) {
        particles.removeAt(i);
        continue;
      }
      p.pos += p.vel * dt;
      p.vel = Offset(p.vel.dx * 0.94, p.vel.dy * 0.94 + 30 * dt);
    }
  }

  void _spawnBurst(Offset at, Color color, int n) {
    final rnd = math.Random();
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final sp = 20 + rnd.nextDouble() * 55;
      particles.add(Particle(
        at,
        Offset(math.cos(a), math.sin(a)) * sp,
        0.4 + rnd.nextDouble() * 0.5,
        1.0 + rnd.nextDouble() * 2.0,
        color,
      ));
    }
  }

  Color _reactorColor(int idx) {
    const colors = [
      Color(0xFF35E7FF),
      Color(0xFFFFA23D),
      Color(0xFF6FA8FF),
      Color(0xFF56F09B),
      Color(0xFF9B5BFF),
      Color(0xFF35E7FF),
      Color(0xFF6FE0FF),
      Color(0xFFFF4FD8),
      Color(0xFFFFC24B),
    ];
    return colors[idx % colors.length];
  }
}

const Color kCrystalColor = Color(0xFF6FE0FF);
