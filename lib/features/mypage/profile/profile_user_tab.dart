import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:localmate/core/constants/app_colors.dart';

class ProfileUserTab extends StatefulWidget {
  final TextEditingController nicknameController;
  final TextEditingController bioController;
  // ageController는 내부에서 생년월일→나이 자동 계산용으로만 씀
  final TextEditingController ageController;
  final TextEditingController nationalityController; // ✅ 국적 추가
  final String? gender;
  final String? mbti;
  final List<String> selectedTravelStyles;
  final List<String> selectedLanguages;
  final List<AssetEntity> selectedAssets;
  final List<String> serverImageUrls;
  final VoidCallback onPickAssets;
  final VoidCallback onChanged;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<String?> onMbtiChanged;
  final ValueChanged<String> onRemoveServerImage;
  final ValueChanged<AssetEntity> onRemoveLocalAsset;

  const ProfileUserTab({
    super.key,
    required this.nicknameController,
    required this.bioController,
    required this.ageController,
    required this.nationalityController,
    required this.gender,
    required this.mbti,
    required this.selectedTravelStyles,
    required this.selectedLanguages,
    required this.selectedAssets,
    required this.serverImageUrls,
    required this.onPickAssets,
    required this.onChanged,
    required this.onGenderChanged,
    required this.onMbtiChanged,
    required this.onRemoveServerImage,
    required this.onRemoveLocalAsset,
  });

  @override
  State<ProfileUserTab> createState() => _ProfileUserTabState();
}

class _ProfileUserTabState extends State<ProfileUserTab> {
  DateTime? _selectedBirthDate; // ✅ 선택된 생년월일

  static const _mbtiList = [
    'INTJ',
    'INTP',
    'ENTJ',
    'ENTP',
    'INFJ',
    'INFP',
    'ENFJ',
    'ENFP',
    'ISTJ',
    'ISFJ',
    'ESTJ',
    'ESFJ',
    'ISTP',
    'ISFP',
    'ESTP',
    'ESFP',
  ];

  // ✅ 국가 목록
  final List<String> _allCountries = [
    '대한민국',
    '미국',
    '일본',
    '중국',
    '영국',
    '프랑스',
    '독일',
    '캐나다',
    '호주',
    '이탈리아',
    '스페인',
    '브라질',
    '인도',
    '멕시코',
    '러시아',
    '네덜란드',
    '스위스',
    '스웨덴',
    '노르웨이',
    '덴마크',
    '핀란드',
    '태국',
    '베트남',
    '싱가포르',
    '말레이시아',
    '인도네시아',
    '필리핀',
    '홍콩',
    '대만',
    '터키',
    '이스라엘',
    '사우디아라비아',
    '아랍에미리트',
    '남아프리카공화국',
    '이집트',
    '나이지리아',
    '아르헨티나',
    '칠레',
    '콜롬비아',
    '뉴질랜드',
    '폴란드',
    '체코',
    '헝가리',
    '오스트리아',
    '벨기에',
    '포르투갈',
  ];

  final List<String> _allTravelStyles = [
    '사진',
    '맛집탐방',
    '쇼핑',
    '관광',
    '액티비티',
    '힐링',
    '역사탐방',
    '자연',
    '캠핑',
    '드라이브',
    '야경',
    '카페투어',
    '로컬체험',
    '음악/공연',
    '스포츠',
  ];

  final List<String> _allLanguages = [
    '한국어',
    '영어',
    '일본어',
    '중국어',
    '스페인어',
    '프랑스어',
    '독일어',
    '이탈리아어',
    '포르투갈어',
    '러시아어',
    '아랍어',
    '태국어',
    '베트남어',
    '인도네시아어',
    '힌디어',
  ];

