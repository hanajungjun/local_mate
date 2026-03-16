import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TourDetailPage extends StatefulWidget {
  final Map<String, dynamic> tourData;

  const TourDetailPage({super.key, required this.tourData});

  @override
  State<TourDetailPage> createState() => _TourDetailPageState();
}

class _TourDetailPageState extends State<TourDetailPage> {
  final supabase = Supabase.instance.client;
  late TextEditingController _memoController;

  @override
  void initState() {
    super.initState();
    // 💡 기존 메모 데이터가 있으면 넣어줍니다.
    _memoController = TextEditingController(
      text: widget.tourData['user_memo'] ?? '',
    );
  }

  // 📝 메모 저장 로직 (나갈 때나 입력할 때 호출)
  Future<void> _saveMemo(String text) async {
    try {
      await supabase
          .from('offers')
          .update({'user_memo': text})
          .eq('id', widget.tourData['id']);
    } catch (e) {
      debugPrint("❌ 메모 저장 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide = widget.tourData['users'] ?? {};
    final request = widget.tourData['travel_requests'] ?? {};

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "확정된 투어 정보",
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 가이드 프로필 카드
            _buildGuideHeader(guide),
            const SizedBox(height: 30),

            // 2. 확정 일시 (크고 시원하게!)
            const Text(
              "투어 일정",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.travelingBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${widget.tourData['meeting_date']}",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.travelingBlue,
                    ),
                  ),
                  Text(
                    "${widget.tourData['meeting_time']} 시작",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 3. 가이드의 제안 메시지
            const Text(
              "가이드의 한마디",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "${widget.tourData['message']}",
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),

            const Divider(height: 60),

            // 4. 나만의 메모장
            Row(
              children: [
                const Icon(Icons.edit_note, color: Colors.orange),
                const SizedBox(width: 5),
                const Text(
                  "나만의 투어 메모",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              maxLines: 5,
              onChanged: (text) => _saveMemo(text), // 💡 입력할 때마다 실시간 저장!
              decoration: InputDecoration(
                hintText: "준비물이나 가이드님께 물어볼 내용을 적어보세요.",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // 5. 채팅방으로 바로가기 버튼
            SizedBox(
              width: double.infinity,
              height: 55,
              child: // TourDetailPage.dart 하단 버튼 부분
              ElevatedButton(
                onPressed: () {
                  // 채팅방 이동 로직
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.travelingBlue,
                  // 💡 아래 부분이 수정된 포인트입니다!
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15), // 요렇게 담아줘야 합니다
                  ),
                ),
                child: const Text(
                  "가이드와 채팅하기",
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
      ),
    );
  }

  Widget _buildGuideHeader(Map<String, dynamic> guide) {
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundImage: guide['profile_image'] != null
              ? NetworkImage(guide['profile_image'])
              : null,
          child: guide['profile_image'] == null
              ? const Icon(Icons.person)
              : null,
        ),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${guide['nickname']} 메이트",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text(
              "현지 전문 가이드",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }
}
