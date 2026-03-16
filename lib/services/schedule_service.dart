import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduleService {
  final _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// 🙋‍♂️ [여행자 모드] 내가 올린 공고 중 '확정'된 일정 가져오기
  Future<List<Map<String, dynamic>>> getUserSchedules() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final data = await _supabase
          .from('offers')
          .select('''
            *,
            travel_requests!inner(title, writer_id),
            users:guide_id(id, nickname, profile_image)
          ''')
          .eq('status', 'confirmed') // 1. 확정된 것만
          .eq('travel_requests.writer_id', userId) // 2. 내가 쓴 공고에 대한 것만
          .order('meeting_date', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("❌ 여행자 일정 로드 실패: $e");
      return [];
    }
  }

  /// 👨‍🏫 [가이드 모드] 내가 제안해서 '확정'된 일정 가져오기
  Future<List<Map<String, dynamic>>> getGuideSchedules() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final data = await _supabase
          .from('offers')
          .select('''
            *,
            travel_requests(title),
            users:guide_id(id, nickname, profile_image)
          ''')
          .eq('status', 'confirmed')
          .eq('guide_id', userId) // 💡 내가 가이드인 것만!
          .order('meeting_date', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("❌ 가이드 일정 로드 실패: $e");
      return [];
    }
  }
}
