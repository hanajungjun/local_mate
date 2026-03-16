import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduleService {
  final _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// 🙋‍♀️ [여행자 모드] user_schedules에서 가져오기
  Future<List<Map<String, dynamic>>> getUserSchedules() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final data = await _supabase
          .from('user_schedules')
          .select('*')
          .eq('user_id', userId)
          .order('trip_date', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("❌ 여행자 일정 로드 실패: $e");
      return [];
    }
  }

  /// 👨‍🏫 [가이드 모드] guide_schedules에서 가져오기
  Future<List<Map<String, dynamic>>> getGuideSchedules() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final data = await _supabase
          .from('guide_schedules')
          .select('*')
          .eq('guide_id', userId)
          .order('trip_date', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("❌ 가이드 일정 로드 실패: $e");
      return [];
    }
  }
}
