import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/plant.dart';
import '../services/plant_repository.dart';
import '../widgets/water_level_bar.dart';

class PlantDetailScreen extends StatefulWidget {
  const PlantDetailScreen({
    super.key,
    required this.repository,
    required this.plantId,
  });

  final PlantRepository repository;
  final String plantId;

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  void _markWateredToday() {
    widget.repository.markWatered(widget.plantId, DateTime.now());
  }

  Future<void> _pickWateredDate(Plant plant) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: plant.lastWatered,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      widget.repository.markWatered(widget.plantId, picked);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete plant?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.repository.delete(widget.plantId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final plant = widget.repository.byId(widget.plantId);
    if (plant == null) {
      return const Scaffold(body: Center(child: Text('Plant not found')));
    }

    final now = DateTime.now();
    final remaining = plant.remainingDays(now);
    final level = plant.waterLevel(now);
    final dateFmt = DateFormat.yMMMMd();

    final daysLabel = remaining > 0
        ? '$remaining day${remaining == 1 ? '' : 's'} until next watering'
        : remaining == 0
            ? 'Due today'
            : 'Overdue by ${-remaining} day${remaining == -1 ? '' : 's'}';

    return Scaffold(
      appBar: AppBar(
        title: Text(plant.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroImage(bytes: plant.imageBytes),
            const SizedBox(height: 20),
            _InfoRow(
                icon: Icons.schedule,
                label: 'Every ${plant.frequencyDays} days'),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.water_drop_outlined,
              label: 'Last watered: ${dateFmt.format(plant.lastWatered)}',
            ),
            const SizedBox(height: 20),
            WaterLevelBar(level: level, height: 20),
            const SizedBox(height: 12),
            Text(
              daysLabel,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _markWateredToday,
                    icon: const Icon(Icons.water_drop),
                    label: const Text('Watered today'),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: () => _pickWateredDate(plant),
                  icon: const Icon(Icons.calendar_today),
                  tooltip: 'Pick a different date',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.local_florist,
            size: 96, color: Colors.green.shade300),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        bytes,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}
