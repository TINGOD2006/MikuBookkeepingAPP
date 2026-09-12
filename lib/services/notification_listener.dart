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
import '../utils/amount_formatter.dart';

class NotificationListenerService {
  static const MethodChannel _channel = MethodChannel(
    'com.countapp/notification',
  );

  static final StorageService _storage = StorageService();

  static StreamController<PaymentNotification>? _paymentStreamController;

  static bool _isInitialized = false;

  // ============================================================
  // ✅ 原生端 <-> Dart 的處理結果協定
  //
  // 原生端只有在收到 [statusSaved] / [statusDuplicate] 時才會把該筆通知
  // 標記為「已處理」；其他狀態（含逾時或 Dart 端已不存在）都會回退成
  // 原生端自行保存，確保通知不會在兩邊都沒被記下來。
  // ============================================================

  /// 已確實寫入明細
  static const String statusSaved = 'saved';

  /// 重複通知，先前已記錄過（不需再記一次，也不算失敗）
  static const String statusDuplicate = 'duplicate';

  /// 使用者已關閉自動記錄：不記錄，但也不算失敗
  static const String statusDisabled = 'disabled';

  /// 判定為「非交易通知」（例如廣告推播）：不記錄，也不算失敗。
  ///
  /// 與 [statusDisabled] 的差別：這是針對「這一則通知的內容」判斷，
  /// 必須標記為已處理避免重複判斷，且原生端**不可**回退成自行保存，
  /// 否則廣告又會被記進明細。
  static const String statusIgnored = 'ignored';

  /// 處理失敗：原生端應回退保存，且不要標記為已處理
  static const String statusFailed = 'failed';

  // ✅ Flutter 端去重快取（記憶體）
  static final Set<String> _processedIds = {};
  static const int _maxCacheSize = 500;

  /// 預設支援的支付應用包名列表（開箱即用）。
  ///
  /// ⚠️ Android 原生端 [getAllowedPackages] 有一份必須保持同步的鏡像，
  ///    位置：android/app/src/main/kotlin/com/example/countapp/NotificationListenerService.kt
  static const List<String> defaultAllowedPackages = [
    'com.tencent.mm', // 微信／微信支付
    'com.eg.android.AlipayGphone', // 支付寶（中國本體）
    'hk.alipay.wallet', // AlipayHK
    // 支付寶 SDK／安全支付：部分交易只有這個套件會發通知，一併保留
    'com.alipay.android.app',
    'com.macaupass.rechargeEasy', // MPay / Macau Pass 澳門通
    'com.google.android.apps.wallet', // Google Pay / Google Wallet
    'com.apple.wallet', // Apple Wallet
    'com.octopus.nfc', // 八達通
    'hk.com.boc.bocmobilebanking', // 中銀香港
    'com.icbc.imobile', // 工銀亞洲
  ];

