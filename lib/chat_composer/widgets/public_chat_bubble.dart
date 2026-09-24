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
                            children: _messageSpans(message, viewerId, highlight, highlightStyle),
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

List<InlineSpan> _messageSpans(
  PublicChatMessage message,
  String viewerId,
  MentionHighlight highlight,
  TextStyle highlightStyle,
) {
  if (message.mentions.isEmpty) {
    return [TextSpan(text: message.content)];
  }
  final spans = <InlineSpan>[];
  var cursor = 0;
  final count = message.mentions.length < message.mentionIndexes.length
      ? message.mentions.length
      : message.mentionIndexes.length;
  for (var i = 0; i < count; i++) {
    final mention = message.mentions[i];
    final index = message.mentionIndexes[i].clamp(0, message.content.length);
    if (index > cursor) {
      spans.add(TextSpan(text: message.content.substring(cursor, index)));
      cursor = index;
    }
    final highlightAt = switch (highlight) {
      MentionHighlight.off => false,
      MentionHighlight.everyone => true,
      MentionHighlight.mentioned => mention.userId == viewerId,
    };
    spans.add(TextSpan(
      text: mention.token,
      style: highlight == MentionHighlight.off
          ? null
          : highlightAt
              ? highlightStyle
              : const TextStyle(
                  color: Color(0xDEFFFFFF),
                  fontWeight: FontWeight.w400,
                ),
    ));
  }
  if (cursor < message.content.length) {
    spans.add(TextSpan(text: message.content.substring(cursor)));
  }
  if (spans.isEmpty) {
    return [TextSpan(text: message.content)];
  }
  return spans;
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
