import 'package:flutter/material.dart';

import '../chat_composer_controller.dart';
import '../models.dart';
import 'reply_quote_bar.dart';

/// 公屏输入框。不监听手打 `@`，只消费 [ChatComposerController] 的入口状态。
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.hintText = '说点什么…',
  });

  final ChatComposerController controller;
  final ValueChanged<ChatSendPayload> onSend;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xF2141826),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.reply != null) ...[
                  ReplyQuoteBar(
                    snapshot: controller.reply!,
                    onClose: controller.clearReply,
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2233),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextField(
                          controller: controller.textController,
                          focusNode: controller.focusNode,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.35,
                          ),
                          cursorColor: const Color(0xFF3DFFB0),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: hintText,
                            hintStyle: const TextStyle(color: Color(0x66FFFFFF), fontSize: 15),
                          ),
                          onSubmitted: (_) => _handleSend(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SendButton(
                      enabled: controller.canSend,
                      onTap: _handleSend,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleSend() {
    final payload = controller.consumeSend();
    if (payload == null) return;
    onSend(payload);
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 72,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: enabled ? const Color(0xFF3DFFB0) : const Color(0x33405670),
        ),
        child: Text(
          '发送',
          style: TextStyle(
            color: enabled ? const Color(0xFF102018) : const Color(0x66FFFFFF),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
