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
      // 💡 upsert 시 'onConflict' 옵션을 명시하면 더 안전합니다.
      await _supabase.from('users').upsert({
        'id': user.id, // Primary Key
        'auth_uid': user.id, // 인증 UID
        'email': user.email,
        'nickname': user.email?.split('@')[0] ?? 'new_mate',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id'); // 👈 'id'가 겹치면 업데이트만 하라고 명시

      debugPrint('✅ 유저 데이터 동기화 성공');
    } catch (e) {
      // 💡 여기서 발생하는 에러가 로그인 차단 원인인지 확인 필수!
      debugPrint('❌ 동기화 에러: $e');
    }
  }

  // 🎯 로그아웃
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
