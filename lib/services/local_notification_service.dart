import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/record.dart';
import '../utils/amount_formatter.dart';
import 'storage_service.dart';

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

  static const AndroidNotificationChannel _budgetChannel =
      AndroidNotificationChannel(
        'budget_alerts',
        '預算提醒',
        description: '當月支出接近或超過預算時顯示提醒通知',
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
    await androidPlugin?.createNotificationChannel(_budgetChannel);
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
    final amount = AmountFormatter.format(record.amount.abs());
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

  /// ✅ 檢查特定月份是否接近或超過預算，若超過則發送提醒通知
  static Future<void> checkAndShowBudgetAlertForMonth(
    int year,
    int month,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('budget_notification_enabled') ?? true;
    if (!enabled) return;

    if (!_initialized) {
      await initialize();
    }

    final storage = StorageService();
    final budget = await storage.loadBudget(year, month);
    if (budget == null || budget <= 0) return;

    final records = await storage.loadRecords();
    double monthlyExpense = 0;
    for (final r in records) {
      if (r.date.year == year && r.date.month == month && r.amount < 0) {
        monthlyExpense += r.amount.abs();
      }
    }

    const androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      '預算提醒',
      channelDescription: '當月支出接近或超過預算時顯示提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    if (monthlyExpense > budget) {
      final overAmount = AmountFormatter.format(monthlyExpense - budget);
      await _plugin.show(
        'budget_over_${year}_$month'.hashCode,
        '⚠️ 預算超支提醒',
        '【$month月】累積支出 \$${AmountFormatter.format(monthlyExpense)}，已超過預算 \$${AmountFormatter.format(budget)} (超支 \$$overAmount)',
        const NotificationDetails(android: androidDetails),
      );
    } else if (monthlyExpense >= budget * 0.8) {
      final percentage = ((monthlyExpense / budget) * 100).toStringAsFixed(0);
      await _plugin.show(
        'budget_near_${year}_$month'.hashCode,
        '⚠️ 預算即將超支提醒',
        '【$month月】累積支出 \$${AmountFormatter.format(monthlyExpense)}，已使用 $percentage% 的預算',
        const NotificationDetails(android: androidDetails),
      );
    }
  }

  /// ✅ 針對新記錄檢查並觸發預算提醒
  static Future<void> checkAndShowBudgetAlert(Record record) async {
    if (record.amount >= 0) return;
    await checkAndShowBudgetAlertForMonth(record.date.year, record.date.month);
  }
}
