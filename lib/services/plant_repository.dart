import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/plant.dart';
import 'settings_service.dart';
import 'sync_service.dart';

class PlantRepository extends ChangeNotifier {
  PlantRepository(this._box, this._settings);

  final Box<Plant> _box;
  final SettingsService _settings;
  final _uuid = const Uuid();

  /// Wired after both Repository and SyncService are constructed (chicken/egg).
  SyncService? sync;

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
    final today = _midnight(DateTime.now());
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final plant = Plant(
      id: _uuid.v4(),
      name: name,
      imageBytes: imageBytes,
      frequencyDays: frequencyDays,
      history: [WateringEntry(date: today, by: _settings.userName)],
      updatedAt: nowMs,
    );
    _box.put(plant.id, plant);
    sync?.enqueueUpsert(plant);
    sync?.enqueueWatering(plant.id, plant.history.first);
    notifyListeners();
    return plant;
  }

  void markWatered(String id, DateTime date) {
    final plant = _box.get(id);
    if (plant == null) return;
    final entry = WateringEntry(date: _midnight(date), by: _settings.userName);
    plant.history.add(entry);
    _box.put(plant.id, plant);
    sync?.enqueueWatering(plant.id, entry);
    notifyListeners();
  }

  void delete(String id) {
    _box.delete(id);
    sync?.enqueueDelete(id, DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
  }

  // -------- methods used by SyncService to apply pulled state --------

  void applyRemoteUpsert(Plant plant) {
    _box.put(plant.id, plant);
    notifyListeners();
  }

  void applyRemoteDelete(String id) {
    _box.delete(id);
    notifyListeners();
  }

  void applyRemoteWatering(String plantId, WateringEntry entry) {
    final plant = _box.get(plantId);
    if (plant == null) return;
    plant.history.add(entry);
    _box.put(plant.id, plant);
    notifyListeners();
  }

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
}
