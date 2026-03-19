import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:localmate/services/chat_service.dart';

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

      final viewedUsers = await _supabase
          .from('likes')
          .select('to_user_id')
          .eq('from_user_id', myId);

      List<String> excludeIds = [myId];
      excludeIds.addAll(
        List<String>.from(viewedUsers.map((l) => l['to_user_id'].toString())),
      );

      var query = _supabase
          .from('users')
          .select('*, guides!inner(*)')
          .eq('guide_status', 'approved')
          .not('id', 'in', excludeIds);

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

  /// ✅ 제안 수락
  Future<String?> acceptOffer({
    required String requestId,
    required String guideId,
    required String offerId,
  }) async {
    try {
      final myId = _supabase.auth.currentUser!.id;

      final requestData = await _supabase
          .from('travel_requests')
          .select('title, travel_at, location_name')
          .eq('id', requestId)
          .single();

      final guideData = await _supabase
          .from('users')
          .select('nickname')
          .eq('id', guideId)
          .single();
      final myData = await _supabase
          .from('users')
          .select('nickname')
          .eq('id', myId)
          .single();

      final DateTime dt = DateTime.parse(
        requestData['travel_at'].toString(),
      ).toLocal();
      final dateStr =
          "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      final timeStr =
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

      final existingRoom = await _supabase
          .from('chat_rooms')
          .select('id')
          .or(
            'and(participant_a.eq.$myId,participant_b.eq.$guideId),and(participant_a.eq.$guideId,participant_b.eq.$myId)',
          )
          .maybeSingle();

      String roomId;

      if (existingRoom != null) {
        roomId = existingRoom['id'];
        await _supabase
            .from('chat_rooms')
            .update({
              'request_id': requestId,
              'schedule_status': 'confirmed',
              'meeting_date': dateStr,
              'meeting_time': timeStr,
              'last_message': '여행 매칭이 확정되었습니다.',
              'last_message_at': DateTime.now().toIso8601String(),
            })
            .eq('id', roomId);
      } else {
        final newRoom = await _supabase
            .from('chat_rooms')
            .insert({
              'participant_a': myId,
              'participant_b': guideId,
              'request_id': requestId,
              'schedule_status': 'confirmed',
              'meeting_date': dateStr,
              'meeting_time': timeStr,
              'last_message': '매칭 완료! 즐거운 여행 되세요.',
              'last_message_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
        roomId = newRoom['id'];
      }

      await _supabase
          .from('travel_requests')
          .update({'status': 'matched'})
          .eq('id', requestId);
      await _supabase
          .from('offers')
          .update({'status': 'accepted'})
          .eq('id', offerId);

      await _supabase.from('user_schedules').insert({
        'user_id': myId,
        'guide_id': guideId,
        'title': requestData['title'],
        'partner_name': guideData['nickname'],
        'trip_date': requestData['travel_at'],
        'status': 'confirmed',
      });

      await _supabase.from('guide_schedules').insert({
        'guide_id': guideId,
        'title': requestData['title'],
        'trip_date': requestData['travel_at'],
        'location': requestData['location_name'],
        'status': 'booked',
      });

      debugPrint("✅ 3개 테이블(Chat, UserSch, GuideSch) 동기화 완료!");
      return roomId;
    } catch (e) {
      debugPrint("❌ 수락 처리 실패: $e");
      return null;
    }
  }

  /// ✉️ 제안 보내기
  Future<String?> sendOffer({
    required String requestId,
    required int price,
    required String message,
  }) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return "로그인이 필요합니다.";

      final activeOffers = await _supabase
          .from('offers')
          .select('id')
          .eq('request_id', requestId)
          .neq('status', 'rejected');

      if (activeOffers.length >= 5) {
        return "이미 제안 슬롯이 가득 찬 공고입니다.";
      }

      await _supabase.from('offers').insert({
        'request_id': requestId,
        'guide_id': myId,
        'price': price,
        'message': message,
        'status': 'pending',
      });

      return null;
    } catch (e) {
      return "제안 전송 중 오류가 발생했습니다.";
    }
  }

  /// 📋 내 여행 공고 목록
  Future<List<Map<String, dynamic>>> fetchMyTravelRequests() async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return [];

      final data = await _supabase
          .from('travel_requests')
          .select('*, offers(status)')
          .eq('writer_id', myId)
          .eq('status', 'searching')
          .order('created_at', ascending: false);

      final processedData = data.map((req) {
        final offers = req['offers'] as List? ?? [];
        final activeCount = offers
            .where((o) => o['status'] != 'rejected')
            .length;
        return {...req, 'active_offers_count': activeCount};
      }).toList();

      return processedData;
    } catch (e) {
      debugPrint('❌ 내 공고 로드 실패: $e');
      return [];
    }
  }

  /// 📩 특정 공고 제안 목록
  Future<List<Map<String, dynamic>>> fetchOffersForRequest(
    String requestId,
  ) async {
    try {
      final data = await _supabase
          .from('offers')
          .select('''
            *,
            users:guide_id(
              id, nickname, profile_image, age, nationality,
              guides(*)
            )
          ''')
          .eq('request_id', requestId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ 제안 목록 로드 실패: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserRequests(String userId) async {
    final response = await _supabase
        .from('requests')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// ❌ 제안 거절
  Future<bool> rejectOffer(String offerId) async {
    try {
      await _supabase
          .from('offers')
          .update({'status': 'rejected'})
          .eq('id', offerId);
      debugPrint("🚫 제안 거절 완료: $offerId");
      return true;
    } catch (e) {
      debugPrint("❌ 제안 거절 실패: $e");
      return false;
    }
  }

  /// 📋 가이드용 여행 공고 리스트
  Future<List<Map<String, dynamic>>> fetchTravelRequests({
    int limit = 20,
  }) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return [];

      var query = _supabase
          .from('travel_requests')
          .select('''
            *,
            users!inner(nickname, profile_image, nationality, fcm_token),
            offers(status, guide_id)
          ''')
          .eq('status', 'searching')
          .neq('writer_id', myId);

      final data = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final processedData = data
          .where((req) {
            final List offers = req['offers'] as List? ?? [];
            final bool isRejectedByMe = offers.any(
              (o) => o['guide_id'] == myId && o['status'] == 'rejected',
            );
            return !isRejectedByMe;
          })
          .map((req) {
            final List offers = req['offers'] as List? ?? [];
            final bool isApplied = offers.any((o) => o['guide_id'] == myId);
            return {...req, 'is_applied': isApplied};
          })
          .toList();

      return List<Map<String, dynamic>>.from(processedData);
    } catch (e) {
      debugPrint('❌ 공고 로드 실패: $e');
      return [];
    }
  }

  /// 💬 채팅 목록용 매칭 방 목록
  Future<List<Map<String, dynamic>>> fetchMatches() async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return [];

      final data = await _supabase
          .from('chat_rooms')
          .select('''
            *,
            participant_a_user:participant_a(id, nickname, profile_image),
            participant_b_user:participant_b(id, nickname, profile_image)
          ''')
          .or('participant_a.eq.$myId,participant_b.eq.$myId')
          .order('last_message_at', ascending: false);

      final processedData = data.map((room) {
        final bool isA = room['participant_a'] == myId;
        final targetUser = isA
            ? room['participant_b_user']
            : room['participant_a_user'];
        return {...room, 'target_user': targetUser};
      }).toList();

      return List<Map<String, dynamic>>.from(processedData);
    } catch (e) {
      debugPrint('❌ fetchMatches 에러: $e');
      return [];
    }
  }
}
