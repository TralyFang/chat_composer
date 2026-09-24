import 'package:flutter/widgets.dart';

import 'mention_editing_controller.dart';
import 'models.dart';

/// 公屏输入态控制器。
///
/// 产品约束：
/// - 默认可同时 @ 多个人；[maxMentions] 为 1 时仅限一人，后一次覆盖前一次
/// - 每次仅回复一条
/// - 入口 @ 插在光标处并保留已输入正文；入口回复仍清草稿
/// - 手打 `@xxx` 不写进 [ChatSendPayload.atUsers]
/// - [highlight] 决定艾特高亮对谁生效，[mentionHighlightStyle] 是高亮样式
class ChatComposerController extends ChangeNotifier {
  ChatComposerController({
    int? maxMentions,
    MentionHighlight highlight = MentionHighlight.mentioned,
    TextStyle mentionHighlightStyle = const TextStyle(
      color: Color(0xFF3DFFB0),
      fontWeight: FontWeight.w600,
    ),
  }) : textController = MentionEditingController(maxMentions: maxMentions),
       _highlight = highlight,
       _mentionHighlightStyle = mentionHighlightStyle {
    textController.applyHighlight(
      enabled: highlight != MentionHighlight.off,
      style: mentionHighlightStyle,
    );
    textController.onMentionChanged = notifyListeners;
    textController.addListener(_onText);
  }

  final MentionEditingController textController;
  final FocusNode focusNode = FocusNode();

  ReplySnapshot? _reply;
  bool _canSend = false;
  MentionHighlight _highlight;
  TextStyle _mentionHighlightStyle;

  ReplySnapshot? get reply => _reply;
  List<MentionTarget> get mentions => textController.mentions;
  bool get canSend => _canSend;
  bool get hasReply => _reply != null;
  bool get hasMention => mentions.isNotEmpty;

  /// null 表示不限制人数。
  int? get maxMentions => textController.maxMentions;

  set maxMentions(int? value) {
    if (textController.maxMentions == value) return;
    textController.maxMentions = value;
    _refreshCanSend();
    notifyListeners();
  }

  /// 公屏和输入框里的艾特高亮范围。关闭时输入框里的 token 也不上色。
  MentionHighlight get highlight => _highlight;

  set highlight(MentionHighlight value) {
    if (_highlight == value) return;
    _highlight = value;
    textController.applyHighlight(
      enabled: value != MentionHighlight.off,
      style: _mentionHighlightStyle,
    );
    notifyListeners();
  }

  TextStyle get mentionHighlightStyle => _mentionHighlightStyle;

  set mentionHighlightStyle(TextStyle value) {
    if (_mentionHighlightStyle == value) return;
    _mentionHighlightStyle = value;
    textController.applyHighlight(
      enabled: _highlight != MentionHighlight.off,
      style: value,
    );
    notifyListeners();
  }

  /// 长按头像/昵称、资料卡 @ 按钮。
  void enterMention(MentionTarget user) {
    textController.insertMention(user);
    _requestFocus();
    _refreshCanSend();
    notifyListeners();
  }

  /// 长按消息 Reply。每次只挂一条引用快照。
  void enterReply(ReplySnapshot snapshot) {
    resetDraft(notify: false);
    _reply = snapshot;
    _requestFocus();
    _refreshCanSend();
    notifyListeners();
  }

  void clearReply() {
    if (_reply == null) return;
    _reply = null;
    notifyListeners();
  }

  void resetDraft({bool notify = true}) {
    _reply = null;
    textController.resetText();
    _refreshCanSend();
    if (notify) notifyListeners();
  }

  /// 组装 sendChatMsg 参数。正文为空则返回 null。
  ChatSendPayload? buildPayload() {
    final content = textController.text.trim();
    if (content.isEmpty) return null;
    return ChatSendPayload(
      content: content,
      atUsers: mentions,
      reply: _reply,
    );
  }

  /// 发送成功后清空输入态。
  ChatSendPayload? consumeSend() {
    final payload = buildPayload();
    if (payload == null) return null;
    resetDraft();
    return payload;
  }

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNode.canRequestFocus) {
        focusNode.requestFocus();
      }
    });
  }

  void _onText() {
    final next = textController.text.trim().isNotEmpty;
    if (next == _canSend) return;
    _canSend = next;
    notifyListeners();
  }

  void _refreshCanSend() {
    _canSend = textController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    textController.onMentionChanged = null;
    textController.removeListener(_onText);
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}
