import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:localmate/services/profile_service.dart';
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
  final _profileService = ProfileService();
  bool _isLoading = false;

  // ── 내 프로필 ──────────────────────────────────────
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  final _ageController = TextEditingController(); // 생년월일→나이 자동계산 저장용
  final _nationalityController = TextEditingController(); // ✅ 국적
  String? _gender;
  String? _mbti;
  List<String> _selectedTravelStyles = [];
  List<String> _selectedLanguages = [];
  List<AssetEntity> _selectedAssets = [];
  List<String> _serverImageUrls = [];

  // ── 가이드 등록 ────────────────────────────────────
  List<String> _selectedLocations = [];
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

  @override
  void dispose() {
    _tabController.dispose();
    _nicknameController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    _nationalityController.dispose();
    _residenceController.dispose();
    _guideBioController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _profileService.getMyProfile();
      if (data != null) {
        setState(() {
          _nicknameController.text = data['nickname'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _ageController.text = data['age']?.toString() ?? '';
          _nationalityController.text = data['nationality'] ?? ''; // ✅
          _gender = data['gender'];
          _mbti = data['mbti'];
          _selectedTravelStyles = List<String>.from(data['travel_style'] ?? []);
          _selectedLanguages = List<String>.from(data['languages'] ?? []);
          _serverImageUrls = List<String>.from(data['profile_image'] ?? []);

          if (data['guides'] != null) {
            final g = data['guides'];
            _guideBioController.text = g['guide_bio'] ?? '';
            _residenceController.text = g['residence_period'] ?? '';
            _selectedSpecialties = List<String>.from(g['specialties'] ?? []);
            _selectedLanguageLevels = Map<String, int>.from(
              g['language_levels'] ?? {},
            );
            _selectedLocations = List<String>.from(g['location_names'] ?? []);
          }
        });
      }
    } catch (e) {
      if (mounted) AppToast.error(context, '프로필을 불러오지 못했습니다.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAssets() async {
    final currentTotal = _selectedAssets.length + _serverImageUrls.length;
    if (currentTotal >= 5) {
      AppToast.error(context, '최대 5장까지 가능합니다.');
      return;
    }

    final List<AssetEntity>? result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 5 - _serverImageUrls.length,
        selectedAssets: _selectedAssets,
        requestType: RequestType.image,
      ),
    );

    if (result != null) {
      final localOnly = <AssetEntity>[];
      for (final asset in result) {
        final file = await asset.originFile;
        if (file != null) localOnly.add(asset);
      }
      if (localOnly.length < result.length && mounted) {
        AppToast.error(context, 'iCloud 사진은 지원하지 않습니다. 기기에 저장된 사진만 선택해주세요.');
      }
      setState(() => _selectedAssets = localOnly);
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await _profileService.updateProfile(
        nickname: _nicknameController.text,
        bio: _bioController.text,
        age: int.tryParse(_ageController.text),
        gender: _gender,
        nationality:
            _nationalityController
                .text
                .isNotEmpty // ✅
            ? _nationalityController.text
            : null,
        mbti: _mbti,
        languages: _selectedLanguages,
        travelStyle: _selectedTravelStyles,
        serverImageUrls: _serverImageUrls,
        newSelectedAssets: _selectedAssets,
        guideBio: _guideBioController.text,
        locationNames: _selectedLocations,
        residencePeriod: _residenceController.text,
        specialties: _selectedSpecialties,
        languageLevels: _selectedLanguageLevels,
      );

      if (!mounted) return;
      widget.isFirstLogin
          ? Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AppShell()),
            )
          : Navigator.pop(context);
    } catch (e) {
      if (mounted) AppToast.error(context, '저장 실패: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                  nicknameController: _nicknameController,
                  bioController: _bioController,
                  ageController: _ageController,
                  nationalityController: _nationalityController, // ✅
                  gender: _gender,
                  mbti: _mbti,
                  selectedTravelStyles: _selectedTravelStyles,
                  selectedLanguages: _selectedLanguages,
                  selectedAssets: _selectedAssets,
                  serverImageUrls: _serverImageUrls,
                  onPickAssets: _pickAssets,
                  onChanged: () => setState(() {}),
                  onGenderChanged: (val) => setState(() => _gender = val),
                  onMbtiChanged: (val) => setState(() => _mbti = val),
                  onRemoveServerImage: (url) =>
                      setState(() => _serverImageUrls.remove(url)),
                  onRemoveLocalAsset: (asset) =>
                      setState(() => _selectedAssets.remove(asset)),
                ),
                ProfileGuideTab(
                  selectedLocations: _selectedLocations,
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
