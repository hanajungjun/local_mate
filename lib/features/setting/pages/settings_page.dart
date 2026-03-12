import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:localmate/services/login_service.dart';
import 'package:localmate/features/auth/login_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'blocked_users_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final supabase = Supabase.instance.client;
  String _currentLocale = 'ko';
  final Map<String, String> _languages = {
    'ko': '🇰🇷 한국어',
    'ja': '🇯🇵 日本語 (Japanese)',
    'zh': '🇨🇳 简体中文 (Chinese)',
    'en': '🇺🇸 English',
    'zh_TW': '🇹🇼 繁體中文 (Taiwan/HK)',
    'vi': '🇻🇳 Tiếng Việt (Vietnamese)',
    'th': '🇹🇭 ภาษาไทย (Thai)',
    'ph': '🇵🇭 Tagalog (Filipino)',
    'id': '🇮🇩 Indonesia (Indonesian)',
    'ms': '🇲🇾 Bahasa Melayu (Malay)',
    'es': '🇪🇸 Español (Spanish)', // 스페인 및 남미 전체
    'fr': '🇫🇷 Français (French)', // 프랑스 및 유럽/아프리카
    'pt': '🇵🇹 Português (Portuguese)', // 포르투갈 및 브라질
  };
  String _getLanguageName(String code) => _languages[code] ?? '🇰🇷 한국어';

  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "언어 설정",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _languages.entries.map((entry) {
                    return ListTile(
                      title: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 15),
                      ),
                      trailing: _currentLocale == entry.key
                          ? const Icon(Icons.check, color: Colors.blueAccent)
                          : null,
                      onTap: () {
                        setState(() => _currentLocale = entry.key);
                        // TODO: 여기에 context.setLocale(Locale(entry.key)); 적용
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 스위치 상태 관리
  bool _pushNotification = true;
  bool _marketingAgreement = false;

  @override
  void initState() {
    super.initState();
    _loadSettings(); // 👈 여기서 실행!
  }

  Future<void> _loadSettings() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // users 테이블에서 현재 유저의 설정값만 쏙 뽑아옵니다.
      final data = await supabase
          .from('users')
          .select('push_enabled, marketing_agreed')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          // 데이터가 없으면 기본값(true/false)을 쓰도록 설정
          _pushNotification = data['push_enabled'] ?? true;
          _marketingAgreement = data['marketing_agreed'] ?? false;
        });
      }
      debugPrint(
        "✅ 설정 로드 완료: 푸시($_pushNotification), 마케팅($_marketingAgreement)",
      );
    } catch (e) {
      debugPrint("⚠️ 설정 로드 실패 (컬럼이 없을 수 있음): $e");
    }
  }

  // 1. 연동 이메일 가져오기
  String _getUserEmail() {
    return supabase.auth.currentUser?.email ?? "정보 없음";
  }

  // 2. 로그아웃 처리
  Future<void> _handleSignOut() async {
    final loginService = LoginService();
    await loginService.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  // 3. 회원 탈퇴 처리 (Storage + DB 삭제)
  Future<void> _deleteAccount() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;

      // [A] Storage 삭제 (profile-images 버킷의 사용자 폴더 비우기)
      final List<FileObject> files = await supabase.storage
          .from('profile-images')
          .list(path: userId);

      if (files.isNotEmpty) {
        final List<String> pathsToDelete = files
            .map((f) => '$userId/${f.name}')
            .toList();
        await supabase.storage.from('profile-images').remove(pathsToDelete);
      }

      // [B] DB 데이터 삭제 (users 테이블)
      // TODO: 외래키(Foreign Key) 추가해서 자동 삭제(CASCADE) 필요!
      // (favorites, user-schedule, chatroom 등)
      await supabase.from('users').delete().eq('id', userId);

      // [C] 로그아웃 및 페이지 이동
      await supabase.auth.signOut();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("회원 탈퇴가 완료되었습니다.")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("탈퇴 처리 중 오류 발생: $e")));
    }
  }

  // 4. 푸시/마케팅 설정 DB 업데이트 함수
  Future<void> _updateNotification(String column, bool value) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // 1. 실제 FCM 토픽 구독/해지 처리 (핵심!)
      if (column == 'push_enabled') {
        if (value) {
          await FirebaseMessaging.instance.subscribeToTopic('all_users');
          debugPrint("📢 all_users 구독 완료");
        } else {
          await FirebaseMessaging.instance.unsubscribeFromTopic('all_users');
          debugPrint("🔕 all_users 해지 완료");
        }
      } else if (column == 'marketing_agreed') {
        if (value) {
          await FirebaseMessaging.instance.subscribeToTopic('marketing');
          debugPrint("📢 marketing 구독 완료");
        } else {
          await FirebaseMessaging.instance.unsubscribeFromTopic('marketing');
          debugPrint("🔕 marketing 해지 완료");
        }
      }

      // 2. DB 상태 업데이트
      await supabase.from('users').update({column: value}).eq('id', userId);
      debugPrint("✅ DB $column 업데이트 성공: $value");
    } catch (e) {
      debugPrint("❌ 업데이트 실패: $e");
      // 실패 시 UI 원복 (기존 코드 유지)
      if (mounted) {
        setState(() {
          if (column == 'push_enabled') _pushNotification = !value;
          if (column == 'marketing_agreed') _marketingAgreement = !value;
        });
      }
    }
  }

  // 공통 확인 다이얼로그
  void _showConfirmDialog(
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text("확인", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "설정",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          _buildSectionTitle("계정 및 보안"),
          _buildInfoTile("이메일 연동", _getUserEmail()),
          _buildActionTile(
            "로그아웃",
            color: Colors.black87,
            onTap: () =>
                _showConfirmDialog("로그아웃", "로그아웃 하시겠습니까?", _handleSignOut),
          ),
          _buildActionTile(
            "회원 탈퇴",
            color: Colors.redAccent,
            onTap: () => _showConfirmDialog(
              "회원 탈퇴",
              "정말 탈퇴하시겠습니까?\n모든 정보가 삭제됩니다.",
              _deleteAccount,
            ),
          ),

          const Divider(thickness: 8, color: Color(0xFFF5F5F5)),

          _buildSectionTitle("알림 및 마케팅"),
          _buildSwitchTile("푸시 알림", _pushNotification, (val) {
            setState(() => _pushNotification = val);
            _updateNotification('push_enabled', val); // 🔔 DB 컬럼명 확인 필요
          }),
          _buildSwitchTile("마케팅 정보 수신 동의", _marketingAgreement, (val) {
            setState(() => _marketingAgreement = val);
            _updateNotification('marketing_agreed', val); // 🔔 DB 컬럼명 확인 필요
          }),

          const Divider(thickness: 8, color: Color(0xFFF5F5F5)),

          _buildSectionTitle("사용자 설정"),
          _buildNavigationTile("언어 설정", _getLanguageName(_currentLocale), () {
            _showLanguageSheet(); // 언어 선택 바텀시트 호출
          }),
          _buildNavigationTile("차단한 메이트 관리", null, () {
            // ✅ 차단 리스트 화면으로 이동
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BlockedUsersPage()),
            );
          }),

          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // --- 위젯 부품들 (동일) ---
  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.blueAccent,
      ),
    ),
  );

  Widget _buildInfoTile(String title, String trailing) => ListTile(
    title: Text(title, style: const TextStyle(fontSize: 15)),
    trailing: Text(
      trailing,
      style: const TextStyle(color: Colors.grey, fontSize: 14),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
  );

  Widget _buildActionTile(
    String title, {
    required Color color,
    required VoidCallback onTap,
  }) => ListTile(
    onTap: onTap,
    title: Text(title, style: TextStyle(fontSize: 15, color: color)),
    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
  );

  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) => SwitchListTile.adaptive(
    title: Text(title, style: const TextStyle(fontSize: 15)),
    value: value,
    onChanged: onChanged,
    activeColor: Colors.blueAccent,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
  );

  Widget _buildNavigationTile(
    String title,
    String? subValue,
    VoidCallback onTap,
  ) => ListTile(
    onTap: onTap,
    title: Text(title, style: const TextStyle(fontSize: 15)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (subValue != null)
          Text(
            subValue,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ],
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
  );
}
