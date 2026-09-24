import 'package:flutter/material.dart';

import '../chat_composer/chat_composer.dart';

class RoomUser {
  const RoomUser({
    required this.id,
    required this.nickname,
    required this.role,
  });

  final String id;
  final String nickname;
  final String role;

  MentionTarget get mention => MentionTarget(userId: id, nickname: nickname);
}

const demoUsers = [
  RoomUser(id: 'u_me', nickname: '我自己', role: '当前视角'),
  RoomUser(id: 'u_anchor', nickname: '夜航主播', role: '主播'),
  RoomUser(id: 'u_luna', nickname: 'Luna', role: '观众'),
  RoomUser(id: 'u_kai', nickname: 'Kai', role: '观众'),
];

class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({super.key});

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  final ChatComposerController _composer = ChatComposerController();
  final List<PublicChatMessage> _messages = [];

  String _viewerId = 'u_me';
  String? _deletedMsgId;
  int _seq = 0;

  RoomUser get _me => demoUsers.firstWhere((e) => e.id == _viewerId);

  @override
  void initState() {
    super.initState();
    _seedMessages();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  void _seedMessages() {
    _messages.addAll([
      _buildMessage(
        sender: demoUsers[1],
        content: '今晚连麦位还剩一个，想上的扣 1',
      ),
      _buildMessage(
        sender: demoUsers[2],
        content: '主播这首好好听',
      ),
      _buildMessage(
        sender: demoUsers[3],
        content: '手打 @夜航主播 不会触发，这条只是普通文本',
      ),
    ]);
  }

  PublicChatMessage _buildMessage({
    required RoomUser sender,
    required String content,
    List<MentionTarget> mentions = const [],
    List<int> mentionIndexes = const [],
    ReplySnapshot? reply,
  }) {
    _seq += 1;
    return PublicChatMessage(
      id: 'msg_$_seq',
      senderId: sender.id,
      senderName: sender.nickname,
      content: content,
      mentions: mentions,
      mentionIndexes: mentionIndexes,
      reply: reply,
      createdAt: DateTime.now(),
    );
  }

  void _closeOverlays() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  void _onMention(RoomUser user) {
    if (user.id == _viewerId) return;
    _composer.enterMention(user.mention, closeOverlays: _closeOverlays);
  }

  void _onReply(PublicChatMessage message) {
    _composer.enterReply(
      ReplySnapshot(
        msgId: message.id,
        senderId: message.senderId,
        senderName: message.senderName,
        content: message.content,
      ),
      closeOverlays: _closeOverlays,
    );
  }

  void _onSend(ChatSendPayload payload) {
    setState(() {
      _messages.add(
        _buildMessage(
          sender: _me,
          content: payload.content,
          mentions: payload.mentions,
          mentionIndexes: payload.mentionIndexes,
          reply: payload.reply,
        ),
      );
    });
  }

  Future<void> _openProfile(RoomUser user) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF151A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _ProfileCard(
          user: user,
          isSelf: user.id == _viewerId,
          onAt: () => _onMention(user),
        );
      },
    );
  }

  Future<void> _openMessageActions(PublicChatMessage message) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF151A28),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply, color: Color(0xFFFFC857)),
                title: const Text('Reply', style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  '每次仅回复一条，进入后会清草稿',
                  style: TextStyle(color: Color(0x88FFFFFF), fontSize: 12),
                ),
                onTap: () => _onReply(message),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFFF8A80)),
                title: const Text('删除原消息', style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  '已发出的引用快照不受影响',
                  style: TextStyle(color: Color(0x88FFFFFF), fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _deletedMsgId = message.id;
                    _messages.removeWhere((e) => e.id == message.id);
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        elevation: 0,
        title: const Text('公屏输入演示'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '切换当前视角',
            onSelected: (id) => setState(() => _viewerId = id),
            itemBuilder: (context) {
              return [
                for (final user in demoUsers)
                  PopupMenuItem(
                    value: user.id,
                    child: Text('${user.nickname} · ${user.role}'),
                  ),
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(_me.nickname, style: const TextStyle(fontSize: 13)),
                  const Icon(Icons.expand_more),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _HintBar(
            viewerName: _me.nickname,
            deletedMsgId: _deletedMsgId,
            singleMention: _composer.maxMentions == 1,
            onSingleMentionChanged: (value) {
              setState(() => _composer.maxMentions = value ? 1 : null);
            },
            highlight: _composer.highlight,
            onHighlightChanged: (value) {
              setState(() => _composer.highlight = value);
            },
          ),
          _UserRail(
            users: demoUsers.where((e) => e.id != _viewerId).toList(),
            onAvatarTap: _openProfile,
            onAvatarLongPress: _onMention,
            onNameLongPress: _onMention,
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final sender = demoUsers.firstWhere(
                  (e) => e.id == message.senderId,
                  orElse: () => RoomUser(
                    id: message.senderId,
                    nickname: message.senderName,
                    role: '观众',
                  ),
                );
                return PublicChatBubble(
                  message: message,
                  viewerId: _viewerId,
                  highlight: _composer.highlight,
                  highlightStyle: _composer.mentionHighlightStyle,
                  onLongPress: () => _openMessageActions(message),
                  onAvatarTap: () => _openProfile(sender),
                  onAvatarLongPress: () => _onMention(sender),
                  onNameLongPress: () => _onMention(sender),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: ChatComposer(
              controller: _composer,
              onSend: _onSend,
            ),
          ),
        ],
      ),
    );
  }
}

class _HintBar extends StatelessWidget {
  const _HintBar({
    required this.viewerName,
    required this.deletedMsgId,
    required this.singleMention,
    required this.onSingleMentionChanged,
    required this.highlight,
    required this.onHighlightChanged,
  });

  final String viewerName;
  final String? deletedMsgId;
  final bool singleMention;
  final ValueChanged<bool> onSingleMentionChanged;
  final MentionHighlight highlight;
  final ValueChanged<MentionHighlight> onHighlightChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0x1A3DFFB0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '当前视角：$viewerName。'
              '${deletedMsgId == null ? '' : ' 已删除 $deletedMsgId，引用快照仍在。'}',
              style: const TextStyle(color: Color(0xFFB8F5D8), fontSize: 12, height: 1.35),
            ),
          ),
          const Text('仅限一人', style: TextStyle(color: Color(0xFFB8F5D8), fontSize: 12)),
          Switch(
            key: const ValueKey('single-mention'),
            value: singleMention,
            onChanged: onSingleMentionChanged,
          ),
          PopupMenuButton<MentionHighlight>(
            key: const ValueKey('mention-highlight'),
            tooltip: '艾特高亮',
            initialValue: highlight,
            onSelected: onHighlightChanged,
            itemBuilder: (context) {
              return const [
                PopupMenuItem(value: MentionHighlight.off, child: Text('关闭高亮')),
                PopupMenuItem(value: MentionHighlight.mentioned, child: Text('仅被艾特者')),
                PopupMenuItem(value: MentionHighlight.everyone, child: Text('所有人可见')),
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                switch (highlight) {
                  MentionHighlight.off => '不高亮',
                  MentionHighlight.mentioned => '仅被艾特',
                  MentionHighlight.everyone => '全都高亮',
                },
                style: const TextStyle(color: Color(0xFFB8F5D8), fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRail extends StatelessWidget {
  const _UserRail({
    required this.users,
    required this.onAvatarTap,
    required this.onAvatarLongPress,
    required this.onNameLongPress,
  });

  final List<RoomUser> users;
  final ValueChanged<RoomUser> onAvatarTap;
  final ValueChanged<RoomUser> onAvatarLongPress;
  final ValueChanged<RoomUser> onNameLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: users.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final user = users[index];
          return Column(
            children: [
              GestureDetector(
                key: ValueKey('user-rail-${user.id}'),
                onTap: () => onAvatarTap(user),
                onLongPress: () => onAvatarLongPress(user),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: HSVColor.fromAHSV(
                    1,
                    (user.nickname.hashCode % 360).abs().toDouble(),
                    0.5,
                    0.75,
                  ).toColor(),
                  child: Text(
                    user.nickname.characters.first,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onLongPress: () => onNameLongPress(user),
                child: Text(
                  user.nickname,
                  style: const TextStyle(color: Color(0xFFB8C0D6), fontSize: 11),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.user,
    required this.isSelf,
    required this.onAt,
  });

  final RoomUser user;
  final bool isSelf;
  final VoidCallback onAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFF3DFFB0),
            child: Text(
              user.nickname.characters.first,
              style: const TextStyle(
                color: Color(0xFF102018),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            user.nickname,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(user.role, style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              key: const ValueKey('profile-at'),
              onPressed: isSelf ? null : onAt,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3DFFB0),
                foregroundColor: const Color(0xFF102018),
                disabledBackgroundColor: const Color(0x33405670),
              ),
              child: Text(isSelf ? '不能 @ 自己' : '@ ${user.nickname}'),
            ),
          ),
        ],
      ),
    );
  }
}
