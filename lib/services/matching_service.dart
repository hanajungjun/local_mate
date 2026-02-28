import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MatchingService {
  final _supabase = Supabase.instance.client;

  /// 🤝 가이드 제안 최종 수락 (종합 선물 세트)
  Future<bool> acceptGuideOffer({
    required String offerId,
    required String requestId,
    required String guideId,
    required String title,
  }) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return false;

      // 1. 해당 제안 수락 상태로 변경
      await _supabase
          .from('offers')
          .update({'status': 'accepted'})
          .eq('id', offerId);

      // 2. 해당 공고의 다른 모든 제안들을 자동으로 'rejected' 변경
      await _supabase
          .from('offers')
          .update({'status': 'rejected'})
          .eq('request_id', requestId)
          .neq('id', offerId); // 지금 수락한 거 제외하고 전부

      // 3. 공고 상태를 'completed'로 변경
      await _supabase
          .from('travel_requests')
          .update({'status': 'completed'})
          .eq('id', requestId);

      // 4. 여행 일정 생성 (가이드 유저 ID를 직접 저장)
      await _supabase.from('user_schedules').insert({
        'user_id': myId,
        'guide_id': guideId, // SQL 수정 후 컬럼명
        'title': title,
        'trip_date': DateTime.now().toIso8601String(),
        'status': 'confirmed',
      });

      // 5. 채팅방(Rooms) 생성 또는 기존 방 가져오기
      // 가이드와 여행자 사이의 고유한 채팅방을 만듭니다.
      await _createChatRoom(myId, guideId, title);

      return true;
    } catch (e) {
      debugPrint('❌ 매칭 수락 중 오류 발생: $e');
      return false;
    }
  }

  /// 💬 채팅방 생성 로직
  Future<void> _createChatRoom(
    String userId,
    String guideId,
    String title,
  ) async {
    try {
      // 1. 중복 생성을 막기 위해 두 ID를 정렬합니다. (Unique 제약 조건 대응)
      final participants = [userId, guideId]..sort();
      final pA = participants[0];
      final pB = participants[1];

      // 2. chat_rooms 테이블에 삽입 (upsert를 쓰면 이미 있을 때 에러 안 남)
      // 이 테이블에는 last_message 컬럼이 없으므로 participant 정보만 넣습니다.
      await _supabase.from('chat_rooms').upsert({
        'participant_a': pA,
        'participant_b': pB,
      }, onConflict: 'participant_a, participant_b');

      debugPrint('✅ 채팅방 생성 또는 확인 완료: $pA - $pB');
    } catch (e) {
      debugPrint('❌ 채팅방 생성 실패: $e');
    }
  }
}
