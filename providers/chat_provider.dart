import 'dart:collection';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class ChatMemberLite {
  final int id;
  final String? nickname;
  final String? username;
  final String? avatar;
  ChatMemberLite({required this.id, this.nickname, this.username, this.avatar});
  factory ChatMemberLite.fromJson(Map<String, dynamic> j) => ChatMemberLite(
    id: (j['id'] ?? j['user_id']) is num
        ? ((j['id'] ?? j['user_id']) as num).toInt()
        : int.parse((j['id'] ?? j['user_id']).toString()),
    nickname: j['nickname'] as String?,
    username: j['username'] as String?,
    avatar: j['profile_img'] as String?,
  );
  String get displayName => nickname ?? username ?? '사용자';
}

class ChatRoomLite {
  final int id;
  final String? title;
  final String? lastMessagePreview;
  final DateTime? updatedAt;
  final List<ChatMemberLite> members;
  ChatRoomLite({
    required this.id,
    required this.title,
    this.lastMessagePreview,
    this.updatedAt,
    this.members = const [],
  });
  factory ChatRoomLite.fromJson(Map<String, dynamic> j) {
    final List memsRaw =
        (j['members'] as List?) ?? (j['participants'] as List?) ?? const [];
    final members = memsRaw
        .map((e) => ChatMemberLite.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    String? preview;
    if (j['last_message'] is String) {
      preview = j['last_message'] as String;
    } else if (j['last'] is Map) {
      final lm = (j['last'] as Map).cast<String, dynamic>();
      preview = (lm['message'] as String?) ??
          (lm['file_url'] != null ? '[사진]' : null);
    }

    DateTime? up;
    final upd = j['updated_at'] ?? j['updatedAt'];
    if (upd is String) up = DateTime.tryParse(upd);

    return ChatRoomLite(
      id: (j['id'] as num).toInt(),
      title: (j['title'] as String?) ?? (j['name'] as String?),
      lastMessagePreview: preview,
      updatedAt: up,
      members: members,
    );
  }

  String displayTitle(int myId) {
    if (title != null && title!.trim().isNotEmpty) return title!;
    if (members.isNotEmpty) {
      final peer =
      members.firstWhere((m) => m.id != myId, orElse: () => members.first);
      return peer.displayName;
    }
    return '대화방';
  }
}

class ChatMessage {
  final int id;
  final int roomId;
  final int senderId;
  final String? message;
  final String? fileUrl;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatar;
  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.message,
    required this.fileUrl,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
  });
  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final u =
    (j['user'] is Map) ? (j['user'] as Map).cast<String, dynamic>() : null;
    final roomIdAny = j['room_id'] ?? j['chat_room_id'] ?? j['chatroom_id'];
    final senderAny = j['sender_id'] ?? j['user_id'];
    final createdAny = j['created_at'] ?? j['createdAt'];
    return ChatMessage(
      id: (j['id'] as num).toInt(),
      roomId: (roomIdAny as num).toInt(),
      senderId: (senderAny as num).toInt(),
      message: j['message'] as String?,
      fileUrl: j['file_url'] as String?,
      createdAt: (createdAny is String)
          ? DateTime.parse(createdAny)
          : (createdAny is DateTime ? createdAny : DateTime.now()),
      senderName: (u?['nickname'] as String?) ?? (u?['username'] as String?),
      senderAvatar: u?['profile_img'] as String?,
    );
  }
}

class ChatProvider extends ChangeNotifier {
  final Dio _dio;
  ChatProvider(this._dio);

  // roomId -> 메시지 캐시
  final Map<int, List<ChatMessage>> _roomMessages = {};
  final Map<int, bool> _isFetching = {};
  final Map<int, bool> _hasMore = {};
  final Map<int, int?> _oldestId = {};

  // 방 리스트
  List<ChatRoomLite> _rooms = [];
  String? error;

  // -------- getters ----------
  UnmodifiableListView<ChatMessage> messagesOf(int roomId) =>
      UnmodifiableListView(_roomMessages[roomId] ?? const []);
  bool isLoading(int roomId) => _isFetching[roomId] ?? false;
  bool hasMore(int roomId) => _hasMore[roomId] ?? true;
  List<ChatRoomLite> get rooms => UnmodifiableListView(_rooms);

  ChatRoomLite? roomById(int id) {
    for (final r in _rooms) {
      if (r.id == id) return r;
    }
    return null;
  }

  String roomTitle(int roomId, int myId) =>
      roomById(roomId)?.displayTitle(myId) ?? '대화방';

