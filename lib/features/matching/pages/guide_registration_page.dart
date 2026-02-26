import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';

class GuideRegistrationPage extends StatefulWidget {
  const GuideRegistrationPage({super.key});

  @override
  State<GuideRegistrationPage> createState() => _GuideRegistrationPageState();
}

class _GuideRegistrationPageState extends State<GuideRegistrationPage> {
  bool _isSubmitted = false; // 신청 완료 여부 상태

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "가이드 등록",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isSubmitted ? _buildPendingStatus() : _buildRegistrationForm(),
    );
  }

  // 폼 입력 화면
  Widget _buildRegistrationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(27.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "로컬메이트 가이드가 되어\n특별한 여행을 제안해 보세요! ✨",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 30),

          _buildUploadSection(
            title: "자격증 인증 (선택)",
            description: "관광통역안내사 등 관련 자격증이 있다면 업로드해주세요.",
            icon: Icons.badge_outlined,
          ),

          const SizedBox(height: 25),

          _buildUploadSection(
            title: "본인 확인 사진 (필수)",
            description: "신뢰도 높은 활동을 위해 본인 얼굴이 잘 나오는 사진을 올려주세요.",
            icon: Icons.camera_alt_outlined,
            isRequired: true,
          ),

          const SizedBox(height: 50),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () {
                // 실제로는 여기서 API 호출을 진행합니다.
                setState(() {
                  _isSubmitted = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.travelingPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                "가이드 신청하기",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 승인 대기 화면
  Widget _buildPendingStatus() {
    return Padding(
      // Center 대신 Padding 위젯으로 감싸서 여백을 줍니다.
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.hourglass_empty_rounded,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            const Text(
              "가이드 승인 대기 중",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "관리자가 제출하신 서류를 검토 중입니다.\n승인까지 평일 기준 1~2일이 소요될 수 있습니다.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "홈으로 돌아가기",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection({
    required String title,
    required String description,
    required IconData icon,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (isRequired)
              const Text(" *", style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 15),
        GestureDetector(
          onTap: () {
            // TODO: 이미지 피커 연결
          },
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.grey[300]!,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.grey[400], size: 30),
                const SizedBox(height: 8),
                Text("파일 업로드", style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
