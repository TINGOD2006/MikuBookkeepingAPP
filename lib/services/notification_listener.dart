import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/record.dart';
import '../services/storage_service.dart';
import '../services/ai_service.dart';
import '../services/local_notification_service.dart';
import '../services/message_service.dart';

class NotificationListenerService {
  static const MethodChannel _channel = MethodChannel(
    'com.countapp/notification',
  );

  static final StorageService _storage = StorageService();

  static StreamController<PaymentNotification>? _paymentStreamController;

  static bool _isInitialized = false;

  // ✅ Flutter 端去重快取（記憶體）
  static final Set<String> _processedIds = {};
  static const int _maxCacheSize = 500;

  /// 預設支援的支付應用包名列表
  static const List<String> defaultAllowedPackages = [
    'com.macaupass.rechargeEasy', // MPay / Macau Pass
    'com.alipay.android.app', // 支付寶
    'com.tencent.mm', // 微信
    'com.google.android.apps.wallet', // Google Pay / Google Wallet
    'com.apple.wallet', // Apple Wallet
    'com.octopus.nfc', // 八達通
    'hk.com.boc.bocmobilebanking', // 中銀香港
    'com.icbc.imobile', // 工銀亞洲
  ];

  /// 取得允許的包名列表
  static Future<List<String>> getAllowedPackages() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList('allowed_package_names');
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return defaultAllowedPackages;
  }

  /// 設定允許的包名列表
  static Future<void> setAllowedPackages(List<String> packages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('allowed_package_names', packages);
    debugPrint('🔄 已更新允許的包名白名單: $packages');
  }

  /// 檢查特定包名是否在白名單中
  static Future<bool> isPackageAllowed(String packageName) async {
    if (packageName.isEmpty) return false;
    // 永遠排除系統及本App本身
    if (packageName == 'com.android.systemui' ||
        packageName == 'com.android.settings' ||
        packageName == 'com.example.countapp') {
      return false;
    }
    final allowed = await getAllowedPackages();
    return allowed.any((pkg) => packageName.contains(pkg) || pkg.contains(packageName));
  }

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

    // ✅ 載入已處理的通知 ID 到記憶體快取
    await _loadProcessedIds();

    final enabled = await isAutoRecordEnabled();
    if (enabled) {
      debugPrint('✅ 自動記帳已啟用');
    } else {
      debugPrint('⏸️ 自動記帳已停用');
    }
  }

  /// ✅ 載入已處理的通知 ID
  static Future<void> _loadProcessedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('flutter_processed_ids') ?? [];
      _processedIds.addAll(ids);
      debugPrint('📋 已載入 ${_processedIds.length} 筆已處理通知');
    } catch (e) {
      debugPrint('⚠️ 載入已處理通知失敗: $e');
    }
  }

  /// ✅ 儲存已處理的通知 ID
  static Future<void> _saveProcessedId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _processedIds.add(id);

      // 限制快取大小
      if (_processedIds.length > _maxCacheSize) {
        final excess = _processedIds.length - _maxCacheSize;
        final ids = _processedIds.toList();
        for (var i = 0; i < excess && i < ids.length; i++) {
          _processedIds.remove(ids[i]);
        }
      }

      await prefs.setStringList(
        'flutter_processed_ids',
        _processedIds.toList(),
      );
    } catch (e) {
      debugPrint('⚠️ 儲存已處理通知失敗: $e');
    }
  }

  /// ✅ 檢查是否已處理
  static bool _isAlreadyProcessed(String eventId) {
    if (eventId.isEmpty) return false;
    return _processedIds.contains(eventId);
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
  static Future<void> _processPaymentNotification(String data) async {
    // ✅ 併發去重：同一時間只處理一筆相同 eventId 的通知
    String? rawId;
    try {
      final raw = jsonDecode(data);
      rawId = raw['eventId'] as String? ?? '';
    } catch (_) {
      // 交給下方正式解析處理
    }
    if (rawId != null && rawId.isNotEmpty) {
      if (!MessageService.beginProcess('notif_$rawId')) {
        debugPrint('⏭️ 通知處理中，跳過重複請求: $rawId');
        return;
      }
    }

    try {
      final json = jsonDecode(data);
      final amount = (json['amount'] as num).toDouble();
      final merchant = json['merchant'] as String? ?? '';
      final text = json['text'] as String? ?? '';
      final eventId = json['eventId'] as String? ?? '';

      debugPrint('💰 收到支付通知: 金額=$amount, 商家=$merchant');

      // ✅ 檢查是否已處理過（Flutter 端去重）
      if (eventId.isNotEmpty && _isAlreadyProcessed(eventId)) {
        debugPrint('⏭️ Flutter 端跳過重複通知: $eventId');
        return;
      }

      // ✅ 檢查自動記錄是否啟用
      final enabled = await isAutoRecordEnabled();
      if (!enabled) {
        debugPrint('⏸️ 自動記錄已停用，跳過');
        return;
      }

      // ✅ 分類
      final prefs = await SharedPreferences.getInstance();
      final useAI = prefs.getBool('use_ai_classification') ?? true;

      AIClassificationResult classification;
      if (useAI) {
        classification = await AIService.classifyNotification(text);
      } else {
        classification = AIService.localClassify(text);
      }

      // ✅ 創建記錄
      final record = Record(
        amount: -amount,
        category: classification.category,
        note: merchant.isNotEmpty
            ? '$merchant - ${classification.note}'
            : classification.note,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        id: eventId.isNotEmpty
            ? eventId
            : DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // ✅ 儲存記錄
      await _storage.addRecord(record);

      // ✅ 標記為已處理
      if (eventId.isNotEmpty) {
        await _saveProcessedId(eventId);
      }

      // ✅ 通知（系統通知與預算提醒皆已內建去重）
      await LocalNotificationService.showRecordAdded(record);
      await LocalNotificationService.checkAndShowBudgetAlert(record);

      _paymentStreamController?.add(
        PaymentNotification(
          record: record,
          confidence: classification.confidence,
          originalText: text,
        ),
      );

      debugPrint(
        '✅ 自動記帳成功: ${record.category} - \$${amount.toStringAsFixed(0)}',
      );
    } catch (e) {
      debugPrint('❌ 處理支付通知失敗: $e');
      // ✅ 不標記為已處理，允許重試
    } finally {
      if (rawId != null && rawId.isNotEmpty) {
        MessageService.endProcess('notif_$rawId');
      }
    }
  }

  /// ✅ 更新自動記錄設定
  static Future<void> setAutoRecordEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_record_enabled', enabled);
    debugPrint('🔄 自動記帳已${enabled ? "啟用" : "停用"}');
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
