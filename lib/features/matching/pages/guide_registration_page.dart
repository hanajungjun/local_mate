import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/services/user_service.dart';

class GuideRegistrationPage extends StatefulWidget {
  const GuideRegistrationPage({super.key});

  @override
  State<GuideRegistrationPage> createState() => _GuideRegistrationPageState();
}

class _GuideRegistrationPageState extends State<GuideRegistrationPage> {
  bool _isSubmitted = false;
  bool _isLoading = false;

  // 📸 이미지 파일 변수
  File? _profileImage;
  File? _certImage;

  final ImagePicker _picker = ImagePicker();

  // 🖼️ 이미지 선택 함수
  Future<void> _pickImage(bool isProfile) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // 용량 최적화
    );

    if (pickedFile != null) {
      setState(() {
        if (isProfile) {
          _profileImage = File(pickedFile.path);
        } else {
          _certImage = File(pickedFile.path);
        }
      });
    }
  }

  // 📤 신청 로직 연동
  Future<void> _submitRegistration() async {
    if (_profileImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("본인 확인 사진은 필수입니다!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // UserService의 실전 로직 호출
      await UserService().submitGuideRegistration(
        profileImage: _profileImage!,
        certImage: _certImage,
      );
      setState(() => _isSubmitted = true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("신청 중 오류가 발생했습니다: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

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

          // 자격증 인증 (선택)
          _buildUploadSection(
            title: "자격증 인증 (선택)",
            description: "관광통역안내사 등 관련 자격증이 있다면 업로드해주세요.",
            icon: Icons.badge_outlined,
            imageFile: _certImage,
            onTap: () => _pickImage(false),
          ),

          const SizedBox(height: 25),

          // 본인 확인 사진 (필수)
          _buildUploadSection(
            title: "본인 확인 사진 (필수)",
            description: "신뢰도 높은 활동을 위해 본인 얼굴이 잘 나오는 사진을 올려주세요.",
            icon: Icons.camera_alt_outlined,
            isRequired: true,
            imageFile: _profileImage,
            onTap: () => _pickImage(true),
          ),

          const SizedBox(height: 50),

          SSubmittingButton(
            isLoading: _isLoading,
            onPressed: _submitRegistration,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection({
    required String title,
    required String description,
    required IconData icon,
    required File? imageFile,
    required VoidCallback onTap,
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
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 180, // 미리보기를 위해 높이를 조금 키움
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: imageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(imageFile, fit: BoxFit.cover),
                  )
                : Column(
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

  // 승인 대기 화면 (형님 코드 유지)
  Widget _buildPendingStatus() {
    return Center(
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
            child: const Text("홈으로 돌아가기", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

// 로딩 상태를 포함한 버튼 위젯 분리
class SSubmittingButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const SSubmittingButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.travelingPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "가이드 신청하기",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
