import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:countapp/services/notification_listener.dart';

/// 支付 APP 白名單的預設值測試。
///
/// 背景：微信與支付寶是主要來源，但舊版預設清單只放了
/// `com.alipay.android.app`（那是支付寶「SDK／安全支付」套件，
/// 不是支付寶主程式），真正會發出付款通知的
/// `com.eg.android.AlipayGphone` 反而不在清單裡。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('預設白名單包名', () {
    test('包含微信與支付寶主程式', () {
      const defaults = NotificationListenerService.defaultAllowedPackages;

      // 微信
      expect(defaults, contains('com.tencent.mm'));
      // 支付寶（中國本體）
      expect(defaults, contains('com.eg.android.AlipayGphone'));
      // AlipayHK
      expect(defaults, contains('hk.alipay.wallet'));
      // 支付寶 SDK（部分交易只從這裡發通知，需保留）
      expect(defaults, contains('com.alipay.android.app'));
      // 原有的 MPay
      expect(defaults, contains('com.macaupass.rechargeEasy'));
    });

    test('沒有重複的包名', () {
      const defaults = NotificationListenerService.defaultAllowedPackages;
      expect(defaults.toSet().length, defaults.length);
    });
  });

  group('getAllowedPackages', () {
    test('沒有自訂清單時回傳預設值', () async {
      final packages = await NotificationListenerService.getAllowedPackages();

      expect(packages, contains('com.tencent.mm'));
      expect(packages, contains('com.eg.android.AlipayGphone'));
    });

    test('回傳的清單必須可修改（白名單管理對話框會直接 add/remove）', () async {
      final packages = await NotificationListenerService.getAllowedPackages();

      // ⚠️ 舊版直接回傳 const 的預設清單，這裡會拋
      //    Unsupported operation: Cannot add to an unmodifiable list
      expect(() => packages.add('com.example.pay'), returnsNormally);
      expect(() => packages.removeAt(0), returnsNormally);
    });

    test('有自訂清單時以自訂清單為準', () async {
      SharedPreferences.setMockInitialValues({
        'allowed_package_names': ['com.example.custom'],
      });

      final packages = await NotificationListenerService.getAllowedPackages();

      expect(packages, ['com.example.custom']);
    });

    test('自訂清單的變更不會污染預設清單', () async {
      final packages = await NotificationListenerService.getAllowedPackages();
      packages.add('com.example.pay');
      packages.remove('com.tencent.mm');

      // 預設清單仍保持原樣
      expect(
        NotificationListenerService.defaultAllowedPackages,
        contains('com.tencent.mm'),
      );
      expect(
        NotificationListenerService.defaultAllowedPackages,
        isNot(contains('com.example.pay')),
      );
    });

    test('儲存後可被讀回', () async {
      await NotificationListenerService.setAllowedPackages([
        'com.tencent.mm',
        'com.eg.android.AlipayGphone',
      ]);

      final packages = await NotificationListenerService.getAllowedPackages();
      expect(packages, ['com.tencent.mm', 'com.eg.android.AlipayGphone']);
    });

    test('微信與支付寶通過 isPackageAllowed', () async {
      expect(
        await NotificationListenerService.isPackageAllowed('com.tencent.mm'),
        isTrue,
      );
      expect(
        await NotificationListenerService.isPackageAllowed(
          'com.eg.android.AlipayGphone',
        ),
        isTrue,
      );
      // 系統與本 App 一律排除
      expect(
        await NotificationListenerService.isPackageAllowed(
          'com.example.countapp',
        ),
        isFalse,
      );
    });
  });

  group('原生端鏡像（Android 讀不到 StringList 的解法）', () {
    test('儲存白名單時會同步寫入純 JSON 鏡像', () async {
      await NotificationListenerService.setAllowedPackages([
        'com.tencent.mm',
        'com.eg.android.AlipayGphone',
      ]);

      final prefs = await SharedPreferences.getInstance();
      final mirror = prefs.getString(
        NotificationListenerService.nativeMirrorKey,
      );

      // 必須是原生端能直接用 JSONArray() 解析的純 JSON 陣列
      expect(mirror, isNotNull);
      expect(jsonDecode(mirror!), ['com.tencent.mm', 'com.eg.android.AlipayGphone']);
    });

    test('鏡像存的是純 JSON 陣列字串（原生端可直接 JSONArray 解析）', () async {
      await NotificationListenerService.setAllowedPackages(['com.tencent.mm']);

      final prefs = await SharedPreferences.getInstance();
      final mirror = prefs.getString(
        NotificationListenerService.nativeMirrorKey,
      );

      expect(mirror!.startsWith('['), isTrue);
      expect(mirror.endsWith(']'), isTrue);
      expect(jsonDecode(mirror), ['com.tencent.mm']);
    });

    test('啟動時同步會把預設白名單寫進鏡像', () async {
      await NotificationListenerService.syncAllowedPackagesToNative();

      final prefs = await SharedPreferences.getInstance();
      final mirror = prefs.getString(
        NotificationListenerService.nativeMirrorKey,
      );
      final decoded = (jsonDecode(mirror!) as List).cast<String>();

      expect(decoded, contains('com.tencent.mm'));
      expect(decoded, contains('com.eg.android.AlipayGphone'));
    });

    test('舊版只有 StringList 的自訂清單會在同步後補上鏡像', () async {
      // 模擬「使用者是在舊版設定的白名單」：只有 StringList、沒有鏡像
      SharedPreferences.setMockInitialValues({
        'allowed_package_names': ['com.legacy.pay'],
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(NotificationListenerService.nativeMirrorKey), isNull);

      await NotificationListenerService.syncAllowedPackagesToNative();

      final mirror = prefs.getString(
        NotificationListenerService.nativeMirrorKey,
      );
      expect(jsonDecode(mirror!), ['com.legacy.pay']);
    });
  });
}
