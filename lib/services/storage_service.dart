import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/record.dart';

class StorageService {
  static const String _recordsKey = 'records';

  // 保存所有記錄
  Future<void> saveRecords(List<Record> records) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> recordsJson = records.map((r) => r.toJsonString()).toList();
    await prefs.setStringList(_recordsKey, recordsJson);
  }

  // 載入所有記錄（ 過濾空字串）
  Future<List<Record>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? recordsJson = prefs.getStringList(_recordsKey);

    if (recordsJson == null) return [];

    return recordsJson
        .where((json) => json.isNotEmpty) //  跳過空字串
        .map((json) {
          try {
            return Record.fromJson(jsonDecode(json) as Map<String, dynamic>);
          } catch (e) {
            //  如果解析失敗，跳過該筆資料
            debugPrint('解析記錄失敗: $e, 內容: $json');
            return null;
          }
        })
        .whereType<Record>() // 過濾掉 null
        .toList();
  }

  // 新增一筆記錄
  Future<void> addRecord(Record record) async {
    final records = await loadRecords();
    records.add(record);
    records.sort((a, b) => b.date.compareTo(a.date));
    await saveRecords(records);
  }

  // 刪除記錄
  Future<void> deleteRecord(int index) async {
    final records = await loadRecords();
    if (index < records.length) {
      records.removeAt(index);
      await saveRecords(records);
    }
  }
}