  /// 取得允許的包名列表
  ///
  /// ⚠️ 一定要回傳「可修改」的清單：呼叫端（白名單管理對話框）會直接對它
  ///    呼叫 add/removeAt。舊版在沒有自訂清單時直接回傳 const 的
  ///    [defaultAllowedPackages]，使用者一按「新增」就會拋
  ///    Unsupported operation: Cannot add to an unmodifiable list。
  static Future<List<String>> getAllowedPackages() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList('allowed_package_names');
    if (custom != null && custom.isNotEmpty) {
      return List<String>.from(custom);
    }
    return List<String>.from(defaultAllowedPackages);
  }

  /// 設定允許的包名列表
  static Future<void> setAllowedPackages(List<String> packages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('allowed_package_names', packages);
    await _mirrorAllowedPackagesToNative(prefs, packages);
    debugPrint('🔄 已更新允許的包名白名單: $packages');
  }

  /// 白名單的「原生端鏡像」鍵。
  ///
  /// ⚠️ 為什麼需要這份鏡像：
  ///    shared_preferences 的 StringList 在 Android 上**不是**存成 JSON，
  ///    而是 `"VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"` +
  ///    Java 序列化的 Base64。原生端用 JSONArray() 解析一定拋例外，
  ///    然後靜默退回預設白名單——也就是使用者自訂的包名在原生端完全失效。
  ///    這裡另外寫一份純 JSON 字串（String 不會被加工）給原生端讀。
  static const String nativeMirrorKey = 'allowed_package_names_json';

  static Future<void> _mirrorAllowedPackagesToNative(
    SharedPreferences prefs,
    List<String> packages,
  ) async {
    await prefs.setString(nativeMirrorKey, jsonEncode(packages));
  }

  /// 把目前有效的白名單同步給原生端。
  ///
  /// ✅ App 每次啟動都呼叫一次：這樣即使使用者是在舊版設定的白名單
  ///    （只有 StringList、原生端讀不到），也會自動補上鏡像，不必重新設定。
  static Future<void> syncAllowedPackagesToNative() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final packages = await getAllowedPackages();
      await _mirrorAllowedPackagesToNative(prefs, packages);
      debugPrint('🔄 已同步白名單到原生端: ${packages.length} 個包名');
    } catch (e) {
      debugPrint('⚠️ 同步白名單到原生端失敗: $e');
    }
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

    // ✅ 把白名單同步成原生端讀得懂的格式（含舊版設定的自訂清單）
    await syncAllowedPackagesToNative();

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
  ///
  /// 回傳值是給原生端判斷「這筆通知到底有沒有被記下來」的依據，
  /// 因此**不可**在這裡把例外吞掉後仍回報成功。
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onPaymentNotification') {
      final String data = call.arguments as String;
      try {
        return await _processPaymentNotification(data);
      } catch (e, stack) {
        debugPrint('❌ 處理支付通知失敗: $e\n$stack');
        // ✅ 回報失敗，讓原生端回退成自行保存，而不是無聲丟掉這筆記錄
        return statusFailed;
      }
    }
    throw PlatformException(
      code: 'NOT_IMPLEMENTED',
      message: 'Method not implemented',
    );
  }

  /// ✅ 處理支付通知
  ///
  /// 回傳 [statusSaved] / [statusDuplicate] / [statusDisabled] / [statusFailed]。
  static Future<String> _processPaymentNotification(String data) async {
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
        // 同一筆通知的另一個請求正在處理中，對原生端而言等同已處理
        return statusDuplicate;
      }
    }

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      // ✅ 容錯：若原生端未提供/提供失敗金額，改從原文提取
      double? amount = (json['amount'] as num?)?.toDouble();
      var merchant = json['merchant'] as String? ?? '';
      final text = json['text'] as String? ?? '';
      final eventId = json['eventId'] as String? ?? '';
      // ✅ 方向：true=收入（收到錢），false/缺省=支出（付錢出去）
      final isIncome = json['isIncome'] as bool? ?? false;

      // ✅ 第二道防線：同一包名也會發行銷推播，必須確認符合已知交易格式。
      //    （原生端已先過濾一次，這裡避免原生端規則漏掉時把廣告記進明細；
      //      回報 statusIgnored 讓原生端「不要」回退保存這筆通知。）
      if (!AIService.isPaymentNotificationText(text)) {
        debugPrint('📢 非交易通知（廣告或格式不符），略過: $text');
        if (eventId.isNotEmpty) {
          await _saveProcessedId(eventId);
        }
        return statusIgnored;
      }

      if (amount == null || amount <= 0) {
        amount = AIService.extractAmount(text);
        if (amount == null || amount <= 0) {
          debugPrint('🚫 無法從通知中提取金額: $text');
          return statusFailed;
        }
      }
      if (merchant.isEmpty) {
        merchant = AIService.extractMerchant(text) ?? '';
      }

      debugPrint(
        '💰 收到支付通知: 金額=$amount, 對象=$merchant, 方向=${isIncome ? '收入' : '支出'}',
      );

      // ✅ 檢查是否已處理過（Flutter 端去重）
      if (eventId.isNotEmpty && _isAlreadyProcessed(eventId)) {
        debugPrint('⏭️ Flutter 端跳過重複通知: $eventId');
        return statusDuplicate;
      }

      // ✅ 檢查自動記錄是否啟用
      final enabled = await isAutoRecordEnabled();
      if (!enabled) {
        debugPrint('⏸️ 自動記錄已停用，跳過');
        return statusDisabled;
      }

      // ✅ 分類（轉帳類別優先，其他支付類型走原本分類）
      final prefs = await SharedPreferences.getInstance();
      final useAI = prefs.getBool('use_ai_classification') ?? true;

      AIClassificationResult classification;
      if (useAI) {
        classification = await AIService.classifyNotification(text);
      } else {
        // ✅ 規則表分類：讀取用戶自訂規則（含內建規則）
        classification = await AIService.localClassifyAsync(text);
      }

      // ✅ 建立備註：優先記錄「轉帳給 XXX / 收到 XXX 轉帳」
      final isTransfer = text.contains('轉賬') ||
          text.contains('轉帳') ||
          text.contains('转账') ||
          text.contains('transfer');
      String note;
      if (isTransfer && merchant.isNotEmpty) {
        note = isIncome ? '收到 $merchant 轉帳' : '轉帳給 $merchant';
      } else if (isTransfer) {
        note = isIncome ? '轉賬收入' : '轉賬支出';
      } else {
        note = merchant.isNotEmpty
            ? '$merchant - ${classification.note}'
            : classification.note;
      }

      // ✅ 創建記錄
      final record = Record(
        amount: isIncome ? amount : -amount,
        category: classification.category,
        note: note,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        id: eventId.isNotEmpty
            ? eventId
            : DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // ✅ 儲存記錄（這一步成功才算「已記錄」）
      await _storage.addRecord(record);

      // ✅ 標記為已處理
      if (eventId.isNotEmpty) {
        await _saveProcessedId(eventId);
      }

      // ✅ 立刻通知畫面更新，不等待後續的通知／預算查詢
      _paymentStreamController?.add(
        PaymentNotification(
          record: record,
          confidence: classification.confidence,
          originalText: text,
        ),
      );

      // ⚠️ 系統通知與預算提醒屬於「加值顯示」，失敗不可影響記錄結果
      //    （否則原生端會誤判為記錄失敗而重複保存）
      try {
        await LocalNotificationService.showRecordAdded(record);
      } catch (e) {
        debugPrint('⚠️ 顯示記帳通知失敗（不影響記錄）: $e');
      }
      try {
        await LocalNotificationService.checkAndShowBudgetAlert(record);
      } catch (e) {
        debugPrint('⚠️ 預算提醒失敗（不影響記錄）: $e');
      }

      debugPrint(
        '✅ 自動記帳成功: ${record.category} - ${record.note} - '
        '\$${AmountFormatter.format(amount)}',
      );
      return statusSaved;
    } catch (e, stack) {
      debugPrint('❌ 處理支付通知失敗: $e\n$stack');
      // ✅ 不標記為已處理，回報失敗讓原生端接手保存
      return statusFailed;
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

  /// 檢查 App 是否已獲得 Android「通知使用權限」（Notification Listener Access）。
  /// 若未獲得，onNotificationPosted 永遠不會被系統呼叫，自動記帳自然失效。
  static Future<bool> isNotificationAccessEnabled() async {
    try {
      final granted = await _channel.invokeMethod<bool>(
        'isNotificationAccessEnabled',
      );
      return granted ?? false;
    } catch (e) {
      debugPrint('⚠️ 檢查通知使用權限失敗: $e');
      return false;
    }
  }

  /// 開啟系統「通知使用權限」設定頁
  static Future<void> openNotificationAccessSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationAccessSettings');
    } catch (e) {
      debugPrint('⚠️ 開啟通知使用權限設定失敗: $e');
    }
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
