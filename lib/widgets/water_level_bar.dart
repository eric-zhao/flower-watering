import 'package:flutter/material.dart';

class WaterLevelBar extends StatelessWidget {
  const WaterLevelBar({
    super.key,
    required this.level,
    this.height = 12,
  });

  /// 1.0 = freshly watered (green), 0.0 = due or overdue (red).
  final double level;
  final double height;

  static Color colorFor(double level) {
    final clamped = level.clamp(0.0, 1.0);
    if (clamped >= 0.5) {
      return Color.lerp(Colors.amber, Colors.green, (clamped - 0.5) * 2)!;
    }
    return Color.lerp(Colors.red, Colors.amber, clamped * 2)!;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colorFor(level),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}
