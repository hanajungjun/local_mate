import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:local_mate/core/constants/app_colors.dart';
import 'package:local_mate/shared/styles/text_styles.dart';
import 'package:local_mate/storage_urls.dart';

class TravelCard extends StatelessWidget {
  final Map<String, dynamic> travel;
  final VoidCallback onTap;

  const TravelCard({super.key, required this.travel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final String city = travel['city'] ?? travel['region_name'] ?? 'Unknown';
    debugPrint('--- 📸 [TravelCard] Build Started for: $city ---');

    final isCompleted = travel['is_completed'] == true;

    // ✅ 새 규칙: DB에는 path, UI에서만 URL 생성
    final String? coverPath = travel['cover_image_url'];
    final String? coverUrl = coverPath != null
        ? StorageUrls.travelImage(coverPath)
        : null;

    debugPrint('🔗 [TravelCard] Final Image URL: $coverUrl');

    final DecorationImage image = isCompleted && coverUrl != null
        ? DecorationImage(
            image: NetworkImage(coverUrl),
            fit: BoxFit.cover,
            onError: (exception, stackTrace) {
              debugPrint('❌ [TravelCard] Image Load Error: $exception');
              debugPrint('❌ [TravelCard] Failed URL: $coverUrl');
            },
          )
        : const DecorationImage(
            image: AssetImage('assets/images/travel_placeholder.png'),
            fit: BoxFit.cover,
          );

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: image,
              ),
              child: isCompleted && coverUrl == null
                  ? const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'travel_with_city'.tr(args: [city]),
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: 6),
          Text(
            '${travel['start_date']} ~ ${travel['end_date']}',
            style: AppTextStyles.bodyMuted,
          ),
        ],
      ),
    );
  }
}
