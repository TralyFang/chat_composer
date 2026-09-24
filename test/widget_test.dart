import 'package:chat_composer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('三个入口能进入输入态，发送后公屏带 @ 和引用', (tester) async {
    await tester.pumpWidget(const ChatComposerApp());
    await tester.pumpAndSettle();

    // 资料卡 @ 按钮
    await tester.tap(find.byKey(const ValueKey('user-rail-u_luna')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-at')));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '@Luna ');

    await tester.enterText(find.byType(TextField), '@Luna 从资料卡艾特你');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(find.textContaining('从资料卡艾特你'), findsOneWidget);
    expect(field.controller!.text, isEmpty);

    // 长按消息 Reply
    await tester.longPress(find.textContaining('今晚连麦位还剩一个'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(find.text('回复 夜航主播'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '我来连麦');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(find.text('我来连麦'), findsOneWidget);
    expect(find.text('回复 夜航主播'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

    await tester.enterText(find.byType(TextField), '你好');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('user-rail-u_luna')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-at')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '你好@Luna ');

    await tester.enterText(find.byType(TextField), '你好@Luna 在吗');
    await tester.pump();
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.textContaining('你好@Luna 在吗'), findsOneWidget);
  });
}
