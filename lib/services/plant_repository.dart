import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/plant.dart';
import 'settings_service.dart';

class PlantRepository extends ChangeNotifier {
  PlantRepository(this._box, this._settings);

  final Box<Plant> _box;
  final SettingsService _settings;
  final _uuid = const Uuid();

  List<Plant> all() {
    final list = _box.values.toList();
    final now = DateTime.now();
    list.sort((a, b) => a.remainingDays(now).compareTo(b.remainingDays(now)));
    return list;
  }

  Plant? byId(String id) => _box.get(id);

  Plant create({
    required String name,
    required Uint8List imageBytes,
    required int frequencyDays,
  }) {
    final now = _midnight(DateTime.now());
    final plant = Plant(
      id: _uuid.v4(),
      name: name,
      imageBytes: imageBytes,
      frequencyDays: frequencyDays,
      history: [WateringEntry(date: now, by: _settings.userName)],
    );
    _box.put(plant.id, plant);
    notifyListeners();
    return plant;
  }

  /// Append a watering entry. Date is normalized to midnight. The current
  /// user-name setting is attached.
  void markWatered(String id, DateTime date) {
    final plant = _box.get(id);
    if (plant == null) return;
    plant.history.add(
      WateringEntry(date: _midnight(date), by: _settings.userName),
    );
    _box.put(plant.id, plant);
    notifyListeners();
  }

  void delete(String id) {
    _box.delete(id);
    notifyListeners();
  }

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
}
