import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _q = TextEditingController();
  final _scroll = ScrollController();
  final _selected = <int>{}; // 그룹 선택된 userId
  final Dio _dio = ApiClient.I.dio;

  Timer? _debounce;

  bool _inited = false;
  bool _isGroup = false;

  // 화면용 상태
  List<Map<String, dynamic>> _users = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_inited) return;
      _inited = true;
      await _loadSuggested(); // 최초 로딩(추천)
    });
  }

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ----- 데이터 로딩 -----

  Future<void> _loadSuggested() async {
    final meId = _meId();
    setState(() { _loading = true; _error = null; });

    try {
      Response res = await _dio.get('/suggest/users', queryParameters: {'limit': 30});
      List list = (res.data is Map && res.data['items'] is List)
          ? (res.data['items'] as List)
          : (res.data is List ? res.data as List : <dynamic>[]);

      // 추천이 비면, 모든 유저 일부라도 긁기 (백엔드에 맞는 보조 라우트가 있으면 교체)
      if (list.isEmpty) {
        final res2 = await _dio.get('/search/users', queryParameters: {'q': 'a', 'limit': 30});
        list = (res2.data is Map && res2.data['items'] is List)
            ? (res2.data['items'] as List)
            : <dynamic>[];
      }

      final users = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((u) => (u['id'] as num?)?.toInt() != meId)
          .toList();

      setState(() { _users = users; });
    } catch (e) {
      setState(() => _error = _pickErr(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- 교체: _onSearchChanged 와 _searchUsers ---

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = v.trim();
      if (q.isEmpty) {
        await _loadSuggested();
      } else {
        await _searchUsers(q);
      }
    });
  }

  Future<void> _searchUsers(String query) async {
    final meId = _meId();
    setState(() { _loading = true; _error = null; });

    try {
      // 1차: 사용자 검색
      Response res = await _dio.get('/search/users', queryParameters: {
        'q': query,
        'limit': 20,
      });

      List list = [];
      if (res.data is Map && (res.data['items'] is List)) {
        list = res.data['items'] as List;
      } else if (res.data is List) {
        list = res.data as List;
      }

      // 결과가 없으면 2차: 멘션 통합검색(@)
      if (list.isEmpty) {
        final mention = query.startsWith('@') ? query : '@$query';
        final res2 = await _dio.get('/search', queryParameters: {
          'q': mention,
          'limit': 20,
        });
        if (res2.data is Map && (res2.data['items'] is List)) {
          list = res2.data['items'] as List;
        } else if (res2.data is List) {
          list = res2.data as List;
        }
      }

      final users = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((u) => (u['id'] as num?)?.toInt() != meId)
          .toList();

      setState(() { _users = users; });
    } catch (e) {
      setState(() { _error = _pickErr(e); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _meId() {
    final auth = context.read<AuthProvider>();
    final me = (auth as dynamic).me;
    if (me is Map && me['id'] is num) return (me['id'] as num).toInt();
    try {
      return (me?.id as int?);
    } catch (_) {
      return null;
    }
  }

  String _pickErr(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['message'] is String) return d['message'] as String;
      if (d is String && d.isNotEmpty) return d;
      return e.message ?? '네트워크 오류가 발생했어요.';
    }
    return '알 수 없는 오류가 발생했어요.';
  }

  // ----- UI -----

  @override
  Widget build(BuildContext context) {
    final users = _users;

    return Scaffold(
      appBar: AppBar(
        title: const Text('새 채팅'),
        centerTitle: false,
        actions: [
          Row(
            children: [
              const Text('그룹', style: TextStyle(fontSize: 14)),
              Switch(
                value: _isGroup,
                onChanged: (v) {
                  setState(() {
                    _isGroup = v;
                    _selected.clear();
                  });
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSuggested,
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: TextField(
                    controller: _q,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: '닉네임/아이디 검색',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ),

              if (_isGroup && _selected.isNotEmpty)
                SliverToBoxAdapter(
                  child: _SelectedChips(
                    selectedIds: _selected,
                    allUsers: users,
                    onRemove: (id) => setState(() => _selected.remove(id)),
                  ),
                ),

              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    child: Center(child: Text(_error!)),
                  ),
                )
              else if (users.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: Text('Not Found')),
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final u = users[i];
                      final uid = (u['id'] as num?)?.toInt();
                      final name = (u['nickname'] ??
                          u['username'] ??
                          u['name'] ??
                          '사용자') as String;
                      final dept =
                      (u['department'] ?? u['major'] ?? '') as String?;
                      final checked = uid != null && _selected.contains(uid);

                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(name),
                        subtitle: (dept != null && dept.isNotEmpty)
                            ? Text(dept)
                            : null,
                        trailing: _isGroup
                            ? Icon(checked
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked)
                            : null,
                        onTap: () async {
                          if (uid == null) return;

                          if (_isGroup) {
                            setState(() {
                              if (checked) {
                                _selected.remove(uid);
                              } else {
                                _selected.add(uid);
                              }
                            });
                          } else {
                            // ✅ 1:1 즉시 방 오픈하고 입장
                            // DM
                            final room = await context.read<ChatProvider>().openDirect(uid);
                            Navigator.pushNamed(context, '/chat/room', arguments: {'roomId': room.id});
                          }
                        },
                      );
                    },
                  ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 80 + MediaQuery.of(context).padding.bottom,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _isGroup
          ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton(
            onPressed: _selected.length >= 2 ? _createGroup : null,
            child: Text('그룹 채팅 만들기 (${_selected.length})'),
          ),
        ),
      )
          : null,
    );
  }

  Future<void> _createGroup() async {
    final title = await _askGroupTitle();
    if (title == null || title.isEmpty) return;

    final room = await context.read<ChatProvider>().createGroup(title, _selected.toList());
    if (!mounted) return;
    Navigator.pushNamed(context, '/chat/room', arguments: {'roomId': room.id});
  }

  Future<String?> _askGroupTitle() async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('그룹 이름'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '예) 알고리즘 스터디',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

class _SelectedChips extends StatelessWidget {
  const _SelectedChips({
    required this.selectedIds,
    required this.allUsers,
    required this.onRemove,
  });

  final Set<int> selectedIds;
  final List<Map<String, dynamic>> allUsers;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    final map = {for (final u in allUsers) (u['id'] as num?)?.toInt(): u};

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: selectedIds.map((id) {
          final u = map[id];
          if (u == null) return const SizedBox.shrink();
          final name =
          (u['nickname'] ?? u['username'] ?? u['name'] ?? '사용자') as String;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InputChip(
              avatar: const CircleAvatar(child: Icon(Icons.person, size: 16)),
              label: Text(name),
              onDeleted: () => onRemove(id),
            ),
          );
        }).toList(),
      ),
    );
  }
}