  String? roomPreview(int roomId) => roomById(roomId)?.lastMessagePreview;

  bool hasLocalMessages(int roomId) =>
      (_roomMessages[roomId]?.isNotEmpty ?? false);

  // -------- helpers ----------
  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (data is Map) {
      final m = data.cast<String, dynamic>();
      final cand = m['items'] ?? m['messages'] ?? m['rows'] ?? m['data'];
      if (cand is List) {
        return cand.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _extractOne(dynamic data) {
    if (data is Map) {
      final m = data.cast<String, dynamic>();
      final one = m['item'] ?? m['message'] ?? m['data'] ?? m;
      return Map<String, dynamic>.from(one as Map);
    }
    return <String, dynamic>{};
  }

  String _pickErr(Object e) {
    if (e is DioException) {
      final msg = e.response?.data is Map
          ? ((e.response!.data['message'] ??
          e.response!.data['error'] ??
          e.message) as String?)
          : e.message;
      return msg ?? '네트워크 오류';
    }
    return e.toString();
  }

  void _appendMessage(ChatMessage m) {
    final list = _roomMessages[m.roomId] ?? <ChatMessage>[];
    if (!list.any((e) => e.id == m.id)) {
      list.add(m);
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _roomMessages[m.roomId] = list;
    }
    final idx = _rooms.indexWhere((r) => r.id == m.roomId);
    if (idx != -1) {
      _rooms[idx] = ChatRoomLite(
        id: _rooms[idx].id,
        title: _rooms[idx].title,
        lastMessagePreview: (m.message != null && m.message!.trim().isNotEmpty)
            ? m.message
            : (m.fileUrl != null ? '[사진]' : _rooms[idx].lastMessagePreview),
        updatedAt: m.createdAt,
        members: _rooms[idx].members,
      );
    }
  }

  int? lastId(int roomId) {
    final list = _roomMessages[roomId];
    if (list == null || list.isEmpty) return null;
    return list.last.id;
    // (createdAt 최신 정렬이므로 마지막 요소가 최신)
  }

  // -------- rooms ----------
  Future<void> fetchRooms() async {
    try {
      final res = await _dio.get('/chats');
      final dataList = _extractList(res.data);
      _rooms = dataList.map((e) => ChatRoomLite.fromJson(e)).toList();
      error = null;
      notifyListeners();
    } catch (e) {
      error = _pickErr(e);
      notifyListeners();
    }
  }

  // 방 들어가기 전에 “미리 한 페이지만” 가져와서 화면 즉시 렌더 가능하게
  Future<void> warmupRoom(int roomId, {int limit = 30}) async {
    if (hasLocalMessages(roomId)) return;
    await loadLatest(roomId, limit: limit);
  }

  Future<ChatRoomLite> openDirect(int userId) async {
    try {
      final res =
      await _dio.post('/chats/direct', data: {'user_id': userId});
      final data = _extractOne(res.data);
      final room = ChatRoomLite.fromJson(data);
      final idx = _rooms.indexWhere((r) => r.id == room.id);
      if (idx == -1) {
        _rooms = [room, ..._rooms];
      } else {
        _rooms[idx] = room;
      }
      notifyListeners();
      return room;
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code != 404 && code != 405) rethrow;
    }
    // 없으면 새로 생성
    final res = await _dio.post('/chats',
        data: {'title': null, 'members': [userId]});
    final data = _extractOne(res.data);
    final room = ChatRoomLite.fromJson(data);
    final idx = _rooms.indexWhere((r) => r.id == room.id);
    if (idx == -1) {
      _rooms = [room, ..._rooms];
    } else {
      _rooms[idx] = room;
    }
    notifyListeners();
    return room;
  }

  Future<ChatRoomLite> createGroup(String title, List<int> memberIds) async {
    final res = await _dio.post('/chats',
        data: {'title': title, 'members': memberIds});
    final data = _extractOne(res.data);
    final room = ChatRoomLite.fromJson(data);
    _rooms = [room, ..._rooms];
    notifyListeners();
    return room;
  }

  // -------- messages ----------
  Future<void> loadLatest(int roomId, {int limit = 30}) async {
    if (_isFetching[roomId] == true) return;
    _isFetching[roomId] = true;
    notifyListeners();
    try {
      final res = await _dio.get('/chats/$roomId/messages',
          queryParameters: {'limit': limit});
      final rawList = _extractList(res.data);
      final msgs = rawList.map((e) => ChatMessage.fromJson(e)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _roomMessages[roomId] = msgs;
      _hasMore[roomId] = msgs.isNotEmpty;
      _oldestId[roomId] = msgs.isNotEmpty ? msgs.first.id : null;
      error = null;
    } catch (e) {
      error = _pickErr(e);
    } finally {
      _isFetching[roomId] = false;
      notifyListeners();
    }
  }

  Future<void> loadMore(int roomId, {int limit = 30}) async {
    if (_isFetching[roomId] == true) return;
    if (_hasMore[roomId] == false) return;
    _isFetching[roomId] = true;
    notifyListeners();
    try {
      final beforeId = _oldestId[roomId];
      final res = await _dio.get('/chats/$roomId/messages', queryParameters: {
        'limit': limit,
        if (beforeId != null) 'before_id': beforeId,
      });
      final rawList = _extractList(res.data);
      final more = rawList.map((e) => ChatMessage.fromJson(e)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (more.isEmpty) {
        _hasMore[roomId] = false;
      } else {
        final buf = _roomMessages[roomId] ?? [];
        final exist = buf.map((e) => e.id).toSet();
        for (final m in more) {
          if (!exist.contains(m.id)) buf.insert(0, m);
        }
        _roomMessages[roomId] = buf;
        _oldestId[roomId] = buf.isNotEmpty ? buf.first.id : _oldestId[roomId];
        _hasMore[roomId] = true;
      }
      error = null;
    } catch (e) {
      error = _pickErr(e);
    } finally {
      _isFetching[roomId] = false;
      notifyListeners();
    }
  }

  /// 최신 이후만 얹는 “가벼운 증분 갱신”
  Future<void> fetchNewer(int roomId) async {
    if (_isFetching[roomId] == true) return;
    final after = lastId(roomId);
    try {
      Response res;
      if (after != null) {
        res = await _dio.get('/chats/$roomId/messages',
            queryParameters: {'after_id': after, 'limit': 30});
      } else {
        res = await _dio.get('/chats/$roomId/messages',
            queryParameters: {'limit': 30});
      }
      final raw = _extractList(res.data);
      if (raw.isEmpty) return;
      final news = raw.map((e) => ChatMessage.fromJson(e)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final buf = _roomMessages[roomId] ?? <ChatMessage>[];
      final set = buf.map((e) => e.id).toSet();
      for (final m in news) {
        if (!set.contains(m.id)) {
          buf.add(m);
          set.add(m.id);
          _appendMessage(m); // 미리보기 갱신
        }
      }
      buf.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _roomMessages[roomId] = buf;
      notifyListeners();
    } catch (_) {
      // 조용히 무시
    }
  }

  // 기존 시그니처 호환
  Future<void> fetchMessages({required int roomId}) => loadLatest(roomId);
  Future<void> refreshMessages({required int roomId}) => loadLatest(roomId);
  Future<void> moreMessages({required int roomId}) => loadMore(roomId);

  // -------- send (낙관적 UI) --------
  Future<ChatMessage?> send({
    required int roomId,
    String? text,
    String? imageUrl,
    String? filePath,
  }) async {
    final path = filePath ?? imageUrl;
    if (path != null) return sendImage(roomId, filePath: path, caption: text);
    return sendText(roomId, text ?? '');
  }

  Future<ChatMessage?> sendText(int roomId, String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return null;
    try {
      final res = await _dio.post('/chats/$roomId/messages',
          data: {'message': text},
          options: Options(contentType: Headers.jsonContentType));
      final data = _extractOne(res.data);
      final msg = ChatMessage.fromJson(data);
      _appendMessage(msg); // ✅ 재조회 없이 즉시 표시
      notifyListeners();
      return msg;
    } catch (e) {
      error = _pickErr(e);
      notifyListeners();
      return null;
    }
  }

  Future<ChatMessage?> sendImage(
      int roomId, {
        required String filePath,
        String? caption,
      }) async {
    try {
      final form = FormData.fromMap({
        if (caption != null && caption.trim().isNotEmpty)
          'message': caption.trim(),
        'file': await MultipartFile.fromFile(
          filePath,
          filename: p.basename(filePath),
        ),
      });
      final res = await _dio.post('/chats/$roomId/messages',
          data: form, options: Options(contentType: 'multipart/form-data'));
      final data = _extractOne(res.data);
      final msg = ChatMessage.fromJson(data);
      _appendMessage(msg); // ✅ 즉시 표시
      notifyListeners();
      return msg;
    } catch (e) {
      error = _pickErr(e);
      notifyListeners();
      return null;
    }
  }
}
