import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:countapp/services/ai_service.dart';

/// 以 logcat（Mpay.txt）實際錄到的 MPay 通知內容做回歸測試。
///
/// 2026-09-10 03:45:39 由 com.macaupass.rechargeEasy 發出：
///   title : 轉賬成功
///   text  : 成功轉賬MOP1.00，點擊查看詳情。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('MPay 轉賬通知解析', () {
    test('成功轉賬MOP1.00 → 金額 1.0', () {
      const text = '轉賬成功 成功轉賬MOP1.00，點擊查看詳情。';
      expect(AIService.extractAmount(text), 1.0);
    });

    test('轉賬成功 成功轉賬MOP1.00 → 分類為轉帳', () {
      const text = '轉賬成功 成功轉賬MOP1.00，點擊查看詳情。';
      final result = AIService.localClassify(text);
      expect(result.category, '轉帳');
    });

    test('MOP 1.00（空格）→ 金額 1.0', () {
      expect(AIService.extractAmount('成功轉賬 MOP 1.00'), 1.0);
    });

    test('MOP\$1.00 → 金額 1.0', () {
      expect(AIService.extractAmount('您已轉賬 MOP\$1.00 給 小明'), 1.0);
    });

    test('HK\$1,234.50 → 金額 1234.5', () {
      expect(AIService.extractAmount('消費 HK\$1,234.50'), 1234.5);
    });

    test('金額：HK\$ 12.00 → 金額 12.0', () {
      expect(AIService.extractAmount('金額：HK\$ 12.00'), 12.0);
    });

    test('時間 03:49:39 不會被誤判為金額', () {
      const text = '03:49:39 成功轉賬MOP1.00';
      expect(AIService.extractAmount(text), 1.0);
    });

    test('日期 2026-09-10 不會被誤判為金額', () {
      expect(AIService.extractAmount('2026-09-10 轉賬 5.00 成功'), 5.0);
    });

    test('長訂單號不會被誤判為金額', () {
      const text = '訂單號 2026091003453572166504，成功轉賬MOP1.00';
      expect(AIService.extractAmount(text), 1.0);
    });

    test('無金額時回傳 null', () {
      expect(AIService.extractAmount('轉賬成功，點擊查看詳情。'), isNull);
    });

    test('extractMerchant 支援「給」格式', () {
      expect(AIService.extractMerchant('您已轉賬 MOP\$1.00 給 翁'), '翁');
    });

    test('extractMerchant 支援「向 XXX 轉賬」', () {
      expect(AIService.extractMerchant('向 小明 轉賬 MOP\$10.00'), '小明');
    });

    test('extractMerchant 支援「收到 XXX 轉賬」', () {
      expect(AIService.extractMerchant('收到 阿強 轉賬 MOP\$50.00'), '阿強');
    });

    test('extractMerchant 支援「來自 XXX」', () {
      expect(AIService.extractMerchant('來自 小美 的轉賬 MOP\$5.00'), '小美');
    });

    test('extractMerchant 支援「轉賬給 XXX」', () {
      expect(AIService.extractMerchant('轉賬給 老陳 MOP\$20.00'), '老陳');
    });

    test('extractMerchant 無對象時回傳 null', () {
      expect(AIService.extractMerchant('成功轉賬MOP1.00，點擊查看詳情。'), isNull);
    });
  });

  group('自訂規則表', () {
    test('內建規則：麥當勞 → 食物', () {
      final result = AIService.localClassify('麥當勞 MOP45');
      expect(result.category, '食物');
    });

    test('內建規則：星巴克 → 食物', () {
      final result = AIService.localClassify('星巴克咖啡 MOP38');
      expect(result.category, '食物');
    });

    test('內建規則：捷運 → 交通', () {
      final result = AIService.localClassify('捷運車費 MOP6');
      expect(result.category, '交通');
    });

    test('內建規則：轉賬 → 轉帳', () {
      final result = AIService.localClassify('成功轉賬MOP1.00');
      expect(result.category, '轉帳');
    });

    test('無匹配時 → 其他', () {
      final result = AIService.localClassify('外星人入侵 MOP999');
      expect(result.category, '其他');
    });

    test('自訂規則：新增詞條可被 localClassifyAsync 使用', () async {
      // 儲存自訂規則：把「麥當勞」改歸入「娛樂」
      await AIService.saveCustomRules({
        '娛樂': ['麥當勞', 'netflix'],
      });
      final rules = await AIService.loadRules();
      expect(rules['娛樂'], contains('麥當勞'));

      // 自訂規則覆蓋內建：麥當勞現在 → 娛樂
      final result = await AIService.localClassifyAsync('麥當勞 MOP45');
      expect(result.category, '娛樂');

      // 清理，避免影響其他測試
      await AIService.resetRules();
    });

    test('自訂規則：新增全新分類', () async {
      await AIService.saveCustomRules({
        '寵物': ['狗糧', '貓砂'],
      });
      final result = await AIService.localClassifyAsync('買狗糧 MOP120');
      expect(result.category, '寵物');
      await AIService.resetRules();
    });

    test('重置規則後恢復內建', () async {
      await AIService.saveCustomRules({
        '食物': ['專屬詞'],
      });
      await AIService.resetRules();
      final rules = await AIService.loadRules();
      // 恢復內建：麥當勞回到食物
      expect(rules['食物'], isNot(contains('專屬詞')));
      expect(rules['食物'], contains('麥當勞'));
      final result = await AIService.localClassifyAsync('麥當勞 MOP45');
      expect(result.category, '食物');
    });
  });
}
