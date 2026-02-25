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
        .order('created_at', ascending: true);
  }

  // 🎯 3. 메시지 보내기
  Future<void> sendMessage(
    String roomId,
    String senderId,
    String content,
  ) async {
    try {
      await _supabase.from('messages').insert({
        'room_id': roomId,
        'sender_id': senderId,
        'content': content,
      });
    } catch (e) {
      debugPrint('메시지 전송 실패: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getChatRoomsStream() {
    return _supabase
        .from('my_chat_rooms')
        .stream(primaryKey: ['id'])
        // 💡 updated_at 대신 데이터가 확실히 있는 created_at으로 정렬!
        .order('created_at', ascending: false);
  }
}
