import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';

class ProfileGuideTab extends StatelessWidget {
  final TextEditingController locationController;
  final TextEditingController residenceController;
  final TextEditingController guideBioController;
  final List<String> selectedSpecialties;
  final Map<String, int> selectedLanguageLevels;
  final VoidCallback onChanged;

  const ProfileGuideTab({
    super.key,
    required this.locationController,
    required this.residenceController,
    required this.guideBioController,
    required this.selectedSpecialties,
    required this.selectedLanguageLevels,
    required this.onChanged,
  });

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
          _inputField(locationController, "활동 지역 (예: 대구 수성구)"),
          const SizedBox(height: 10),
          _inputField(residenceController, "거주 기간 (예: 10년 토박이)"),
          const SizedBox(height: 10),
          _inputField(guideBioController, "가이드로서 줄 수 있는 도움", maxLines: 4),
          const SizedBox(height: 20),

          const Text(
            "🗣️ 구사 가능 언어 레벨",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildLanguageLevels(),

          const SizedBox(height: 20),
          const Text("나의 전문 분야", style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: ['맛집', '카페', '야경', '역사']
                .map(
                  (s) => FilterChip(
                    label: Text(s),
                    selected: selectedSpecialties.contains(s),
                    onSelected: (v) {
                      v
                          ? selectedSpecialties.add(s)
                          : selectedSpecialties.remove(s);
                      onChanged();
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageLevels() {
    final languages = ['한국어', 'English', '日本語', '中文'];
    return Column(
      children: languages.map((lang) {
        final hasLang = selectedLanguageLevels.containsKey(lang);
        return Column(
          children: [
            CheckboxListTile(
              title: Text(lang),
              value: hasLang,
              onChanged: (v) {
                v!
                    ? selectedLanguageLevels[lang] = 3
                    : selectedLanguageLevels.remove(lang);
                onChanged();
              },
            ),
            if (hasLang)
              Slider(
                value: selectedLanguageLevels[lang]!.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: "Lv.${selectedLanguageLevels[lang]}",
                activeColor: AppColors.travelingBlue,
                onChanged: (v) {
                  selectedLanguageLevels[lang] = v.toInt();
                  onChanged();
                },
              ),
          ],
        );
      }).toList(),
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