  // ── 생년월일 DatePicker ───────────────────────────
  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _selectedBirthDate ?? DateTime(now.year - 25);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 1, 12, 31),
      locale: const Locale('ko'),
      helpText: '생년월일 선택',
      cancelText: '취소',
      confirmText: '확인',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.travelingBlue,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
      // ✅ 나이 자동 계산 후 ageController에 저장
      final age =
          now.year -
          picked.year -
          (now.month < picked.month ||
                  (now.month == picked.month && now.day < picked.day)
              ? 1
              : 0);
      widget.ageController.text = age.toString();
      widget.onChanged();
    }
  }

  // ── 국적 선택 BottomSheet ─────────────────────────
  void _showNationalitySheet() {
    final controller = TextEditingController();
    List<String> filtered = List.from(_allCountries);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.65,
            child: Column(
              children: [
                _sheetHandle(),
                const Text(
                  '국적 선택',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _sheetSearchField(
                  controller: controller,
                  hint: '국가 검색 또는 직접 입력',
                  onChanged: (val) {
                    setSheet(() {
                      filtered = val.isEmpty
                          ? List.from(_allCountries)
                          : _allCountries
                                .where((c) => c.contains(val))
                                .toList();
                      if (val.isNotEmpty && !filtered.contains(val.trim())) {
                        filtered.insert(0, val.trim());
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final country = filtered[i];
                      final isSelected =
                          widget.nationalityController.text == country;
                      return ListTile(
                        leading: Icon(
                          Icons.flag_outlined,
                          color: isSelected
                              ? Colors.grey
                              : AppColors.travelingBlue,
                        ),
                        title: Text(country),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check,
                                color: AppColors.travelingBlue,
                              )
                            : null,
                        onTap: () {
                          setState(
                            () => widget.nationalityController.text = country,
                          );
                          widget.onChanged();
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── MBTI 팝업 ──────────────────────────────────────
  void _showMbtiPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'MBTI 선택',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
            ),
            itemCount: _mbtiList.length,
            itemBuilder: (_, i) {
              final type = _mbtiList[i];
              final isSelected = widget.mbti == type;
              return GestureDetector(
                onTap: () {
                  widget.onMbtiChanged(type);
                  Navigator.pop(ctx);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.travelingBlue
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.travelingBlue
                          : Colors.grey.shade300,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onMbtiChanged(null);
              Navigator.pop(ctx);
            },
            child: const Text('선택 해제'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // ── 여행스타일 BottomSheet ─────────────────────────
  void _showTravelStyleSheet() {
    final controller = TextEditingController();
    List<String> filtered = List.from(_allTravelStyles);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.65,
            child: Column(
              children: [
                _sheetHandle(),
                const Text(
                  '여행 스타일 추가',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _sheetSearchField(
                  controller: controller,
                  hint: '스타일 검색 또는 직접 입력',
                  onChanged: (val) {
                    setSheet(() {
                      filtered = val.isEmpty
                          ? List.from(_allTravelStyles)
                          : _allTravelStyles
                                .where((s) => s.contains(val))
                                .toList();
                      if (val.isNotEmpty && !filtered.contains(val.trim())) {
                        filtered.insert(0, val.trim());
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final style = filtered[i];
                      final isSelected = widget.selectedTravelStyles.contains(
                        style,
                      );
                      return ListTile(
                        leading: Icon(
                          Icons.explore_outlined,
                          color: isSelected
                              ? Colors.grey
                              : AppColors.travelingBlue,
                        ),
                        title: Text(style),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.grey)
                            : const Icon(
                                Icons.add,
                                color: AppColors.travelingBlue,
                              ),
                        onTap: isSelected
                            ? null
                            : () {
                                if (!_allTravelStyles.contains(style)) {
                                  setState(() => _allTravelStyles.add(style));
                                }
                                setState(
                                  () => widget.selectedTravelStyles.add(style),
                                );
                                widget.onChanged();
                                Navigator.pop(ctx);
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 언어 BottomSheet ──────────────────────────────
  void _showLanguageSheet() {
    final controller = TextEditingController();
    List<String> filtered = List.from(_allLanguages);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.65,
            child: Column(
              children: [
                _sheetHandle(),
                const Text(
                  '언어 추가',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _sheetSearchField(
                  controller: controller,
                  hint: '언어 검색 또는 직접 입력',
                  onChanged: (val) {
                    setSheet(() {
                      filtered = val.isEmpty
                          ? List.from(_allLanguages)
                          : _allLanguages
                                .where(
                                  (l) => l.toLowerCase().contains(
                                    val.toLowerCase(),
                                  ),
                                )
                                .toList();
                      if (val.isNotEmpty &&
                          !filtered.any(
                            (l) => l.toLowerCase() == val.trim().toLowerCase(),
                          )) {
                        filtered.insert(0, val.trim());
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final lang = filtered[i];
                      final isSelected = widget.selectedLanguages.contains(
                        lang,
                      );
                      return ListTile(
                        leading: Icon(
                          Icons.language,
                          color: isSelected
                              ? Colors.grey
                              : AppColors.travelingBlue,
                        ),
                        title: Text(lang),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.grey)
                            : const Icon(
                                Icons.add,
                                color: AppColors.travelingBlue,
                              ),
                        onTap: isSelected
                            ? null
                            : () {
                                if (!_allLanguages.contains(lang)) {
                                  setState(() => _allLanguages.add(lang));
                                }
                                setState(
                                  () => widget.selectedLanguages.add(lang),
                                );
                                widget.onChanged();
                                Navigator.pop(ctx);
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // initState 대신 여기서 ageController 값으로 초기 생년월일 추정
    // (저장된 age가 있으면 올해 기준 역산, 없으면 null)
    if (_selectedBirthDate == null && widget.ageController.text.isNotEmpty) {
      final age = int.tryParse(widget.ageController.text);
      if (age != null) {
        _selectedBirthDate = DateTime(DateTime.now().year - age, 1, 1);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 프로필 사진 ──────────────────────────────
          const Text(
            '프로필 사진 (최대 5장)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                GestureDetector(
                  onTap: widget.onPickAssets,
                  child: Container(
                    width: 90,
                    height: 90,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_a_photo_outlined,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ...widget.serverImageUrls.map((url) => _buildNetworkImage(url)),
                ...widget.selectedAssets.map(
                  (asset) => _buildLocalImage(asset),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 닉네임 ───────────────────────────────────
          TextField(
            controller: widget.nicknameController,
            decoration: _inputDeco('닉네임'),
          ),
          const SizedBox(height: 16),

          // ── 성별 ─────────────────────────────────────
          const Text('성별', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _GenderButton(
                  label: '남성',
                  value: 'male',
                  selected: widget.gender == 'male',
                  onTap: () => widget.onGenderChanged('male'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderButton(
                  label: '여성',
                  value: 'female',
                  selected: widget.gender == 'female',
                  onTap: () => widget.onGenderChanged('female'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 생년월일 (DatePicker) ─────────────────────
          const Text('생년월일', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickBirthDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedBirthDate != null
                        ? '${_selectedBirthDate!.year}년 '
                              '${_selectedBirthDate!.month}월 '
                              '${_selectedBirthDate!.day}일'
                              '  (만 ${widget.ageController.text}세)'
                        : '생년월일을 선택하세요',
                    style: TextStyle(
                      fontSize: 15,
                      color: _selectedBirthDate != null
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 국적 ─────────────────────────────────────
          const Text('국적', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showNationalitySheet,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.nationalityController.text.isNotEmpty
                        ? widget.nationalityController.text
                        : '국적을 선택하세요',
                    style: TextStyle(
                      fontSize: 15,
                      color: widget.nationalityController.text.isNotEmpty
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 자기소개 ──────────────────────────────────
          TextField(
            controller: widget.bioController,
            maxLines: 3,
            decoration: _inputDeco('자기소개'),
          ),
          const SizedBox(height: 16),

          // ── MBTI ─────────────────────────────────────
          const Text('MBTI', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showMbtiPicker,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.mbti ?? 'MBTI를 선택하세요',
                    style: TextStyle(
                      fontSize: 15,
                      color: widget.mbti != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── 여행 스타일 ───────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '여행 스타일',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _showTravelStyleSheet,
                icon: const Icon(
                  Icons.add,
                  size: 16,
                  color: AppColors.travelingBlue,
                ),
                label: const Text(
                  '추가',
                  style: TextStyle(
                    color: AppColors.travelingBlue,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          widget.selectedTravelStyles.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '여행 스타일을 추가해보세요',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.selectedTravelStyles.map((style) {
                    return _RemovableChip(
                      label: style,
                      onRemove: () {
                        setState(
                          () => widget.selectedTravelStyles.remove(style),
                        );
                        widget.onChanged();
                      },
                    );
                  }).toList(),
                ),
          const SizedBox(height: 16),

          // ── 사용 가능 언어 ────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '사용 가능 언어',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _showLanguageSheet,
                icon: const Icon(
                  Icons.add,
                  size: 16,
                  color: AppColors.travelingBlue,
                ),
                label: const Text(
                  '추가',
                  style: TextStyle(
                    color: AppColors.travelingBlue,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          widget.selectedLanguages.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '사용 가능한 언어를 추가해보세요',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.selectedLanguages.map((lang) {
                    return _RemovableChip(
                      label: lang,
                      onRemove: () {
                        setState(() => widget.selectedLanguages.remove(lang));
                        widget.onChanged();
                      },
                    );
                  }).toList(),
                ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── 공통 헬퍼 ─────────────────────────────────────
  Widget _sheetHandle() => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _sheetSearchField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: TextField(
      controller: controller,
      autofocus: true,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: onChanged,
    ),
  );

  Widget _buildNetworkImage(String url) => Stack(
    children: [
      Container(
        width: 90,
        height: 90,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
        ),
      ),
      Positioned(
        top: 2,
        right: 10,
        child: GestureDetector(
          onTap: () => widget.onRemoveServerImage(url),
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, size: 14, color: Colors.white),
          ),
        ),
      ),
    ],
  );

  Widget _buildLocalImage(AssetEntity asset) => FutureBuilder<Widget>(
    future: asset
        .thumbnailDataWithSize(const ThumbnailSize(180, 180))
        .then(
          (bytes) => bytes != null
              ? Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: MemoryImage(bytes),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => widget.onRemoveLocalAsset(asset),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox(width: 90, height: 90),
        ),
    builder: (_, snap) => snap.data ?? const SizedBox(width: 90, height: 90),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
  );
}

// ── X 버튼 달린 칩 ────────────────────────────────
class _RemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _RemovableChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.travelingBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.travelingBlue.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.travelingBlue,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppColors.travelingBlue,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 성별 버튼 ─────────────────────────────────────
class _GenderButton extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  const _GenderButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.travelingBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.travelingBlue : Colors.grey.shade400,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
