import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../models/plant.dart';
import 'plant_repository.dart';
import 'settings_service.dart';

const _kLastSyncedAt = 'lastSyncedAt';
const _kQueue = 'queue';
const _kLastSyncStatus = 'lastSyncStatus'; // 'ok' | 'error' | ''
const _kLastSyncMessage = 'lastSyncMessage';
const _kLastSyncWallClock = 'lastSyncWallClock';

/// One queued operation to push to the server.
class PendingOp {
  PendingOp({
    required this.kind,
    required this.plantId,
    required this.payload,
  });

  /// 'plant_upsert' | 'plant_delete' | 'watering_add'
  final String kind;
  final String plantId;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'plantId': plantId,
        'payload': payload,
      };

  static PendingOp fromJson(Map<String, dynamic> m) => PendingOp(
        kind: m['kind'] as String,
        plantId: m['plantId'] as String,
        payload: Map<String, dynamic>.from(m['payload'] as Map),
      );
}

/// Holds the household sync queue + reconciles local Hive with the server.
class SyncService extends ChangeNotifier {
  SyncService(this._box, this._settings, this._repo) {
    _settings.addListener(_onSettingsChanged);
  }

  final Box _box;
  final SettingsService _settings;
  final PlantRepository _repo;

  bool _running = false;
  String _lastObservedPasscode = '';

  // ---- persisted state ----------------------------------------------------

  int get lastSyncedAt => _box.get(_kLastSyncedAt, defaultValue: 0) as int;
  String get lastStatus =>
      _box.get(_kLastSyncStatus, defaultValue: '') as String;
  String get lastMessage =>
      _box.get(_kLastSyncMessage, defaultValue: '') as String;
  int get lastWallClock =>
      _box.get(_kLastSyncWallClock, defaultValue: 0) as int;

