import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/plant.dart';

class PlantRepository extends ChangeNotifier {
  PlantRepository(this._box);

  final Box<Plant> _box;
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
    final plant = Plant(
      id: _uuid.v4(),
      name: name,
      imageBytes: imageBytes,
      frequencyDays: frequencyDays,
      lastWatered: _midnight(DateTime.now()),
    );
    _box.put(plant.id, plant);
    notifyListeners();
    return plant;
  }

  void markWatered(String id, DateTime date) {
    final plant = _box.get(id);
    if (plant == null) return;
    plant.lastWatered = _midnight(date);
    _box.put(plant.id, plant);
    notifyListeners();
  }

  void delete(String id) {
    _box.delete(id);
    notifyListeners();
  }

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
}
