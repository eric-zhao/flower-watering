import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

const _kLanguage = 'language';
const _kUserName = 'userName';
const _kServerUrl = 'serverUrl';
const _kHousehold = 'householdPasscode';

const defaultServerUrl = 'http://47.237.79.175:7100';

class SettingsService extends ChangeNotifier {
  SettingsService(this._box);

  static SettingsService? _instance;
  static SettingsService get instance => _instance!;
  static void register(SettingsService s) => _instance = s;

  final Box _box;

  String get language => _box.get(_kLanguage, defaultValue: 'zh') as String;
  String get userName => _box.get(_kUserName, defaultValue: '') as String;
  String get serverUrl =>
      _box.get(_kServerUrl, defaultValue: defaultServerUrl) as String;
  String get householdPasscode =>
      _box.get(_kHousehold, defaultValue: '') as String;

  bool get syncEnabled => householdPasscode.isNotEmpty;

  Future<void> setLanguage(String code) async {
    await _box.put(_kLanguage, code);
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    await _box.put(_kUserName, name.trim());
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    await _box.put(_kServerUrl, url.trim());
    notifyListeners();
  }

  Future<void> setHouseholdPasscode(String passcode) async {
    await _box.put(_kHousehold, passcode.trim());
    notifyListeners();
  }
}
