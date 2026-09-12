import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 一筆無障礙讀屏「探針」結果。
///
/// 由原生端 [PaymentAccessibilityService] 在偵測到白名單支付 App 的視窗時產生，
/// 用來判斷對方的付款結果畫面在無障礙節點樹裡到底有沒有可讀文字。
@immutable
class AccessibilityProbeLog {
  /// 記錄時間
  final DateTime time;

  /// 來源 App 包名
  final String packageName;

  /// 視窗／事件來源的 class 名稱
  final String className;

  /// 事件類型（WINDOW_STATE_CHANGED / WINDOW_CONTENT_CHANGED …）
  final String eventType;

  /// 走訪到的節點總數
  final int nodeCount;

  /// 有文字的節點數（**這是探針的核心指標**）
  final int textCount;

  /// 該畫面文字是否符合已知交易格式
  final bool paymentLike;

  /// 該畫面文字是否被判定為廣告推播
  final bool advertisement;

  /// 推斷出的金額（沒有則為 null）
  final double? amount;

  /// 是否為收入
  final bool isIncome;

  /// 一句話結論
  final String verdict;

  /// 蒐集到的節點文字（以「｜」分隔）
  final String text;

  const AccessibilityProbeLog({
    required this.time,
    required this.packageName,
    required this.className,
    required this.eventType,
    required this.nodeCount,
    required this.textCount,
    required this.paymentLike,
    required this.advertisement,
    required this.amount,
    required this.isIncome,
    required this.verdict,
    required this.text,
  });

  factory AccessibilityProbeLog.fromJson(Map<String, dynamic> json) {
    return AccessibilityProbeLog(
      time: DateTime.fromMillisecondsSinceEpoch(
        (json['time'] as num?)?.toInt() ?? 0,
      ),
      packageName: json['package'] as String? ?? '',
      className: json['className'] as String? ?? '',
      eventType: json['eventType'] as String? ?? '',
      nodeCount: (json['nodeCount'] as num?)?.toInt() ?? 0,
      textCount: (json['textCount'] as num?)?.toInt() ?? 0,
      paymentLike: json['paymentLike'] as bool? ?? false,
      advertisement: json['advertisement'] as bool? ?? false,
      amount: (json['amount'] as num?)?.toDouble(),
      isIncome: json['isIncome'] as bool? ?? false,
      verdict: json['verdict'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }

  String get formattedTime {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}

/// 無障礙讀屏探針的存取介面。
///
/// ⚠️ 這是「可行性驗證」用的工具，不是正式的記帳來源。
/// 目前原生端只會 dump 節點樹文字，不會建立任何記錄。
class AccessibilityProbeService {
  AccessibilityProbeService._();

  /// 與通知監聽共用同一個方法通道
  static const MethodChannel _channel = MethodChannel(
    'com.countapp/notification',
  );

  /// 無障礙服務目前是否已啟用
  static Future<bool> isEnabled() async {
    try {
      final enabled = await _channel.invokeMethod<bool>(
        'isAccessibilityProbeEnabled',
      );
      return enabled ?? false;
    } catch (e) {
      debugPrint('⚠️ 檢查無障礙探針狀態失敗: $e');
      return false;
    }
  }

  /// 開啟系統的無障礙設定頁
  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openAccessibilitySettings');
    } catch (e) {
      debugPrint('⚠️ 開啟無障礙設定失敗: $e');
    }
  }

  /// 讀取探針結果（最新的排在最後）
  static Future<List<AccessibilityProbeLog>> loadLogs() async {
    try {
      final raw = await _channel.invokeMethod<String>(
        'getAccessibilityProbeLogs',
      );
      if (raw == null || raw.isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AccessibilityProbeLog.fromJson)
          .toList();
    } catch (e) {
      debugPrint('⚠️ 讀取無障礙探針結果失敗: $e');
      return const [];
    }
  }

  /// 清空探針結果
  static Future<void> clearLogs() async {
    try {
      await _channel.invokeMethod<void>('clearAccessibilityProbeLogs');
    } catch (e) {
      debugPrint('⚠️ 清空無障礙探針結果失敗: $e');
    }
  }
}
