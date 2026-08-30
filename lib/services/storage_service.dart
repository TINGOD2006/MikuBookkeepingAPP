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

  // 載入所有記錄
  Future<List<Record>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? recordsJson = prefs.getStringList(_recordsKey);

    if (recordsJson == null) return [];

    return recordsJson
        .map((json) => Record.fromJson(jsonDecode(json)))
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

  // 輔助方法：解析 JSON
  Map<String, dynamic> jsonDecode(String json) {
    return Map<String, dynamic>.from(_jsonDecode(json));
  }

  // 使用 dart:convert 的 jsonDecode
  dynamic _jsonDecode(String json) {
    return jsonDecode(json);
  }
}