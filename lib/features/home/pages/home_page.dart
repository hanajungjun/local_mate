import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/services/user_service.dart';
import 'package:localmate/services/profile_service.dart';
import 'travel_mode.dart';
import 'guide_mode.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onGoToTravel;
  final VoidCallback? onStartRequest;
  final VoidCallback? onStartGuide;
  final Function(bool isTraveler)? onModeChanged;

  const HomePage({
    super.key,
    required this.onGoToTravel,
    this.onStartRequest,
    this.onStartGuide,
    this.onModeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ✅ 현재 모드 상태 (true: 여행자, false: 가이드)
  bool _isTravelerMode = true;
  @override
  void initState() {
    super.initState();
    _loadUserMode(); // 시작할 때 마지막 모드 불러오기
  }

  // DB에서 마지막 모드 설정 가져오기
  Future<void> _loadUserMode() async {
    try {
      final profile = await ProfileService().getMyProfile();
      if (profile != null && profile['last_mode'] != null) {
        setState(() {
          _isTravelerMode = profile['last_mode'] == 'traveler';
        });
      }
    } catch (e) {
      debugPrint("모드 로딩 실패: $e");
    }
  }

  // 모드 전환 및 DB 저장
  Future<void> _toggleMode(bool travelerMode) async {
    if (_isTravelerMode == travelerMode) return;

    setState(() => _isTravelerMode = travelerMode);

    try {
      await UserService().updateLastMode(travelerMode ? 'traveler' : 'guide');
      // ✅ 추가: 부모 위젯(MainScreen)에게 모드가 바뀌었다고 알림
      if (widget.onModeChanged != null) {
        widget.onModeChanged!(travelerMode);
      }
    } catch (e) {
      debugPrint("모드 저장 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. [고정] 상단 헤더
            _buildCustomHeader(),

            // 2. [고정] 모드 전환 토글 탭
            _buildModeToggle(),

            // 3. [가변] 모드에 따라 스위칭되는 메인 뷰
            Expanded(
              child: SingleChildScrollView(
                child: _isTravelerMode
                    ? TravelMode(onStartRequest: widget.onStartRequest)
                    : GuideMode(onStartGuide: widget.onStartGuide),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 상단 헤더
  Widget _buildCustomHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(27, 20, 27, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Local Mate",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.travelingBlue,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, size: 28),
          ),
        ],
      ),
    );
  }

  // 여행자/가이드 모드 전환 토글
  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 15),
      child: Container(
        height: 54,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _buildToggleItem(
              "여행자 모드",
              _isTravelerMode,
              AppColors.travelingBlue,
              () => _toggleMode(true), // ✅ 수정
            ),
            _buildToggleItem(
              "가이드 모드",
              !_isTravelerMode,
              AppColors.travelingPurple,
              () => _toggleMode(false), // ✅ 수정
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(
    String title,
    bool isActive,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
