import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LikeListPage extends StatelessWidget {
  const LikeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser!.id;

    return StreamBuilder<List<Map<String, dynamic>>>(
      // 💡 아까 만든 View를 구독합니다.
      stream: Supabase.instance.client
          .from('users_who_liked_me')
          .stream(primaryKey: ['from_user_id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final likers = snapshot.data!;
        if (likers.isEmpty)
          return const Center(child: Text("아직 나를 좋아요 누른 사람이 없어요."));

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2열로 예쁘게 배치
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: likers.length,
          itemBuilder: (context, index) {
            final user = likers[index];
            return _buildLikerCard(user);
          },
        );
      },
    );
  }

  Widget _buildLikerCard(Map<String, dynamic> user) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        image: DecorationImage(
          image: NetworkImage(user['profile_image'][0]),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
          ),
        ),
        padding: const EdgeInsets.all(12),
        alignment: Alignment.bottomLeft,
        child: Text(
          user['nickname'] ?? '비공개',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
