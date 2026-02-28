import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';

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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {}, // 제안하기 로직
                child: const Text("가이드 제안 보내기"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
