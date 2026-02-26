import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiscoverService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchMates({int limit = 10}) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return [];

      final Set<String> excludeIds = {myId};

      // 내가 이미 좋아요 누른 사람 제외
      try {
        final likes = await _supabase
            .from('likes')
            .select('to_user_id')
            .eq('from_user_id', myId);
        for (var l in likes) {
          excludeIds.add(l['to_user_id'].toString());
        }
      } catch (_) {}

      final List<String> excludeList = excludeIds.toList();
      final excludeStr = '(${excludeList.join(',')})';

      final data = await _supabase
          .from('users')
          .select()
          .not('id', 'in', excludeStr)
          .limit(limit);

      debugPrint('🔥 [결과] 불러온 유저 수: ${data.length}');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ 최종 로드 실패: $e');
      return [];
    }
  }

  // ✅ 실제 likes 테이블에 저장
  Future<bool> sendLike(String targetUserId) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return false;

      await _supabase.from('likes').insert({
        'from_user_id': myId,
        'to_user_id': targetUserId,
      });

      debugPrint('❤️ $targetUserId 님에게 좋아요 저장 완료!');
      return true;
    } catch (e) {
      debugPrint('Like 에러: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMatches() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('로그인된 유저가 없습니다.');
      return [];
    }

    final myId = user.id;
    try {
      final myLikesData = await _supabase
          .from('likes')
          .select('to_user_id')
          .eq('from_user_id', myId);

      final List<String> myLikedIds = List<String>.from(
        myLikesData.map((l) => l['to_user_id'].toString()),
      );

      if (myLikedIds.isEmpty) return [];

      final mutualLikesData = await _supabase
          .from('likes')
          .select('from_user_id')
          .eq('to_user_id', myId)
          .inFilter('from_user_id', myLikedIds);

      final List<String> mutualIds = List<String>.from(
        mutualLikesData.map((l) => l['from_user_id'].toString()),
      );

      if (mutualIds.isEmpty) return [];

      final usersData = await _supabase
          .from('users')
          .select()
          .inFilter('id', mutualIds);

      return List<Map<String, dynamic>>.from(usersData);
    } catch (e) {
      print('Match 로드 실패: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchGuideProfile(String userId) async {
    try {
      final data = await _supabase
          .from('users')
          .select('*, guides(*)')
          .eq('id', userId)
          .maybeSingle();

      return data;
    } catch (e) {
      debugPrint('가이드 데이터 JOIN 로드 실패: $e');
      return null;
    }
  }

  Future<void> updateGuideStats(String guideId, double newRating) async {
    try {
      await _supabase
          .from('guides')
          .update({'guide_count': 1, 'rating_avg': newRating})
          .eq('id', guideId);
    } catch (e) {
      debugPrint('가이드 스탯 업데이트 실패: $e');
    }
  }
}
