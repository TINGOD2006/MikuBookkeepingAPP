import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countapp/services/accessibility_probe_service.dart';

/// 無障礙讀屏探針的 Dart 端測試。
///
/// 探針本身跑在 Android 原生端（PaymentAccessibilityService），
/// 這裡測試的是「原生端回傳的結果能不能被正確解析、顯示」，
/// 以及通道失敗時不會讓畫面炸掉。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.countapp/notification');

  /// 設定原生端的假回應
  void mockChannel({
    bool enabled = false,
    String logs = '[]',
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isAccessibilityProbeEnabled':
          return enabled;
        case 'getAccessibilityProbeLogs':
          return logs;
        case 'clearAccessibilityProbeLogs':
          return true;
        case 'openAccessibilitySettings':
          return true;
        default:
          return null;
      }
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Map<String, dynamic> probeEntry({
    int time = 1757000000000,
    String packageName = 'com.tencent.mm',
    int nodeCount = 42,
    int textCount = 7,
    bool paymentLike = true,
    bool advertisement = false,
    Object? amount = 13.0,
    bool isIncome = false,
    String verdict = '✅ 讀到 7 段文字，判定可記錄：金額 -13.0',
    String text = '支付成功 ｜ 成功交易 MOP13.00 ｜ 點擊查看詳情',
  }) => {
    'time': time,
    'package': packageName,
    'className': 'com.tencent.mm.ui.LauncherUI',
    'eventType': 'WINDOW_CONTENT_CHANGED',
    'nodeCount': nodeCount,
    'textCount': textCount,
    'paymentLike': paymentLike,
    'advertisement': advertisement,
    'amount': amount,
    'isIncome': isIncome,
    'verdict': verdict,
    'text': text,
  };

  group('AccessibilityProbeLog 解析', () {
    test('完整欄位會被正確解析', () {
      final log = AccessibilityProbeLog.fromJson(probeEntry());

      expect(log.packageName, 'com.tencent.mm');
      expect(log.nodeCount, 42);
      expect(log.textCount, 7);
      expect(log.paymentLike, isTrue);
      expect(log.advertisement, isFalse);
      expect(log.amount, 13.0);
      expect(log.isIncome, isFalse);
      expect(log.eventType, 'WINDOW_CONTENT_CHANGED');
      expect(log.text, contains('MOP13.00'));
    });

    test('讀不到文字時 textCount 為 0（探針的關鍵指標）', () {
      final log = AccessibilityProbeLog.fromJson(
        probeEntry(
          textCount: 0,
          paymentLike: false,
          amount: null,
          text: '',
          verdict: '❌ 節點樹沒有任何文字（自繪視圖／WebView）→ 讀屏這條路線不可行',
        ),
      );

      expect(log.textCount, 0);
      expect(log.amount, isNull);
      expect(log.text, isEmpty);
      expect(log.verdict, contains('不可行'));
    });

    test('amount 為 null 不會拋錯', () {
      final log = AccessibilityProbeLog.fromJson(probeEntry(amount: null));
      expect(log.amount, isNull);
    });

    test('欄位缺漏時使用安全的預設值', () {
      final log = AccessibilityProbeLog.fromJson(const {});

      expect(log.packageName, '');
      expect(log.nodeCount, 0);
      expect(log.textCount, 0);
      expect(log.paymentLike, isFalse);
      expect(log.amount, isNull);
    });
  });

  group('AccessibilityProbeService', () {
    test('讀取並解析多筆探針結果', () async {
      mockChannel(
        enabled: true,
        logs: jsonEncode([
          probeEntry(packageName: 'com.tencent.mm'),
          probeEntry(
            packageName: 'com.eg.android.AlipayGphone',
            amount: 8.8,
            isIncome: true,
          ),
        ]),
      );

      final logs = await AccessibilityProbeService.loadLogs();

      expect(logs, hasLength(2));
      expect(logs.first.packageName, 'com.tencent.mm');
      expect(logs.last.packageName, 'com.eg.android.AlipayGphone');
      expect(logs.last.amount, 8.8);
      expect(logs.last.isIncome, isTrue);
    });

    test('服務啟用狀態會被回報', () async {
      mockChannel(enabled: true);
      expect(await AccessibilityProbeService.isEnabled(), isTrue);

      mockChannel(enabled: false);
      expect(await AccessibilityProbeService.isEnabled(), isFalse);
    });

    test('沒有紀錄時回傳空清單', () async {
      mockChannel(logs: '[]');
      expect(await AccessibilityProbeService.loadLogs(), isEmpty);
    });

    test('原生端回傳壞資料時回傳空清單，不會拋錯', () async {
      mockChannel(logs: '這不是 JSON');
      expect(await AccessibilityProbeService.loadLogs(), isEmpty);
    });

    test('通道不存在時（例如非 Android）安全降級', () async {
      // 沒有設定 mock handler → MissingPluginException
      expect(await AccessibilityProbeService.loadLogs(), isEmpty);
      expect(await AccessibilityProbeService.isEnabled(), isFalse);
    });
  });
}
