import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:countapp/services/ai_service.dart';
import 'package:countapp/services/notification_listener.dart';
import 'package:countapp/services/storage_service.dart';

/// 廣告推播過濾的回歸測試。
///
/// 起因：MPay 的優惠推播與真實交易通知來自同一個包名
/// （com.macaupass.rechargeEasy），舊版只要求「白名單包名 + 任一寬鬆關鍵字」，
/// 而關鍵字清單包含單獨的「成功」「交易」「$」以及 App 名稱「MPay」，
/// 這些在廣告文案裡同樣會出現，於是下面這則廣告被記成了一筆 268 元的消費：
///
///   「澳門皇冠假日酒店限量秒殺 全年抵價 海鮮自助晚餐 268起 生蠔 三文魚
///     刺身 燒虎蝦任食 畀你五折體驗 即刻入mPass搶購」
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 實際被誤記的廣告全文（title 會與內容合併，因此含 App 名稱）
  const String adText =
      'MPay 澳門皇冠假日酒店限量秒殺 全年抵價 海鮮自助晚餐 268起 生蠔 三文魚刺身 '
      '燒虎蝦任食 畀你五折體驗 即刻入mPass搶購 全年抵價 海鮮自助晚餐 26';

  group('廣告推播判定', () {
    test('MPay 優惠推播會被判定為廣告', () {
      expect(AIService.isAdvertisement(adText), isTrue);
      expect(AIService.isPaymentNotificationText(adText), isFalse);
    });

    test('真實交易通知不會被誤判為廣告', () {
      const realNotifications = [
        '轉賬成功 成功轉賬MOP1.00，點擊查看詳情。',
        '支付成功 成功交易 MOP13.00 點擊查看詳情',
        '支付成功 成功交易 MOP8.80 點擊查看詳情',
        '收到 阿強 轉賬 MOP\$50.00',
        '轉賬給 老陳 MOP\$20.00',
        '消費 HK\$1,234.50',
        '您已轉賬 MOP\$1.00 給 小明',
        '您已支付 12.00 元',
        '金額：HK\$ 12.00',
      ];
      for (final text in realNotifications) {
        expect(
          AIService.isAdvertisement(text),
          isFalse,
          reason: '不該被判為廣告: $text',
        );
        expect(
          AIService.isPaymentNotificationText(text),
          isTrue,
          reason: '應被接受為交易通知: $text',
        );
      }
    });

    test('只有 App 名稱與「成功」字樣不算交易通知', () {
      // 舊版會因為關鍵字「MPay」「成功」而放行，新版必須要求交易格式
      expect(
        AIService.isPaymentNotificationText('MPay 成功登入，歡迎使用'),
        isFalse,
      );
      expect(
        AIService.isPaymentNotificationText('MPay 系統維護通知'),
        isFalse,
      );
      expect(
        AIService.isPaymentNotificationText('您的驗證碼是 123456'),
        isFalse,
      );
    });

    test('廣告文案中的價格不會被當成交易金額', () {
      // 舊版「關鍵字後 40 字內第一個整數」會抓到 268
      expect(AIService.extractAmount(adText), isNull);
    });
  });

  group('通知處理（端到端）', () {
    const MethodCodec codec = StandardMethodCodec();
    const String channelName = 'com.countapp/notification';

    final StorageService storage = StorageService();

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
      required String text,
      double amount = 0,
      String merchant = '',
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

    test('廣告推播回報 ignored，且不會寫入任何記錄', () async {
      final result = await deliver(
        payload(eventId: 'evt-ad-1', text: adText, amount: 268),
      );

      expect(result, NotificationListenerService.statusIgnored);
      expect(await storage.loadRecords(), isEmpty);
    });

    test('真實交易通知仍會正常記錄', () async {
      final result = await deliver(
        payload(
          eventId: 'evt-real-1',
          text: '支付成功 成功交易 MOP13.00 點擊查看詳情',
          amount: 13.0,
        ),
      );

      expect(result, NotificationListenerService.statusSaved);

      final records = await storage.loadRecords();
      expect(records, hasLength(1));
      expect(records.single.amount, -13.0);
    });

    test('ignored 與 failed 不同：格式不符不算失敗', () async {
      final ignored = await deliver(
        payload(eventId: 'evt-ad-2', text: adText, amount: 268),
      );
      final failed = await deliver(
        payload(
          eventId: 'evt-noamount-1',
          text: '轉賬成功，點擊查看詳情。',
          amount: 0,
        ),
      );

      // 廣告 → ignored（native 不回退保存）
      expect(ignored, NotificationListenerService.statusIgnored);
      // 符合交易格式但取不到金額 → failed（讓原生端知道沒記錄成功）
      expect(failed, NotificationListenerService.statusFailed);
      expect(await storage.loadRecords(), isEmpty);
    });

    test('廣告被判定過後不會寫入記錄', () async {
      // 送兩次同一筆廣告：每次都不會記錄，也不會出錯
      expect(
        await deliver(payload(eventId: 'evt-ad-3', text: adText, amount: 268)),
        NotificationListenerService.statusIgnored,
      );
      expect(
        await deliver(payload(eventId: 'evt-ad-3', text: adText, amount: 268)),
        NotificationListenerService.statusIgnored,
      );
      expect(await storage.loadRecords(), isEmpty);
    });
  });
}
