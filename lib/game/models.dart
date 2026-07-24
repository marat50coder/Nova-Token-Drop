import 'dart:math' as math;
import 'dart:ui';

/// Physics/gameplay role of a placed device.
enum DeviceKind {
  reactor, // must be charged to win
  core, // central core: the final, larger reactor
  bumper, // decorative reflective peg, small score
  magnet, // attracts the token within its field
  antigrav, // pushes the token away (anti-gravity well)
  teleporter, // paired portal
  booster, // accelerates the token
  crystal, // collectible energy crystal (bonus, one-shot)
}

class Device {
  final DeviceKind kind;
  Offset pos; // world units (0..100 wide)
  final double radius; // world units
  final String cat; // sprite category
  final int spriteIndex;
  final int linkId; // teleporters: shared id for the pair
  final double fieldRadius;
  final double fieldStrength;
  final double boostSpeed;

  // runtime state
  bool charged = false;
  bool consumed = false; // for crystals
  double pulse = 0; // 0..1 hit animation
  double spin = 0; // rotation for animated devices

  Device({
    required this.kind,
    required this.pos,
    required this.radius,
    required this.cat,
    required this.spriteIndex,
    this.linkId = -1,
    this.fieldRadius = 0,
    this.fieldStrength = 0,
    this.boostSpeed = 0,
  });

  bool get mustCharge => kind == DeviceKind.reactor || kind == DeviceKind.core;
}

class Reflector {
  Offset center; // world units
  double length;
  double angle; // radians, 0 = horizontal
  final bool rotatable;
  double pulse = 0;
  Reflector({
    required this.center,
    required this.length,
    required this.angle,
    this.rotatable = true,
  });

  Offset get a =>
      Offset(center.dx - length / 2 * math.cos(angle), center.dy - length / 2 * math.sin(angle));
  Offset get b =>
      Offset(center.dx + length / 2 * math.cos(angle), center.dy + length / 2 * math.sin(angle));
}
