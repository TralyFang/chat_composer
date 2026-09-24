import 'package:chat_composer/chat_composer/chat_composer.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatComposerController controller;

  const luna = MentionTarget(userId: 'u_luna', nickname: 'Luna');
  const kai = MentionTarget(userId: 'u_kai', nickname: 'Kai');
  const replyA = ReplySnapshot(
    msgId: 'msg_a',
    senderId: 'u_anchor',
    senderName: '夜航主播',
    content: '今晚连麦位还剩一个',
  );
  const replyB = ReplySnapshot(
    msgId: 'msg_b',
    senderId: 'u_luna',
    senderName: 'Luna',
    content: '这首好好听',
  );

  setUp(() {
    controller = ChatComposerController();
  });

  tearDown(() {
    controller.dispose();
  });

  test('手打 @xxx 不进入 atUserIds', () {
    controller.textController.text = '@夜航主播 你好';
    final payload = controller.buildPayload();
    expect(payload, isNotNull);
    expect(payload!.atUserIds, isEmpty);
    expect(payload.mentions, isEmpty);
    expect(payload.content, '@夜航主播 你好');
  });

  test('入口 @ 写入唯一 atUserId，正文不含前缀', () {
    controller.enterMention(luna);
    controller.textController.text = '${luna.token}看一下';
    final payload = controller.buildPayload();
    expect(payload!.atUserIds, ['u_luna']);
    expect(payload.content, '看一下');
    expect(payload.toSendChatMsg(roomId: 88)['atUserIds'], ['u_luna']);
  });

  test('默认可同时 @ 多个人', () {
    controller.textController.value = const TextEditingValue(
      text: '你好',
      selection: TextSelection.collapsed(offset: 2),
    );
    controller.enterMention(luna);
    controller.enterMention(kai);
    final text = '${controller.textController.text}在吗';
    controller.textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    expect(controller.mentions, [luna, kai]);
    expect(controller.textController.text, '你好${luna.token}${kai.token}在吗');
    final payload = controller.buildPayload()!;
    expect(payload.atUserIds, ['u_luna', 'u_kai']);
    expect(payload.content, '你好在吗');
    expect(payload.mentionIndexes, [2, 2]);
  });

  test('maxMentions 为 1 时后一次覆盖前一次', () {
    final single = ChatComposerController(maxMentions: 1);
    addTearDown(single.dispose);
    single.enterMention(luna);
    single.enterMention(kai);
    single.textController.value = TextEditingValue(
      text: '${kai.token}换人',
      selection: TextSelection.collapsed(offset: kai.token.length + 2),
    );
    expect(single.mentions, [kai]);
    expect(single.buildPayload()!.atUserIds, ['u_kai']);
  });

  test('每次仅回复一条，后一次覆盖前一次', () {
    controller.enterReply(replyA);
    controller.enterReply(replyB);
    expect(controller.reply?.msgId, 'msg_b');
  });

  test('已有正文时 @ 插在光标处，前后都能继续输入', () {
    controller.textController.value = const TextEditingValue(
      text: '你好',
      selection: TextSelection.collapsed(offset: 2),
    );
    controller.enterMention(luna);
    expect(controller.textController.text, '你好${luna.token}');
    expect(controller.mentions, [luna]);

    final withQuestion = '你好${luna.token}在吗';
    controller.textController.value = TextEditingValue(
      text: withQuestion,
      selection: TextSelection.collapsed(offset: withQuestion.length),
    );
    expect(controller.mentions, [luna]);

    final withLead = '前文你好${luna.token}在吗';
    controller.textController.value = TextEditingValue(
      text: withLead,
      selection: const TextSelection.collapsed(offset: 2),
    );
    expect(controller.mentions, [luna]);
    expect(controller.textController.selection.baseOffset, 2);

    final payload = controller.buildPayload()!;
    expect(payload.atUserIds, ['u_luna']);
    expect(payload.content, '前文你好在吗');
    expect(payload.mentionIndexes, [4]);
  });

  test('光标落进 @ 内部时贴到最近边缘', () {
    controller.textController.value = const TextEditingValue(
      text: '你好',
      selection: TextSelection.collapsed(offset: 2),
    );
    controller.enterMention(luna);
    final text = controller.textController.text;
    controller.textController.value = TextEditingValue(
      text: text,
      selection: const TextSelection.collapsed(offset: 3),
    );
    expect(controller.mentions, [luna]);
    expect(controller.textController.selection.baseOffset, 2);
  });

  test('回删原子 @ 保留前后正文', () {
    controller.textController.value = const TextEditingValue(
      text: '你好',
      selection: TextSelection.collapsed(offset: 2),
    );
    controller.enterMention(luna);
    final withBody = '你好${luna.token}在吗';
    controller.textController.value = TextEditingValue(
      text: withBody,
      selection: TextSelection.collapsed(offset: withBody.length),
    );
    final tokenEnd = 2 + luna.token.length;
    final broken = withBody.replaceRange(tokenEnd - 1, tokenEnd, '');
    controller.textController.value = TextEditingValue(
      text: broken,
      selection: TextSelection.collapsed(offset: tokenEnd - 1),
    );
    expect(controller.mentions, isEmpty);
    expect(controller.textController.text, '你好在吗');
    expect(controller.buildPayload()!.atUserIds, isEmpty);
    expect(controller.buildPayload()!.content, '你好在吗');
  });

  test('回删原子 @ 后不再带 atUserIds', () {
    controller.enterMention(luna);
    controller.textController.value = TextEditingValue(
      text: '${luna.token}hi',
      selection: TextSelection.collapsed(offset: luna.token.length + 2),
    );
    controller.textController.value = TextEditingValue(
      text: 'hi',
      selection: const TextSelection.collapsed(offset: 0),
    );
    expect(controller.mentions, isEmpty);
    expect(controller.buildPayload()!.atUserIds, isEmpty);
    expect(controller.buildPayload()!.content, 'hi');
  });

  test('consumeSend 带上 reply 快照并清空输入态', () {
    controller.enterReply(replyA);
    controller.textController.text = '收到';
    final payload = controller.consumeSend();
    expect(payload!.reply?.msgId, 'msg_a');
    expect(payload.reply?.content, '今晚连麦位还剩一个');
    expect(controller.reply, isNull);
    expect(controller.textController.text, isEmpty);
    expect(controller.canSend, isFalse);
  });

  test('艾特高亮范围可切换，关闭时输入框不上色', () {
    expect(controller.highlight, MentionHighlight.mentioned);
    expect(controller.textController.highlightMentions, isTrue);

    controller.highlight = MentionHighlight.everyone;
    expect(controller.textController.highlightMentions, isTrue);

    controller.highlight = MentionHighlight.off;
    expect(controller.textController.highlightMentions, isFalse);

    const style = TextStyle(color: Color(0xFFFFC857), fontWeight: FontWeight.w700);
    controller.mentionHighlightStyle = style;
    expect(controller.textController.highlightStyle, style);
  });

  test('正文为空不能发送', () {
    controller.enterMention(luna);
    expect(controller.buildPayload(), isNull);
  });
}
