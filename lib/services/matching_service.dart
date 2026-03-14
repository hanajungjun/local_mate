import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MatchingService {
  final _supabase = Supabase.instance.client;

  /// 🤝 가이드 제안 최종 수락
  Future<String?> acceptGuideOffer({
    // ✅ 리턴 타입을 String? (방 ID)로 변경
    required String offerId,
    required String requestId,
    required String guideId,
    required String title,
  }) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return null;

      // 1~4번 로직 (offers 업데이트, 일정 생성 등)은 그대로 유지...
      await _supabase
          .from('offers')
          .update({'status': 'accepted'})
          .eq('id', offerId);
      await _supabase
          .from('offers')
          .update({'status': 'rejected'})
          .eq('request_id', requestId)
          .neq('id', offerId);
      await _supabase
          .from('travel_requests')
          .update({'status': 'completed'})
          .eq('id', requestId);
      await _supabase.from('user_schedules').insert({
        'user_id': myId,
        'guide_id': guideId,
        'title': title,
        'trip_date': DateTime.now().toIso8601String(),
        'status': 'confirmed',
      });

      // 5. 채팅방 생성 로직 호출 및 방 ID 받기
      final roomId = await _getOrCreateChatRoom(myId, guideId);

      return roomId; // ✅ 생성되거나 조회된 방 ID를 반환
    } catch (e) {
      debugPrint('❌ 매칭 수락 중 오류 발생: $e');
      return null;
    }
  }

  /// 💬 채팅방 생성 또는 기존 방 ID 가져오기 로직
  Future<String?> _getOrCreateChatRoom(String userId, String guideId) async {
    try {
      final participants = [userId, guideId]..sort();
      final pA = participants[0];
      final pB = participants[1];

      // 🔍 1. 먼저 이미 존재하는 방이 있는지 조회
      final existingRoom = await _supabase
          .from('chat_rooms')
          .select('id')
          .eq('participant_a', pA)
          .eq('participant_b', pB)
          .maybeSingle();

      if (existingRoom != null) {
        debugPrint('♻️ 기존 채팅방 발견: ${existingRoom['id']}');
        return existingRoom['id'].toString();
      }

      // ✨ 2. 방이 없으면 새로 생성
      final newRoom = await _supabase
          .from('chat_rooms')
          .insert({'participant_a': pA, 'participant_b': pB})
          .select()
          .single();

      debugPrint('✅ 새 채팅방 생성 완료: ${newRoom['id']}');
      return newRoom['id'].toString();
    } catch (e) {
      debugPrint('❌ 채팅방 처리 실패: $e');
      return null;
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
