import '../services/settings_service.dart';

/// Lookup table keyed by language code. Each method returns the localized
/// string based on the current setting. Add a new language by adding a new
/// key to the inner maps.
class S {
  static String _t(Map<String, String> m) =>
      m[SettingsService.instance.language] ?? m['en'] ?? '';

  // App + screens
  static String get appTitle =>
      _t({'zh': '花草浇水', 'en': 'Flower Watering'});
  static String get myPlants => _t({'zh': '我的植物', 'en': 'My Plants'});
  static String get noPlantsYet =>
      _t({'zh': '还没有植物', 'en': 'No plants yet'});
  static String get tapPlusToAdd => _t({
        'zh': '点击 + 添加第一株植物',
        'en': 'Tap + to add your first plant',
      });

  // Add plant
  static String get addPlant => _t({'zh': '添加植物', 'en': 'Add Plant'});
  static String get tapToAddPhoto =>
      _t({'zh': '点击添加照片', 'en': 'Tap to add a photo'});
  static String get chooseFromGallery =>
      _t({'zh': '从相册选择', 'en': 'Choose from gallery'});
  static String get takeAPhoto =>
      _t({'zh': '拍照', 'en': 'Take a photo'});
  static String get removePhoto =>
      _t({'zh': '移除照片', 'en': 'Remove photo'});
  static String get plantName =>
      _t({'zh': '植物名称', 'en': 'Plant name'});
  static String get waterEveryDays =>
      _t({'zh': '浇水间隔（天）', 'en': 'Water every (days)'});
  static String get save => _t({'zh': '保存', 'en': 'Save'});
  static String get required => _t({'zh': '必填', 'en': 'Required'});
  static String get enterANumber =>
      _t({'zh': '请输入数字', 'en': 'Enter a number'});
  static String get between1And365 =>
      _t({'zh': '1 到 365 之间', 'en': 'Between 1 and 365'});
  static String pickerError(String e) =>
      _t({'zh': '无法选择图片：$e', 'en': 'Could not pick image: $e'});

  // Detail
  static String everyNDays(int n) =>
      _t({'zh': '每 $n 天浇一次', 'en': 'Every $n days'});
  static String lastWateredOn(String date) =>
      _t({'zh': '上次浇水：$date', 'en': 'Last watered: $date'});
  static String daysUntilNext(int n) => _t({
        'zh': '距离下次浇水还有 $n 天',
        'en': '$n day${n == 1 ? '' : 's'} until next watering',
      });
  static String get dueToday => _t({'zh': '今天该浇水', 'en': 'Due today'});
  static String overdueByDays(int n) => _t({
        'zh': '已逾期 $n 天',
        'en': 'Overdue by $n day${n == 1 ? '' : 's'}',
      });
  static String get wateredToday =>
      _t({'zh': '今天已浇水', 'en': 'Watered today'});
  static String get pickADate =>
      _t({'zh': '选择其他日期', 'en': 'Pick a different date'});
  static String get plantNotFound =>
      _t({'zh': '找不到此植物', 'en': 'Plant not found'});
  static String get waterHistory =>
      _t({'zh': '浇水历史', 'en': 'Water history'});
  static String get noHistoryYet =>
      _t({'zh': '尚无浇水记录', 'en': 'No watering recorded yet'});
  static String byName(String name) =>
      _t({'zh': '由 $name 浇水', 'en': 'Watered by $name'});
  static const String anonymous = '';
  static String get unknownWaterer =>
      _t({'zh': '匿名', 'en': 'Anonymous'});

  // Card list
  static String daysLeft(int n) => _t({
        'zh': '剩余 $n 天',
        'en': '$n day${n == 1 ? '' : 's'} left',
      });

  // Delete confirm
  static String deletePlantTitle(String name) =>
      _t({'zh': '删除 $name？', 'en': 'Delete $name?'});
  static String get cannotBeUndone =>
      _t({'zh': '此操作无法撤销。', 'en': 'This cannot be undone.'});
  static String get cancel => _t({'zh': '取消', 'en': 'Cancel'});
  static String get delete => _t({'zh': '删除', 'en': 'Delete'});
  static String get deletePlant =>
      _t({'zh': '删除植物', 'en': 'Delete plant'});

  // Settings
  static String get settings => _t({'zh': '设置', 'en': 'Settings'});
  static String get language => _t({'zh': '语言', 'en': 'Language'});
  static String get chinese => _t({'zh': '中文', 'en': 'Chinese'});
  static String get english => _t({'zh': '英文', 'en': 'English'});
  static String get yourName => _t({'zh': '您的名字', 'en': 'Your name'});
  static String get yourNameHint => _t({
        'zh': '用于记录每次浇水是谁',
        'en': 'Used to record who watered each plant',
      });

  // Family Sync
  static String get familySync => _t({'zh': '家庭共享', 'en': 'Family Sync'});
  static String get householdPasscode =>
      _t({'zh': '家庭口令', 'en': 'Household passcode'});
  static String get householdPasscodeHint => _t({
        'zh': '家人输入同一个口令即可共享植物数据',
        'en': 'Family members who enter the same passcode share plant data',
      });
  static String get serverUrl => _t({'zh': '服务器地址', 'en': 'Server URL'});
  static String get syncNow => _t({'zh': '立即同步', 'en': 'Sync now'});
  static String get notJoined =>
      _t({'zh': '尚未加入家庭', 'en': 'Not joined'});
  static String pendingChanges(int n) => _t({
        'zh': '离线 — $n 项待同步',
        'en': 'Offline — $n pending',
      });
  static String syncedNMinAgo(int n) => _t({
        'zh': '已同步 — $n 分钟前',
        'en': 'Synced — $n min ago',
      });
  static String get syncedJustNow =>
      _t({'zh': '已同步 — 刚刚', 'en': 'Synced — just now'});
  static String syncFailed(String msg) =>
      _t({'zh': '同步失败：$msg', 'en': 'Sync failed: $msg'});
}
