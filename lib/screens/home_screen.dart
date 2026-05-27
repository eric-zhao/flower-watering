import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../services/plant_repository.dart';
import '../widgets/plant_card.dart';
import 'add_plant_screen.dart';
import 'plant_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final PlantRepository repository;

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

  Future<void> _confirmDelete(Plant plant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${plant.name}?'),
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
      widget.repository.delete(plant.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plants = widget.repository.all();

    return Scaffold(
      appBar: AppBar(title: const Text('My Plants')),
      body: plants.isEmpty
          ? const _EmptyState()
          : RefreshIndicator(
              onRefresh: () async => setState(() {}),
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
            'No plants yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text('Tap + to add your first plant'),
        ],
      ),
    );
  }
}
