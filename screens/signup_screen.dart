import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();

  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  final _studentNo = TextEditingController();
  final _nickname = TextEditingController();
  final _name = TextEditingController();
  final _department = TextEditingController();

  bool _busy = false;
  bool _agree = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    _studentNo.dispose();
    _nickname.dispose();
    _name.dispose();
    _department.dispose();
    super.dispose();
  }

  String? _req(String? v, {String label = '값'}) {
    if (v == null || v.trim().isEmpty) return '$label을(를) 입력하세요';
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('약관 동의가 필요합니다.')),
      );
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (_password.text != _password2.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    try {
      final auth = context.read<AuthProvider>();
      final a = auth as dynamic;

      final payload = {
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'student_no': _studentNo.text.trim(),
        'nickname': _nickname.text.trim(),
        'name': _name.text.trim(),
        'department': _department.text.trim(),
      };

      bool ok = false;

      // 1) register({...})
      try {
        final r = await a.register?.call(payload);
        ok = (r == true) || (r?.success == true);
      } catch (_) {}

      // 2) signUp({...})
      if (!ok) {
        try {
          final r = await a.signUp?.call(payload);
          ok = (r == true) || (r?.success == true);
        } catch (_) {}
      }

      // 3) register(username, email, password, ...)
      if (!ok) {
        try {
          final r = await a.register?.call(
            username: payload['username'],
            email: payload['email'],
            password: payload['password'],
            studentNo: payload['student_no'],
            nickname: payload['nickname'],
            name: payload['name'],
            department: payload['department'],
          );
          ok = (r == true) || (r?.success == true);
        } catch (_) {}
      }

      // 4) signUp(username:..., email:..., password:...)
      if (!ok) {
        try {
          final r = await a.signUp?.call(
            username: payload['username'],
            email: payload['email'],
            password: payload['password'],
            studentNo: payload['student_no'],
            nickname: payload['nickname'],
            name: payload['name'],
            department: payload['department'],
          );
          ok = (r == true) || (r?.success == true);
        } catch (_) {}
      }

      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입이 완료됐어요. 로그인해주세요.')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입에 실패했어요. 입력값을 확인해주세요.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입 오류: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = const SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(
                  labelText: '아이디',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _req(v, label: '아이디'),
                textInputAction: TextInputAction.next,
              ),
              spacing,
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => _req(v, label: '이메일'),
                textInputAction: TextInputAction.next,
              ),
              spacing,
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) => _req(v, label: '비밀번호'),
                textInputAction: TextInputAction.next,
              ),
              spacing,
              TextFormField(
                controller: _password2,
                decoration: const InputDecoration(
                  labelText: '비밀번호 확인',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) => _req(v, label: '비밀번호 확인'),
                onFieldSubmitted: (_) => _submit(),
              ),
              spacing,
              TextFormField(
                controller: _studentNo,
                decoration: const InputDecoration(
                  labelText: '학번',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _req(v, label: '학번'),
                textInputAction: TextInputAction.next,
              ),
              spacing,
              TextFormField(
                controller: _nickname,
                decoration: const InputDecoration(
                  labelText: '닉네임',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _req(v, label: '닉네임'),
                textInputAction: TextInputAction.next,
              ),
              spacing,
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: '이름(선택)',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              spacing,
              TextFormField(
                controller: _department,
                decoration: const InputDecoration(
                  labelText: '학과(선택)',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
              ),
              spacing,
              Row(
                children: [
                  Checkbox(
                    value: _agree,
                    onChanged: (v) => setState(() => _agree = v ?? false),
                  ),
                  const Expanded(
                    child: Text('이용약관 및 개인정보 처리방침에 동의합니다.'),
                  ),
                ],
              ),
              spacing,
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('회원가입'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('이미 계정이 있으신가요? 로그인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
