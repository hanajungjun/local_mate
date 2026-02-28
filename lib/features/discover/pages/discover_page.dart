import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:localmate/services/discover_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 💡 분리한 뷰 파일들을 import 해주세요 (파일명 확인 필수!)
import 'traveler_discover_view.dart';
import 'guide_discover_view.dart';
import 'discover_detail_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
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

    // 1. 로딩 시작 및 모든 상태 초기화 (매우 중요!)
    setState(() {
      _isLoading = true;
      _isEnd = false; // ✅ '다 확인함' 상태를 풀어줘야 카드가 다시 보입니다.
      _currentIndex = 0; // ✅ 인덱스도 처음으로 되돌립니다.
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user != null) {
        // 유저의 현재 모드(last_mode) 확인
        final userData = await supabase
            .from('users')
            .select('last_mode')
            .eq('id', user.id)
            .single();

        _isTravelerMode = userData['last_mode'] == 'traveler';
      }

      // 2. 모드에 맞는 데이터 가져오기
      if (_isTravelerMode) {
        _users = await _discoverService.fetchMates(isTravelerMode: true);
        debugPrint('✅ 여행자 모드: ${_users.length}명의 메이트 로드 완료');
      } else {
        _requests = await _discoverService.fetchTravelRequests();
        debugPrint('✅ 가이드 모드: ${_requests.length}개의 공고 로드 완료');
      }
    } catch (e) {
      debugPrint('❌ 데이터 초기화 실패: $e');
    } finally {
      // 3. 로딩 종료 및 화면 갱신
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 🔍 상세 페이지 이동 로직
  void _goToDetail(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiscoverDetailPage(
          user: user,
          onSwipeAction: (direction) {
            if (direction == 'left') {
              _controller.swipe(CardSwiperDirection.left);
            } else {
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
                          if (_users.isNotEmpty &&
                              _currentIndex < _users.length) {
                            final target = _users[_currentIndex];
                            await _discoverService.sendLike(
                              target['id'].toString(),
                            );
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
