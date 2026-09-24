import 'package:flutter/material.dart';

import 'demo/live_room_page.dart';

void main() {
  runApp(const ChatComposerApp());
}

class ChatComposerApp extends StatelessWidget {
  const ChatComposerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '公屏输入框',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3DFFB0),
          surface: Color(0xFF0B1020),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        useMaterial3: true,
      ),
      home: const LiveRoomPage(),
    );
  }
}
