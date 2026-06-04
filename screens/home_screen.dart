// lib/screens/home_screen.dart
import 'package:flutter/material.dart';

// 상단바 아이콘 동작 대상 화면들
import 'notification_screen.dart';
import 'chat_list_screen.dart';
import 'write_post_screen.dart';

// 탭 컨텐츠
import 'home_feed_post.dart';
import 'search_screen.dart';
import 'community_screen.dart';   // ← 상세가 아니라 탭용 스크린 (embed 파라미터 없음)
import 'profile_screen.dart';     // ← 이건 embed 지원

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  final _tabs = const [
    HomeFeedPost(),                    // 홈
    SearchScreen(embed: true),         // 검색 (탭 내: 자체 AppBar 숨김)
    CommunityScreen(),                 // 커뮤니티 (embed 파라미터 없음)
    ProfileScreen(embed: true),        // 마이페이지 (탭 내)
  ];

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationScreen()),
    );
  }

  void _openChats() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatListScreen()),
    );
  }

  void _openComposer() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WritePostScreen()),
    );
  }

  PreferredSizeWidget _homeAppBar() {
    return AppBar(
      centerTitle: false,
      titleSpacing: 8,
      title: const Text(
        'Dong Story',
        style: TextStyle(
          color: Color(0xFF2E7D32),
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_outlined),
          onPressed: _openNotifications,
        ),
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          onPressed: _openChats,
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: _openComposer,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ 홈 탭에서만 상단바 표시
      appBar: _tabIndex == 0 ? _homeAppBar() : null,

      body: IndexedStack(index: _tabIndex, children: _tabs),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
          NavigationDestination(icon: Icon(Icons.search), label: '검색'),
          NavigationDestination(icon: Icon(Icons.groups_2_outlined), label: '커뮤니티'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '마이페이지'),
        ],
      ),
    );
  }
}
