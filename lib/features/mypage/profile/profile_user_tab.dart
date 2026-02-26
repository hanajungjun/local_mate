import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:localmate/core/constants/app_colors.dart';

class ProfileUserTab extends StatelessWidget {
  final TextEditingController nicknameController;
  final TextEditingController bioController;
  final TextEditingController ageController;
  final String? gender;
  final String? mbti;
  final List<String> selectedTravelStyles;
  final List<String> selectedLanguages;
  final List<AssetEntity> selectedAssets;
  final List<String> serverImageUrls;
  final VoidCallback onChanged;
  final Future<void> Function() onPickAssets; // 추가

  const ProfileUserTab({
    super.key,
    required this.nicknameController,
    required this.bioController,
    required this.ageController,
    required this.gender,
    required this.mbti,
    required this.selectedTravelStyles,
    required this.selectedLanguages,
    required this.selectedAssets,
    required this.serverImageUrls,
    required this.onChanged,
    required this.onPickAssets,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "프로필 사진 (최대 5장)",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildPhotoSection(),
          const SizedBox(height: 20),
          _inputField(nicknameController, "닉네임"),
          const SizedBox(height: 10),
          _buildGenderSelector(),
          const SizedBox(height: 10),
          _inputField(ageController, "나이", isNumber: true),
          const SizedBox(height: 10),
          _inputField(bioController, "자기소개", maxLines: 3),
          const SizedBox(height: 20),
          _buildChoiceChips("여행 스타일", [
            '사진',
            '맛집탐방',
            '쇼핑',
            '관광',
            '액티비티',
            '힐링',
          ], selectedTravelStyles),
          _buildChoiceChips("가능 언어", [
            '한국어',
            'English',
            '日本語',
            '中文',
          ], selectedLanguages),
          _buildMbtiDropdown(),
        ],
      ),
    );
  }

  // --- 내부 위젯들 ---
  Widget _buildPhotoSection() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: onPickAssets,
            child: Container(
              width: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Icon(Icons.add_a_photo, color: Colors.grey),
            ),
          ),
          ...selectedAssets.map((asset) => _assetItem(asset)),
          ...serverImageUrls.map((url) => _urlItem(url)),
        ],
      ),
    );
  }

  Widget _assetItem(AssetEntity asset) => Container(
    margin: const EdgeInsets.only(left: 10),
    width: 100,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AssetEntityImage(asset, isOriginal: false, fit: BoxFit.cover),
    ),
  );

  Widget _urlItem(String url) => Container(
    margin: const EdgeInsets.only(left: 10),
    width: 100,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
    ),
  );

  Widget _buildGenderSelector() {
    return Row(
      children: ['male', 'female'].map((val) {
        final isSel = gender == val;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton(
              onPressed: () {
                /* 부모 setState 호출 필요 */
                onChanged();
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: isSel ? AppColors.travelingBlue : Colors.white,
              ),
              child: Text(
                val == 'male' ? "남성" : "여성",
                style: TextStyle(color: isSel ? Colors.white : Colors.black),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChoiceChips(String title, List<String> opts, List<String> sel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        Wrap(
          spacing: 8,
          children: opts
              .map(
                (o) => FilterChip(
                  label: Text(o),
                  selected: sel.contains(o),
                  onSelected: (v) {
                    v ? sel.add(o) : sel.remove(o);
                    onChanged();
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildMbtiDropdown() {
    return DropdownButton<String>(
      value: mbti,
      isExpanded: true,
      hint: const Text("MBTI 선택"),
      items: [
        'ISTJ',
        'ENFP',
        'ENTJ',
        'INTJ',
      ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) {
        /* 부모 setState */
        onChanged();
      },
    );
  }

  Widget _inputField(
    TextEditingController ctrl,
    String hint, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
