import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';

class AppTextStyles {
  // =====================================================
  // 🧭 Landing / Login (Figma 기준)
  // =====================================================
  static const TextStyle landingTitle = TextStyle(
    fontSize: 35,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25, // 줄간격 고정
    letterSpacing: -1.5,
  );

  static const TextStyle landingSubtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w300,
    color: AppColors.textSecondary,
    height: 1.5, // 줄간격 고정
    letterSpacing: -0.3,
  );

  // =====================================================
  // 🧭 Page / Section
  // =====================================================
  static const TextStyle pageTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textColor01,
    letterSpacing: -0.3,
  );

  static const TextStyle travelTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.textColor02,
    letterSpacing: -0.3,
  );

  static const TextStyle travelText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w100,
    color: AppColors.textColor02,
    letterSpacing: -0.5,
  );

  // =====================================================
  // ✍️ Body
  // =====================================================
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle bodyDisabled = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textDisabled,
  );

  // =====================================================
  // 🔘 Button (Theme용)
  // =====================================================
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.onPrimary,
  );

  static const TextStyle buttonOutline = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // =====================================================
  // 🏷 Small / Meta
  // =====================================================
  static const TextStyle caption = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // =========================
  // 🧳 Home 상태 카드
  // =========================
  static const statusTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: Colors.white,
  );

  static const statusSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w100,
    color: Colors.white70,
  );

  static const TextStyle listTitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w300,
    color: AppColors.textColor03,
  );

  // =====================================================
  // 🧳 Home Travel Status Header
  // =====================================================

  // 지역명 (굵게)
  static const TextStyle homeTravelLocation = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textColor02,
    letterSpacing: -0.3,
  );

  // "여행 중" 텍스트 (얇게)
  static const TextStyle homeTravelStatus = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w300,
    color: AppColors.textColor02,
    letterSpacing: -0.3,
  );

  // 여행 전 제목
  static const TextStyle homeTravelTitleIdle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: AppColors.textColor02,
    letterSpacing: -0.3,
  );

  // 날짜 / 일정
  static final TextStyle homeTravelDate = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w100,
    color: AppColors.textColor02.withOpacity(0.9),
    letterSpacing: -0.5,
  );

  // 설명
  static final TextStyle homeTravelInfo = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w200,
    color: AppColors.textColor02,
    letterSpacing: -0.5,
  );
}
