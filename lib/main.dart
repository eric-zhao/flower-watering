import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/plant.dart';
import 'screens/home_screen.dart';
import 'services/plant_repository.dart';

const _boxName = 'plants';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(PlantAdapter());
  final box = await _openOrReset();
  if (kDebugMode && box.isEmpty) {
    _seedDemoPlants(box);
  }
  runApp(FlowerWateringApp(repository: PlantRepository(box)));
}

Future<Box<Plant>> _openOrReset() async {
  try {
    return await Hive.openBox<Plant>(_boxName);
  } catch (_) {
    await Hive.deleteBoxFromDisk(_boxName);
    return await Hive.openBox<Plant>(_boxName);
  }
}

void _seedDemoPlants(Box<Plant> box) {
  final today = DateTime.now();
  final midnight = DateTime(today.year, today.month, today.day);
  final demos = [
    Plant(
      id: 'demo-rosemary',
      name: 'Rosemary',
      imageBytes: Uint8List(0),
      frequencyDays: 5,
      lastWatered: midnight.subtract(const Duration(days: 7)),
    ),
    Plant(
      id: 'demo-money-tree',
      name: 'Money Tree',
      imageBytes: Uint8List(0),
      frequencyDays: 10,
      lastWatered: midnight.subtract(const Duration(days: 7)),
    ),
    Plant(
      id: 'demo-aloe',
      name: 'Aloe Vera',
      imageBytes: Uint8List(0),
      frequencyDays: 14,
      lastWatered: midnight.subtract(const Duration(days: 2)),
    ),
  ];
  for (final p in demos) {
    box.put(p.id, p);
  }
}

class FlowerWateringApp extends StatelessWidget {
  const FlowerWateringApp({super.key, required this.repository});

  final PlantRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flower Watering',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: HomeScreen(repository: repository),
    );
  }
}
