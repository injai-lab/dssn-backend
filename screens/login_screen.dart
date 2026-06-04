// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final id = _id.text.trim();
    final pw = _pw.text;

    try {
      final a = auth as dynamic;
      bool success = false;

      // 1) login(usernameOrEmail, password)
      try {
        final r = await a.login(usernameOrEmail: id, password: pw);
        success = (r == true) || (r?.success == true);
      } catch (_) {}

      // 2) login(username, password)
      if (!success) {
        try {
          final r = await a.login(username: id, password: pw);
          success = (r == true) || (r?.success == true);
        } catch (_) {}
      }

      // 3) signIn(id, pw)
      if (!success) {
        try {
          final r = await a.signIn(id, pw);
          success = (r == true) || (r?.success == true);
        } catch (_) {}
      }

      if (!success) {
        throw Exception('아이디 또는 비밀번호를 확인해 주세요.');
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() => _error = e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    return Scaffold(
      // ⬇⬇ AppBar 없음! (상단 초록 영역 제거)
      backgroundColor: const Color(0xFFF6F8F5), // 은은한 밝은 배경
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Dong Story 타이틀
                    Text(
                      'Dong Story',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 이메일/아이디
                    TextFormField(
                      controller: _id,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '이메일 또는 아이디를 입력하세요.' : null,
                      decoration: InputDecoration(
                        hintText: '이메일 (student_num@du.ac.kr)',
                        prefixIcon: const Icon(Icons.mail_outline),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 비밀번호
                    TextFormField(
                      controller: _pw,
                      obscureText: true,
                      onFieldSubmitted: (_) => _doLogin(),
                      validator: (v) =>
                      (v == null || v.isEmpty) ? '비밀번호를 입력하세요.' : null,
                      decoration: InputDecoration(
                        hintText: '비밀번호',
                        prefixIcon: const Icon(Icons.lock_outline),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 로그인 버튼 (둥근 모양)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                        onPressed: _busy ? null : _doLogin,
                        child: _busy
                            ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Text('로그인'),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 22),

                    // 하단 회원가입 링크
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('계정이 없으신가요?  '),
                        InkWell(
                          onTap: _busy ? null : () => Navigator.pushNamed(context, '/signup'),
                          child: Text(
                            '회원가입',
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: primary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
