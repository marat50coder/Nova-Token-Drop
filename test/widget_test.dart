import 'package:flutter_test/flutter_test.dart';

import 'package:dropgame/game/level.dart';

void main() {
  test('all 40 levels build with required reactors and a core', () {
    for (var id = 1; id <= 40; id++) {
      final level = LevelFactory.build(id);
      expect(level.reactorCount, greaterThanOrEqualTo(1));
      expect(level.devices.any((d) => d.mustCharge), isTrue);
      expect(level.ballCount, greaterThan(0));
    }
  });
}
