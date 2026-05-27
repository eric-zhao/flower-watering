import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../models/plant.dart';
import '../services/plant_repository.dart';
import '../services/settings_service.dart';
import '../services/sync_service.dart';
import '../widgets/plant_card.dart';
import 'add_plant_screen.dart';
import 'plant_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.settings,
    required this.syncService,
  });

  final PlantRepository repository;
  final SettingsService settings;
  final SyncService syncService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  Future<void> _openAdd() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddPlantScreen(repository: widget.repository),
      ),
    );
  }

  Future<void> _openDetail(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlantDetailScreen(
          repository: widget.repository,
          plantId: id,
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          settings: widget.settings,
          syncService: widget.syncService,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Plant plant) async {
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
      widget.repository.delete(plant.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plants = widget.repository.all();

    return Scaffold(
      appBar: AppBar(
        title: Text(S.myPlants),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: S.settings,
            onPressed: _openSettings,
          ),
        ],
      ),
      body: plants.isEmpty
          ? const _EmptyState()
          : RefreshIndicator(
              onRefresh: () async {
                await widget.syncService.runSync();
                if (mounted) setState(() {});
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: plants.length,
                itemBuilder: (_, i) {
                  final plant = plants[i];
                  return PlantCard(
                    plant: plant,
                    onTap: () => _openDetail(plant.id),
                    onDelete: () => _confirmDelete(plant),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_florist,
              size: 64, color: Colors.green.shade200),
          const SizedBox(height: 12),
          Text(
            S.noPlantsYet,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(S.tapPlusToAdd),
        ],
      ),
    );
  }
}
