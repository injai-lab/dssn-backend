import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';

class ChatRoomScreen extends StatefulWidget {
  final int roomId;
  const ChatRoomScreen({super.key, required this.roomId});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  bool _inited = false;
  bool _loadingMore = false;
  bool _initialLoading = true;
  Timer? _poll; // 가벼운 자동 갱신 타이머
  int _lastCount = 0;

  int _myId(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final a = auth as dynamic;
    try {
      return (a.me?.id as int?) ??
          (a.user?.id as int?) ??
          (a.currentUser?.id as int?) ??
          0;
    } catch (_) {
      return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_inited) return;
      _inited = true;

      final cp = context.read<ChatProvider>();
      // 들어가기 전에 캐시 없으면 한 번만 가져와서 즉시 노출
      await cp.warmupRoom(widget.roomId, limit: 30);
      _initialLoading = false;
      if (mounted) setState(() {});
      _jumpToBottom();

      // 위로 올리면 과거 더 불러오기
      _scroll.addListener(() async {
        if (_loadingMore) return;
        if (_scroll.position.pixels <= 120 &&
            cp.hasMore(widget.roomId) &&
            !cp.isLoading(widget.roomId)) {
          _loadingMore = true;
          await cp.loadMore(widget.roomId);
          _loadingMore = false;
        }
      });

      // 2초마다 최신만 얹는 가벼운 갱신 (스크롤이 거의 바닥일 때만 자동 점프)
      _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
        final before = cp.messagesOf(widget.roomId).length;
        await cp.fetchNewer(widget.roomId);
        final after = cp.messagesOf(widget.roomId).length;
        final nearBottom = !_scroll.hasClients
            ? true
            : (_scroll.position.pixels < 80);
        if (after > before && nearBottom) _jumpToBottom();
      });
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0, // reverse:true에서 0이 가장 아래
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _pullToRefresh() async {
    await context.read<ChatProvider>().loadLatest(widget.roomId);
    _jumpToBottom();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;

    _text.clear();
    final cp = context.read<ChatProvider>();

    // 낙관적 즉시 표기됨
    final sent = await cp.send(roomId: widget.roomId, text: text);

    // 서버 시각/정렬 확정 위해 아주 가볍게 최신만 덮어쓰기
    if (sent != null) {
      await cp.fetchNewer(widget.roomId);
      _jumpToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ChatProvider>();
    final msgs = cp.messagesOf(widget.roomId);
    final me = _myId(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(cp.roomTitle(widget.roomId, me)),
        // 새로고침 아이콘 제거 요청 반영 (없음)
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _pullToRefresh,
              child: msgs.isEmpty
                  ? ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 32),
                  Center(child: Text('메시지가 없습니다.')),
                ],
              )
                  : ListView.builder(
                controller: _scroll,
                reverse: true, // 최신이 아래
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  // reverse:true 대응
                  final m = msgs[msgs.length - 1 - i];
                  final prev =
                  (i + 1 < msgs.length) ? msgs[msgs.length - 1 - (i + 1)] : null;

                  final mine = m.senderId == me;
                  final startsGroup =
                      (prev == null) || (prev.senderId != m.senderId);

                  return _MessageRow(
                    mine: mine,
                    startsGroup: startsGroup,
                    text: m.message,
                    time: _fmtTime(m.createdAt),
                    senderName: m.senderName,
                    senderAvatar: m.senderAvatar,
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: () {
                      // 필요 시 이미지 전송 연결:
                      // context.read<ChatProvider>().sendImage(widget.roomId, filePath: ...);
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: '메시지 입력...',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _MessageRow extends StatelessWidget {
  final bool mine;
  final bool startsGroup;
  final String? text;
  final String time;
  final String? senderName;
  final String? senderAvatar;

  const _MessageRow({
    required this.mine,
    required this.startsGroup,
    required this.text,
    required this.time,
    this.senderName,
    this.senderAvatar,
  });

  @override
  Widget build(BuildContext context) {
    // 내 메시지: 오른쪽 / 연보라
    // 상대 메시지: 왼쪽 / 연녹 + 그룹 시작이면 프로필/이름 표시
    final bg = mine ? const Color(0xFFEDE7F6) : const Color(0xFFE8F5E9);

    if (mine) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      (text == null || text!.isEmpty) ? '(첨부)' : text!,
                      style:
                      const TextStyle(color: Colors.black87, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(time,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 상대 메시지 (왼쪽)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 그룹 시작일 때만 아바타 표시
          if (startsGroup)
            CircleAvatar(
              radius: 16,
              backgroundImage:
              (senderAvatar != null && senderAvatar!.isNotEmpty)
                  ? NetworkImage(senderAvatar!)
                  : null,
              child: (senderAvatar == null || senderAvatar!.isEmpty)
                  ? const Icon(Icons.person, size: 18)
                  : null,
            )
          else
            const SizedBox(width: 32), // 아바타 자리 맞춤

          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (startsGroup && (senderName != null && senderName!.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(senderName!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    (text == null || text!.isEmpty) ? '(첨부)' : text!,
                    style:
                    const TextStyle(color: Colors.black87, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 2),
                Text(time,
                    style:
                    const TextStyle(fontSize: 11, color: Colors.black45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
