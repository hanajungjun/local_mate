import 'package:flutter/material.dart';
import 'package:localmate/features/map/pages/traveler_map_page.dart';
import 'package:localmate/features/map/pages/guide_map_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MapViewPage extends StatefulWidget {
  const MapViewPage({super.key}); // ✅ isTraveler 파라미터 제거

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  final supabase = Supabase.instance.client;
  bool? _isTraveler; // null = 로딩 중

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  Future<void> _loadMode() async {
    try {
      final myId = supabase.auth.currentUser?.id;
      if (myId == null) return;

      final res = await supabase
          .from('users')
          .select('last_mode')
          .eq('auth_uid', myId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isTraveler = (res?['last_mode'] ?? 'traveler') == 'traveler';
          debugPrint(
            "🗺️ MapViewPage - last_mode: ${res?['last_mode']}, isTraveler: $_isTraveler",
          );
        });
      }
    } catch (e) {
      debugPrint("❌ last_mode 조회 실패: $e");
      if (mounted) setState(() => _isTraveler = true); // 폴백
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isTraveler == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _isTraveler! ? const TravelerMapPage() : const GuideMapPage();
  }
}
