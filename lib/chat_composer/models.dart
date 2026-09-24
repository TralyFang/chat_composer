/// 艾特高亮对谁生效。
enum MentionHighlight {
  /// 不高亮，和正文同一套样式。
  off,

  /// 只有被 @ 的人看到高亮。
  mentioned,

  /// 所有人都能看到高亮。
  everyone,
}

/// 被 @ 的目标。只有从入口选中的人才会进入 [ChatSendPayload.atUserIds]。
class MentionTarget {
  const MentionTarget({
    required this.userId,
    required this.nickname,
  });

  final String userId;
  final String nickname;

  /// 输入框里的原子 token，含尾部空格，方便继续打正文。
  String get token => '@$nickname ';

  MentionTarget copyWith({String? userId, String? nickname}) {
    return MentionTarget(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MentionTarget &&
        other.userId == userId &&
        other.nickname == nickname;
  }

  @override
  int get hashCode => Object.hash(userId, nickname);
}

/// 回复快照。发送时固化，原消息删除后公屏引用区仍用这份数据。
class ReplySnapshot {
  const ReplySnapshot({
    required this.msgId,
    required this.senderId,
    required this.senderName,
    required this.content,
  });

  final String msgId;
  final String senderId;
  final String senderName;
  final String content;

  Map<String, dynamic> toJson() {
    return {
      'msgId': msgId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
    };
  }

  factory ReplySnapshot.fromJson(Map<String, dynamic> json) {
    return ReplySnapshot(
      msgId: json['msgId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      content: json['content'] as String,
    );
  }
}

/// [sendChatMsg] 入参。手打 `@xxx` 不会出现在 [atUserIds] 里。
class ChatSendPayload {
  const ChatSendPayload({
    required this.content,
    required this.atUserIds,
    this.mentions = const [],
    this.mentionIndexes = const [],
    this.reply,
  });

  /// 正文，不含原子 `@昵称 `。[mentionIndexes] 是它们在正文中的插入位置。
  final String content;

  /// 入口确认过的 userId，顺序与 [mentions] 一致。
  final List<String> atUserIds;

  final List<MentionTarget> mentions;

  /// [content] 中插入各 `@昵称 ` 的下标，与 [mentions] 一一对应。
  final List<int> mentionIndexes;

  final ReplySnapshot? reply;

  Map<String, dynamic> toSendChatMsg({int? roomId}) {
    return {
      'roomId': ?roomId,
      'content': content,
      'atUserIds': atUserIds,
      'mentionIndexes': ? (mentions.isEmpty ? null : mentionIndexes),
      'reply': ?reply?.toJson(),
    };
  }
}

/// 公屏消息。引用区和 @ 都来自发送时快照。
class PublicChatMessage {
  const PublicChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.mentions = const [],
    this.mentionIndexes = const [],
    this.reply,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final List<MentionTarget> mentions;

  /// [content] 中插入各 `@昵称 ` 的下标，与 [mentions] 一一对应。
  final List<int> mentionIndexes;

  final ReplySnapshot? reply;
  final DateTime createdAt;

  bool isMentioning(String viewerId) => mentions.any((item) => item.userId == viewerId);
}
