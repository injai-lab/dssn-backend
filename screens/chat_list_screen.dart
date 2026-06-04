import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _inited = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_inited) return;
      _inited = true;
      await context.read<ChatProvider>().fetchRooms();
    });
  }

  int _myId(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final a = auth as dynamic;
    try { return (a.me?.id as int?) ?? (a.user?.id as int?) ?? (a.currentUser?.id as int?) ?? 0; }
    catch (_) { return 0; }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ChatProvider>();
    final rooms = cp.rooms;
    final myId = _myId(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: () => cp.fetchRooms(),
          ),
          IconButton(
            tooltip: '새 대화',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () => Navigator.pushNamed(context, '/chat/new'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => cp.fetchRooms(),
        child: ListView.separated(
          itemCount: rooms.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final r = rooms[i];
            final title = r.displayTitle(myId);
            final preview = r.lastMessagePreview ?? '';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFD4F4D3),
                child: const Icon(Icons.chat_bubble, color: Colors.green),
              ),
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: (preview.isNotEmpty)
                  ? Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              onTap: () => Navigator.pushNamed(
                context,
                '/chat/room',
                arguments: {'roomId': r.id}, // 안전한 진입
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/chat/new'),
        child: const Icon(Icons.edit),
      ),
    );
  }
}
