import 'package:supabase_flutter/supabase_flutter.dart';

class WishlistService {
  final _supabase = Supabase.instance.client;

  String? get _myId => _supabase.auth.currentUser?.id;

  /// ✅ 내가 좋아요한 유저 목록 (from_user_id = 나)
  /// likes에서 to_user_id 목록 가져온 후 users 테이블에서 상대방 정보 조회
  Future<List<Map<String, dynamic>>> getMyLikes() async {
    if (_myId == null) return [];
    try {
      // 1. 내가 좋아요한 likes rows 가져오기
      final likesData = await _supabase
          .from('likes')
          .select('id, to_user_id, created_at')
          .eq('from_user_id', _myId!)
          .order('created_at', ascending: false);

      final likes = List<Map<String, dynamic>>.from(likesData);
      if (likes.isEmpty) return [];

      // 2. to_user_id 목록으로 유저 정보 한 번에 가져오기
      final toUserIds = likes.map((l) => l['to_user_id']).toList();
      final usersData = await _supabase
          .from('users')
          .select('*')
          .inFilter('id', toUserIds);

      final usersMap = {
        for (var u in List<Map<String, dynamic>>.from(usersData)) u['id']: u,
      };

      // 3. likes + users 합치기
      return likes.map((like) {
        return {...like, 'users': usersMap[like['to_user_id']] ?? {}};
      }).toList();
    } catch (e) {
      print('❌ 좋아요 목록 로드 실패: $e');
      return [];
    }
  }

  /// ✅ 내가 제안한 공고 목록 (guide_id = 나)
  /// ✅ 내가 제안한 공고 목록 (전체 상태 포함)
  Future<List<Map<String, dynamic>>> getMyOffers() async {
    if (_myId == null) return [];
    try {
      // offers의 status와 travel_requests의 status를 모두 가져옵니다.
      final data = await _supabase
          .from('offers')
          .select('''
            *,
            travel_requests (*)
          ''')
          .eq('guide_id', _myId!)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('❌ 공고 제안 목록 로드 실패: $e');
      return [];
    }
  }

  /// ✅ 좋아요 취소
  Future<void> unlikeUser(String toUserId) async {
    if (_myId == null) return;
    try {
      await _supabase
          .from('likes')
          .delete()
          .eq('from_user_id', _myId!)
          .eq('to_user_id', toUserId);
    } catch (e) {
      print('❌ 좋아요 취소 실패: $e');
    }
  }
}
