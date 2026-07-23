import 'package:flutter/material.dart';
import 'storage.dart';
import 'theme.dart';

/// A milestone tied to a real lifetime stat in [GameStorage]. Progress and
/// completion are always derived from actual save data, never hard-coded.
class AchievementDef {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<Color> color;
  final int reward;
  final int target;
  final int Function(GameStorage) progressOf;

  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.reward,
    required this.target,
    required this.progressOf,
  });
}

final List<AchievementDef> kAchievements = [
  AchievementDef(
    id: 'first_spark',
    title: 'First Spark',
    description: 'Complete your first level.',
    icon: Icons.flag_rounded,
    color: const [NovaColors.green, NovaColors.cyan],
    reward: 20,
    target: 1,
    progressOf: (s) => s.levelsCompleted,
  ),
  AchievementDef(
    id: 'reactor_tech',
    title: 'Reactor Technician',
    description: 'Charge 50 reactors in total.',
    icon: Icons.bolt_rounded,
    color: const [NovaColors.green, NovaColors.cyan],
    reward: 40,
    target: 50,
    progressOf: (s) => s.lifeReactors,
  ),
  AchievementDef(
    id: 'reactor_master',
    title: 'Reactor Master',
    description: 'Charge 250 reactors in total.',
    icon: Icons.electric_bolt_rounded,
    color: const [NovaColors.gold, Color(0xFFFF8A3D)],
    reward: 150,
    target: 250,
    progressOf: (s) => s.lifeReactors,
  ),
  AchievementDef(
    id: 'chain_five',
    title: 'Chain Reaction',
    description: 'Land a x5 reactor chain.',
    icon: Icons.auto_awesome_rounded,
    color: const [NovaColors.magenta, NovaColors.violet],
    reward: 30,
    target: 5,
    progressOf: (s) => s.lifeChainBest,
  ),
  AchievementDef(
    id: 'chain_ten',
    title: 'Overload',
    description: 'Land a x10 reactor chain.',
    icon: Icons.whatshot_rounded,
    color: const [NovaColors.red, NovaColors.magenta],
    reward: 100,
    target: 10,
    progressOf: (s) => s.lifeChainBest,
  ),
  AchievementDef(
    id: 'crystal_collector',
    title: 'Crystal Collector',
    description: 'Collect 100 crystals from the field.',
    icon: Icons.diamond_rounded,
    color: const [NovaColors.cyan, NovaColors.blue],
    reward: 40,
    target: 100,
    progressOf: (s) => s.lifeCrystalsCollected,
  ),
  AchievementDef(
    id: 'crystal_hoarder',
    title: 'Crystal Hoarder',
    description: 'Collect 500 crystals from the field.',
    icon: Icons.diamond_rounded,
    color: const [NovaColors.blue, NovaColors.violet],
    reward: 150,
    target: 500,
    progressOf: (s) => s.lifeCrystalsCollected,
  ),
  AchievementDef(
    id: 'perfectionist',
    title: 'Perfectionist',
    description: 'Earn 3 stars on 10 levels.',
    icon: Icons.military_tech_rounded,
    color: const [NovaColors.gold, NovaColors.red],
    reward: 60,
    target: 10,
    progressOf: (s) => s.perfectLevels,
  ),
  AchievementDef(
    id: 'sharp_shooter',
    title: 'Sharp Shooter',
    description: 'Launch 200 tokens.',
    icon: Icons.rocket_launch_rounded,
    color: const [NovaColors.violet, NovaColors.pink],
    reward: 50,
    target: 200,
    progressOf: (s) => s.lifeBallsLaunched,
  ),
  AchievementDef(
    id: 'field_engineer',
    title: 'Field Engineer',
    description: 'Trigger 100 magnetic/gravity fields.',
    icon: Icons.blur_on_rounded,
    color: const [NovaColors.blue, NovaColors.violet],
    reward: 50,
    target: 100,
    progressOf: (s) => s.lifeMagnetUses,
  ),
  AchievementDef(
    id: 'booster_junkie',
    title: 'Booster Junkie',
    description: 'Trigger 100 speed boosters.',
    icon: Icons.speed_rounded,
    color: const [NovaColors.cyan, NovaColors.green],
    reward: 50,
    target: 100,
    progressOf: (s) => s.lifeBoosterUses,
  ),
  AchievementDef(
    id: 'galaxy_conqueror',
    title: 'Galaxy Conqueror',
    description: 'Complete all 40 levels.',
    icon: Icons.public_rounded,
    color: NovaColors.goldGradient,
    reward: 300,
    target: 40,
    progressOf: (s) => s.levelsCompleted,
  ),
];
