import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class LoginService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 🎯 이메일/비번 로그인 로직
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // 로그인 성공 시 유저 정보 업데이트 실행
        await syncUserToDatabase(response.user!);
      }
      return response.user;
    } catch (e) {
      debugPrint('로그인 에러: $e');
      rethrow; // 에러를 위로 던져서 UI에서 알림을 띄우게 함
    }
  }

  // ✅ 사용자의 프로필 상태를 확인하는 로직 (서비스로 분리)
  Future<bool> isNewUser(String userId) async {
    try {
      final profile = await _supabase
          .from('users')
          .select('nickname')
          .eq('auth_uid', userId)
          .maybeSingle();

      // 프로필이 없거나 닉네임이 비어있으면 신규 유저로 판단
      if (profile == null ||
          profile['nickname'] == null ||
          profile['nickname'].toString().isEmpty) {
        return true;
      }
      return false;
    } catch (e) {
      // 에러 발생 시 안전하게 신규 유저로 처리하거나 로그 출력
      debugPrint("⚠️ 유저 상태 확인 실패: $e");
      return true;
    }
  }

  Future<void> syncUserToDatabase(User user) async {
    try {
      // 1. 먼저 DB에 기존 유저 정보가 있는지 확인합니다.
      final existingUser = await _supabase
          .from('users')
          .select('nickname')
          .eq('auth_uid', user.id)
          .maybeSingle();

      // 2. 업데이트할 데이터 맵을 만듭니다.
      final Map<String, dynamic> updateData = {
        'id': user.id,
        'auth_uid': user.id,
        'email': user.email,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 3. ⭐ 핵심: 기존에 닉네임이 없을 때만 이메일 기반 닉네임을 추가합니다.
      if (existingUser == null || existingUser['nickname'] == null) {
        updateData['nickname'] = user.email?.split('@')[0] ?? 'new_mate';
        debugPrint('🆕 신규 유저: 초기 닉네임을 설정합니다.');
      } else {
        debugPrint('✅ 기존 유저: 기존 닉네임(${existingUser['nickname']})을 유지합니다.');
      }

      // 4. 이제 안전하게 upsert를 실행합니다.
      await _supabase.from('users').upsert(updateData, onConflict: 'id');

      debugPrint('✅ 유저 데이터 동기화 완료');
    } catch (e) {
      debugPrint('❌ 동기화 에러: $e');
    }
  }

  // 🎯 로그아웃
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
