import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:localmate/services/user_service.dart';
import 'package:localmate/app/app_shell.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/core/widgets/popup/app_toast.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:localmate/features/mypage/profile/profile_user_tab.dart';
import 'package:localmate/features/mypage/profile/profile_guide_tab.dart';

class ProfileEditPage extends StatefulWidget {
  final bool isFirstLogin;
  const ProfileEditPage({super.key, this.isFirstLogin = false});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _userService = UserService();
  bool _isLoading = false;

  // 1. 공통 및 Mate 컨트롤러/변수
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  final _ageController = TextEditingController();
  String? _gender;
  String? _mbti;
  List<String> _selectedTravelStyles = [];
  List<String> _selectedLanguages = [];
  List<AssetEntity> _selectedAssets = [];
  List<String> _serverImageUrls = [];

  // 2. Guide 컨트롤러/변수
  final _locationController = TextEditingController();
  final _residenceController = TextEditingController();
  final _guideBioController = TextEditingController();
  List<String> _selectedSpecialties = [];
  Map<String, int> _selectedLanguageLevels = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _userService.getMyProfile();
    if (data != null) {
      setState(() {
        _nicknameController.text = data['nickname'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _ageController.text = data['age']?.toString() ?? '';
        _gender = data['gender'];
        _mbti = data['mbti'];
        _selectedTravelStyles = List<String>.from(data['travel_style'] ?? []);
        _selectedLanguages = List<String>.from(data['languages'] ?? []);
        _serverImageUrls = List<String>.from(data['profile_image'] ?? []);

        if (data['guides'] != null) {
          final g = data['guides'];
          _guideBioController.text = g['guide_bio'] ?? '';
          _locationController.text = g['location_name'] ?? '';
          _residenceController.text = g['residence_period'] ?? '';
          _selectedSpecialties = List<String>.from(g['specialties'] ?? []);
          _selectedLanguageLevels = Map<String, int>.from(
            g['language_levels'] ?? {},
          );
        }
      });
    }
    setState(() => _isLoading = false);
  }

  // ✅ 갤러리에서 사진 선택 로직 (ProfileEditPage 내부에 추가)
  Future<void> _pickAssets() async {
    // 1. 사진 개수 제한 체크 (로컬 + 서버 사진 합쳐서 5장)
    if (_selectedAssets.length + _serverImageUrls.length >= 5) {
      AppToast.error(context, '최대 5장까지 가능합니다.');
      return;
    }

    // 2. 위챗 에셋 피커 실행
    final List<AssetEntity>? result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 5 - _serverImageUrls.length, // 남은 자리만큼만 선택
        selectedAssets: _selectedAssets,
        requestType: RequestType.image,
      ),
    );

    // 3. 결과가 있으면 상태 업데이트
    if (result != null) {
      setState(() {
        _selectedAssets = result;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await _userService.updateProfile(
        nickname: _nicknameController.text,
        bio: _bioController.text,
        age: int.tryParse(_ageController.text),
        gender: _gender,
        mbti: _mbti,
        languages: _selectedLanguages,
        travelStyle: _selectedTravelStyles,
        profileImage: _serverImageUrls,
        guideBio: _guideBioController.text,
        locationName: _locationController.text,
        residencePeriod: _residenceController.text,
        specialties: _selectedSpecialties,
        languageLevels: _selectedLanguageLevels, // ✅ 추가된 레벨 저장
      );
      if (!mounted) return;
      widget.isFirstLogin
          ? Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AppShell()),
            )
          : Navigator.pop(context);
    } catch (e) {
      AppToast.error(context, '저장 실패');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.isFirstLogin ? 'welcome_title'.tr() : 'edit_profile'.tr(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.travelingBlue,
          tabs: const [
            Tab(text: "내 프로필"),
            Tab(text: "가이드 등록"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: Text('save'.tr()),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                ProfileUserTab(
                  // ✅ 쪼갠 위젯으로 전달
                  nicknameController: _nicknameController,
                  bioController: _bioController,
                  ageController: _ageController,
                  gender: _gender,
                  mbti: _mbti,
                  selectedTravelStyles: _selectedTravelStyles,
                  selectedLanguages: _selectedLanguages,
                  selectedAssets: _selectedAssets,
                  serverImageUrls: _serverImageUrls,
                  onPickAssets: _pickAssets,
                  onChanged: () => setState(() {}),
                ),
                ProfileGuideTab(
                  // ✅ 쪼갠 위젯으로 전달
                  locationController: _locationController,
                  residenceController: _residenceController,
                  guideBioController: _guideBioController,
                  selectedSpecialties: _selectedSpecialties,
                  selectedLanguageLevels: _selectedLanguageLevels,
                  onChanged: () => setState(() {}),
                ),
              ],
            ),
    );
  }
}
