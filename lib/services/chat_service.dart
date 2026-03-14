import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 🎯 1. 채팅방 가져오기 또는 새로 만들기
  Future<String> getOrCreateRoom(String myId, String targetId) async {
    try {
      // 이미 방이 있는지 확인
      final existingRoom = await _supabase
          .from('chat_rooms')
          .select()
          .or(
            'and(participant_a.eq.$myId,participant_b.eq.$targetId),and(participant_a.eq.$targetId,participant_b.eq.$myId)',
          )
          .maybeSingle();

      if (existingRoom != null) {
        return existingRoom['id'];
      }

      // 없으면 새로 생성
      final newRoom = await _supabase
          .from('chat_rooms')
          .insert({'participant_a': myId, 'participant_b': targetId})
          .select()
          .single();

      return newRoom['id'];
    } catch (e) {
      debugPrint('채팅방 생성 에러: $e');
      rethrow;
    }
  }

  // 🎯 2. 실시간 메시지 스트림 (Stream)
  Stream<List<Map<String, dynamic>>> getMessageStream(String roomId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: false);
  }

  // 🎯 3. 메시지 보내기
  Future<void> sendMessage(
    String roomId,
    String senderId,
    String content,
  ) async {
    // 1. 메시지 DB 저장 (기존 로직)
    await _supabase.from('messages').insert({
      'room_id': roomId,
      'sender_id': senderId,
      'content': content,
    });

    // 2. 상대방 정보 및 방 상태 조회
    // (상대방 fcm_token과 현재 방에 들어와 있는지 active_users 확인)
    final roomData = await _supabase
        .from('chat_rooms')
        .select('active_users, participant_a, participant_b')
        .eq('id', roomId)
        .single();

    final myId = _supabase.auth.currentUser!.id;
    final String targetId = roomData['participant_a'] == myId
        ? roomData['participant_b']
        : roomData['participant_a'];

    final List activeUsers = roomData['active_users'] ?? [];

    // 3. 상대방이 방에 없으면(채팅창 안 보고 있으면) 푸시 발송!
    if (!activeUsers.contains(targetId)) {
      // 상대방의 fcm_token 가져오기
      final targetUser = await _supabase
          .from('users')
          .select('fcm_token, nickname')
          .eq('id', targetId)
          .single();

      if (targetUser['fcm_token'] != null) {
        await _supabase.functions.invoke(
          'send-push',
          body: {
            'targetType': 'token',
            'targetValue': targetUser['fcm_token'],
            'title':
                '${_supabase.auth.currentUser!.userMetadata?['nickname'] ?? "메이트"}',
            'body': content, // 메시지 내용
            'data': {'type': 'chat', 'roomId': roomId},
          },
        );
        debugPrint("🚀 상대방이 부재중이라 푸시 발송 완료!");
      }
    } else {
      debugPrint("🤫 상대방이 채팅 중이라 푸시를 생략합니다.");
    }
  }

  Stream<List<Map<String, dynamic>>> getChatRoomsStream() {
    final myId = _supabase.auth.currentUser!.id;

    // 💡 포인트: 테이블 뒤에 .select('*, users!other_participant_id(nickname, profile_image)')
    // 형태로 조인하면 상대방 정보를 한 번에 긁어옵니다.
    return _supabase
        .from('my_chat_rooms')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((maps) => maps.map((map) => map as Map<String, dynamic>).toList());
  }

  // 타이핑 상태 업데이트
  Future<void> updateTypingStatus(
    String roomId,
    String userId,
    bool isTyping,
  ) async {
    if (isTyping) {
      await _supabase
          .from('chat_rooms')
          .update({
            'typing_users': _supabase.rpc(
              'array_append_unique',
              params: {
                'arr': 'typing_users', // 실제로는 RPC나 array_append 사용
                'val': userId,
              },
            ),
          })
          .eq('id', roomId);

      // 간단하게 하려면 아래처럼 처리 (PostgreSQL array_append 사용)
      await _supabase.rpc(
        'update_typing_presence',
        params: {'room_id': roomId, 'user_id': userId, 'is_typing': true},
      );
    } else {
      await _supabase.rpc(
        'update_typing_presence',
        params: {'room_id': roomId, 'user_id': userId, 'is_typing': false},
      );
    }
  }

  Future<void> sendImageMessage(
    String roomId,
    String senderId,
    String imageUrl,
  ) async {
    // 1. [여기에 결제 재화 체크/차감 로직이 들어갈 자리]
    // 예: if (userPoints < 10) throw Error("포인트가 부족합니다.");

    // 2. 메시지 저장 (type을 image로!)
    await _supabase.from('messages').insert({
      'room_id': roomId,
      'sender_id': senderId,
      'content': '사진을 보냈습니다.', // 목록 미리보기용 텍스트
      'message_type': 'image',
      'image_url': imageUrl,
    });

    // 3. 기존 스마트 푸시 로직 동일하게 수행 (body를 "사진을 보냈습니다"로)
    // ... (기존 sendMessage의 푸시 로직 호출)
  }
}
