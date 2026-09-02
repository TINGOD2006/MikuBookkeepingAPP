import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/record.dart';

class StorageService {
  static const String _recordsKey = 'records';

  // ========== 記錄相關方法 ==========
  Future<void> saveRecords(List<Record> records) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> recordsJson = records
        .map((r) => r.toJsonString())
        .toList();
    await prefs.setStringList(_recordsKey, recordsJson);
  }

  Future<List<Record>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? recordsJson = prefs.getStringList(_recordsKey);

    if (recordsJson == null || recordsJson.isEmpty) return [];

    final List<Record> records = [];
    for (final json in recordsJson) {
      if (json.isEmpty) continue;
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        records.add(Record.fromJson(map));
      } catch (e) {
        debugPrint('⚠️ 跳過無效記錄: $e');
        continue;
      }
    }
    return records;
  }

  Future<void> addRecord(Record record) async {
    final records = await loadRecords();
    records.add(record);
    records.sort((a, b) => b.date.compareTo(a.date));
    await saveRecords(records);
  }

  Future<void> deleteRecord(int index) async {
    final records = await loadRecords();
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
