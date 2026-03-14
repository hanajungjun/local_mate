import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:localmate/services/discover_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'traveler_discover_view.dart';
import 'guide_discover_view.dart';
import 'discover_detail_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => DiscoverPageState();
}

class DiscoverPageState extends State<DiscoverPage> {
  final DiscoverService _discoverService = DiscoverService();
  final CardSwiperController _controller = CardSwiperController();

  // 데이터 상태
  List<Map<String, dynamic>> _users = []; // 여행자 모드 (가이드 리스트)
  List<Map<String, dynamic>> _requests = []; // 가이드 모드 (여행 공고 리스트)

  bool _isLoading = true;
  bool _isTravelerMode = true; // 현재 유저의 모드
  bool _isEnd = false; // ✅ 카드가 모두 끝났는지 체크하는 상태 변수
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  /// ✅ 초기 데이터 로드: 모드 확인 및 상태 초기화 후 데이터 호출
  Future<void> _initializeData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isEnd = false;
      _currentIndex = 0;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user != null) {
        final userData = await supabase
            .from('users')
            .select('last_mode')
            .eq('id', user.id)
            .single();

        // 🔥 핵심: 여기서도 await 이후에 체크
        if (!mounted) return;

        _isTravelerMode = userData['last_mode'] == 'traveler';

        if (_isTravelerMode) {
          final fetchedUsers = await _discoverService.fetchMates(
            isTravelerMode: true,
          );
          if (!mounted) return; // 다시 체크
          setState(() {
            _users = fetchedUsers;
          });
        } else {
          final fetchedRequests = await _discoverService.fetchTravelRequests();
          if (!mounted) return; // 다시 체크
          setState(() {
            _requests = fetchedRequests;
          });
        }
      }
    } catch (e) {
      // 🔥 catch 블록 안에서도 setState가 있다면 mounted 체크 필수
      if (mounted) {
        debugPrint('❌ 데이터 초기화 실패: $e');
      }
    } finally {
      // 마지막 로딩 해제 시점에도 체크
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ [추가] 외부(AppShell)에서 이 키를 통해 호출할 수 있도록 공개 함수를 만듭니다.
  void refreshData() {
    debugPrint("🔄 DiscoverPage: 외부 요청으로 데이터를 새로고침합니다.");
    _initializeData(); // 기존에 만들어둔 데이터 로드 함수 실행
  }

  /// 🔍 상세 페이지 이동 로직 (DiscoverPage 내부)
  void _goToDetail(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiscoverDetailPage(
          user: user,
          onSwipeAction: (direction) async {
            // ✅ async 추가
            if (direction == 'left') {
              _controller.swipe(CardSwiperDirection.left);
            } else {
              // ❤️ [추가] 상세 페이지에서 좋아요 눌렀을 때도 알림 발송!
              try {
                // 1. DB 저장
                await _discoverService.sendLike(user['id'].toString());

                // 2. 푸시 발송 (Edge Function 호출)
                await Supabase.instance.client.functions.invoke(
                  'send-push',
                  body: {
                    'targetType': 'token',
                    'targetValue': user['fcm_token'], // 대상자 토큰
                    'title': '❤️ 새로운 좋아요!',
                    'body': '상세 프로필을 본 유저가 형님을 찜했습니다!',
                    'data': {
                      'type': 'like',
                      'senderId': Supabase.instance.client.auth.currentUser?.id,
                    },
                  },
                );
                debugPrint("🚀 상세페이지 좋아요 푸시 발송 성공!");
              } catch (e) {
                debugPrint("❌ 상세페이지 푸시 발송 실패: $e");
              }

              _controller.swipe(CardSwiperDirection.right);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // 부드러운 배경색
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isTravelerMode
            ? (_isEnd
                  ? _buildEndView() // 다 확인했을 때의 안내 화면
                  : TravelerDiscoverView(
                      users: _users,
                      controller: _controller,
                      // ✅ 이 부분이 빠져서 에러가 났던 거예요!
                      onEnd: () {
                        setState(() => _isEnd = true);
                      },
                      onSwipe: (index) => setState(() => _currentIndex = index),
                      onDetailTap: (user) => _goToDetail(user),
                      onActionBtnTap: (direction) async {
                        if (direction == 'left') {
                          _controller.swipe(CardSwiperDirection.left);
                        } else {
                          // 👉 오른쪽 스와이프 (좋아요) 처리
                          if (_users.isNotEmpty &&
                              _currentIndex < _users.length) {
                            final target =
                                _users[_currentIndex]; // 좋아요 누른 대상자 정보

                            // 1. DB에 좋아요 기록 저장
                            await _discoverService.sendLike(
                              target['id'].toString(),
                            );

                            // 2. 상대방에게 실시간 푸시 발송 (Edge Function 호출)
                            try {
                              await Supabase.instance.client.functions.invoke(
                                'send-push',
                                body: {
                                  'targetType': 'token', // 또는 특정 유저 토픽
                                  'targetValue':
                                      target['fcm_token'], // 👈 대상자의 FCM 토큰
                                  'title': '❤️ 새로운 좋아요!',
                                  'body': '누군가 형님을 가이드로 선택하고 싶어 해요!',
                                  'data': {
                                    'type': 'like',
                                    'senderId': Supabase
                                        .instance
                                        .client
                                        .auth
                                        .currentUser
                                        ?.id,
                                  },
                                },
                              );
                              debugPrint("🚀 상대방에게 좋아요 푸시 발송 성공!");
                            } catch (e) {
                              debugPrint("❌ 푸시 발송 실패: $e");
                            }

                            _controller.swipe(CardSwiperDirection.right);
                          }
                        }
                      },
                    ))
            : GuideDiscoverView(
                requests: _requests,
                onRefresh: _initializeData,
              ),
      ),
    );
  }

  /// 🏷 상단 앱바 (현재 모드 표시)
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _isTravelerMode ? "가이드 찾기" : "여행 공고",
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      backgroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      // 필요한 경우 모드 전환 버튼이나 필터를 여기에 추가 가능
    );
  }

  /// 🏁 모든 카드를 다 확인했을 때 보여줄 안내 화면
  Widget _buildEndView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 20),
          const Text(
            "모든 메이트를 확인했어요!",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "새로운 메이트가 나타날 때까지 기다려보세요.",
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              // 💡 다시 처음부터 데이터를 불러오거나 상태를 초기화합니다.
              _initializeData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              "처음부터 다시 보기",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
