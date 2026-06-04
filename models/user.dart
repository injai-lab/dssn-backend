// lib/models/user.dart
class User {
  final int id;                 // int로 고정
  final String username;
  final String? name;
  final String? nickname;
  final String? email;
  final String? profileImg;     // profile_img | profileImg 모두 수용
  final String? department;
  final String? studentNo;      // student_no | studentNo
  final String? bio;

  User({
    required this.id,
    required this.username,
    this.name,
    this.nickname,
    this.email,
    this.profileImg,
    this.department,
    this.studentNo,
    this.bio,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _toInt(json['id']) ?? -1,
      username: (json['username'] ?? json['login'] ?? '').toString(),
      name: json['name']?.toString(),
      nickname: (json['nickname'] ?? json['nick'])?.toString(),
      email: json['email']?.toString(),
      profileImg: (json['profile_img'] ?? json['profileImg'] ?? json['avatar'])?.toString(),
      department: json['department']?.toString(),
      studentNo: (json['student_no'] ?? json['studentNo'])?.toString(),
      bio: json['bio']?.toString(),
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  String get displayName =>
      nickname?.trim().isNotEmpty == true
          ? nickname!.trim()
          : (name?.trim().isNotEmpty == true ? name!.trim() : username);
}
