// lib/models/chat.dart
import 'user.dart';

class ChatRoom {
  final int id;                       // int 고정
  final String? title;
  final bool isGroup;
  final DateTime? createdAt;
  final List<User> members;
  final ChatMessage? lastMessage;

  ChatRoom({
    required this.id,
    this.title,
    required this.isGroup,
    this.createdAt,
    this.members = const [],
    this.lastMessage,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final membersRaw = (json['members'] ??
        json['users'] ??
        json['participants']);

    final msgsRaw = json['messages'];
    ChatMessage? last;
    if (msgsRaw is List && msgsRaw.isNotEmpty && msgsRaw.first is Map<String, dynamic>) {
      last = ChatMessage.fromJson(msgsRaw.first as Map<String, dynamic>);
    } else if (json['lastMessage'] is Map<String, dynamic>) {
      last = ChatMessage.fromJson(json['lastMessage'] as Map<String, dynamic>);
    }

    return ChatRoom(
      id: _toInt(json['id']) ?? -1,
      title: json['title']?.toString(),
      isGroup: (json['is_group'] ?? json['isGroup'] ?? false) == true,
      createdAt: _toDate(json['created_at'] ?? json['createdAt']),
      members: _parseUsers(membersRaw),
      lastMessage: last,
    );
  }

  static List<User> _parseUsers(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().map(User.fromJson).toList();
    }
    return const [];
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }
}

class ChatMessage {
  final int id;                 // int 고정
  final int roomId;
  final int senderId;
  final String? message;
  final String? fileUrl;        // file_url | url
  final bool isDeleted;
  final DateTime? createdAt;
  final User? sender;           // 선택적으로 포함될 수 있음

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    this.message,
    this.fileUrl,
    this.isDeleted = false,
    this.createdAt,
    this.sender,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: _toInt(json['id']) ?? -1,
      roomId: _toInt(json['chatroom_id'] ?? json['room_id'] ?? json['chatRoomId']) ?? -1,
      senderId: _toInt(json['sender_id'] ?? json['user_id'] ?? json['senderId']) ?? -1,
      message: json['message']?.toString(),
      fileUrl: (json['file_url'] ?? json['url'])?.toString(),
      isDeleted: (json['is_deleted'] ?? json['deleted'] ?? false) == true,
      createdAt: _toDate(json['created_at'] ?? json['createdAt']),
      sender: (json['sender'] is Map<String, dynamic>)
          ? User.fromJson(json['sender'] as Map<String, dynamic>)
          : (json['user'] is Map<String, dynamic>)
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }
}
