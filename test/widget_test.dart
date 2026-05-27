import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flower_watering/widgets/water_level_bar.dart';

void main() {
  test('colorFor: endpoints match the expected lerps', () {
    expect(
      WaterLevelBar.colorFor(1.0),
      Color.lerp(Colors.amber, Colors.green, 1.0),
    );
    expect(
      WaterLevelBar.colorFor(0.5),
      Color.lerp(Colors.amber, Colors.green, 0.0),
    );
    expect(
      WaterLevelBar.colorFor(0.0),
      Color.lerp(Colors.red, Colors.amber, 0.0),
    );
  });

  test('colorFor: clamps out-of-range values to the endpoints', () {
    expect(WaterLevelBar.colorFor(1.5), WaterLevelBar.colorFor(1.0));
    expect(WaterLevelBar.colorFor(-0.2), WaterLevelBar.colorFor(0.0));
  });
}