  List<PendingOp> get queue {
    final raw = _box.get(_kQueue, defaultValue: <dynamic>[]) as List;
    return raw
        .map((e) => PendingOp.fromJson(jsonDecode(e as String) as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveQueue(List<PendingOp> ops) async {
    await _box.put(_kQueue, ops.map((o) => jsonEncode(o.toJson())).toList());
  }

  // ---- enqueue API (called by PlantRepository) ----------------------------

  Future<void> enqueueUpsert(Plant p) async {
    if (!_settings.syncEnabled) return;
    final ops = queue;
    // Collapse: if there's already an upsert for this plant, replace it.
    ops.removeWhere(
      (o) => o.kind == 'plant_upsert' && o.plantId == p.id,
    );
    ops.add(
      PendingOp(
        kind: 'plant_upsert',
        plantId: p.id,
        payload: {
          'name': p.name,
          'image_b64':
              p.imageBytes.isEmpty ? null : base64Encode(p.imageBytes),
          'frequency_days': p.frequencyDays,
          'updated_at': p.updatedAt,
        },
      ),
    );
    await _saveQueue(ops);
    notifyListeners();
  }

  Future<void> enqueueDelete(String plantId, int deletedAt) async {
    if (!_settings.syncEnabled) return;
    final ops = queue;
    ops.removeWhere((o) => o.plantId == plantId);
    ops.add(
      PendingOp(
        kind: 'plant_delete',
        plantId: plantId,
        payload: {'deleted_at': deletedAt},
      ),
    );
    await _saveQueue(ops);
    notifyListeners();
  }

  Future<void> enqueueWatering(String plantId, WateringEntry e) async {
    if (!_settings.syncEnabled) return;
    final ops = queue;
    ops.add(
      PendingOp(
        kind: 'watering_add',
        plantId: plantId,
        payload: {
          'watered_date': e.date.millisecondsSinceEpoch,
          'watered_by': e.by,
          'recorded_at': DateTime.now().millisecondsSinceEpoch,
        },
      ),
    );
    await _saveQueue(ops);
    notifyListeners();
  }

  // ---- sync cycle ---------------------------------------------------------

  Future<void> runSync() async {
    if (_running) return;
    if (!_settings.syncEnabled) return;
    _running = true;
    try {
      await _pushQueue();
      await _pullState();
      await _box.put(_kLastSyncStatus, 'ok');
      await _box.put(_kLastSyncMessage, '');
      await _box.put(
        _kLastSyncWallClock,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      await _box.put(_kLastSyncStatus, 'error');
      await _box.put(_kLastSyncMessage, e.toString());
      if (kDebugMode) {
        // ignore: avoid_print
        print('Sync failed: $e');
      }
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<void> _pushQueue() async {
    var pending = queue;
    while (pending.isNotEmpty) {
      final op = pending.first;
      try {
        await _sendOp(op);
      } catch (e) {
        // Stop draining on first network failure; keep ops in place.
        rethrow;
      }
      pending.removeAt(0);
      await _saveQueue(pending);
    }
  }

  Future<void> _sendOp(PendingOp op) async {
    final base = _settings.serverUrl;
    final headers = {
      'Content-Type': 'application/json',
      // Percent-encode so non-ASCII passcodes (e.g. Chinese) round-trip
      // through the browser fetch API, which requires ISO-8859-1 headers.
      'X-Household': Uri.encodeComponent(_settings.householdPasscode),
    };
    final body = jsonEncode(op.payload);

    http.Response res;
    switch (op.kind) {
      case 'plant_upsert':
        res = await http
            .put(Uri.parse('$base/api/plants/${op.plantId}'),
                headers: headers, body: body)
            .timeout(const Duration(seconds: 15));
        break;
      case 'plant_delete':
        res = await http
            .delete(Uri.parse('$base/api/plants/${op.plantId}'),
                headers: headers, body: body)
            .timeout(const Duration(seconds: 15));
        break;
      case 'watering_add':
        res = await http
            .post(Uri.parse('$base/api/plants/${op.plantId}/waterings'),
                headers: headers, body: body)
            .timeout(const Duration(seconds: 15));
        break;
      default:
        return;
    }
    if (res.statusCode >= 400) {
      throw Exception('${op.kind} ${op.plantId} -> ${res.statusCode}');
    }
  }

  Future<void> _pullState() async {
    final base = _settings.serverUrl;
    final res = await http
        .get(
          Uri.parse('$base/api/state?since=$lastSyncedAt'),
          headers: {
            'X-Household': Uri.encodeComponent(_settings.householdPasscode),
          },
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('GET /api/state -> ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final serverNow = data['server_now'] as int;
    final plants = (data['plants'] as List).cast<Map<String, dynamic>>();
    final waterings = (data['waterings'] as List).cast<Map<String, dynamic>>();

    for (final p in plants) {
      final local = _repo.byId(p['id'] as String);
      final remoteUpdatedAt = p['updated_at'] as int;
      final remoteDeletedAt = p['deleted_at'] as int?;
      final localMostRecent = local?.updatedAt ?? 0;

      if (remoteDeletedAt != null) {
        if (local == null || remoteDeletedAt > localMostRecent) {
          _repo.applyRemoteDelete(p['id'] as String);
        }
      } else {
        if (local == null || remoteUpdatedAt > localMostRecent) {
          final imgB64 = p['image_b64'] as String?;
          final imgBytes = imgB64 == null
              ? Uint8List(0)
              : base64Decode(imgB64);
          _repo.applyRemoteUpsert(
            Plant(
              id: p['id'] as String,
              name: p['name'] as String,
              imageBytes: imgBytes,
              frequencyDays: p['frequency_days'] as int,
              history: local?.history ?? <WateringEntry>[],
              updatedAt: remoteUpdatedAt,
            ),
          );
        }
      }
    }

    for (final w in waterings) {
      final plant = _repo.byId(w['plant_id'] as String);
      if (plant == null) continue; // skip waterings for unknown plant
      final entry = WateringEntry(
        date: DateTime.fromMillisecondsSinceEpoch(w['watered_date'] as int),
        by: w['watered_by'] as String,
      );
      final dup = plant.history.any(
        (e) =>
            e.date.millisecondsSinceEpoch == entry.date.millisecondsSinceEpoch &&
            e.by == entry.by,
      );
      if (!dup) {
        _repo.applyRemoteWatering(plant.id, entry);
      }
    }

    await _box.put(_kLastSyncedAt, serverNow);
  }

  // ---- triggers -----------------------------------------------------------

  /// Called when settings change: if the passcode flipped from empty to a
  /// real value, seed the queue with all current local plants + waterings
  /// so they get pushed up to the household on first sync.
  void _onSettingsChanged() {
    final current = _settings.householdPasscode;
    if (current != _lastObservedPasscode) {
      final prev = _lastObservedPasscode;
      _lastObservedPasscode = current;
      if (prev.isEmpty && current.isNotEmpty) {
        _seedQueueFromLocal();
      }
      // Reset sync horizon when switching households.
      _box.put(_kLastSyncedAt, 0);
      runSync();
    }
  }

  Future<void> _seedQueueFromLocal() async {
    final ops = <PendingOp>[];
    for (final plant in _repo.all()) {
      ops.add(
        PendingOp(
          kind: 'plant_upsert',
          plantId: plant.id,
          payload: {
            'name': plant.name,
            'image_b64': plant.imageBytes.isEmpty
                ? null
                : base64Encode(plant.imageBytes),
            'frequency_days': plant.frequencyDays,
            'updated_at': plant.updatedAt,
          },
        ),
      );
      for (final e in plant.history) {
        ops.add(
          PendingOp(
            kind: 'watering_add',
            plantId: plant.id,
            payload: {
              'watered_date': e.date.millisecondsSinceEpoch,
              'watered_by': e.by,
              'recorded_at': DateTime.now().millisecondsSinceEpoch,
            },
          ),
        );
      }
    }
    await _saveQueue([...queue, ...ops]);
  }

  Timer? _periodicTimer;

  void startPeriodicSync({Duration interval = const Duration(seconds: 60)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => runSync());
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _periodicTimer?.cancel();
    super.dispose();
  }
}
