import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduleService {
  final _supabase = Supabase.instance.client;

  // 현재 로그인한 유저의 ID를 안전하게 가져오는 getter
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // 여행자 일정 가져오기
  Future<List<Map<String, dynamic>>> getUserSchedules() async {
    final userId = currentUserId;
    if (userId == null) return []; // 로그인 안 되어 있으면 빈 리스트

    return await _supabase
        .from('user_schedules')
        .select()
        .eq('user_id', userId)
        .order('trip_date', ascending: true);
  }

  // 가이드 일정 가져오기
  Future<List<Map<String, dynamic>>> getGuideSchedules() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return [];

    // ✅ guide_schedules 대신 실제 데이터가 쌓이는 user_schedules를 조회합니다.
    final data = await Supabase.instance.client
        .from('user_schedules')
        .select('*')
        .eq('guide_id', myId) // 💡 내가 가이드인 일정만!
        .order('trip_date', ascending: true);

    return List<Map<String, dynamic>>.from(data);
  }
}
