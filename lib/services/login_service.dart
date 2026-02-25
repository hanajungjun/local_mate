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

  Future<void> syncUserToDatabase(User user) async {
    try {
      // 💡 에러 로그를 보면 첫 번째 값이 PK(id)인 것 같습니다.
      // user.id를 두 군데 다 확실히 넣어주세요.
      await _supabase.from('users').upsert({
        'id': user.id,
        'auth_uid': user.id,
        'email': user.email,
        'nickname': user.email?.split('@')[0] ?? 'tester', // 일단 뭐라도 넣기
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ 동기화 시도 완료');
    } catch (e) {
      debugPrint('❌ 서비스단 에러: $e');
    }
  }

  // 🎯 로그아웃
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
