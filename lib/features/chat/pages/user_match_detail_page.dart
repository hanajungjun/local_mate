import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:localmate/core/constants/app_colors.dart';

class UserMatchDetailPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserMatchDetailPage({super.key, required this.user});

  @override
  State<UserMatchDetailPage> createState() => _UserMatchDetailPageState();
}

class _UserMatchDetailPageState extends State<UserMatchDetailPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _userRequests = [];
  bool _isLoadingRequests = true;

  @override
  void initState() {
    super.initState();
    _fetchUserRequests();
  }

  // ✅ 해당 유저의 여행 공고 중 '모집 중'인 것만 가져오기
  Future<void> _fetchUserRequests() async {
    try {
      final response = await _supabase
          .from('travel_requests')
          .select('*')
          .eq('writer_id', widget.user['id'])
          .eq('status', 'searching') // 👈 이 줄을 추가해서 모집 중인 공고만 필터링!
          .order('travel_at', ascending: false);

      if (mounted) {
        setState(() {
          _userRequests = List<Map<String, dynamic>>.from(response);
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      debugPrint("❌ 공고 로드 실패: $e");
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  // ✅ 맞좋아요(매칭) 처리
  // ✅ 매칭(좋아요) 처리 및 상대방에게 푸시 알림 발송
  Future<void> _handleMatch() async {
    try {
      // 1. DB에 맞좋아요 저장 (매칭 성사)
      await _supabase.from('likes').insert({
        'from_user_id': _supabase.auth.currentUser!.id,
        'to_user_id': widget.user['id'],
      });

      // 2. 상대방에게 매칭 성공 푸시 알림 발송
      // widget.user 안에 상대방의 fcm_token이 들어있어야 합니다.
      if (widget.user['fcm_token'] != null) {
        try {
          await _supabase.functions.invoke(
            'send-push',
            body: {
              'targetType': 'token',
              'targetValue': widget.user['fcm_token'],
              'title': '🎉 매칭 성공!',
              'body':
                  '${_supabase.auth.currentUser!.userMetadata?['nickname'] ?? "누군가"}님과 매칭되었습니다! 지금 대화를 시작해보세요.',
              'data': {
                'type': 'match', // 채팅 리스트의 채팅 탭으로 이동하게끔 설정
                'senderId': _supabase.auth.currentUser!.id,
              },
            },
          );
          debugPrint("🚀 매칭 푸시 발송 성공!");
        } catch (e) {
          debugPrint("❌ 푸시 발송 중 오류 (하지만 매칭은 성공): $e");
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("매칭 성공! 상대방에게 알림을 보냈습니다."),
            backgroundColor: Colors.blueAccent,
          ),
        );
        Navigator.pop(context); // 매칭 후 상세 페이지 닫기
      }
    } catch (e) {
      debugPrint("❌ 매칭 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("이미 매칭되었거나 오류가 발생했습니다.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        (widget.user['profile_image'] != null &&
            (widget.user['profile_image'] as List).isNotEmpty)
        ? widget.user['profile_image'][0]
        : null;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.user['nickname']}님의 프로필')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 큰 프로필 이미지
            Container(
              width: double.infinity,
              height: 350,
              decoration: BoxDecoration(
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Colors.grey[200],
              ),
              child: imageUrl == null
                  ? const Icon(Icons.person, size: 100, color: Colors.grey)
                  : null,
            ),

            // 2. 유저 기본 정보 섹션
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${widget.user['nickname']}, ${widget.user['age'] ?? '??'}세",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "📍 ${widget.user['nationality'] ?? '지구인'}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.user['bio'] ?? "자기소개가 아직 없어요.",
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),

            const Divider(thickness: 8, color: Color(0xFFF5F5F5)),

            // 3. 여행 공고 리스트 섹션
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "✈️ 이 메이트의 여행 계획",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingRequests)
                    const Center(child: CircularProgressIndicator())
                  else if (_userRequests.isEmpty)
                    const Text("등록된 공고가 없습니다.")
                  else
                    // 리스트 빌더 부분
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _userRequests.length,
                      itemBuilder: (context, index) {
                        final req = _userRequests[index];
                        // 날짜 포맷 (timestamp -> yyyy-MM-dd)
                        final travelDate = req['travel_at'] != null
                            ? req['travel_at'].toString().substring(0, 10)
                            : '날짜 미정';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(
                              Icons.flight_takeoff,
                              color: Colors.blue,
                            ),
                            title: Text(req['title'] ?? '제목 없음'),
                            subtitle: Text(
                              "📍 ${req['location_name'] ?? '장소 미정'} · 📅 $travelDate",
                            ),
                            trailing: Text(
                              "${req['headcount']}명",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 100), // 하단 버튼 공간
          ],
        ),
      ),
      // 4. 하단 고정 좋아요 버튼
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _handleMatch,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.travelingBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            "나도 좋아요! (매칭하기)",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
