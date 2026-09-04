import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/record.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const AndroidNotificationChannel _recordsChannel =
      AndroidNotificationChannel(
        'record_updates',
        '記帳通知',
        description: '新增收支或轉帳紀錄時顯示通知',
        importance: Importance.high,
      );

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_recordsChannel);
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> showRecordAdded(Record record) async {
    if (!_initialized) {
      await initialize();
    }

    final isExpense = record.amount < 0;
    final type = isExpense ? '支出' : '收入／轉帳';
    final sign = isExpense ? '-' : '+';
    final amount = record.amount.abs().toStringAsFixed(
      record.amount.abs() == record.amount.abs().roundToDouble() ? 0 : 2,
    );
    final note = record.note.trim();
    final details = note.isEmpty ? record.category : '${record.category}・$note';

    const androidDetails = AndroidNotificationDetails(
      'record_updates',
      '記帳通知',
      channelDescription: '新增收支或轉帳紀錄時顯示通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      record.id.hashCode,
      '$type已新增',
      '$details  $sign$amount',
      const NotificationDetails(android: androidDetails),
    );
  }
}
