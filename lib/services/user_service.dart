import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  /// 🛠 가이드 신청 (프로필 이미지 + 인증 이미지 업로드)
  Future<void> submitGuideRegistration({
    required File profileImage,
    File? certImage,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("로그인이 필요합니다.");

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final profilePath = '${user.id}/guide_profile_$timestamp.webp';

    await _supabase.storage
        .from('verifications')
        .upload(
          profilePath,
          profileImage,
          fileOptions: const FileOptions(upsert: true),
        );

    String? certPath;
    if (certImage != null) {
      certPath = '${user.id}/guide_cert_$timestamp.webp';
      await _supabase.storage
          .from('verifications')
          .upload(
            certPath,
            certImage,
            fileOptions: const FileOptions(upsert: true),
          );
    }

    await _supabase
        .from('users')
        .update({
          'guide_status': 'pending',
          'guide_profile_image': profilePath,
          'guide_certification_image': certPath,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('auth_uid', user.id);
  }

  /// ✈️ 여행 공고 생성
  Future<void> createTravelRequest({
    required String title,
    required String locationName,
    required DateTime travelAt,
    required String companionType,
    String? content,
    int headcount = 1,
    int? budget,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("로그인이 필요합니다.");

    final userData = await _supabase
        .from('users')
        .select('id')
        .eq('auth_uid', user.id)
        .single();

    final String writerInternalId = userData['id'];

    await _supabase.from('travel_requests').insert({
      'writer_id': writerInternalId,
      'title': title,
      'location_name': locationName,
      'travel_at': travelAt.toIso8601String(),
      'companion_type': companionType,
      'content': content,
      'headcount': headcount,
      'budget': budget,
      'status': 'searching',
    });
  }

  /// 🔄 마지막 모드 업데이트 (traveler / guide)
  Future<void> updateLastMode(String mode) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('users')
        .update({'last_mode': mode})
        .eq('auth_uid', user.id);
  }
}
