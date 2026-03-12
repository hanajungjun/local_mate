import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/services/login_service.dart';
import 'package:localmate/services/profile_service.dart';
import 'package:localmate/features/auth/login_page.dart';
import 'package:localmate/features/setting/pages/settings_page.dart';
import 'package:localmate/features/mypage/profile/profile_edit_page.dart';

class MyProfilePage extends StatefulWidget {
  // ✅ 데이터 로드를 위해 Stateful로 변경
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final _loginService = LoginService();
  final _profileService = ProfileService(); // ✅ 유저 정보 엔진

  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyProfile(); // ✅ 진입 시 프로필 읽어오기
  }

  Future<void> _loadMyProfile() async {
    // 1. 시작 시점 체크 (선택사항이나 권장)
    if (!mounted) return;
    setState(() => _isLoading = true);

    final data = await _profileService.getMyProfile();

    // 🔥 핵심: 비동기(await) 작업이 끝난 후, 위젯이 아직 화면에 있는지 확인!
    if (!mounted) return;

    setState(() {
      _profileData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "마이페이지",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            onPressed: () {
              // ✅ 2. 버튼 클릭 시 SettingsPage로 이동!
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // 로딩 중일 때
          : RefreshIndicator(
              // ✅ 아래로 당겨서 새로고침 가능
              onRefresh: _loadMyProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildProfileSection(), // 1. 프로필 (연동 완료)
                    const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
                    _buildWalletSection(), // 2. 지갑
                    const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
                    _buildMenuSection(context), // 3. 메뉴
                  ],
                ),
              ),
            ),
    );
  }

  // ✅ 상단 프로필 영역 (DB 연동 버전)
  Widget _buildProfileSection() {
    // DB에 데이터가 없으면 기본값 노출
    final String nickname = _profileData?['nickname'] ?? "여행하는 메이트";
    final double rating = (_profileData?['rating'] ?? 5)
        .toDouble(); // ✅ .toDouble() 추가
    final List<dynamic> images = _profileData?['profile_image'] ?? [];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          // 💡 첫 번째 프로필 이미지가 있으면 보여주고, 없으면 아이콘
          CircleAvatar(
            radius: 35,
            backgroundColor: const Color(0xFFEEEEEE),
            backgroundImage: images.isNotEmpty ? NetworkImage(images[0]) : null,
            child: images.isEmpty
                ? const Icon(Icons.person, size: 40, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "$rating (후기 0개)",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ✅ 프로필 수정 버튼 연동
          OutlinedButton(
            onPressed: () async {
              // 수정 페이지 갔다가 돌아오면 데이터 다시 로드!
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileEditPage(isFirstLogin: false),
                ),
              );
              _loadMyProfile();
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              "프로필 수정",
              style: TextStyle(fontSize: 12, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // 지갑/수익 영역
  Widget _buildWalletSection() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "내 지갑",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "보유 포인트",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "24,500 P",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "출금하기",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Column(
      children: [
        _menuTile(Icons.storefront_outlined, "아이템 상점", "가이드 홍보 아이템 사기", () {}),
        _menuTile(Icons.favorite_border, "관심 목록", "내가 찜한 가이드/공고", () {}),
        _menuTile(Icons.card_membership, "이용권 관리", "멤버십 구독 정보", () {}),
        _menuTile(Icons.help_outline, "고객센터 (로그아웃)", "세션을 종료하고 나갑니다", () async {
          await _loginService.signOut();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
            );
          }
        }),
      ],
    );
  }

  Widget _menuTile(
    IconData icon,
    String title,
    String sub,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.black87),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        sub,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.grey,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
