import 'package:supabase_flutter/supabase_flutter.dart';

class MapService {
  final _supabase = Supabase.instance.client;

  /// 📍 지도에 표시할 가이드 목록 가져오기 (광고 레벨순 정렬)
  /// [radiusDegrees] : 화면 크기에 따라 동적으로 전달받는 범위 (기본 ±0.1도)
  Future<List<Map<String, dynamic>>> getNearbyGuides(
    double lat,
    double lng, {
    double radiusDegrees = 0.1,
  }) async {
    try {
      final data = await _supabase
          .from('guides')
          .select('*, users!inner(*)')
          .not('latitude', 'is', null)
          .gte('latitude', lat - radiusDegrees)
          .lte('latitude', lat + radiusDegrees)
          .gte('longitude', lng - radiusDegrees)
          .lte('longitude', lng + radiusDegrees)
          .order('ad_level', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("❌ 근처 가이드 로드 실패: $e");
      return [];
    }
  }
}
