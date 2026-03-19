import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TourService {
  final SupabaseClient _supabase = Supabase.instance.client;
  String? get _myId => _supabase.auth.currentUser?.id;

  /// 🏆 1. [여행자용] 투어 완료 및 리뷰 등록
  Future<void> completeByTraveler({
    required String requestId,
    required String userScheduleId,
    required String guideScheduleId,
    required String guideId,
    required int rating,
    required String comment,
  }) async {
    try {
      // 리뷰 먼저 저장 (가이드에게는 아직 안 보임 - status로 제어 가능)
      await _supabase.from('guide_reviews').insert({
        'guide_id': guideId,
        'writer_id': _myId,
        'request_id': requestId,
        'rating': rating,
        'comment': comment,
      });

      // 내 스케줄은 완료로, 가이드 스케줄은 '완료대기'로 변경
      await _supabase
          .from('user_schedules')
          .update({'status': 'completed'})
          .eq('id', userScheduleId);
      await _supabase
          .from('guide_schedules')
          .update({'status': 'performing_completion'})
          .eq('id', guideScheduleId);

      debugPrint("✅ 여행자 완료 처리 성공 (가이드 승인 대기)");
    } catch (e) {
      rethrow;
    }
  }

  /// 🏆 2. [가이드용] 최종 종료 확인 (이때 평점 업데이트)
  /// 🏆 [가이드용] 최종 종료 확인 및 별점 반영
  Future<void> confirmByGuide({
    required String guideId,
    required String guideScheduleId,
    required String requestId,
  }) async {
    if (_myId == null) throw Exception("로그인이 필요합니다.");

    try {
      // 1. 해당 투어의 여행자 리뷰 가져오기
      final reviewRes = await _supabase
          .from('guide_reviews')
          .select('rating')
          .eq('request_id', requestId)
          .maybeSingle();

      if (reviewRes == null) {
        throw Exception("여행자의 완료 확정이 아직 처리되지 않았습니다.");
      }

      int newRating = reviewRes['rating'];

      // 2. 가이드 현재 정보 가져오기
      final guideRes = await _supabase
          .from('guides')
          .select('rating_avg, review_count, guide_count')
          .eq('id', guideId)
          .single();

      int currentReviewCount = guideRes['review_count'] ?? 0;
      double currentAvg = (guideRes['rating_avg'] ?? 5.0).toDouble();

      // 3. 새 평균 계산 (기존총점 + 새점수) / 새리뷰수
      int nextReviewCount = currentReviewCount + 1;
      double nextAvg =
          ((currentAvg * currentReviewCount) + newRating) / nextReviewCount;

      // 4. 가이드 테이블 업데이트 (소수점 2자리)
      await _supabase
          .from('guides')
          .update({
            'rating_avg': double.parse(nextAvg.toStringAsFixed(2)),
            'review_count': nextReviewCount,
            'guide_count': (guideRes['guide_count'] ?? 0) + 1,
          })
          .eq('id', guideId);

      // 5. 가이드 일정 상태 최종 완료로 변경
      await _supabase
          .from('guide_schedules')
          .update({'status': 'completed'})
          .eq('id', guideScheduleId);

      debugPrint("🎊 가이드 최종 확인 및 별점 반영 완료!");
    } catch (e) {
      debugPrint("❌ 가이드 확인 실패: $e");
      rethrow;
    }
  }

  /// ❌ 2. 일정 및 공고 취소 (어제 만든 로직 이사)
  Future<void> cancelTour({
    required String requestId,
    required String userScheduleId,
    required String guideScheduleId,
    required String chatRoomId,
    required String cancelledByRole,
    String? reason,
  }) async {
    if (_myId == null) throw Exception("로그인이 필요합니다.");

    try {
      // 상황별 공고 처리 (여행자 취소 -> 삭제, 가이드 취소 -> 복구)
      if (cancelledByRole == 'traveler') {
        await _supabase.from('travel_requests').delete().eq('id', requestId);
      } else {
        await _supabase
            .from('travel_requests')
            .update({'status': 'searching'})
            .eq('id', requestId);
      }

      // 제안 상태 -> 취소(cancelled)
      await _supabase
          .from('offers')
          .update({'status': 'cancelled'})
          .eq('request_id', requestId)
          .eq('status', 'accepted');

      // 일정 삭제 (또는 상태변경)
      await _supabase.from('user_schedules').delete().eq('id', userScheduleId);
      await _supabase
          .from('guide_schedules')
          .delete()
          .eq('id', guideScheduleId);

      // 채팅방 상단바 초기화
      await _supabase
          .from('chat_rooms')
          .update({
            'schedule_status': 'none',
            'meeting_date': null,
            'meeting_time': null,
            'last_message': '🚫 투어가 취소되었습니다: $reason',
            'last_message_at': DateTime.now().toIso8601String(),
          })
          .eq('id', chatRoomId);

      // 취소 이력 저장
      await _supabase.from('schedule_cancellations').insert({
        'user_schedule_id': userScheduleId,
        'guide_schedule_id': guideScheduleId,
        'cancelled_by': _myId,
        'cancelled_by_role': cancelledByRole,
        'reason': reason,
      });

      debugPrint("✅ 투어 취소 처리 성공");
    } catch (e) {
      debugPrint("❌ 투어 취소 실패: $e");
      rethrow;
    }
  }

  /// ❌ 일정 취소
  /// ❌ 일정 취소 (상황별 분기: 여행자 취소 -> 삭제, 가이드 취소 -> 공고 복구)
  Future<void> cancelSchedule({
    required String requestId,
    required String userScheduleId,
    required String guideScheduleId,
    required String chatRoomId,
    required String cancelledByRole, // 'traveler' 또는 'guide'
    String? reason,
  }) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) throw Exception("로그인이 필요합니다.");

    try {
      // ✅ [추가] 관심 목록(offers)의 상태도 cancelled로 변경!
      // 그래야 '내 제안 공고' 탭에서 '취소됨'으로 뜹니다.
      await _supabase
          .from('offers')
          .update({'status': 'cancelled'})
          .eq('request_id', requestId)
          .eq('guide_id', myId); // 내가 보낸 제안만 취소

      // 1. [공고 처리] 누가 취소했느냐에 따라 다르게!
      if (cancelledByRole == 'traveler') {
        // 여행자가 취소 -> 공고를 아예 삭제 (이 여행은 끝!)
        await _supabase.from('travel_requests').delete().eq('id', requestId);
      } else {
        // 가이드가 취소 -> 공고를 다시 'searching'으로 복구 (다른 가이드 찾기)
        await _supabase
            .from('travel_requests')
            .update({'status': 'searching'})
            .eq('id', requestId);
      }

      // 2. [일정 삭제] 이건 양쪽 다 공통으로 스케줄에서 지워버립니다.
      await _supabase.from('user_schedules').delete().eq('id', userScheduleId);
      await _supabase
          .from('guide_schedules')
          .delete()
          .eq('id', guideScheduleId);

      // 3. [채팅방 업데이트] 상태 초기화 및 마지막 메시지 기록
      String roleName = cancelledByRole == 'traveler' ? "여행자" : "가이드";
      await _supabase
          .from('chat_rooms')
          .update({
            'schedule_status': 'none',
            'meeting_date': null,
            'meeting_time': null,
            'last_message': '🚫 $roleName가 일정을 취소했습니다: $reason',
            'last_message_at': DateTime.now().toIso8601String(),
          })
          .eq('id', chatRoomId);

      // 4. [취소 이력 저장] 나중에 분쟁 해결용 기록
      await _supabase.from('schedule_cancellations').insert({
        'user_schedule_id': userScheduleId,
        'guide_schedule_id': guideScheduleId,
        'cancelled_by': myId,
        'cancelled_by_role': cancelledByRole,
        'reason': reason,
      });

      debugPrint("✅ $roleName에 의한 취소 처리 완료");
    } catch (e) {
      debugPrint("❌ 취소 처리 실패: $e");
      rethrow;
    }
  }
}
