import 'dart:typed_data';

import 'package:hive/hive.dart';

class Plant {
  Plant({
    required this.id,
    required this.name,
    required this.imageBytes,
    required this.frequencyDays,
    required this.lastWatered,
  });

  final String id;
  String name;

  /// Empty when no photo has been picked.
  Uint8List imageBytes;

  int frequencyDays;
  DateTime lastWatered;

  bool get hasImage => imageBytes.isNotEmpty;

  int daysSinceWatered(DateTime now) =>
      _midnight(now).difference(_midnight(lastWatered)).inDays;

  int remainingDays(DateTime now) => frequencyDays - daysSinceWatered(now);

  double waterLevel(DateTime now) =>
      (remainingDays(now) / frequencyDays).clamp(0.0, 1.0);

  bool isOverdue(DateTime now) => remainingDays(now) <= 0;

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
}

class PlantAdapter extends TypeAdapter<Plant> {
  @override
  final int typeId = 1;

  @override
  Plant read(BinaryReader reader) {
    return Plant(
      id: reader.readString(),
      name: reader.readString(),
      imageBytes: Uint8List.fromList(reader.readByteList()),
      frequencyDays: reader.readInt(),
      lastWatered: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, Plant obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeByteList(obj.imageBytes);
    writer.writeInt(obj.frequencyDays);
    writer.writeInt(obj.lastWatered.millisecondsSinceEpoch);
  }
}
