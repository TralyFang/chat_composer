import 'package:flutter/material.dart';

import '../models.dart';

/// 公屏气泡。引用区最多 3 行；@ 高亮由 [highlight] 决定。
class PublicChatBubble extends StatelessWidget {
  const PublicChatBubble({
    super.key,
    required this.message,
    required this.viewerId,
    this.highlight = MentionHighlight.mentioned,
    this.highlightStyle = const TextStyle(
      color: Color(0xFF3DFFB0),
      fontWeight: FontWeight.w700,
    ),
    this.onLongPress,
    this.onAvatarLongPress,
    this.onNameLongPress,
    this.onAvatarTap,
  });

  final PublicChatMessage message;
  final String viewerId;
  final MentionHighlight highlight;
  final TextStyle highlightStyle;
  final VoidCallback? onLongPress;
  final VoidCallback? onAvatarLongPress;
  final VoidCallback? onNameLongPress;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            onLongPress: onAvatarLongPress,
            child: _Avatar(name: message.senderName),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onLongPress: onLongPress,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: onNameLongPress,
                    child: Text(
                      message.senderName,
                      style: const TextStyle(
                        color: Color(0xFFB8C0D6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: const BoxDecoration(
                      color: Color(0x66101828),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.reply != null) ...[
                          _QuoteBlock(snapshot: message.reply!),
                          const SizedBox(height: 6),
                        ],
                        Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                            children: _contentSpans(
                              message.content,
                              message.atUsers,
                              viewerId,
                              highlight,
                              highlightStyle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<InlineSpan> _contentSpans(
  String content,
  List<MentionTarget> atUsers,
  String viewerId,
  MentionHighlight highlight,
  TextStyle highlightStyle,
) {
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final user in atUsers) {
    final located = _locateToken(content, user.token, cursor);
    if (located == null) continue;
    if (located.start > cursor) {
      spans.add(TextSpan(text: content.substring(cursor, located.start)));
    }
    spans.add(TextSpan(
      text: content.substring(located.start, located.end),
      style: _mentionStyle(user, viewerId, highlight, highlightStyle),
    ));
    cursor = located.end;
  }
  if (cursor < content.length) {
    spans.add(TextSpan(text: content.substring(cursor)));
  }
  if (spans.isEmpty) {
    spans.add(TextSpan(text: content));
  }
  return spans;
}

/// 在 [content] 的 [cursor] 之后找下一次原子 @。
///
/// [token] 形如 `@Luna `，尾部空格用来和后面的正文分开。
/// 发送时全文会 trim，艾特落在句尾时这个空格会被去掉，只剩 `@Luna`。
/// 第一种情况按完整 token 匹配；句尾才退回不带空格的写法，避免把中间的普通文字认成艾特。
({int start, int end})? _locateToken(String content, String token, int cursor) {
  final index = content.indexOf(token, cursor);
  if (index >= 0) return (start: index, end: index + token.length);
  // 句尾被 trim 掉的尾部空格。
  final bare = token.trimRight();
  if (bare.length == token.length) return null;
  final bareIndex = content.indexOf(bare, cursor);
  if (bareIndex < 0 || bareIndex + bare.length != content.length) return null;
  return (start: bareIndex, end: content.length);
}

TextStyle? _mentionStyle(
  MentionTarget? mention,
  String viewerId,
  MentionHighlight highlight,
  TextStyle highlightStyle,
) {
  if (mention == null || highlight == MentionHighlight.off) return null;
  final highlightAt = highlight == MentionHighlight.everyone || mention.userId == viewerId;
  if (highlightAt) return highlightStyle;
  return const TextStyle(
    color: Color(0xDEFFFFFF),
    fontWeight: FontWeight.w400,
  );
}

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.snapshot});

  final ReplySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFFFFC857), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snapshot.senderName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFFC857),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            snapshot.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final hue = (name.hashCode % 360).abs().toDouble();
    return CircleAvatar(
      radius: 16,
      backgroundColor: HSVColor.fromAHSV(1, hue, 0.45, 0.72).toColor(),
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
