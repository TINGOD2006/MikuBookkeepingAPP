import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

/// 統一的訊息管道（通知／SnackBar）。
///
/// 用途：
/// 1. 集中管理所有通知訊息，供全 App 重複使用（取代散落在各頁面的
///    ScaffoldMessenger.showSnackBar 與 LocalNotificationService 直接呼叫）。
/// 2. 內建去重機制：相同 [key]（預設為訊息文字）在 [dedupeDuration]
///    時間內只會推送一條訊息，避免快速連點按鈕或重複事件造成訊息不斷彈出。
class MessageService {
  MessageService._();

  /// 全域 ScaffoldMessengerKey（在 MaterialApp 註冊，讓無 context 時也能顯示 SnackBar）
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// 防止同一條訊息在短時間內重複推送的預設時間窗
  static const Duration dedupeDuration = Duration(seconds: 3);

  static bool _init = false;
  static final Map<String, DateTime> _lastShownAt = HashMap();
  static final Set<String> _processing = <String>{};
  static final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// 初始化：註冊全域 SnackBar 顯示器，並接上全域通知事件流。
  static void init() {
    if (_init) return;
    _init = true;

    _subscriptions.add(
      globalMessages.listen((event) {
        if (event.isToast) {
          showSnackBar(
            event.message,
            color: event.color,
            duration: event.duration,
          );
        }
      }),
    );
  }

  /// 全域通知事件（SnackBar 用）。任何位置可經由 [push] 推送。
  static final StreamController<MessageEvent> _messageController =
      StreamController<MessageEvent>.broadcast();

  static Stream<MessageEvent> get globalMessages => _messageController.stream;

  /// 推送一條 SnackBar 訊息（經過去重）。
  ///
  /// - [key]：去重鍵，預設為 [message] 本身。
  /// - [force]：設為 true 時忽略去重，一定會顯示。
  /// - [color]：背景色；null 時使用主題預設。
  /// - [duration]：顯示時間；null 時使用 3 秒。
  ///
  /// 重複呼叫（相同 [key] 且在 [dedupeDuration] 內）只會推送一次，
  /// 之後的呼叫會被跳過並回傳 false。
  static bool showSnackBar(
    String message, {
    String? key,
    bool force = false,
    Color? color,
    Duration? duration,
  }) {
    final dedupeKey = key ?? message;
    if (!force && !tryAcquireOnce('snack:$dedupeKey')) {
      debugPrint('🛡️ MessageService: 略過重複訊息 "$dedupeKey"');
      return false;
    }

    final messenger = messengerKey.currentState;
    if (messenger == null) {
      debugPrint('⚠️ MessageService: ScaffoldMessenger 尚未就緒，略過 "$message"');
      return true;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          duration: duration ?? const Duration(seconds: 3),
        ),
      );
    return true;
  }

  /// 推送一條 SnackBar 訊息到指定的 [messenger]（用於尚未掛載全域
  /// messenger 的畫面，例如 Dialog 內部），同樣經過全域去重。
  static bool showSnackBarOn(
    ScaffoldMessengerState messenger,
    String message, {
    String? key,
    bool force = false,
    Color? color,
    Duration? duration,
  }) {
    final dedupeKey = key ?? message;
    if (!force && !tryAcquireOnce('snack:$dedupeKey')) {
      debugPrint('🛡️ MessageService: 略過重複訊息 "$dedupeKey"');
      return false;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          duration: duration ?? const Duration(seconds: 3),
        ),
      );
    return true;
  }

  /// 非同步版本（避免 await 時被忽略的回傳值）。
  static Future<bool> showSnackBarAsync(
    String message, {
    String? key,
    bool force = false,
    Color? color,
    Duration? duration,
  }) async =>
      showSnackBar(
        message,
        key: key,
        force: force,
        color: color,
        duration: duration,
      );

  /// 推送一條事件到全域事件流（供需要監聽的元件使用）。
  static void push(
    String message, {
    String? key,
    Color? color,
    Duration? duration,
    bool isToast = false,
  }) {
    _messageController.add(
      MessageEvent(
        message: message,
        key: key ?? message,
        color: color,
        duration: duration,
        isToast: isToast,
      ),
    );
  }

  // ==================== 去重核心 ====================

  /// 嘗試取得指定 [key] 的推送權；在 [dedupeDuration] 時間窗內已推送過
  /// 則回傳 false（SnackBar 與系統通知共用此去重邏輯）。
  static bool tryAcquireOnce(String key) {
    final now = DateTime.now();
    final last = _lastShownAt[key];
    if (last != null && now.difference(last) < dedupeDuration) {
      return false;
    }
    _lastShownAt[key] = now;

    // 避免快取無限增長：超過 500 筆時清除最舊的一半
    if (_lastShownAt.length > 500) {
      final entries = _lastShownAt.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      for (var i = 0; i < entries.length ~/ 2; i++) {
        _lastShownAt.remove(entries[i].key);
      }
    }
    return true;
  }

  /// 嘗試取得指定 [key] 的推送權，時間窗為 [duration]（用於較長的處理去重）。
  static bool tryAcquireOnceFor(
    String key,
    Duration duration,
  ) {
    final now = DateTime.now();
    final last = _lastShownAt[key];
    if (last != null && now.difference(last) < duration) {
      return false;
    }
    _lastShownAt[key] = now;
    return true;
  }

  /// 檢查某個 [key] 是否正在處理中（供 async 流程做併發去重）。
  static bool isProcessing(String key) => _processing.contains(key);

  /// 標記某個 [key] 開始處理；若已處理中則回傳 false。
  static bool beginProcess(String key) => _processing.add(key);

  /// 結束處理並清除標記。
  static void endProcess(String key) => _processing.remove(key);

  /// 清除去重狀態（主要供測試使用）。
  @visibleForTesting
  static void reset() {
    _lastShownAt.clear();
    _processing.clear();
  }
}

/// 全域訊息事件。
class MessageEvent {
  final String message;
  final String key;
  final Color? color;
  final Duration? duration;
  final bool isToast;

  MessageEvent({
    required this.message,
    required this.key,
    this.color,
    this.duration,
    this.isToast = false,
  });
}
