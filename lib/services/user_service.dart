import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class UserService {
  final _supabase = Supabase.instance.client;

  // ✅ 통합 프로필 가져오기 (가이드 상태 확인용)
  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final data = await _supabase
        .from('users')
        .select('*, guides(*)')
        .eq('auth_uid', user.id)
        .maybeSingle();

    return data;
  }

  /// 🛠 가이드 신청 실전 로직 (WebP 확장자 적용)
  Future<void> submitGuideRegistration({
    required File profileImage,
    File? certImage,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("로그인이 필요합니다.");

    // 1. Storage 업로드 (WebP 확장자로 경로 설정)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final profilePath = '${user.id}/guide_profile_$timestamp.webp'; // 확장자 변경

    await _supabase.storage
        .from('verifications')
        .upload(
          profilePath,
          profileImage,
          fileOptions: const FileOptions(upsert: true),
        );

    String? certPath;
    if (certImage != null) {
      certPath = '${user.id}/guide_cert_$timestamp.webp'; // 확장자 변경
      await _supabase.storage
          .from('verifications')
          .upload(
            certPath,
            certImage,
            fileOptions: const FileOptions(upsert: true),
          );
    }

    // 2. DB 업데이트
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

  // ✅ 통합 업데이트 로직 (Users + Guides)
  Future<void> updateProfile({
    // [Users 테이블용 - 기본 정보]
    required String nickname,
    required String bio,
    int? age,
    String? gender,
    String? nationality,
    String? mbti,
    List<String>? languages,
    List<String>? travelStyle,
    List<String>? interests,
    List<String>? profileImage,
    // [Guides 테이블용 - 가이드 정보]
    String? guideBio,
    String? locationName,
    String? residencePeriod,
    List<String>? specialties,
    Map<String, int>? languageLevels,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("세션이 만료되었습니다. 다시 로그인해주세요.");

    // 1. Users 테이블 업데이트 (기본 정보)
    // onConflict: 'auth_uid'를 지정해줘야 중복 에러 없이 업데이트(Upsert)가 됩니다.
    final userRes = await _supabase
        .from('users')
        .upsert({
          'auth_uid': user.id,
          'nickname': nickname,
          'bio': bio,
          'age': age,
          'gender': gender,
          'nationality': nationality,
          'mbti': mbti,
          'languages': languages,
          'travel_style': travelStyle,
          'interests': interests,
          'profile_image': profileImage,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'auth_uid')
        .select('id')
        .single();

    final String userId = userRes['id'];

    // 2. 가이드 정보가 입력되었다면 Guides 테이블도 함께 업데이트
    // 가이드 활동 지역이나 소개글이 있을 때만 실행합니다.
    if (locationName != null || residencePeriod != null || guideBio != null) {
      await _supabase.from('guides').upsert({
        'id': userId, // users.id와 동일하게 매칭 (Foreign Key)
        'guide_bio': guideBio,
        'location_name': locationName,
        'residence_period': residencePeriod,
        'specialties': specialties,
        'language_levels': languageLevels,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }
}
