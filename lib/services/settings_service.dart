import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

const _kLanguage = 'language';
const _kUserName = 'userName';

class SettingsService extends ChangeNotifier {
  SettingsService(this._box);

  static SettingsService? _instance;
  static SettingsService get instance => _instance!;
  static void register(SettingsService s) => _instance = s;

  final Box _box;

  String get language => _box.get(_kLanguage, defaultValue: 'zh') as String;
  String get userName => _box.get(_kUserName, defaultValue: '') as String;

  Future<void> setLanguage(String code) async {
    await _box.put(_kLanguage, code);
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    await _box.put(_kUserName, name.trim());
    notifyListeners();
  }
}
