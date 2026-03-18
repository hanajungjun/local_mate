import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. [내부 함수] 상대방 부재 시 푸시 알림 발송 로직 (중복 제거)
  Future<void> _sendPushIfInactive(String roomId, String content) async {
    try {
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

      // 상대방이 현재 채팅방을 보고 있지 않을 때만 푸시 발송
      if (!activeUsers.contains(targetId)) {
        final targetUser = await _supabase
            .from('users')
            .select('fcm_token')
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
              'body': content,
              'data': {'type': 'chat', 'roomId': roomId},
            },
          );
          debugPrint("🚀 푸시 알림 발송 완료");
        }
      }
    } catch (e) {
      debugPrint("⚠️ 푸시 발송 체크 중 오류 (무시 가능): $e");
    }
  }

  // 2. 채팅방 가져오기 또는 생성
  Future<String> getOrCreateRoom(
    String myId,
    String targetId, {
    String? requestId,
  }) async {
    try {
      var query = _supabase.from('chat_rooms').select('id');
      if (requestId != null) {
        query = query.eq('request_id', requestId);
      }

      final existingRoom = await query
          .or(
            'and(participant_a.eq.$myId,participant_b.eq.$targetId),and(participant_a.eq.$targetId,participant_b.eq.$myId)',
          )
          .maybeSingle();

      if (existingRoom != null) return existingRoom['id'];

      final newRoom = await _supabase
          .from('chat_rooms')
          .insert({
            'participant_a': myId,
            'participant_b': targetId,
            'request_id': requestId,
            'last_message': '대화를 시작해보세요!',
          })
          .select()
          .single();

      return newRoom['id'];
    } catch (e) {
      debugPrint("❌ 채팅방 생성 에러: $e");
      rethrow;
    }
  }

  // 3. 메시지 스트림
  Stream<List<Map<String, dynamic>>> getMessageStream(String roomId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: false);
  }

  // 4. 텍스트 메시지 전송
  Future<void> sendMessage(
    String roomId,
    String senderId,
    String content,
  ) async {
    // 메시지 저장
    await _supabase.from('messages').insert({
      'room_id': roomId,
      'sender_id': senderId,
      'content': content,
      'message_type': 'text',
      'is_read': false,
    });

    // 채팅방 목록 미리보기 업데이트
    await _supabase
        .from('chat_rooms')
        .update({
          'last_message': content,
          'last_message_at': DateTime.now().toIso8601String(),
        })
        .eq('id', roomId);

    // 푸시 알림 체크
    await _sendPushIfInactive(roomId, content);
  }

  // 5. 이미지 메시지 전송 (WebP 압축 포함)
  Future<void> sendImageMessage(
    String roomId,
    String senderId,
    dynamic imageFile,
  ) async {
    try {
      // WebP 변환 및 압축
      final Uint8List? compressedBytes =
          await FlutterImageCompress.compressWithFile(
            imageFile.path,
            minWidth: 1024,
            minHeight: 1024,
            quality: 80,
            format: CompressFormat.webp,
          );

      if (compressedBytes == null) return;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.webp';
      final path = 'chat/$roomId/$fileName';

      // Supabase Storage 업로드
      await _supabase.storage
          .from('chat')
          .uploadBinary(
            path,
            compressedBytes,
            fileOptions: const FileOptions(contentType: 'image/webp'),
          );

      final imageUrl = _supabase.storage.from('chat').getPublicUrl(path);
      const String pushContent = '📷 사진을 보냈습니다.';

      // 메시지 저장
      await _supabase.from('messages').insert({
        'room_id': roomId,
        'sender_id': senderId,
        'content': pushContent,
        'message_type': 'image',
        'image_url': imageUrl,
        'is_read': false,
      });

      // 채팅방 목록 업데이트
      await _supabase
          .from('chat_rooms')
          .update({
            'last_message': pushContent,
            'last_message_at': DateTime.now().toIso8601String(),
          })
          .eq('id', roomId);

      // 푸시 알림 체크
      await _sendPushIfInactive(roomId, pushContent);
    } catch (e) {
      debugPrint("❌ 이미지 전송 실패: $e");
    }
  }

  // 6. 채팅방 목록 스트림
  Stream<List<Map<String, dynamic>>> getChatRoomsStream() {
    return _supabase
        .from('my_chat_rooms')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((maps) => maps.map((map) => map as Map<String, dynamic>).toList());
  }

  // 7. 타이핑 및 퇴장 관련 함수들
  Future<void> updateTypingStatus(
    String roomId,
    String userId,
    bool isTyping,
  ) async {
    await _supabase.rpc(
      'update_typing_presence',
      params: {'room_id': roomId, 'user_id': userId, 'is_typing': isTyping},
    );
  }

  Future<void> leaveChatRoom(String roomId) async {
    final myId = _supabase.auth.currentUser!.id;
    await _supabase.rpc(
      'leave_chat_room',
      params: {'room_id': roomId, 'user_id': myId},
    );
  }

  Future<bool> isPartnerLeft(String roomId) async {
    final myId = _supabase.auth.currentUser!.id;
    final room = await _supabase
        .from('chat_rooms')
        .select('left_users, participant_a, participant_b')
        .eq('id', roomId)
        .single();
    final String partnerId = room['participant_a'] == myId
        ? room['participant_b']
        : room['participant_a'];
    final List leftUsers = room['left_users'] ?? [];
    return leftUsers.contains(partnerId);
  }

  Future<void> reportMessage({
    required String messageId,
    required String roomId,
    required String reason,
  }) async {
    final myId = _supabase.auth.currentUser!.id;
    await _supabase.from('reports').insert({
      'reporter_id': myId,
      'message_id': messageId,
      'room_id': roomId,
      'reason': reason,
    });
  }
}
