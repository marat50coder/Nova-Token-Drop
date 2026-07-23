import 'package:flutter/material.dart';

/// A single daily-challenge template. [metricKey] matches the keys used by
/// [GameStorage.addDailyProgress]/[GameStorage.dailyProgress].
class DailyChallengeDef {
  final String metricKey;
  final int target;
  final int reward;
  final String title;
  final IconData icon;
  final List<Color> color;
  const DailyChallengeDef({
    required this.metricKey,
    required this.target,
    required this.reward,
    required this.title,
    required this.icon,
    required this.color,
  });
}

const List<Color> _cGreen = [Color(0xFF56F09B), Color(0xFF35E7FF)];
const List<Color> _cGold = [Color(0xFFFFE39A), Color(0xFFFFC24B)];
const List<Color> _cBlue = [Color(0xFF3D7BFF), Color(0xFF9B5BFF)];
const List<Color> _cPink = [Color(0xFFFF4FD8), Color(0xFFFF5C8A)];

/// Fixed pool of daily-challenge templates, mirroring the design doc's
/// "Ежедневные задания" list. Three are drawn deterministically each day.
const List<DailyChallengeDef> kDailyPool = [
  DailyChallengeDef(
      metricKey: 'reactors',
      target: 20,
      reward: 150,
      title: 'Charge 20 reactors',
      icon: Icons.bolt_rounded,
      color: _cGreen),
  DailyChallengeDef(
      metricKey: 'reactors',
      target: 45,
      reward: 260,
      title: 'Charge 45 reactors',
      icon: Icons.bolt_rounded,
      color: _cGreen),
  DailyChallengeDef(
      metricKey: 'chains',
      target: 8,
      reward: 180,
      title: 'Create 8 chain reactions',
      icon: Icons.auto_awesome_rounded,
      color: _cGold),
  DailyChallengeDef(
      metricKey: 'chains',
      target: 15,
      reward: 260,
      title: 'Create 15 chain reactions',
      icon: Icons.auto_awesome_rounded,
      color: _cGold),
  DailyChallengeDef(
      metricKey: 'magnet',
      target: 25,
      reward: 150,
      title: 'Trigger magnetic devices 25 times',
      icon: Icons.blur_on_rounded,
      color: _cBlue),
  DailyChallengeDef(
      metricKey: 'crystals',
      target: 10,
      reward: 200,
      title: 'Collect 10 energy crystals',
      icon: Icons.diamond_rounded,
      color: _cPink),
  DailyChallengeDef(
      metricKey: 'crystals',
      target: 20,
      reward: 320,
      title: 'Collect 20 energy crystals',
      icon: Icons.diamond_rounded,
      color: _cPink),
  DailyChallengeDef(
      metricKey: 'levels',
      target: 3,
      reward: 220,
      title: 'Complete 3 levels',
      icon: Icons.flag_rounded,
      color: _cGold),
  DailyChallengeDef(
      metricKey: 'levels',
      target: 5,
      reward: 320,
      title: 'Complete 5 levels',
      icon: Icons.flag_rounded,
      color: _cGold),
  DailyChallengeDef(
      metricKey: 'booster',
      target: 20,
      reward: 150,
      title: 'Trigger boosters 20 times',
      icon: Icons.rocket_launch_rounded,
      color: _cBlue),
];

/// Deterministically picks 3 distinct challenges for "today".
List<DailyChallengeDef> todaysChallenges() {
  final d = DateTime.now();
  var s = d.year * 10000 + d.month * 100 + d.day;
  final idxs = <int>{};
  while (idxs.length < 3) {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    idxs.add(s % kDailyPool.length);
  }
  return idxs.map((i) => kDailyPool[i]).toList();
}
