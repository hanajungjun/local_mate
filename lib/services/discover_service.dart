import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiscoverService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // lib/services/discover_service.dart 내 수정

  Future<List<Map<String, dynamic>>> fetchMates({int limit = 10}) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return [];

      // 1. 내가 좋아요를 눌렀거나 나를 누른 모든 '좋아요' 관련 ID 추출
      final likesData = await _supabase
          .from('likes')
          .select('from_user_id, to_user_id')
          .or('from_user_id.eq.$myId,to_user_id.eq.$myId');

      // 관련 있는 모든 ID를 하나의 Set으로 모음
      final Set<String> excludeIds = {myId}; // 나 자신은 당연히 제외
      for (var like in likesData) {
        excludeIds.add(like['from_user_id']);
        excludeIds.add(like['to_user_id']);
      }

      // 2. 이미 채팅방이 존재하는 유저 ID 추출
      final roomsData = await _supabase
          .from('chat_rooms')
          .select('participant_a, participant_b')
          .or('participant_a.eq.$myId,participant_b.eq.$myId');

      for (var room in roomsData) {
        excludeIds.add(room['participant_a']);
        excludeIds.add(room['participant_b']);
      }

      // 3. 필터링된 유저 리스트 가져오기
      // excludeIds에 포함되지 않은 유저만 가져옵니다.
      final data = await _supabase
          .from('users')
          .select()
          .not('id', 'in', '(${excludeIds.join(',')})') // 이 문법이 핵심!
          .limit(limit);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('유저 필터링 로드 실패: $e');
      return [];
    }
  }

  // 좋아요 전송 (이름표 없이 String 값만 받도록 수정 완료!)
  Future<bool> sendLike(String targetUserId) async {
    try {
      // 지금은 로그만 찍지만, 나중에 여기에 likes 테이블 저장 로직이 들어갑니다.
      print('DEBUG: $targetUserId 님에게 좋아요를 보냈습니다!');
      return true;
    } catch (e) {
      print('Like 에러: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMatches() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('로그인된 유저가 없습니다.');
      return []; // 로그인 안 됐으면 빈 목록 반환해서 에러 방지
    }

    final myId = user.id;
    try {
      // 1. 내가 좋아요 누른 사람들(to_user_id) 목록 가져오기
      final myLikesData = await _supabase
          .from('likes')
          .select('to_user_id')
          .eq('from_user_id', myId);

      final List<String> myLikedIds = List<String>.from(
        myLikesData.map((l) => l['to_user_id'].toString()),
      );

      if (myLikedIds.isEmpty) return [];

      // 2. 그 사람들 중에서 나를 좋아요 누른 사람들(서로 좋아요) 찾아내기
      // 'in_' 대신 'inFilter'를 사용합니다.
      final mutualLikesData = await _supabase
          .from('likes')
          .select('from_user_id')
          .eq('to_user_id', myId)
          .inFilter('from_user_id', myLikedIds); // 👈 여기서 에러 해결!

      final List<String> mutualIds = List<String>.from(
        mutualLikesData.map((l) => l['from_user_id'].toString()),
      );

      if (mutualIds.isEmpty) return [];

      // 3. 최종적으로 서로 좋아요한 사람들의 유저 정보 가져오기
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

  // 🎯 가이드 정보를 포함한 유저 상세 정보 가져오기
  Future<Map<String, dynamic>?> fetchGuideProfile(String userId) async {
    try {
      // 'users' 테이블을 조회하면서 연결된 'guides' 테이블 데이터도 같이 긁어옵니다.
      // SQL의 JOIN과 같은 역할이에요.
      final data = await _supabase
          .from('users')
          .select('*, guides(*)') // 유저 정보 전체 + 가이드 정보 전체
          .eq('id', userId)
          .maybeSingle(); // 데이터가 없어도 에러 대신 null 반환

      return data;
    } catch (e) {
      debugPrint('가이드 데이터 JOIN 로드 실패: $e');
      return null;
    }
  }

  // 🎯 가이드 횟수나 점수 업데이트 (가이드 활동 완료 시 사용)
  Future<void> updateGuideStats(String guideId, double newRating) async {
    try {
      // 기존 점수 계산 로직은 나중에 짜더라도, 일단 구조만 잡아둡니다.
      await _supabase
          .from('guides')
          .update({
            'guide_count': 1, // 실제로는 기존값 + 1 해야함
            'rating_avg': newRating,
          })
          .eq('id', guideId);
    } catch (e) {
      debugPrint('가이드 스탯 업데이트 실패: $e');
    }
  }
}
