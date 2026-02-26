import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  // ✅ 통합 프로필 가져오기 (users + guides join)
  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    // users 테이블과 guides 테이블을 Left Join해서 가져옵니다.
    final data = await _supabase
        .from('users')
        .select('*, guides(*)')
        .eq('auth_uid', user.id)
        .maybeSingle();

    return data;
  }

  // ✅ 통합 업데이트 로직
  Future<void> updateProfile({
    // [Users 테이블용]
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
    // [Guides 테이블용]
    String? guideBio,
    String? locationName,
    String? residencePeriod,
    List<String>? specialties,
    Map<String, int>? languageLevels,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("세션 없음");

    // 1. Users 테이블 업데이트 (기본 정보)
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
        })
        .select('id')
        .single();

    final String userId = userRes['id'];

    // 2. 가이드 정보가 하나라도 있으면 Guides 테이블 업데이트
    if (locationName != null || residencePeriod != null || guideBio != null) {
      await _supabase.from('guides').upsert({
        'id': userId, // users.id와 동일하게 매칭
        'guide_bio': guideBio,
        'location_name': locationName,
        'residence_period': residencePeriod,
        'specialties': specialties,
        'updated_at': DateTime.now().toIso8601String(),
        'language_levels': languageLevels,
      });
    }
  }

  // ✅ 여행 공고(Request) 생성 함수
  Future<void> createTravelRequest({
    required String title,
    required String content,
    required String locationName,
    required DateTime travelDate,
    required int headcount,
    required int budget,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("로그인이 필요합니다.");

    // users 테이블의 ID를 먼저 가져옵니다.
    final userData = await _supabase
        .from('users')
        .select('id')
        .eq('auth_uid', user.id)
        .single();

    await _supabase.from('travel_requests').insert({
      'writer_id': userData['id'], // 작성자 ID
      'title': title,
      'content': content,
      'location_name': locationName,
      'travel_date': travelDate.toIso8601String(),
      'headcount': headcount,
      'budget': budget,
      'status': 'searching', // 기본값: 모집중
    });
  }
}
