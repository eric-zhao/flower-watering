import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../i18n/strings.dart';
import '../models/plant.dart';
import '../services/plant_repository.dart';
import '../services/settings_service.dart';
import '../widgets/adaptive_image.dart';
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
    SettingsService.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onChange);
    SettingsService.instance.removeListener(_onChange);
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
    final plant = widget.repository.byId(widget.plantId);
    if (plant == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.deletePlantTitle(plant.name)),
        content: Text(S.cannotBeUndone),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.delete),
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
      return Scaffold(body: Center(child: Text(S.plantNotFound)));
    }

    final now = DateTime.now();
    final remaining = plant.remainingDays(now);
    final level = plant.waterLevel(now);
    final locale = SettingsService.instance.language == 'zh' ? 'zh_CN' : 'en';
    final dateFmt = DateFormat.yMMMMd(locale);

    final daysLabel = remaining > 0
        ? S.daysUntilNext(remaining)
        : remaining == 0
            ? S.dueToday
            : S.overdueByDays(-remaining);

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
              label: S.everyNDays(plant.frequencyDays),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.water_drop_outlined,
              label: S.lastWateredOn(dateFmt.format(plant.lastWatered)),
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
                    label: Text(S.wateredToday),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: () => _pickWateredDate(plant),
                  icon: const Icon(Icons.calendar_today),
                  tooltip: S.pickADate,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _HistorySection(plant: plant, dateFmt: dateFmt),
          ],
        ),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.plant, required this.dateFmt});
  final Plant plant;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final entries = plant.sortedHistory();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(Icons.history, color: Colors.green.shade700),
        title: Text(S.waterHistory),
        subtitle: entries.isEmpty
            ? Text(S.noHistoryYet)
            : Text(dateFmt.format(entries.first.date)),
        children: entries.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(S.noHistoryYet),
                ),
              ]
            : entries
                .map(
                  (e) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.water_drop, size: 18),
                    title: Text(dateFmt.format(e.date)),
                    subtitle: Text(
                      e.by.isEmpty ? S.unknownWaterer : S.byName(e.by),
                    ),
                  ),
                )
                .toList(),
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
    return AdaptiveImage(bytes: bytes);
  }
}
