import 'package:flutter/material.dart';

/// 검색 화면
/// - embed=true(기본): 탭 바디로 쓰일 때 → AppBar 없이 바디만 렌더
/// - embed=false: 단독 진입(푸시/딥링크) → 자체 AppBar 포함
class SearchScreen extends StatefulWidget {
  final bool embed;
  const SearchScreen({super.key, this.embed = true});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  bool _typing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _buildBody(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // 검색창
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: '검색어를 입력하세요',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _typing
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _ctrl.clear();
                    setState(() => _typing = false);
                    // TODO: 검색 초기화
                  },
                )
                    : null,
              ),
              onChanged: (v) => setState(() => _typing = v.isNotEmpty),
              onSubmitted: (q) {
                // TODO: 실제 검색 submit
                FocusScope.of(context).unfocus();
              },
            ),
          ),
          const SizedBox(height: 8),

          // TODO: 탭(통합/유저/태그)나 결과 리스트를 여기에 배치
          Expanded(
            child: Center(
              child: Text(
                _typing ? 'Enter로 검색하세요.' : '검색 결과가 없습니다.',
                style: const TextStyle(color: Colors.black45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embed) return _buildBody(context);
    return Scaffold(appBar: AppBar(title: const Text('검색')), body: _buildBody(context));
  }
}
