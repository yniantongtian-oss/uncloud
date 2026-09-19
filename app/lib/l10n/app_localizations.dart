import 'package:flutter/widgets.dart';

/// Hand-written localizations for Uncloud — no codegen, no .arb files.
///
/// Add a key by adding it to the `en` map (source of truth) and then to
/// every other supported locale map. Look up with `AppLocalizations.of(context)`
/// or the shorthand `context.l10n.someKey`.
class AppLocalizations {
  const AppLocalizations(this.localeName);

  final String localeName;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  static AppLocalizations of(BuildContext context) {
    final result =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(result != null, 'No AppLocalizations found in context');
    return result!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String _t(String key) {
    final lang = _strings[localeName] ?? _strings['en']!;
    return lang[key] ?? _strings['en']![key] ?? key;
  }

  String _p(String key, Map<String, String> params) {
    var text = _t(key);
    params.forEach((name, value) {
      text = text.replaceAll('{$name}', value);
    });
    return text;
  }

  // ---------------------------------------------------------------------------
  // Keys (English is the source of truth; keep both maps in sync).
  // ---------------------------------------------------------------------------
  static const Map<String, Map<String, String>> _strings = {
    'en': {
      // General / nav
      'appTitle': 'Uncloud',
      'tagline': 'No cloud. No account. No server.',
      'ok': 'OK',
      'cancel': 'Cancel',
      'retry': 'Retry',
      'save': 'Save',
      'navTimeline': 'Timeline',
      'navDevices': 'Devices',
      'navTransfers': 'Transfers',
      'settingsTitle': 'Settings',
      'taglineLong': 'Uncloud — your data, your devices',
      // Onboarding
      'onbTitle1': 'Your data stays yours',
      'onbBody1':
          'Uncloud keeps every photo and file on your own devices. Nothing is uploaded anywhere — there is no server to upload to.',
      'onbTitle2': 'Direct phone-PC link',
      'onbBody2':
          'Pair devices with a QR code and sync over your local network at full LAN speed. Works even without internet.',

      'onbTitle3': 'Local AI',
      'onbBody3':
          'Deduplication and face grouping run entirely on your hardware. No model ever sees your data but you.',
      'onbSkip': 'Skip',
      'onbNext': 'Next',
      'onbGetStarted': 'Get started',
      'onbContinueDemo': 'Continue in demo mode',

      // Pairing
      'pairingTitle': 'Pair devices',
      'pairingShowQr': 'Show this code on the other device',
      'pairingScan': 'Scan QR to pair',
      'pairingMyCode': 'My pairing code',
      'pairingScanHint':
          'Open Uncloud on your other device and scan this code, or let it discover you automatically.',
      'pairingDiscovered': 'Discovered on this network',
      'pairingNone': 'Looking for devices on your network…',
      'pairingPair': 'Pair',
      'pairingPaired': 'Paired',
      'pairingSuccess': 'Paired with {name}',
      'pairingInvalidCode': 'This QR code is not a valid Uncloud pairing code.',
      'pairingDone': 'Continue',
      'pairingScanSimTitle': 'Simulate a scan',
      'pairingScanSimBody':
          'Camera scanning is stubbed in demo mode. Pick a device to simulate scanning its QR code.',

      // Timeline
      'timelineTitle': 'Timeline',
      'timelineToday': 'Today',
      'timelineYesterday': 'Yesterday',
      'timelineEmptyTitle': 'No photos yet',
      'timelineEmptyBody':
          'Photos and videos on this device (and backed-up items) will appear here, grouped by day.',
      'timelineItemCount': '{count} items',
      'timelineRefreshFailed': 'Could not refresh the library.',
      'timelineBackupBanner': 'Auto-backup is on — new photos sync to {device}',


      // Devices
      'devicesTitle': 'Devices',
      'devicesEmptyTitle': 'No devices paired',
      'devicesEmptyBody':
          'Pair your PC or another phone to start backing up and browsing files across devices.',
      'devicesPairCta': 'Pair a device',
      'devicesOnline': 'Online',
      'devicesOffline': 'Offline',
      'devicesLastSeenNow': 'Last seen just now',
      'devicesLastSeenMinutes': 'Last seen {minutes} min ago',
      'devicesLastSeenHours': 'Last seen {hours} h ago',
      'devicesLastSeenDays': 'Last seen {days} d ago',
      'devicesStorage': 'Storage',
      'devicesStorageFree': '{free} free of {total}',
      'devicesBrowseFiles': 'Browse files',
      'devicesBackupNow': 'Backup now',
      'devicesBackupStarted': 'Backup to {name} started',
      'devicesUnpair': 'Unpair',
      'devicesUnpairConfirm': 'Unpair {name}? Transfers to it will stop.',
      'deviceDetailTitle': 'Device details',
      'deviceDetailId': 'Device ID',
      'deviceDetailAddress': 'Address',
      'deviceDetailComingSoon':
          'Remote browsing is coming soon — the LAN file API is stubbed in demo mode.',

      // Local AI stubs
      'aiSection': 'Local AI',
      'aiDedupe': 'Find duplicates',
      'aiFaces': 'Group by faces',
      'aiComingSoon': 'Coming soon',
      'aiComingSoonBody':
          'On-device AI features (dedupe, faces) are coming in a future release. Everything will run locally, as always.',


      // Transfers
      'transfersTitle': 'Transfers',
      'transfersActive': 'Active',
      'transfersHistory': 'History',
      'transfersEmptyTitle': 'Nothing transferring',
      'transfersEmptyBody':
          'Files you send or receive between devices will show up here with live progress.',
      'transferQueued': 'Queued',
      'transferActive': 'Transferring',
      'transferDone': 'Completed',
      'transferFailed': 'Failed',
      'transferSending': 'Sending to {name}',
      'transferReceiving': 'Receiving from {name}',
      'transferCancel': 'Cancel',
      'transferRetry': 'Retry',
      'transferClearDone': 'Clear completed',
      'transferProgressOf': '{done} of {total}',

      // Settings
      'settingsLanguage': 'Language',
      'languageSystem': 'Follow system',
      'languageEn': 'English',
      'languageZh': '简体中文',
      'settingsTheme': 'Theme',
      'themeSystem': 'System',
      'themeLight': 'Light',
      'themeDark': 'Dark',
      'settingsBackup': 'Backup',
      'settingsAutoBackup': 'Auto-backup photos & videos',
      'settingsAutoBackupSubtitle':
          'Sync new camera items to your paired PC over LAN',
      'settingsBackupFolder': 'Backup folder',
      'settingsBackupFolderNone': 'Not set',
      'settingsAbout': 'About',
      'settingsVersion': 'Version',
      'settingsLicenses': 'Open-source licenses',
      'settingsTagline': 'Uncloud — your data, your devices',
      'settingsLanguageChanged': 'Language updated',

      // Errors / misc
      'errorGeneric': 'Something went wrong. Please try again.',
      'demoModeBadge': 'Demo mode — sample data',
    },


    'zh': {
      // 通用 / 导航
      'appTitle': 'Uncloud',
      'tagline': '无云端 · 无账号 · 无服务器',
      'ok': '好',
      'cancel': '取消',
      'retry': '重试',
      'save': '保存',
      'navTimeline': '时间线',
      'navDevices': '设备',
      'navTransfers': '传输',
      'settingsTitle': '设置',
      'taglineLong': 'Uncloud —— 你的数据，你的设备',
      // 引导页
      'onbTitle1': '数据只属于你',
      'onbBody1': 'Uncloud 让每张照片和文件都留在你自己的设备上。没有任何上传——因为根本没有服务器可以上传。',
      'onbTitle2': '手机与电脑直连',
      'onbBody2': '扫码配对设备，通过局域网全速同步。即使没有互联网也能正常工作。',
      'onbTitle3': '本地 AI',
      'onbBody3': '去重和人脸分组完全在你的硬件上运行。除了你，任何模型都看不到你的数据。',
      'onbSkip': '跳过',
      'onbNext': '下一步',
      'onbGetStarted': '开始使用',
      'onbContinueDemo': '以演示模式继续',

      // 配对
      'pairingTitle': '配对设备',
      'pairingShowQr': '在另一台设备上扫描此二维码',
      'pairingScan': '扫码配对',
      'pairingMyCode': '我的配对码',
      'pairingScanHint': '在另一台设备上打开 Uncloud 扫描此二维码，或等待它自动发现你。',
      'pairingDiscovered': '在此网络中发现',
      'pairingNone': '正在局域网中查找设备…',
      'pairingPair': '配对',
      'pairingPaired': '已配对',
      'pairingSuccess': '已与 {name} 配对',
      'pairingInvalidCode': '此二维码不是有效的 Uncloud 配对码。',
      'pairingDone': '继续',
      'pairingScanSimTitle': '模拟扫码',
      'pairingScanSimBody': '演示模式下相机扫码为占位功能。请选择一个设备以模拟扫描其配对码。',

      // 时间线
      'timelineTitle': '时间线',
      'timelineToday': '今天',
      'timelineYesterday': '昨天',
      'timelineEmptyTitle': '还没有照片',
      'timelineEmptyBody': '此设备上的照片和视频（以及已备份的内容）将按天分组显示在这里。',
      'timelineItemCount': '{count} 个项目',
      'timelineRefreshFailed': '无法刷新媒体库。',
      'timelineBackupBanner': '自动备份已开启——新照片将同步到 {device}',


      // 设备
      'devicesTitle': '设备',
      'devicesEmptyTitle': '尚未配对设备',
      'devicesEmptyBody': '配对你的电脑或另一部手机，即可开始跨设备备份和浏览文件。',
      'devicesPairCta': '配对设备',
      'devicesOnline': '在线',
      'devicesOffline': '离线',
      'devicesLastSeenNow': '刚刚在线',
      'devicesLastSeenMinutes': '{minutes} 分钟前在线',
      'devicesLastSeenHours': '{hours} 小时前在线',
      'devicesLastSeenDays': '{days} 天前在线',
      'devicesStorage': '存储空间',
      'devicesStorageFree': '共 {total}，剩余 {free}',
      'devicesBrowseFiles': '浏览文件',
      'devicesBackupNow': '立即备份',
      'devicesBackupStarted': '已开始备份到 {name}',
      'devicesUnpair': '取消配对',
      'devicesUnpairConfirm': '取消与 {name} 的配对？到该设备的传输将停止。',
      'deviceDetailTitle': '设备详情',
      'deviceDetailId': '设备 ID',
      'deviceDetailAddress': '地址',
      'deviceDetailComingSoon': '远程浏览即将推出——演示模式下局域网文件 API 为占位实现。',

      // 本地 AI 占位
      'aiSection': '本地 AI',
      'aiDedupe': '查找重复项',
      'aiFaces': '按人脸分组',
      'aiComingSoon': '即将推出',
      'aiComingSoonBody': '设备端 AI 功能（去重、人脸）将在未来版本中推出。一如既往，一切均在本地运行。',


      // 传输
      'transfersTitle': '传输',
      'transfersActive': '进行中',
      'transfersHistory': '历史',
      'transfersEmptyTitle': '暂无传输',
      'transfersEmptyBody': '你在设备之间发送或接收的文件将在这里显示实时进度。',
      'transferQueued': '排队中',
      'transferActive': '传输中',
      'transferDone': '已完成',
      'transferFailed': '失败',
      'transferSending': '正在发送到 {name}',
      'transferReceiving': '正在从 {name} 接收',
      'transferCancel': '取消',
      'transferRetry': '重试',
      'transferClearDone': '清除已完成',
      'transferProgressOf': '{total} 中的 {done}',

      // 设置
      'settingsLanguage': '语言',
      'languageSystem': '跟随系统',
      'languageEn': 'English',
      'languageZh': '简体中文',
      'settingsTheme': '主题',
      'themeSystem': '跟随系统',
      'themeLight': '浅色',
      'themeDark': '深色',
      'settingsBackup': '备份',
      'settingsAutoBackup': '自动备份照片和视频',
      'settingsAutoBackupSubtitle': '通过局域网将新拍摄的内容同步到已配对的电脑',
      'settingsBackupFolder': '备份文件夹',
      'settingsBackupFolderNone': '未设置',
      'settingsAbout': '关于',
      'settingsVersion': '版本',
      'settingsLicenses': '开源许可',
      'settingsTagline': 'Uncloud —— 你的数据，你的设备',
      'settingsLanguageChanged': '语言已更新',

      // 错误 / 其他
      'errorGeneric': '出错了，请重试。',
      'demoModeBadge': '演示模式 — 示例数据',
    },
  };


  // General / nav
  String get appTitle => _t('appTitle');
  String get tagline => _t('tagline');
  String get taglineLong => _t('taglineLong');
  String get ok => _t('ok');
  String get cancel => _t('cancel');
  String get retry => _t('retry');
  String get save => _t('save');
  String get navTimeline => _t('navTimeline');
  String get navDevices => _t('navDevices');
  String get navTransfers => _t('navTransfers');
  String get settingsTitle => _t('settingsTitle');

  // Onboarding
  String get onbTitle1 => _t('onbTitle1');
  String get onbBody1 => _t('onbBody1');
  String get onbTitle2 => _t('onbTitle2');
  String get onbBody2 => _t('onbBody2');
  String get onbTitle3 => _t('onbTitle3');
  String get onbBody3 => _t('onbBody3');
  String get onbSkip => _t('onbSkip');
  String get onbNext => _t('onbNext');
  String get onbGetStarted => _t('onbGetStarted');
  String get onbContinueDemo => _t('onbContinueDemo');

  // Pairing
  String get pairingTitle => _t('pairingTitle');
  String get pairingShowQr => _t('pairingShowQr');
  String get pairingScan => _t('pairingScan');
  String get pairingMyCode => _t('pairingMyCode');
  String get pairingScanHint => _t('pairingScanHint');
  String get pairingDiscovered => _t('pairingDiscovered');
  String get pairingNone => _t('pairingNone');
  String get pairingPair => _t('pairingPair');
  String get pairingPaired => _t('pairingPaired');
  String pairingSuccess(String name) => _p('pairingSuccess', {'name': name});
  String get pairingInvalidCode => _t('pairingInvalidCode');
  String get pairingDone => _t('pairingDone');
  String get pairingScanSimTitle => _t('pairingScanSimTitle');
  String get pairingScanSimBody => _t('pairingScanSimBody');

  // Timeline
  String get timelineTitle => _t('timelineTitle');
  String get timelineToday => _t('timelineToday');
  String get timelineYesterday => _t('timelineYesterday');
  String get timelineEmptyTitle => _t('timelineEmptyTitle');
  String get timelineEmptyBody => _t('timelineEmptyBody');
  String timelineItemCount(int count) =>
      _p('timelineItemCount', {'count': '$count'});
  String get timelineRefreshFailed => _t('timelineRefreshFailed');
  String timelineBackupBanner(String device) =>
      _p('timelineBackupBanner', {'device': device});


  // Devices
  String get devicesTitle => _t('devicesTitle');
  String get devicesEmptyTitle => _t('devicesEmptyTitle');
  String get devicesEmptyBody => _t('devicesEmptyBody');
  String get devicesPairCta => _t('devicesPairCta');
  String get devicesOnline => _t('devicesOnline');
  String get devicesOffline => _t('devicesOffline');
  String get devicesLastSeenNow => _t('devicesLastSeenNow');
  String devicesLastSeenMinutes(int minutes) =>
      _p('devicesLastSeenMinutes', {'minutes': '$minutes'});
  String devicesLastSeenHours(int hours) =>
      _p('devicesLastSeenHours', {'hours': '$hours'});
  String devicesLastSeenDays(int days) =>
      _p('devicesLastSeenDays', {'days': '$days'});
  String get devicesStorage => _t('devicesStorage');
  String devicesStorageFree(String free, String total) =>
      _p('devicesStorageFree', {'free': free, 'total': total});
  String get devicesBrowseFiles => _t('devicesBrowseFiles');
  String get devicesBackupNow => _t('devicesBackupNow');
  String devicesBackupStarted(String name) =>
      _p('devicesBackupStarted', {'name': name});
  String get devicesUnpair => _t('devicesUnpair');
  String devicesUnpairConfirm(String name) =>
      _p('devicesUnpairConfirm', {'name': name});
  String get deviceDetailTitle => _t('deviceDetailTitle');
  String get deviceDetailId => _t('deviceDetailId');
  String get deviceDetailAddress => _t('deviceDetailAddress');
  String get deviceDetailComingSoon => _t('deviceDetailComingSoon');

  // Local AI stubs
  String get aiSection => _t('aiSection');
  String get aiDedupe => _t('aiDedupe');
  String get aiFaces => _t('aiFaces');
  String get aiComingSoon => _t('aiComingSoon');
  String get aiComingSoonBody => _t('aiComingSoonBody');

  // Transfers
  String get transfersTitle => _t('transfersTitle');
  String get transfersActive => _t('transfersActive');
  String get transfersHistory => _t('transfersHistory');
  String get transfersEmptyTitle => _t('transfersEmptyTitle');
  String get transfersEmptyBody => _t('transfersEmptyBody');
  String get transferQueued => _t('transferQueued');
  String get transferActive => _t('transferActive');
  String get transferDone => _t('transferDone');
  String get transferFailed => _t('transferFailed');
  String transferSending(String name) => _p('transferSending', {'name': name});
  String transferReceiving(String name) =>
      _p('transferReceiving', {'name': name});
  String get transferCancel => _t('transferCancel');
  String get transferRetry => _t('transferRetry');
  String get transferClearDone => _t('transferClearDone');
  String transferProgressOf(String done, String total) =>
      _p('transferProgressOf', {'done': done, 'total': total});


  // Settings
  String get settingsLanguage => _t('settingsLanguage');
  String get languageSystem => _t('languageSystem');
  String get languageEn => _t('languageEn');
  String get languageZh => _t('languageZh');
  String get settingsTheme => _t('settingsTheme');
  String get themeSystem => _t('themeSystem');
  String get themeLight => _t('themeLight');
  String get themeDark => _t('themeDark');
  String get settingsBackup => _t('settingsBackup');
  String get settingsAutoBackup => _t('settingsAutoBackup');
  String get settingsAutoBackupSubtitle => _t('settingsAutoBackupSubtitle');
  String get settingsBackupFolder => _t('settingsBackupFolder');
  String get settingsBackupFolderNone => _t('settingsBackupFolderNone');
  String get settingsAbout => _t('settingsAbout');
  String get settingsVersion => _t('settingsVersion');
  String get settingsLicenses => _t('settingsLicenses');
  String get settingsTagline => _t('settingsTagline');
  String get settingsLanguageChanged => _t('settingsLanguageChanged');

  // Errors / misc
  String get errorGeneric => _t('errorGeneric');
  String get demoModeBadge => _t('demoModeBadge');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Shorthand so every widget can write `context.l10n.appTitle`.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

