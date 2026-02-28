import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/services/discover_service.dart'; // 서비스 호출용

class GuideDiscoverView extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final VoidCallback onRefresh;

  const GuideDiscoverView({
    super.key,
    required this.requests,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(child: Text("현재 올라온 여행 공고가 없어요."));
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) =>
            _buildRequestCard(context, requests[index]),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> req) {
    final writer = req['users'];

    // 1. 현재 제안 개수 파악 (Supabase 쿼리 결과에 따라 구조가 다를 수 있으니 안전하게 처리)
    final int offerCount =
        (req['offers'] != null && (req['offers'] as List).isNotEmpty)
        ? req['offers'][0]['count']
        : 0;

    // 2. 5건 이상이면 마감 상태로 판정
    final bool isFull = offerCount >= 5;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(
                    (writer['profile_image'] != null &&
                            (writer['profile_image'] as List).isNotEmpty)
                        ? writer['profile_image'][0].toString()
                        : 'https://picsum.photos/100',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "${writer['nickname']} • ${req['companion_type']}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  "${req['budget']} P",
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Text(
              req['title'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              req['content'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                // ✅ 3. 마감 상태면 null을 전달하여 버튼을 비활성화 시킵니다.
                onPressed: isFull ? null : () => _showOfferModal(context, req),
                style: ElevatedButton.styleFrom(
                  // ✅ 4. 마감 상태일 때의 배경색 처리
                  backgroundColor: isFull
                      ? Colors.grey.shade400
                      : AppColors.travelingBlue,
                  disabledBackgroundColor: Colors.grey.shade300, // 비활성화 시 배경색
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  // ✅ 5. 텍스트에 현재 제안 개수 표시
                  isFull
                      ? "제안 마감 ($offerCount/5)"
                      : "가이드 제안 보내기 ($offerCount/5)",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✉️ 제안서 작성 팝업 (BottomSheet)
  void _showOfferModal(BuildContext context, Map<String, dynamic> req) {
    // 공고의 예산을 기본 제안가로 세팅
    final TextEditingController priceController = TextEditingController(
      text: req['budget']?.toString(),
    );
    final TextEditingController messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 키보드가 올라올 때 화면이 가려지지 않게 함
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20, // 키보드 높이만큼 패딩
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "가이드 제안하기",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "${req['title']} 공고에 대한 제안입니다.",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "제안 금액 (Point)",
                suffixText: "P",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "여행자에게 보낼 메시지",
                hintText: "어떤 코스로 가이드 해주실 건가요?",
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  // 1. 함수 호출 (String? 결과를 받음)
                  final resultMessage = await DiscoverService().sendOffer(
                    requestId: req['id'],
                    price: int.tryParse(priceController.text) ?? 0,
                    message: messageController.text,
                  );

                  // 2. 결과 체크: 에러 메시지가 없으면(null이면) 성공!
                  if (resultMessage == null) {
                    if (context.mounted) {
                      Navigator.pop(context); // 팝업 닫기
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("✅ 제안을 성공적으로 보냈습니다!")),
                      );
                    }
                  } else {
                    // 3. 에러 메시지가 있으면(5건 초과 등) 메시지 출력
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(resultMessage)));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.travelingBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "제안 전송하기",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
