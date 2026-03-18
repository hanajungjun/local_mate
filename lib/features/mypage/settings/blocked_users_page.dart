import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  // 1. 차단 목록 가져오기 (Realtime 대신 간단하게 Fetch 로직)
  Future<void> _fetchBlockedUsers() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // blocked_users 테이블에서 내가 차단한 사람 목록 + 상대방 유저 정보(users) 조인
      final data = await _supabase
          .from('blocked_users')
          .select(
            '*, blocked_user_info:users!blocked_id(nickname, profile_image_url)',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _blockedUsers = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ 차단 목록 로드 에러: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. 차단 해제 처리
  Future<void> _unblockUser(String blockId, String nickname) async {
    try {
      await _supabase.from('blocked_users').delete().eq('id', blockId);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("$nickname님 차단이 해제되었습니다.")));
        _fetchBlockedUsers(); // 목록 새로고침
      }
    } catch (e) {
      debugPrint("❌ 차단 해제 에러: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "차단한 메이트 관리",
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : _blockedUsers.isEmpty
          ? _buildEmptyState()
          : _buildBlockedList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "차단한 메이트가 없습니다.",
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: _blockedUsers.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: Color(0xFFF5F5F5)),
      itemBuilder: (context, index) {
        final item = _blockedUsers[index];
        final userInfo = item['blocked_user_info'];
        final nickname = userInfo?['nickname'] ?? "알 수 없는 사용자";
        final profileImg = userInfo?['profile_image_url'];
        final createdAt = DateTime.parse(item['created_at']).toLocal();

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFF5F5F5),
            backgroundImage: profileImg != null
                ? NetworkImage(profileImg)
                : null,
            child: profileImg == null
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          title: Text(
            nickname,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            "차단일: ${DateFormat('yyyy.MM.dd').format(createdAt)}",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          trailing: OutlinedButton(
            onPressed: () => _showUnblockDialog(item['id'], nickname),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "차단 해제",
              style: TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
        );
      },
    );
  }

  void _showUnblockDialog(String blockId, String nickname) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "차단 해제",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text("$nickname님의 차단을 해제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unblockUser(blockId, nickname);
            },
            child: const Text("확인", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }
}
