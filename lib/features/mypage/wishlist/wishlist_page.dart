import 'package:flutter/material.dart';
import 'package:localmate/services/wishlist_service.dart';
import 'package:localmate/core/utils/image_utils.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage>
    with SingleTickerProviderStateMixin {
  final WishlistService _wishlistService = WishlistService();

  late TabController _tabController;

  List<Map<String, dynamic>> _likes = [];
  List<Map<String, dynamic>> _offers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _wishlistService.getMyLikes(),
      _wishlistService.getMyOffers(),
    ]);

    if (!mounted) return;
    setState(() {
      _likes = results[0];
      _offers = results[1];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '관심 목록',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: '좋아요 한 메이트 (${_likes.length})'),
            Tab(text: '내 제안 공고 (${_offers.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildLikesTab(), _buildOffersTab()],
            ),
    );
  }

  // ─────────────────────────────────────────
  // 탭 1: 좋아요한 메이트 목록
  // ─────────────────────────────────────────
  Widget _buildLikesTab() {
    if (_likes.isEmpty) {
      return _buildEmpty('아직 좋아요한 메이트가 없어요 💙');
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _likes.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 80, endIndent: 20),
        itemBuilder: (context, index) {
          final like = _likes[index];
          final user = like['users'] ?? {};
          return _LikeTile(
            user: user,
            likedAt: like['created_at'] ?? '',
            onUnlike: () async {
              await _wishlistService.unlikeUser(user['id'].toString());
              _loadAll();
            },
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────
  // 탭 2: 내가 제안한 공고 목록
  // ─────────────────────────────────────────
  Widget _buildOffersTab() {
    if (_offers.isEmpty) {
      return _buildEmpty('아직 제안한 공고가 없어요 📋');
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _offers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final offer = _offers[index];
          final request = offer['travel_requests'] ?? {};
          return _OfferCard(offer: offer, request: request);
        },
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// 좋아요 타일
// ─────────────────────────────────────────
class _LikeTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final String likedAt;
  final VoidCallback onUnlike;

  const _LikeTile({
    required this.user,
    required this.likedAt,
    required this.onUnlike,
  });

  @override
  Widget build(BuildContext context) {
    final profileImage = getProfileImage(user['profile_image']);
    final nickname = user['nickname'] ?? '이름 없음';
    final nationality = user['nationality'] ?? '로컬';
    final age = user['age']?.toString() ?? '??';

    // created_at 날짜 포맷 (앞 10자리만)
    final date = likedAt.length >= 10 ? likedAt.substring(0, 10) : likedAt;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(profileImage),
      ),
      title: Text(
        nickname,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Text(
        '$nationality • $age세  |  $date',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: GestureDetector(
        onTap: () => _confirmUnlike(context),
        child: const Icon(Icons.favorite, color: Colors.pink, size: 26),
      ),
    );
  }

  void _confirmUnlike(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('좋아요 취소'),
        content: const Text('이 메이트의 좋아요를 취소할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('아니요'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onUnlike();
            },
            child: const Text('취소하기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// 공고 제안 카드
// ─────────────────────────────────────────
class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final Map<String, dynamic> request;

  const _OfferCard({required this.offer, required this.request});

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return '수락됨 ✅';
      case 'rejected':
        return '거절됨 ❌';
      default:
        return '대기 중 ⏳';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = offer['status'] ?? 'pending';
    final price = offer['price'] ?? 0;
    final message = offer['message'] ?? '';
    final meetingDate = offer['meeting_date'] ?? '-';
    final meetingTime = offer['meeting_time'] ?? '-';
    final requestTitle = request['title'] ?? '공고 정보 없음';
    final createdAt = (offer['created_at'] ?? '').toString();
    final date = createdAt.length >= 10
        ? createdAt.substring(0, 10)
        : createdAt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(blurRadius: 6, color: Colors.black12, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 공고 제목 + 상태 뱃지
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  requestTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _statusColor(status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // 제안 내용
          _infoRow(Icons.attach_money, '제안 금액', '${price.toString()}원'),
          const SizedBox(height: 6),
          _infoRow(
            Icons.calendar_today_outlined,
            '희망 날짜',
            '$meetingDate $meetingTime',
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoRow(Icons.message_outlined, '메시지', message),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              '제안일: $date',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.grey),
        const SizedBox(width: 6),
        Text(
          '$label  ',
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
