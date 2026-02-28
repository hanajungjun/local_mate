import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/core/widgets/popup/app_toast.dart';

class ProfileGuideTab extends StatefulWidget {
  final List<String> selectedLocations;
  final TextEditingController residenceController;
  final TextEditingController guideBioController;
  final List<String> selectedSpecialties;
  final Map<String, int> selectedLanguageLevels;
  final VoidCallback onChanged;

  const ProfileGuideTab({
    super.key,
    required this.selectedLocations,
    required this.residenceController,
    required this.guideBioController,
    required this.selectedSpecialties,
    required this.selectedLanguageLevels,
    required this.onChanged,
  });

  @override
  State<ProfileGuideTab> createState() => _ProfileGuideTabState();
}

class _ProfileGuideTabState extends State<ProfileGuideTab> {
  // ✅ 기본 제공 언어 목록 (사용자가 추가하면 여기에 append됨)
  final List<String> _allLanguages = [
    '한국어',
    'English',
    '日本語',
    '中文',
    'Español',
    'Français',
    'Deutsch',
    'Italiano',
    'Português',
    'Русский',
    'العربية',
    'ภาษาไทย',
    'Tiếng Việt',
    'Bahasa Indonesia',
    'हिन्दी',
  ];

  // ✅ 언어 추가 BottomSheet
  void _showAddLanguageSheet() {
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
                // 핸들
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  '언어 추가',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                // 검색창
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '언어 검색 또는 직접 입력',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
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
                        // 직접 입력한 텍스트도 선택 가능하게 맨 위에 표시
                        if (val.isNotEmpty &&
                            !filtered.any(
                              (l) => l.toLowerCase() == val.toLowerCase(),
                            )) {
                          filtered.insert(0, val.trim());
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final lang = filtered[i];
                      final alreadyAdded = widget.selectedLanguageLevels
                          .containsKey(lang);
                      return ListTile(
                        leading: Icon(
                          Icons.language,
                          color: alreadyAdded
                              ? Colors.grey
                              : AppColors.travelingBlue,
                        ),
                        title: Text(lang),
                        trailing: alreadyAdded
                            ? const Icon(Icons.check, color: Colors.grey)
                            : const Icon(
                                Icons.add,
                                color: AppColors.travelingBlue,
                              ),
                        onTap: alreadyAdded
                            ? null
                            : () {
                                // 목록에 없는 직접 입력 언어면 _allLanguages에도 추가
                                if (!_allLanguages.contains(lang)) {
                                  setState(() => _allLanguages.add(lang));
                                }
                                setState(() {
                                  widget.selectedLanguageLevels[lang] = 3;
                                });
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

  // ✅ GPS → 주소 변환 후 인덱스 0에 고정
  Future<void> _setCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) AppToast.error(context, '위치 권한이 필요합니다.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) AppToast.error(context, '설정에서 위치 권한을 허용해주세요.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isEmpty) return;

      final p = placemarks.first;
      final address = [
        p.administrativeArea,
        (p.subLocality?.isNotEmpty == true) ? p.subLocality : p.locality,
        (p.thoroughfare?.isNotEmpty == true)
            ? p.thoroughfare
            : p.subThoroughfare,
      ].where((e) => e != null && e!.isNotEmpty).join(' ');

      if (address.isEmpty) return;

      setState(() {
        if (widget.selectedLocations.isEmpty) {
          widget.selectedLocations.add(address);
        } else {
          widget.selectedLocations[0] = address;
        }
      });
      widget.onChanged();
      if (mounted) AppToast.success(context, '현재 위치 등록: $address');
    } catch (e) {
      if (mounted) AppToast.error(context, '위치를 가져오지 못했습니다.');
    }
  }

  // ✅ 지역 검색 BottomSheet
  void _showLocationSearchSheet() {
    if (widget.selectedLocations.length >= 3) {
      AppToast.error(context, '활동 지역은 최대 3개까지 설정 가능합니다.');
      return;
    }

    final searchController = TextEditingController();
    final suggestions = [
      '서울 종로구',
      '서울 마포구',
      '서울 홍대',
      '서울 명동',
      '서울 이태원',
      '부산 해운대',
      '부산 광안리',
      '제주 성산',
      '제주 협재',
      '경주 황리단길',
      '전주 한옥마을',
      '강릉 안목해변',
    ];
    List<String> filtered = List.from(suggestions);

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
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  '지역 검색',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '지역명 검색 (예: 홍대, 해운대)',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setSheet(() {
                        filtered = val.isEmpty
                            ? List.from(suggestions)
                            : suggestions
                                  .where((s) => s.contains(val))
                                  .toList();
                        if (val.isNotEmpty && !filtered.contains(val)) {
                          filtered.insert(0, val);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final loc = filtered[i];
                      final alreadyAdded = widget.selectedLocations.contains(
                        loc,
                      );
                      return ListTile(
                        leading: Icon(
                          Icons.place_outlined,
                          color: alreadyAdded
                              ? Colors.grey
                              : AppColors.travelingBlue,
                        ),
                        title: Text(loc),
                        trailing: alreadyAdded
                            ? const Icon(Icons.check, color: Colors.grey)
                            : null,
                        onTap: alreadyAdded
                            ? null
                            : () {
                                setState(
                                  () => widget.selectedLocations.add(loc),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "🏠 가이드 등록 정보",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 15),

          _buildLocationSection(),
          const SizedBox(height: 20),

          const Text(
            "🏠 거주 및 소개",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _inputField(widget.residenceController, "거주 기간 (예: 10년 토박이)"),
          const SizedBox(height: 10),
          _inputField(
            widget.guideBioController,
            "가이드로서 줄 수 있는 도움",
            maxLines: 4,
          ),

          const SizedBox(height: 30),
          const Text(
            "🗣️ 구사 가능 언어 레벨",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildLanguageLevels(),

          const SizedBox(height: 30),
          const Text(
            "🎯 나의 전문 분야",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['맛집', '카페', '야경', '역사', '쇼핑', '액티비티']
                .map(
                  (s) => FilterChip(
                    label: Text(s),
                    selectedColor: AppColors.travelingBlue.withOpacity(0.2),
                    checkmarkColor: AppColors.travelingBlue,
                    selected: widget.selectedSpecialties.contains(s),
                    onSelected: (v) {
                      setState(() {
                        v
                            ? widget.selectedSpecialties.add(s)
                            : widget.selectedSpecialties.remove(s);
                      });
                      widget.onChanged();
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    final homeLocation = widget.selectedLocations.isNotEmpty
        ? widget.selectedLocations[0]
        : null;
    final extraLocations = widget.selectedLocations.length > 1
        ? widget.selectedLocations.sublist(1)
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "활동 지역 (최대 3개)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (widget.selectedLocations.length < 3)
              TextButton.icon(
                onPressed: _showLocationSearchSheet,
                icon: const Icon(
                  Icons.add_location_alt_outlined,
                  size: 16,
                  color: AppColors.travelingBlue,
                ),
                label: const Text(
                  '지역 추가',
                  style: TextStyle(
                    color: AppColors.travelingBlue,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildHomeSlot(homeLocation),
        const SizedBox(height: 8),
        if (extraLocations.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: extraLocations
                .map(
                  (loc) => InputChip(
                    avatar: const Icon(
                      Icons.place,
                      size: 14,
                      color: AppColors.travelingBlue,
                    ),
                    label: Text(loc, style: const TextStyle(fontSize: 12)),
                    onDeleted: () {
                      setState(() => widget.selectedLocations.remove(loc));
                      widget.onChanged();
                    },
                    deleteIconColor: Colors.redAccent,
                    backgroundColor: AppColors.travelingBlue.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: AppColors.travelingBlue.withOpacity(0.3),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildHomeSlot(String? location) {
    return GestureDetector(
      onTap: _setCurrentLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: location != null
              ? AppColors.travelingBlue.withOpacity(0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: location != null
                ? AppColors.travelingBlue.withOpacity(0.4)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.home_outlined,
              size: 20,
              color: location != null ? AppColors.travelingBlue : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '우리동네',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    location ?? '탭해서 현재 위치 등록',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: location != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.my_location,
              size: 18,
              color: location != null
                  ? AppColors.travelingBlue
                  : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 언어 레벨 섹션 - 추가 버튼 포함
  Widget _buildLanguageLevels() {
    final activeLanguages = widget.selectedLanguageLevels.keys.toList();

    return Column(
      children: [
        // 선택된 언어 목록
        ...activeLanguages.map(
          (lang) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                ListTile(
                  title: Text(lang, style: const TextStyle(fontSize: 14)),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      setState(
                        () => widget.selectedLanguageLevels.remove(lang),
                      );
                      widget.onChanged();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      const Text(
                        "레벨 ",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Expanded(
                        child: Slider(
                          value: widget.selectedLanguageLevels[lang]!
                              .toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          activeColor: AppColors.travelingBlue,
                          onChanged: (v) {
                            setState(
                              () => widget.selectedLanguageLevels[lang] = v
                                  .toInt(),
                            );
                            widget.onChanged();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          "Lv.${widget.selectedLanguageLevels[lang]}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.travelingBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ✅ 언어 추가 버튼
        TextButton.icon(
          onPressed: _showAddLanguageSheet,
          icon: const Icon(Icons.add, color: AppColors.travelingBlue),
          label: const Text(
            '언어 추가',
            style: TextStyle(color: AppColors.travelingBlue),
          ),
          style: TextButton.styleFrom(
            backgroundColor: AppColors.travelingBlue.withOpacity(0.07),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ],
    );
  }

  Widget _inputField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}
