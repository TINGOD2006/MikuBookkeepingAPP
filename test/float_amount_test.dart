import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:countapp/models/record.dart';
import 'package:countapp/services/storage_service.dart';
import 'package:countapp/utils/amount_formatter.dart';
import 'package:countapp/widgets/add_record_dialog.dart';

/// 浮點數金額（含小數）的迴歸測試。
///
/// 記錄金額在資料層一直是 `double`，但手動記帳的鍵盤只能輸入整數，
/// 而且所有顯示都用 `toStringAsFixed(0)` 把小數吃掉。
/// 這組測試鎖住「可以輸入小數 → 存得下去 → 顯示得出來」的完整鏈路。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AmountFormatter.format（顯示用，最多兩位小數並去掉尾端 0）', () {
    test('整數金額不顯示小數', () {
      expect(AmountFormatter.format(0), '0');
      expect(AmountFormatter.format(12), '12');
      expect(AmountFormatter.format(-12), '-12');
    });

    test('保留有效的小數', () {
      expect(AmountFormatter.format(12.5), '12.5');
      expect(AmountFormatter.format(-12.5), '-12.5');
      expect(AmountFormatter.format(0.75), '0.75');
      expect(AmountFormatter.format(-0.75), '-0.75');
    });

    test('尾端多餘的 0 會被移除', () {
      expect(AmountFormatter.format(12.50), '12.5');
      expect(AmountFormatter.format(12.00), '12');
      expect(AmountFormatter.format(12.10), '12.1');
    });

    test('超過兩位小數會四捨五入', () {
      expect(AmountFormatter.format(12.567), '12.57');
      expect(AmountFormatter.format(12.564), '12.56');
      expect(AmountFormatter.format(-12.567), '-12.57');
    });

    test('浮點誤差不會顯示成一長串數字', () {
      // 經典的 0.1 + 0.2 = 0.30000000000000004
      expect(AmountFormatter.format(0.1 + 0.2), '0.3');
    });

    test('不會顯示 "-0"', () {
      expect(AmountFormatter.format(-0.001), '0');
      expect(AmountFormatter.format(-0.0), '0');
    });
  });

  group('AmountFormatter.round（存檔前正規化）', () {
    test('正規化到兩位小數', () {
      expect(AmountFormatter.round(12.567), 12.57);
      expect(AmountFormatter.round(12.5), 12.5);
      expect(AmountFormatter.round(12.0), 12.0);
    });

    test('消除浮點誤差累積', () {
      expect(AmountFormatter.round(0.1 + 0.2), 0.3);
      expect(AmountFormatter.round(1.1 + 2.2), 3.3);
    });
  });

  group('AmountFormatter.formatWithSeparator（千分位）', () {
    test('整數部分才加千分位，小數原樣保留', () {
      expect(AmountFormatter.formatWithSeparator(1234.5), '1,234.5');
      expect(AmountFormatter.formatWithSeparator(1234567), '1,234,567');
      expect(AmountFormatter.formatWithSeparator(-1234.56), '-1,234.56');
      expect(AmountFormatter.formatWithSeparator(999), '999');
      expect(AmountFormatter.formatWithSeparator(1000), '1,000');
    });
  });

  group('AmountFormatter.formatInput（輸入中的字串）', () {
    test('結尾帶小數點也能正確分組', () {
      expect(AmountFormatter.formatInput('1234.'), '1,234.');
      expect(AmountFormatter.formatInput('1234.5'), '1,234.5');
    });

    test('尚未輸入完成時不會掉字', () {
      expect(AmountFormatter.formatInput('0'), '0');
      expect(AmountFormatter.formatInput('0.'), '0.');
      expect(AmountFormatter.formatInput(''), '0');
      expect(AmountFormatter.formatInput('12'), '12');
    });
  });

  group('Record 存取（小數金額不會被吃掉）', () {
    test('JSON 來回轉換保留小數', () {
      final record = Record(
        amount: -12.34,
        category: '食物',
        note: '午餐',
        date: DateTime(2026, 3, 5),
        id: 'decimal-1',
      );

      final restored = Record.fromJson(
        jsonDecode(record.toJsonString()) as Map<String, dynamic>,
      );

      expect(restored.amount, -12.34);
    });

    test('舊資料的整數金額仍可讀取', () {
      final restored = Record.fromJson({
        'amount': -12, // 舊版存成 int
        'category': '食物',
        'note': '',
        'date': '2026-03-05T00:00:00.000',
        'createdAt': '2026-03-05T00:00:00.000',
        'id': 'legacy-int',
      });

      expect(restored.amount, -12.0);
      expect(restored.amount, isA<double>());
    });

    test('小數金額可經 StorageService 寫入並讀回', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();

      await storage.addRecord(
        Record(
          amount: -12.34,
          category: '食物',
          note: '午餐',
          date: DateTime(2026, 3, 5),
          id: 'decimal-storage-1',
        ),
      );

      final records = await storage.loadRecords();
      expect(records, hasLength(1));
      expect(records.single.amount, -12.34);
    });
  });

  group('記帳鍵盤（可以輸入小數）', () {
    Future<List<Record>> pumpAndEnter(
      WidgetTester tester,
      List<String> keys,
    ) async {
      final saved = <Record>[];
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AddRecordDialog(onSave: saved.add),
                ),
                child: const Text('開啟'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('開啟'));
      await tester.pumpAndSettle();

      // 選一個支出分類 → 展開輸入區
      await tester.tap(find.text('食物'));
      await tester.pumpAndSettle();

      for (final key in keys) {
        // 鍵盤在金額顯示之後才建立，因此取最後一個符合文字者即為按鍵
        //（「0」同時出現在金額顯示與鍵盤上，必須取鍵盤那顆）
        await tester.tap(find.text(key).last);
        await tester.pump();
      }

      return saved;
    }

    testWidgets('輸入 12.5 會存成 -12.5', (tester) async {
      final saved = await pumpAndEnter(tester, ['1', '2', '.', '5']);

      // 輸入中的金額即時顯示小數
      expect(find.text('12.5'), findsOneWidget);

      await tester.tap(find.text('保存記帳'));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved.single.amount, -12.5);
    });

    testWidgets('輸入 0.75 會存成 -0.75', (tester) async {
      final saved = await pumpAndEnter(tester, ['0', '.', '7', '5']);
      expect(find.text('0.75'), findsOneWidget);

      await tester.tap(find.text('保存記帳'));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved.single.amount, -0.75);
    });

    testWidgets('小數點只能輸入一次', (tester) async {
      await pumpAndEnter(tester, ['1', '.', '.', '5']);
      expect(find.text('1.5'), findsOneWidget);
      expect(find.text('1..5'), findsNothing);
    });

    testWidgets('小數最多兩位', (tester) async {
      await pumpAndEnter(tester, ['1', '.', '2', '3', '4']);
      expect(find.text('1.23'), findsOneWidget);
    });

    testWidgets('⌫ 可以刪掉小數點', (tester) async {
      await pumpAndEnter(tester, ['1', '2', '.', '⌫']);
      expect(find.text('12'), findsWidgets);
    });
  });
}
