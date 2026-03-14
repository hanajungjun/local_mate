import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_match_detail_page.dart';

class LikeListPage extends StatefulWidget {
  const LikeListPage({super.key});

  @override
  State<LikeListPage> createState() => _LikeListPageState();
}

class _LikeListPageState extends State<LikeListPage> {
  final _supabase = Supabase.instance.client;

  // ✅ 사진 클릭 시 상세 페이지로 이동
  void _goToUserDetail(Map<String, dynamic> user) {
    // 뷰에서 넘어온 데이터 중 'from_user_id'를 실제 유저 'id'로 사용합니다.
    final Map<String, dynamic> userData = {...user, 'id': user['from_user_id']};

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserMatchDetailPage(user: userData),
      ),
    ).then((_) {
      // 상세 페이지에서 돌아왔을 때 목록을 새로고침하기 위해 setState 호출
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      // 1. 나를 좋아한 유저 목록 실시간 스트림
      stream: _supabase
          .from('users_who_liked_me')
          .stream(primaryKey: ['from_user_id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text("데이터 로딩 중 오류 발생"));
        }

        final rawLikers = snapshot.data ?? [];

        // 2. 내가 이미 좋아요를 누른(매칭된) 사람들을 제외하기 위한 FutureBuilder
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _supabase
              .from('likes')
              .select('to_user_id')
              .eq('from_user_id', myId),
          builder: (context, matchSnapshot) {
            if (matchSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // 내가 이미 좋아요를 보낸 대상자들의 ID Set
            final myLikesIds = (matchSnapshot.data ?? [])
                .map((item) => item['to_user_id'].toString())
                .toSet();

            // 3. 필터링: 나를 좋아한 사람 리스트 중, 내가 아직 좋아요를 안 보낸 사람만 남김
            final likers = rawLikers.where((user) {
              final String fromId = user['from_user_id'].toString();
              return !myLikesIds.contains(fromId);
            }).toList();

            if (likers.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border, size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "새로운 좋아요가 없습니다.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: likers.length,
              itemBuilder: (context, index) {
                final user = likers[index];
                return GestureDetector(
                  onTap: () => _goToUserDetail(user),
                  child: _buildLikerCard(user),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLikerCard(Map<String, dynamic> user) {
    String? imageUrl;
    if (user['profile_image'] != null &&
        user['profile_image'] is List &&
        (user['profile_image'] as List).isNotEmpty) {
      imageUrl = user['profile_image'][0];
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.grey[200],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 2,
          ),
        ],
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
          ),
        ),
        padding: const EdgeInsets.all(12),
        alignment: Alignment.bottomLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl == null)
              const Icon(Icons.person, color: Colors.white, size: 30),
            Text(
              user['nickname'] ?? '비공개',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (user['nationality'] != null)
              Text(
                user['nationality'],
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
