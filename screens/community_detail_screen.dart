import 'package:flutter/material.dart';

/// 커뮤니티 화면
/// - embed=true(기본): 탭 바디 → 상단 AppBar 없음, 바디만
/// - embed=false: 단독 진입 → 자체 AppBar 포함
class CommunityDetailScreen extends StatefulWidget {
  final bool embed;
  const CommunityDetailScreen({super.key, this.embed = true});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  int _chip = 0;
  final _tabs = const ['자유게시판', '질문게시판', '정보공유 게시판'];

  Widget _buildBody(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카테고리 칩
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final selected = i == _chip;
                return Padding(
                  padding: EdgeInsets.only(right: i == _tabs.length - 1 ? 0 : 8),
                  child: ChoiceChip(
                    label: Text(_tabs[i]),
                    selected: selected,
                    selectedColor: Colors.green.shade600,
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                    side: BorderSide(
                      color: selected ? Colors.green : Colors.green.shade300,
                    ),
                    onSelected: (_) => setState(() => _chip = i),
                  ),
                );
              }),
            ),
          ),

          const Divider(height: 1),

          // 본문
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // TODO: 선택 카테고리 새로고침
                await Future.delayed(const Duration(milliseconds: 350));
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: const [
                  SizedBox(height: 24),
                  Center(
                    child: Text('선택된 게시판에 작성된 글이 없습니다.',
                        style: TextStyle(color: Colors.black45)),
                  ),
                ],
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
    return Scaffold(appBar: AppBar(title: const Text('커뮤니티')), body: _buildBody(context));
  }
}
