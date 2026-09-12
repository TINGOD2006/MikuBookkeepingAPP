import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/record.dart';

class StorageService {
  static const String _recordsKey = 'records';
  static Future<void> _recordWriteQueue = Future<void>.value();

  /// ✅ 原生端（NotificationListenerService）在 App 未執行時直接保存的記錄。
  ///
  /// 新格式：一筆記錄一個鍵（`native_record_<eventId>`），原生端只做「新增」，
  /// 不再讀取整份清單後覆寫，因此不會與 Dart 端的匯入（讀取＋刪除）互相蓋掉。
  static const String nativeRecordKeyPrefix = 'native_record_';

  /// 舊格式：單一 JSON 陣列字串（相容舊版 App 寫入的資料，匯入後即刪除）。
  static const String legacyNativeRecordsKey = 'native_records';

  // ========== 記錄相關方法 ==========
  Future<void> saveRecords(List<Record> records) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> recordsJson = records
        .map((r) => r.toJsonString())
        .toList();
    await prefs.setStringList(_recordsKey, recordsJson);
  }

  /// 把「讀取 → 修改 → 寫回」序列化執行。
  ///
  /// 同時只允許一個操作動到記錄清單，否則（例如自動記錄與畫面重新載入
  /// 同時發生）兩邊各自讀出舊清單再寫回，就會互相覆蓋而少掉記錄。
  Future<T> _serializeWrite<T>(Future<T> Function() action) {
    final operation = _recordWriteQueue.then((_) => action());
    // 佇列本身不停留在失敗狀態，錯誤交由 operation 傳回呼叫者
    _recordWriteQueue = operation.then<void>((_) {}, onError: (_) {});
    return operation;
  }

  /// 載入全部記錄（含匯入原生端在 App 未執行時保存的記錄）。
  Future<List<Record>> loadRecords() {
    return _serializeWrite(_loadRecordsWithImport);
  }

  /// ⚠️ 只能在寫入佇列「內部」呼叫（佇列外的呼叫請用 [loadRecords]）。
  Future<List<Record>> _loadRecordsWithImport() async {
    final prefs = await SharedPreferences.getInstance();
    final records = <Record>[];

    for (final json in prefs.getStringList(_recordsKey) ?? const <String>[]) {
      if (json.isEmpty) continue;
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        records.add(Record.fromJson(map));
      } catch (e) {
        debugPrint('⚠️ 跳過無效記錄: $e');
        continue;
      }
    }

    // ✅ 合併原生端待匯入的記錄。
    //    ⚠️ 任何一筆壞資料都不能讓整份明細載入失敗（舊版只要原生記錄解析
    //    失敗，loadRecords 就會拋錯 → 明細頁整頁空白且再也匯入不進去）。
    final newlyImported = <Record>[];
    final sourceKeys = _collectNativeRecords(prefs, records, newlyImported);

    records.sort((a, b) => b.date.compareTo(a.date));

    // ✅ 匯入的記錄必須先寫進主要清單，成功後才刪除來源鍵。
    //    舊版只把記錄放進回傳的清單、卻立刻刪掉來源鍵，
    //    結果這筆記錄從未落地，下次載入就無聲消失。
    if (newlyImported.isNotEmpty) {
      await saveRecords(records);
    }
    for (final key in sourceKeys) {
      await prefs.remove(key);
    }

    return records;
  }

  /// 收集原生端保存的記錄到 [records]，回傳「確認處理完畢、可以刪除」的來源鍵。
  ///
  /// 解析失敗的資料不會列入回傳值，因此會被保留待下次載入再試。
  List<String> _collectNativeRecords(
    SharedPreferences prefs,
    List<Record> records,
    List<Record> newlyImported,
  ) {
    final keysToRemove = <String>[];
    final knownIds = records.map((r) => r.id).toSet();

    void takeRecord(Record record, String source) {
      if (knownIds.add(record.id)) {
        records.add(record);
        newlyImported.add(record);
        debugPrint('📥 已匯入原生自動記帳（$source）: ${record.id}');
      } else {
        debugPrint('⏭️ 原生記錄已存在，略過: ${record.id}');
      }
    }

    // 1) 新格式：一筆一個鍵（append-only，不會與匯入互相覆蓋）
    for (final key in prefs
        .getKeys()
        .where((key) => key.startsWith(nativeRecordKeyPrefix))
        .toList()) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        keysToRemove.add(key);
        continue;
      }

      final record = _tryDecodeRecord(raw);
      if (record == null) {
        // ⚠️ 保留資料，避免無聲丟失
        debugPrint('⚠️ 原生記錄格式無效，保留待修復: $key');
        continue;
      }

      keysToRemove.add(key);
      takeRecord(record, '新格式');
    }

    // 2) 舊格式：單一 JSON 陣列（元素為 JSON 字串或 JSON 物件）
    final legacyJson = prefs.getString(legacyNativeRecordsKey);
    if (legacyJson == null || legacyJson.isEmpty) return keysToRemove;

    try {
      final decoded = jsonDecode(legacyJson);
      if (decoded is List) {
        for (final item in decoded) {
          final record = _tryDecodeRecord(item);
          if (record == null) continue;
          takeRecord(record, '舊格式');
        }
      }
      keysToRemove.add(legacyNativeRecordsKey);
    } catch (e) {
      debugPrint('⚠️ 舊格式原生記錄解析失敗，保留待修復: $e');
    }

    return keysToRemove;
  }

  /// 嘗試把原生端保存的資料轉成 [Record]；失敗回傳 null（不拋錯）。
  Record? _tryDecodeRecord(Object? raw) {
    try {
      dynamic decoded = raw;
      if (decoded is String) {
        if (decoded.isEmpty) return null;
        decoded = jsonDecode(decoded);
      }
      if (decoded is! Map) return null;
      return Record.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e) {
      debugPrint('⚠️ 無法解析原生記錄: $e');
      return null;
    }
  }

  Future<void> addRecord(Record record) {
    return _serializeWrite(() => _addRecordIfNew(record));
  }

  Future<void> _addRecordIfNew(Record record) async {
    final records = await _loadRecordsWithImport();
    if (records.any((existing) => existing.id == record.id)) {
      debugPrint('⏭️ 跳過重複記錄: ${record.id}');
      return;
    }
    records.add(record);
    records.sort((a, b) => b.date.compareTo(a.date));
    await saveRecords(records);
  }

  Future<void> deleteRecord(int index) {
    return _serializeWrite(() => _deleteRecordAt(index));
  }

  Future<void> _deleteRecordAt(int index) async {
    final records = await _loadRecordsWithImport();
    if (index >= 0 && index < records.length) {
      records.removeAt(index);
      await saveRecords(records);
    }
  }

  // ========== ✅ 預算相關方法 ==========

  // 儲存預算
  Future<void> saveBudget(int year, int month, double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'budget_${year}_${month.toString().padLeft(2, '0')}';
    await prefs.setDouble(key, amount);
  }

  // 載入預算
  Future<double?> loadBudget(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'budget_${year}_${month.toString().padLeft(2, '0')}';
    return prefs.getDouble(key);
  }

  // 獲取某個月的總支出
  Future<double> getMonthlyExpense(int year, int month) async {
    final records = await loadRecords();
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 1);

    return records
        .where(
          (record) =>
              record.amount < 0 &&
              record.date.isAfter(
                monthStart.subtract(const Duration(days: 1)),
              ) &&
              record.date.isBefore(monthEnd),
        )
        .fold<double>(0.0, (sum, record) => sum + record.amount.abs());
  }

  // 獲取所有已儲存預算的月份列表
  Future<List<String>> getBudgetMonths() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    return keys
        .where((key) => key.startsWith('budget_'))
        .map((key) => key.replaceAll('budget_', ''))
        .toList();
  }
}
