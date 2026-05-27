import 'dart:typed_data';

import 'package:hive/hive.dart';

class WateringEntry {
  WateringEntry({required this.date, required this.by});

  final DateTime date;
  final String by; // empty when no user name was set

  WateringEntry copyWith({DateTime? date, String? by}) =>
      WateringEntry(date: date ?? this.date, by: by ?? this.by);
}

class Plant {
  Plant({
    required this.id,
    required this.name,
    required this.imageBytes,
    required this.frequencyDays,
    required this.history,
    required this.updatedAt,
  });

  final String id;
  String name;
  Uint8List imageBytes;
  int frequencyDays;
  List<WateringEntry> history;

  /// ms since epoch. Bumped when metadata changes (name / photo / frequency).
  /// Watering inserts do NOT bump it; they sync via their own endpoint.
  int updatedAt;

  bool get hasImage => imageBytes.isNotEmpty;

  DateTime get lastWatered => history.isEmpty
      ? DateTime.now()
      : history.reduce((a, b) => a.date.isAfter(b.date) ? a : b).date;

  int daysSinceWatered(DateTime now) =>
      _midnight(now).difference(_midnight(lastWatered)).inDays;

  int remainingDays(DateTime now) => frequencyDays - daysSinceWatered(now);

  double waterLevel(DateTime now) =>
      (remainingDays(now) / frequencyDays).clamp(0.0, 1.0);

  bool isOverdue(DateTime now) => remainingDays(now) <= 0;

  List<WateringEntry> sortedHistory() {
    final list = [...history];
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
}

class PlantAdapter extends TypeAdapter<Plant> {
  @override
  final int typeId = 3;

  @override
  Plant read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final imageBytes = Uint8List.fromList(reader.readByteList());
    final frequencyDays = reader.readInt();
    final updatedAt = reader.readInt();
    final n = reader.readInt();
    final history = <WateringEntry>[];
    for (var i = 0; i < n; i++) {
      final ts = reader.readInt();
      final by = reader.readString();
      history.add(
        WateringEntry(date: DateTime.fromMillisecondsSinceEpoch(ts), by: by),
      );
    }
    return Plant(
      id: id,
      name: name,
      imageBytes: imageBytes,
      frequencyDays: frequencyDays,
      history: history,
      updatedAt: updatedAt,
    );
  }

  @override
  void write(BinaryWriter writer, Plant obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeByteList(obj.imageBytes);
    writer.writeInt(obj.frequencyDays);
    writer.writeInt(obj.updatedAt);
    writer.writeInt(obj.history.length);
    for (final e in obj.history) {
      writer.writeInt(e.date.millisecondsSinceEpoch);
      writer.writeString(e.by);
    }
  }
}
