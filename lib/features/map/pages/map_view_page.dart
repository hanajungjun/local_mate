import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MapViewPage extends StatefulWidget {
  const MapViewPage({super.key});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  GoogleMapController? _controller;
  LatLng? _currentPosition;
  final Set<Marker> _markers = {};

  // 💡 DB에서 가져올 광고 가이드와 일반 메이트 리스트
  List<Map<String, dynamic>> _adGuides = [];
  List<Map<String, dynamic>> _generalMates = [];

  @override
  void initState() {
    super.initState();
    _initMapData();
  }

  // 📍 위치 권한 확인 및 데이터 로드 통합
  Future<void> _initMapData() async {
    await _determinePosition();
    await _loadMatesFromDB(); // 👈 이제 진짜 DB에서 긁어옵니다.
  }

  Future<void> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    }
  }

  // 📍 DB(Supabase)에서 위치와 광고 정보가 포함된 데이터 로드
  Future<void> _loadMatesFromDB() async {
    final supabase = Supabase.instance.client;

    try {
      // 1. 가이드 테이블에서 위경도와 광고 레벨이 있는 데이터 가져오기
      final data = await supabase
          .from('guides')
          .select('*, users(*)')
          .not('latitude', 'is', null);

      List<Map<String, dynamic>> fetchedGuides =
          List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          // 2. 광고 레벨에 따라 리스트 분리
          _adGuides = fetchedGuides
              .where((g) => (g['ad_level'] ?? 0) > 0)
              .toList();
          _generalMates = fetchedGuides
              .where((g) => (g['ad_level'] ?? 0) == 0)
              .toList();

          // 3. 지도 마커 찍기
          _markers.clear();
          for (var guide in fetchedGuides) {
            _markers.add(
              Marker(
                markerId: MarkerId(guide['id'].toString()),
                position: LatLng(guide['latitude'], guide['longitude']),
                icon: (guide['ad_level'] ?? 0) > 0
                    ? BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange,
                      ) // 광고는 오렌지색
                    : BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                onTap: () => _showMateInfo(guide),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint("데이터 로드 에러: $e");
    }
  }

  void _showMateInfo(Map<String, dynamic> guide) {
    final user = guide['users'];
    final List<dynamic> interests = user['interests'] ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // 배경 투명하게 해서 커스텀 디자인 강조
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. 프로필 상단 (프사 + 이름 + 광고배지)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundImage: NetworkImage(user['profile_image'][0]),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                user['nickname'],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if ((guide['ad_level'] ?? 0) > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text(
                                    "AD",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            "${user['location_name']} • ${user['age']}세",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.favorite_border,
                        color: Colors.pink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // 2. 가이드 한줄 소개
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    guide['guide_bio'] ?? user['bio'] ?? "반가워요! 등촌동 메이트입니다.",
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 15),

                // 3. 관심사 태그
                Wrap(
                  spacing: 8,
                  children: interests
                      .map(
                        (item) => Chip(
                          label: Text(
                            item,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.blue[50],
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),

                // 4. 액션 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // 💡 여기서 채팅방 개설 로직 연결!
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      "메시지 보내기",
                      style: TextStyle(
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
      },
    );
  }

  static const LatLng _dongchonDong = LatLng(37.5518, 126.8489);

  @override
  Widget build(BuildContext context) {
    // 💡 화면 전체 높이를 변수에 담아두면 계산하기 편합니다.
    final screenHeight = MediaQuery.of(context).size.height;
    final initialSheetSize = 0.3; // 하단 시트의 초기 비율

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Local Mates Around Me',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 1. 전체 화면 지도
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    //target: _currentPosition!,
                    target: _dongchonDong,
                    zoom: 13.0,
                  ),
                  onMapCreated: (controller) => _controller = controller,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false, // 커스텀 버튼 사용을 위해 끔
                  markers: _markers,
                ),

                // 2. 💡 내 위치 찾기 버튼 (MediaQuery 적용)
                Positioned(
                  // 하단 시트 시작 높이(screenHeight * 0.3)에 여유 공간(16)을 더함
                  bottom: (screenHeight * initialSheetSize) + 16,
                  right: 16,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    mini: true,
                    elevation: 4, // 그림자 추가해서 좀 더 입체적으로
                    onPressed: _moveToCurrentPosition,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),

                // 3. 시나리오 2: 드래그 가능한 리스트 시트
                DraggableScrollableSheet(
                  initialChildSize: initialSheetSize,
                  minChildSize: 0.15,
                  maxChildSize: 0.9,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(blurRadius: 10, color: Colors.black12),
                        ],
                      ),
                      child: ListView(
                        controller: scrollController,
                        children: [
                          _buildHandle(),

                          // 💡 광고 슬롯: 리스트 최상단 가로 슬라이더
                          if (_adGuides.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(
                                left: 16,
                                bottom: 8,
                                top: 8,
                              ),
                              child: Text(
                                "오늘의 추천 가이드 (AD)",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _buildAdSlider(),
                            const Divider(),
                          ],

                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              "내 주변 메이트",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildGeneralList(),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  // 📍 내 현재 위치로 카메라 이동시키는 함수
  Future<void> _moveToCurrentPosition() async {
    if (_controller == null) return;

    // 다시 한 번 최신 위치를 잡고 이동합니다.
    Position position = await Geolocator.getCurrentPosition();
    _controller!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        15.0, // 줌 레벨 살짝 당겨주기
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // 🎯 광고 카드 슬라이더
  Widget _buildAdSlider() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _adGuides.length,
        itemBuilder: (context, index) {
          final guide = _adGuides[index];
          final user = guide['users'];
          return Container(
            width: 260,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              image: DecorationImage(
                image: NetworkImage(user['profile_image'][0]),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.3),
                  BlendMode.darken,
                ),
              ),
            ),
            padding: const EdgeInsets.all(12),
            alignment: Alignment.bottomLeft,
            child: Text(
              user['nickname'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          );
        },
      ),
    );
  }

  // 🎯 일반 리스트
  Widget _buildGeneralList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _generalMates.length,
      itemBuilder: (context, index) {
        final mate = _generalMates[index];
        final user = mate['users'];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(user['profile_image'][0]),
          ),
          title: Text(user['nickname']),
          subtitle: Text(user['bio'] ?? "반가워요!"),
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }
}
