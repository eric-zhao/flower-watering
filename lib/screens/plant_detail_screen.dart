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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroImage(bytes: plant.imageBytes),
            const SizedBox(height: 12),
            _MetaRow(
              schedule: S.everyNDays(plant.frequencyDays),
              lastWatered:
                  S.lastWateredOn(dateFmt.format(plant.lastWatered)),
            ),
            const SizedBox(height: 12),
            WaterLevelBar(level: level, height: 16),
            const SizedBox(height: 8),
            Text(
              daysLabel,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _markWateredToday,
                    icon: const Icon(Icons.water_drop),
                    label: Text(S.wateredToday),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _pickWateredDate(plant),
                  icon: const Icon(Icons.calendar_today),
                  tooltip: S.pickADate,
                ),
              ],
            ),
            const SizedBox(height: 12),
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
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: Icon(Icons.history,
            color: Colors.green.shade700, size: 20),
        title: Text(S.waterHistory,
            style: Theme.of(context).textTheme.bodyMedium),
        subtitle: entries.isEmpty
            ? Text(S.noHistoryYet,
                style: Theme.of(context).textTheme.bodySmall)
            : Text(dateFmt.format(entries.first.date),
                style: Theme.of(context).textTheme.bodySmall),
        children: entries.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(S.noHistoryYet),
                ),
              ]
            : entries
                .map(
                  (e) => ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: const Icon(Icons.water_drop, size: 16),
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.schedule, required this.lastWatered});
  final String schedule;
  final String lastWatered;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final iconColor = Colors.grey.shade700;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(schedule,
                    style: style, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.water_drop_outlined,
                  size: 18, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(lastWatered,
                    style: style, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
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
        height: 160,
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.local_florist,
            size: 80, color: Colors.green.shade300),
      );
    }
    return AdaptiveImage(bytes: bytes, maxHeight: 220);
  }
}
