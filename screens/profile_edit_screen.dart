// lib/screens/profile_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nickCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  String? _avatarUrl; // 미리보기/저장용
  bool _saving = false;
  bool _changed = false;

  Map<String, dynamic> _asMap(dynamic v) =>
      (v is Map<String, dynamic>) ? v : <String, dynamic>{};

  Map<String, dynamic> _extractUserMap(AuthProvider ap) {
    // me, data, user 등 래핑된 구조를 한 번에 처리
    Map<String, dynamic> cur = _asMap(ap.me);
    for (final k in ['data', 'user', 'me', 'profile']) {
      final nxt = cur[k];
      if (nxt is Map<String, dynamic>) cur = nxt;
    }
    return cur;
  }

  @override
  void initState() {
    super.initState();
    // 초기값 바인딩
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ap = context.read<AuthProvider>();
      final m = _extractUserMap(ap);

      final nickname = (m['nickname'] ?? m['displayName'] ?? m['display_name'] ?? m['name']) as String?;
      final bio = (m['intro'] ?? m['bio'] ?? m['about'] ?? m['description']) as String?;
      final avatar = (m['avatar'] ?? m['avatar_url'] ?? m['profile_image'] ?? m['profile_image_url']) as String?;

      _nickCtrl.text = (nickname ?? '').trim();
      _bioCtrl.text = (bio ?? '').trim();
      _avatarUrl = (avatar ?? '').trim().isEmpty ? null : avatar!.trim();

      setState(() {}); // 미리보기 갱신
    });

    // 변경 감지
    _nickCtrl.addListener(() => setState(() => _changed = true));
    _bioCtrl.addListener(() => setState(() => _changed = true));
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      // ✅ 서버 스펙에 맞게 AuthProvider에 업데이트 메서드가 있다 가정
      //    (메서드명이 다르면 providers/auth_provider.dart에서 함수명만 맞춰줘)
      await context.read<AuthProvider>().updateProfile(
        nickname: _nickCtrl.text.trim(),
        intro: _bioCtrl.text.trim(),
        avatarUrl: _avatarUrl, // 서버가 받지 않으면 null로 무시됨
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필이 저장되었습니다.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openAvatarMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('이미지 URL로 설정'),
              onTap: () async {
                Navigator.pop(ctx);
                final url = await _askUrl();
                if (url != null && url.trim().isNotEmpty) {
                  setState(() {
                    _avatarUrl = url.trim();
                    _changed = true;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('아바타 제거'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _avatarUrl = null;
                  _changed = true;
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _askUrl() async {
    final ctrl = TextEditingController(text: _avatarUrl ?? '');
    return showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('이미지 URL 입력'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'https://example.com/avatar.png',
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(dctx, ctrl.text), child: const Text('확인')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '뒤로',
        ),
        title: const Text('프로필 편집'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: (_saving || !_changed) ? null : _save,
            child: _saving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('저장'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // ===== 상단 아바타 + 라벨 =====
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage:
                    (_avatarUrl != null && _avatarUrl!.isNotEmpty) ? NetworkImage(_avatarUrl!) : null,
                    child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 36)
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _openAvatarMenu,
                    child: const Text('사진 또는 아바타 수정'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),

            // ===== 닉네임 =====
            _ListField(
              title: '닉네임',
              child: TextFormField(
                controller: _nickCtrl,
                decoration: const InputDecoration(
                  hintText: '닉네임/이름',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '닉네임을 입력하세요.';
                  if (v.trim().length > 30) return '닉네임은 30자 이내로 입력하세요.';
                  return null;
                },
              ),
            ),

            // ===== 자기소개 =====
            _ListField(
              title: '소개',
              child: TextFormField(
                controller: _bioCtrl,
                decoration: const InputDecoration(
                  hintText: '자기소개',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: 3,
                maxLength: 200,
              ),
            ),

            // (필요 시) 향후 확장: 링크/배너/음악 등 항목을 여기에 ListTile로 추가 가능
          ],
        ),
      ),
    );
  }
}

/// 인스타그램 스타일의 설정 행: 좌측 라벨, 우측 값/에디터
class _ListField extends StatelessWidget {
  final String title;
  final Widget child;

  const _ListField({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1F000000))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}
