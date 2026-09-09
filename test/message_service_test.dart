import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countapp/services/message_service.dart';

void main() {
  setUp(() {
    MessageService.reset();
  });

  group('MessageService 去重', () {
    test('相同 key 在時間窗內只會推送一次', () {
      // 無 messenger 註冊時，showSnackBar 回傳 true（嘗試顯示）但實際略過 UI。
      // 去重判斷發生在 messenger 之前，因此可用回傳值驗證。
      expect(MessageService.tryAcquireOnce('test-key'), isTrue);
      expect(MessageService.tryAcquireOnce('test-key'), isFalse);
    });

    test('不同 key 各自獨立去重', () {
      expect(MessageService.tryAcquireOnce('a'), isTrue);
      expect(MessageService.tryAcquireOnce('a'), isFalse);
      expect(MessageService.tryAcquireOnce('b'), isTrue);
    });

    test('時間窗過後可再次推送', () async {
      expect(MessageService.tryAcquireOnce('t1'), isTrue);
      expect(MessageService.tryAcquireOnce('t1'), isFalse);

      await Future.delayed(
        MessageService.dedupeDuration + const Duration(milliseconds: 100),
      );

      expect(MessageService.tryAcquireOnce('t1'), isTrue);
    });

    test('showSnackBar 相同訊息去重', () {
      // messenger 未註冊 → 第一次回傳 true（已通過去重），
      // 第二次相同訊息應被去重攔截回傳 false。
      expect(
        MessageService.showSnackBar('測試訊息', key: 'k'),
        isTrue,
      );
      expect(
        MessageService.showSnackBar('測試訊息', key: 'k'),
        isFalse,
      );
    });

    test('force 可跳過去重', () {
      expect(MessageService.tryAcquireOnce('f'), isTrue);
      expect(MessageService.tryAcquireOnce('f'), isFalse);
      expect(MessageService.tryAcquireOnceFor('f', Duration.zero), isTrue);
    });

    test('tryAcquireOnceFor 使用指定時間窗', () async {
      expect(MessageService.tryAcquireOnceFor('w', const Duration(milliseconds: 50)), isTrue);
      expect(MessageService.tryAcquireOnceFor('w', const Duration(milliseconds: 50)), isFalse);

      await Future.delayed(const Duration(milliseconds: 60));

      expect(MessageService.tryAcquireOnceFor('w', const Duration(milliseconds: 50)), isTrue);
    });
  });

  group('MessageService 併發處理去重', () {
    test('beginProcess / endProcess', () {
      expect(MessageService.isProcessing('p1'), isFalse);
      expect(MessageService.beginProcess('p1'), isTrue);
      expect(MessageService.isProcessing('p1'), isTrue);
      // 重複開始處理應回傳 false
      expect(MessageService.beginProcess('p1'), isFalse);

      MessageService.endProcess('p1');
      expect(MessageService.isProcessing('p1'), isFalse);
    });
  });

  group('MessageService 全域事件流', () {
    test('push 事件可被監聽', () {
      final received = <MessageEvent>[];
      final sub = MessageService.globalMessages.listen(received.add);

      MessageService.push('事件訊息', isToast: true);

      expect(received, hasLength(1));
      expect(received.single.message, '事件訊息');
      expect(received.single.isToast, isTrue);

      sub.cancel();
    });
  });

  group('MessageService SnackBar 顯示', () {
    testWidgets('註冊 messengerKey 後可顯示 SnackBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: MessageService.messengerKey,
          home: const Scaffold(body: SizedBox()),
        ),
      );

      final shown = MessageService.showSnackBar(
        '你好，世界',
        key: 'hello',
      );
      expect(shown, isTrue);
      await tester.pump();

      expect(find.text('你好，世界'), findsOneWidget);
    });

    testWidgets('相同訊息重複呼叫只顯示一條', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: MessageService.messengerKey,
          home: const Scaffold(body: SizedBox()),
        ),
      );

      final first = MessageService.showSnackBar('重複', key: 'dup');
      final second = MessageService.showSnackBar('重複', key: 'dup');
      expect(first, isTrue);
      expect(second, isFalse);

      await tester.pump();
      expect(find.text('重複'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });
}
