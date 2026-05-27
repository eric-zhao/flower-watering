import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/plant.dart';
import 'water_level_bar.dart';

class PlantCard extends StatelessWidget {
  const PlantCard({super.key, required this.plant, required this.onTap});

  final Plant plant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = plant.remainingDays(now);
    final level = plant.waterLevel(now);

    final daysLabel = remaining > 0
        ? '$remaining day${remaining == 1 ? '' : 's'} left'
        : remaining == 0
            ? 'Due today'
            : 'Overdue by ${-remaining} day${remaining == -1 ? '' : 's'}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Thumbnail(bytes: plant.imageBytes),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    WaterLevelBar(level: level),
                    const SizedBox(height: 6),
                    Text(
                      daysLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.local_florist, color: Colors.green.shade400),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        bytes,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}
