import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/services/login_service.dart';
import 'package:localmate/services/profile_service.dart';
import 'package:localmate/features/auth/login_page.dart';
import 'package:localmate/features/mypage/settings/settings_page.dart';
import 'package:localmate/features/mypage/shop/shop_page.dart';
import 'package:localmate/features/mypage/profile/profile_edit_page.dart';
import 'package:localmate/features/mypage/wishlist/wishlist_page.dart';
import 'package:localmate/features/mypage/supports/my_support_page.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final _loginService = LoginService();
  final _profileService = ProfileService();

  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  Future<void> _loadMyProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final data = await _profileService.getMyProfile();

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
        // ✅ [수정] 상단 톱니바퀴 아이콘 제거 (메뉴 리스트로 이동했으니까요!)
        actions: const [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMyProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildProfileSection(),
                    const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
                    _buildWalletSection(),
                    const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
                    _buildMenuSection(context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Column(
      children: [
        // ✅ 1. '아이템 상점' -> '상점'으로 이름 변경
        _menuTile(Icons.storefront_outlined, "상점", "가이드 홍보 아이템 및 유료 서비스", () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShopPage()), // ✅ 이제 여기로 이동!
          );
        }),
        // ✅ 2. '이용권 관리' 자리에 '설정' 배치 (상단에 있던 톱니바퀴 로직 이동)
        _menuTile(Icons.settings_outlined, "설정", "알림 설정, 계정 관리 및 서비스 환경", () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          );
        }),

        _menuTile(Icons.favorite_border, "관심 목록", "내가 찜한 메이트 & 제안 공고", () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WishlistPage()),
          );
        }),

        _menuTile(Icons.help_outline, "지원", "공지사항, 약관 및 문의하기", () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MySupportPage()),
          );
        }),
      ],
    );
  }

  Widget _buildProfileSection() {
    final String nickname = _profileData?['nickname'] ?? "여행하는 메이트";
    final double rating = (_profileData?['rating'] ?? 5).toDouble();
    final List<dynamic> images = _profileData?['profile_image'] ?? [];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
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
          OutlinedButton(
            onPressed: () async {
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
