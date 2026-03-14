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
  bool _isTravelerMode = true;
  bool _isEnd = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  /// ✅ 핵심: 데이터를 서비스(fetchTravelRequests)를 통해 확실히 긁어옵니다.
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

        if (!mounted) return;

        _isTravelerMode = userData['last_mode'] == 'traveler';

        if (_isTravelerMode) {
          // 1. 여행자 모드: 가이드 리스트 로드
          _users = await _discoverService.fetchMates(isTravelerMode: true);
        } else {
          // 2. 가이드 모드: 여행 공고 리스트 로드 (조인된 offers 데이터 포함)
          // 💡 여기서 fetchTravelRequests를 호출해야 0/5 숫자가 나옵니다!
          _requests = await _discoverService.fetchTravelRequests();
        }
      }
    } catch (e) {
      if (mounted) debugPrint('❌ 데이터 초기화 실패: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void refreshData() {
    _initializeData();
  }

  void _goToDetail(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiscoverDetailPage(
          user: user,
          onSwipeAction: (direction) async {
            if (direction == 'left') {
              _controller.swipe(CardSwiperDirection.left);
            } else {
              await _discoverService.sendLike(user['id'].toString());
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isTravelerMode
            ? (_isEnd ? _buildEndView() : _buildTravelerModeView())
            : _buildGuideModeView(), // 가이드 모드 호출
      ),
    );
  }

  // 🏷 상단 앱바
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
    );
  }

  // 1. 여행자 모드 (카드 스와이프)
  Widget _buildTravelerModeView() {
    return TravelerDiscoverView(
      users: _users,
      controller: _controller,
      onEnd: () => setState(() => _isEnd = true),
      onSwipe: (index) => setState(() => _currentIndex = index),
      onDetailTap: (user) => _goToDetail(user),
      onActionBtnTap: (direction) async {
        if (direction == 'left') {
          _controller.swipe(CardSwiperDirection.left);
        } else {
          if (_users.isNotEmpty && _currentIndex < _users.length) {
            await _discoverService.sendLike(
              _users[_currentIndex]['id'].toString(),
            );
            _controller.swipe(CardSwiperDirection.right);
          }
        }
      },
    );
  }

  // 2. 가이드 모드 (리스트 형태)
  Widget _buildGuideModeView() {
    // 💡 StreamBuilder를 걷어내고, _initializeData에서 가져온 _requests를 직접 씁니다.
    return GuideDiscoverView(
      requests: _requests,
      onRefresh: () async {
        await _initializeData(); // 제안 후 돌아오면 다시 긁어와서 0/5 갱신!
      },
    );
  }

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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => _initializeData(),
            child: const Text("처음부터 다시 보기"),
          ),
        ],
      ),
    );
  }
}
