import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:countapp/models/record.dart';
import 'package:countapp/services/notification_listener.dart';
import 'package:countapp/services/storage_service.dart';

/// 自動記錄（通知監聽）回歸測試。
///
/// 針對「通知說已記錄，明細頁卻沒有」的兩個根因：
///   1. 原生端只顧著送出通知就標記為已處理，Dart 端其實沒寫入 → 記錄永久消失。
///   2. 原生端在 App 未執行時保存的記錄，匯入明細時會失敗或互相蓋掉。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodCodec codec = StandardMethodCodec();
  const String channelName = 'com.countapp/notification';

  final StorageService storage = StorageService();

  /// 模擬 Android 端透過 MethodChannel 送出一筆支付通知，並取回處理結果。
  Future<String?> deliver(Map<String, dynamic> payload) async {
    final ByteData data = codec.encodeMethodCall(
      MethodCall('onPaymentNotification', jsonEncode(payload)),
    );
    final ByteData? reply = await TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .handlePlatformMessage(channelName, data, null);
    if (reply == null) return null;
    return codec.decodeEnvelope(reply) as String?;
  }

  Map<String, dynamic> payload({
    required String eventId,
    double amount = 1.0,
    String merchant = '',
    String text = '成功轉賬MOP1.00，點擊查看詳情。',
    bool isIncome = false,
  }) => {
    'amount': amount,
    'merchant': merchant,
    'text': text,
    'packageName': 'com.macaupass.rechargeEasy',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'eventId': eventId,
    'isIncome': isIncome,
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'auto_record_enabled': true,
      'use_ai_classification': false,
    });
    await NotificationListenerService.initialize();
  });

  group('通知處理結果狀態（原生端據此決定是否回退保存）', () {
    test('正常情況回報 saved，且記錄確實寫入明細', () async {
      final result = await deliver(payload(eventId: 'evt-saved-1'));

      expect(result, NotificationListenerService.statusSaved);

      final records = await storage.loadRecords();
      expect(records, hasLength(1));
      expect(records.single.id, 'evt-saved-1');
      expect(records.single.amount, -1.0);
      expect(records.single.category, '轉帳');
    });

    test('成功記錄時會推送 paymentStream 事件', () async {
      final events = <PaymentNotification>[];
      final subscription = NotificationListenerService.paymentStream.listen(
        events.add,
      );

      await deliver(payload(eventId: 'evt-stream-1'));
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.record.id, 'evt-stream-1');

      await subscription.cancel();
    });

    test('同一筆通知再次送達回報 duplicate，且不會重複寫入', () async {
      expect(
        await deliver(payload(eventId: 'evt-dup-1')),
        NotificationListenerService.statusSaved,
      );
      expect(
        await deliver(payload(eventId: 'evt-dup-1')),
        NotificationListenerService.statusDuplicate,
      );

      final records = await storage.loadRecords();
      expect(records, hasLength(1));
    });

    test('自動記錄關閉時回報 disabled，且不寫入任何記錄', () async {
      SharedPreferences.setMockInitialValues({
        'auto_record_enabled': false,
        'use_ai_classification': false,
      });

      final result = await deliver(payload(eventId: 'evt-disabled-1'));

      expect(result, NotificationListenerService.statusDisabled);
      expect(await storage.loadRecords(), isEmpty);
    });

    test('資料格式錯誤回報 failed（不可拋出例外讓原生端誤判成功）', () async {
      final ByteData data = codec.encodeMethodCall(
        const MethodCall('onPaymentNotification', '這不是 JSON'),
      );
      final ByteData? reply = await TestDefaultBinaryMessengerBinding
          .instance
          .defaultBinaryMessenger
          .handlePlatformMessage(channelName, data, null);

      expect(
        codec.decodeEnvelope(reply!) as String?,
        NotificationListenerService.statusFailed,
      );
    });

    test('無法取得金額時回報 failed，不寫入記錄', () async {
      final result = await deliver(
        payload(eventId: 'evt-noamount-1', amount: 0, text: '轉賬成功，點擊查看詳情。'),
      );

      expect(result, NotificationListenerService.statusFailed);
      expect(await storage.loadRecords(), isEmpty);
    });

    test('未實作的 method 會回報 NOT_IMPLEMENTED 錯誤', () async {
      final ByteData data = codec.encodeMethodCall(
        const MethodCall('unknownMethod', null),
      );
      final ByteData? reply = await TestDefaultBinaryMessengerBinding
          .instance
          .defaultBinaryMessenger
          .handlePlatformMessage(channelName, data, null);

      expect(
        () => codec.decodeEnvelope(reply!),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('原生端待匯入記錄（App 未執行時保存）', () {
    String nativeRecordJson(String id, {double amount = -12.0}) => jsonEncode({
      'amount': amount,
      'category': '轉帳',
      'note': '轉帳給 小明',
      'date': '2026-09-10T03:45:39.000Z',
      'createdAt': '2026-09-10T03:45:39.000Z',
      'id': id,
    });

    test('新格式（一筆一個鍵）會被匯入明細，且匯入後刪除該鍵', () async {
      SharedPreferences.setMockInitialValues({
        'native_record_native-1': nativeRecordJson('native-1'),
      });

      final records = await storage.loadRecords();
      expect(records, hasLength(1));
      expect(records.single.id, 'native-1');
      expect(records.single.amount, -12.0);

      // 再次載入不應重複匯入
      final again = await storage.loadRecords();
      expect(again, hasLength(1));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.startsWith('native_record_')),
        isEmpty,
      );
    });

    test('舊格式（單一 JSON 陣列）仍可匯入', () async {
      SharedPreferences.setMockInitialValues({
        'native_records': jsonEncode([nativeRecordJson('legacy-1')]),
      });

      final records = await storage.loadRecords();
      expect(records, hasLength(1));
      expect(records.single.id, 'legacy-1');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('native_records'), isNull);
    });

    test('已在明細中的同一筆記錄不會被原生記錄重複匯入', () async {
      final prefs = await SharedPreferences.getInstance();
      final existing = Record(
        amount: -12.0,
        category: '轉帳',
        note: '轉帳給 小明',
        date: DateTime.parse('2026-09-10T03:45:39.000Z'),
        id: 'shared-id',
      );
      await prefs.setStringList('records', [existing.toJsonString()]);
      await prefs.setString(
        'native_record_shared-id',
        nativeRecordJson('shared-id'),
      );

      final records = await storage.loadRecords();
      expect(records, hasLength(1));
      expect(records.single.id, 'shared-id');
    });

    test('原生記錄格式損壞時不會讓整份明細載入失敗，且保留該筆資料', () async {
      final prefs = await SharedPreferences.getInstance();
      final good = Record(
        amount: -5.0,
        category: '食物',
        note: '早餐',
        date: DateTime.now(),
        id: 'good-1',
      );
      await prefs.setStringList('records', [good.toJsonString()]);
      await prefs.setString('native_record_broken', '不是 JSON');

      final records = await storage.loadRecords();

      expect(records, hasLength(1));
      expect(records.single.id, 'good-1');
      // 資料保留，未被無聲刪除
      expect(prefs.getString('native_record_broken'), isNotNull);
    });

    test('單筆記錄 JSON 損壞時只跳過該筆，其他記錄照常載入', () async {
      final prefs = await SharedPreferences.getInstance();
      final good = Record(
        amount: -5.0,
        category: '食物',
        note: '早餐',
        date: DateTime.now(),
        id: 'good-2',
      );
      await prefs.setStringList('records', ['壞掉的資料', good.toJsonString()]);

      final records = await storage.loadRecords();
      expect(records, hasLength(1));
      expect(records.single.id, 'good-2');
    });
  });
}
