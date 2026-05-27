import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'i18n/strings.dart';
import 'models/plant.dart';
import 'screens/home_screen.dart';
import 'services/plant_repository.dart';
import 'services/settings_service.dart';

const _plantsBox = 'plants';
const _settingsBox = 'settings';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(PlantAdapter());
  await initializeDateFormatting('zh_CN');
  await initializeDateFormatting('en');

  final settingsBox = await Hive.openBox(_settingsBox);
  final settings = SettingsService(settingsBox);
  SettingsService.register(settings);

  final plantsBox = await _openOrReset();
  final repo = PlantRepository(plantsBox, settings);
  if (kDebugMode && plantsBox.isEmpty) {
    _seedDemoPlants(plantsBox);
  }

  runApp(FlowerWateringApp(settings: settings, repository: repo));
}

Future<Box<Plant>> _openOrReset() async {
  try {
    return await Hive.openBox<Plant>(_plantsBox);
  } catch (_) {
    await Hive.deleteBoxFromDisk(_plantsBox);
    return await Hive.openBox<Plant>(_plantsBox);
  }
}

void _seedDemoPlants(Box<Plant> box) {
  final today = DateTime.now();
  final midnight = DateTime(today.year, today.month, today.day);
  final demos = [
    Plant(
      id: 'demo-rosemary',
      name: '迷迭香',
      imageBytes: Uint8List(0),
      frequencyDays: 5,
      history: [
        WateringEntry(
            date: midnight.subtract(const Duration(days: 7)), by: ''),
      ],
    ),
    Plant(
      id: 'demo-money-tree',
      name: '发财树',
      imageBytes: Uint8List(0),
      frequencyDays: 10,
      history: [
        WateringEntry(
            date: midnight.subtract(const Duration(days: 7)), by: ''),
      ],
    ),
    Plant(
      id: 'demo-aloe',
      name: '芦荟',
      imageBytes: Uint8List(0),
      frequencyDays: 14,
      history: [
        WateringEntry(
            date: midnight.subtract(const Duration(days: 2)), by: ''),
      ],
    ),
  ];
  for (final p in demos) {
    box.put(p.id, p);
  }
}

class FlowerWateringApp extends StatelessWidget {
  const FlowerWateringApp({
    super.key,
    required this.settings,
    required this.repository,
  });

  final SettingsService settings;
  final PlantRepository repository;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (_, __) => MaterialApp(
        title: S.appTitle,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        home: HomeScreen(repository: repository, settings: settings),
      ),
    );
  }
}
