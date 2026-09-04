import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'; // ✅ 加入 debugPrint
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/record.dart';
import '../services/storage_service.dart';
import '../services/ai_service.dart';
import '../services/local_notification_service.dart';

class NotificationListenerService {
  static const MethodChannel _channel = MethodChannel(
    'com.countapp/notification',
  );

  static final StorageService _storage = StorageService();

  static StreamController<PaymentNotification>? _paymentStreamController;

  static bool _isInitialized = false;

  /// 支付通知流
  static Stream<PaymentNotification> get paymentStream {
    _paymentStreamController ??=
        StreamController<PaymentNotification>.broadcast();
    return _paymentStreamController!.stream;
  }

  /// ✅ 初始化
  static Future<void> initialize() async {
    if (_isInitialized) return;

    _channel.setMethodCallHandler(_handleMethodCall);

    _isInitialized = true;

    final enabled = await isAutoRecordEnabled();
    if (enabled) {
      debugPrint('✅ 自動記帳已啟用'); // ✅ 使用 debugPrint
    } else {
      debugPrint('⏸️ 自動記帳已停用'); // ✅ 使用 debugPrint
    }
  }

  /// ✅ 處理來自 Android 端的 MethodCall
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onPaymentNotification') {
      final String data = call.arguments as String;
      await _processPaymentNotification(data);
      return true;
    }
    throw PlatformException(
      code: 'NOT_IMPLEMENTED',
      message: 'Method not implemented',
    );
  }

  /// ✅ 處理支付通知
  /// ✅ 處理支付通知
  static Future<void> _processPaymentNotification(String data) async {
    try {
      final json = jsonDecode(data);
      final amount = (json['amount'] as num).toDouble();
      final merchant = json['merchant'] as String? ?? '';
      final text = json['text'] as String? ?? '';
      final eventId = json['eventId'] as String?;

      debugPrint('💰 收到支付通知: 金額=$amount, 商家=$merchant');

      // 檢查是否啟用自動記錄
      final enabled = await isAutoRecordEnabled();
      if (!enabled) {
        debugPrint('⏸️ 自動記錄已停用，跳過');
        return;
      }

      // ✅ 檢查分類方式
      final prefs = await SharedPreferences.getInstance();
      final useAI = prefs.getBool('use_ai_classification') ?? true;

      AIClassificationResult classification;
      if (useAI) {
        // 使用 AI 分類
        classification = await AIService.classifyNotification(text);
      } else {
        // 使用本地規則分類
        classification = AIService.localClassify(text);
      }

      // 創建記錄
      final record = Record(
        amount: -amount,
        category: classification.category,
        note: merchant.isNotEmpty
            ? '$merchant - ${classification.note}'
            : classification.note,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        id: eventId,
      );

      await _storage.addRecord(record);
      await LocalNotificationService.showRecordAdded(record);

      _paymentStreamController?.add(
        PaymentNotification(
          record: record,
          confidence: classification.confidence,
          originalText: text,
        ),
      );

      debugPrint('✅ 自動記帳成功: ${record.category} - \$$amount.toStringAsFixed(0)');
    } catch (e) {
      debugPrint('❌ 處理支付通知失敗: $e');
    }
  }

  /// ✅ 更新自動記錄設定
  static Future<void> setAutoRecordEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_record_enabled', enabled);
    debugPrint('🔄 自動記帳已${enabled ? "啟用" : "停用"}'); // ✅ 使用 debugPrint
  }

  /// 更新後台常駐通知設定
  static Future<void> setBackgroundNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_notification_enabled', enabled);
    final started = await _channel.invokeMethod<bool>(
      'setForegroundNotification',
      enabled,
    );
    if (enabled && started != true) {
      await _channel.invokeMethod<void>('openNotificationAccessSettings');
    }
    debugPrint('🔔 後台常駐通知已${enabled ? "啟用" : "停用"}');
  }

  /// ✅ 檢查自動記錄是否啟用
  static Future<bool> isAutoRecordEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_record_enabled') ?? false;
  }
}

/// 支付通知事件
class PaymentNotification {
  final Record record;
  final double confidence;
  final String originalText;

  PaymentNotification({
    required this.record,
    required this.confidence,
    required this.originalText,
  });
}
