import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiscoverService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// 🔍 [모드 공통] 데이터 불러오기
  Future<List<Map<String, dynamic>>> fetchMates({
    required bool isTravelerMode,
    int limit = 10,
  }) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return [];

      // 1. 제외할 ID 목록 (나 + 이미 스와이프한 사람)
      final viewedUsers = await _supabase
          .from('likes')
          .select('to_user_id')
          .eq('from_user_id', myId);

      List<String> excludeIds = [myId];
      excludeIds.addAll(
        List<String>.from(viewedUsers.map((l) => l['to_user_id'].toString())),
      );

      // 2. 쿼리 실행
      // 여행자 모드일 때는 반드시 가이드 정보(!inner)가 있고, 승인된(approved) 사람만 가져옴
      var query = _supabase
          .from('users')
          .select('*, guides!inner(*)') // 가이드 테이블에 데이터가 있는 유저만
          .eq('guide_status', 'approved') // 승인된 가이드만 필터링
          .not('id', 'in', excludeIds); // 나를 포함한 제외 목록 거르기

      final data = await query.limit(limit);

      debugPrint('📊 [결과] 승인된 가이드 수: ${data.length}명');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ fetchMates 에러: $e');
      return [];
    }
  }

  /// ❤️ 좋아요 저장
  Future<bool> sendLike(String targetUserId) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return false;
      await _supabase.from('likes').insert({
        'from_user_id': myId,
        'to_user_id': targetUserId,
      });
      return true;
    } catch (e) {
      debugPrint('Like 에러: $e');
      return false;
    }
  }

  /// ✅ ChatListPage용 매치 목록 (에러 방지용으로 유지)
  Future<List<Map<String, dynamic>>> fetchMatches() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];
    try {
      final myLikes = await _supabase
          .from('likes')
          .select('to_user_id')
          .eq('from_user_id', user.id);
      final List<String> myLikedIds = List<String>.from(
        myLikes.map((l) => l['to_user_id'].toString()),
      );
      if (myLikedIds.isEmpty) return [];
      final mutualLikes = await _supabase
          .from('likes')
          .select('from_user_id')
          .eq('to_user_id', user.id)
          .inFilter('from_user_id', myLikedIds);
      final List<String> mutualIds = List<String>.from(
        mutualLikes.map((l) => l['from_user_id'].toString()),
      );
      if (mutualIds.isEmpty) return [];
      return List<Map<String, dynamic>>.from(
        await _supabase.from('users').select().inFilter('id', mutualIds),
      );
    } catch (e) {
      return [];
    }
  }

  /// 📋 [가이드 모드용] 여행 공고 리스트 가져오기
  Future<List<Map<String, dynamic>>> fetchTravelRequests({
    int limit = 20,
  }) async {
    try {
      final myId = _supabase.auth.currentUser?.id;

      // 1. 로그인 체크 (강력하게)
      if (myId == null) {
        debugPrint('⚠️ 로그인이 필요합니다.');
        return [];
      }

      // 2. 쿼리 실행
      final data = await _supabase
          .from('travel_requests')
          .select('*, users!inner(nickname, profile_image, nationality)')
          .eq('status', 'searching')
          .neq('writer_id', myId) // ✅ 이제 myId가 null이 아님이 보장됨
          .order('travel_at', ascending: true)
          .limit(limit);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ 공고 로드 실패: $e');
      return [];
    }
  }

  /// ✉️ [가이드 전용] 여행 공고에 제안 보내기
  /// ✉️ [가이드 전용] 제안 보내기 (최대 5건 제한 추가)
  Future<String?> sendOffer({
    required String requestId,
    required int price,
    required String message,
  }) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return "로그인이 필요합니다.";

      // 1. 현재 공고에 달린 제안 개수 확인
      final countResponse = await _supabase
          .from('offers')
          .select('id') // 특정 컬럼만 선택
          .eq('request_id', requestId);

      final currentCount = countResponse.length;

      // 2. 5건 이상이면 차단
      if (currentCount >= 5) {
        return "이미 5건의 제안이 완료된 공고입니다.";
      }

      // 3. 제안 저장
      await _supabase.from('offers').insert({
        'request_id': requestId,
        'guide_id': myId,
        'price': price,
        'message': message,
      });

      return null; // 성공 시 null 반환
    } catch (e) {
      return "제안 전송 중 오류가 발생했습니다.";
    }
  }

  /// 📋 [여행자 전용] 내가 등록한 여행 공고 목록 가져오기
  Future<List<Map<String, dynamic>>> fetchMyTravelRequests() async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return [];

      final data = await _supabase
          .from('travel_requests')
          .select('*, offers(count)') // 공고 데이터 + 제안 개수 카운트
          .eq('writer_id', myId)
          // 매칭 수락 시 status가 'completed'로 변했다면 이 목록에서 자동으로 제외됩니다.
          .eq('status', 'searching')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ 내 공고 로드 실패: $e');
      return [];
    }
  }

  /// 📩 [여행자 전용] 특정 공고에 들어온 가이드 제안 목록 가져오기
  Future<List<Map<String, dynamic>>> fetchOffersForRequest(
    String requestId,
  ) async {
    try {
      final data = await _supabase
          .from('offers')
          .select(
            '*, users:guide_id(nickname, profile_image, age, nationality)',
          ) // 가이드 정보 조인
          .eq('request_id', requestId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ 제안 목록 로드 실패: $e');
      return [];
    }
  }

  // discover_service.dart
  Future<List<Map<String, dynamic>>> fetchUserRequests(String userId) async {
    final response = await _supabase
        .from('requests')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
}
