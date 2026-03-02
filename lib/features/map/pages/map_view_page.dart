import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:localmate/core/utils/image_utils.dart';

class MapViewPage extends StatefulWidget {
  const MapViewPage({super.key});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  GoogleMapController? _controller;
  LatLng? _currentPosition;
  final Set<Marker> _markers = {};

  List<Map<String, dynamic>> _adGuides = [];
  List<Map<String, dynamic>> _generalMates = [];

  final Random _random = Random();

  // ✅ 좌표를 동네 수준으로 퍼뜨리는 함수 (±약 500m)
  LatLng _fuzzyLocation(double lat, double lng) {
    final latOffset = (_random.nextDouble() - 0.5) * 0.01;
    final lngOffset = (_random.nextDouble() - 0.5) * 0.01;
    return LatLng(lat + latOffset, lng + lngOffset);
  }

  @override
  void initState() {
    super.initState();
    _initMapData();
  }

  Future<void> _initMapData() async {
    await _determinePosition();
    await _loadMatesFromDB();
  }

  Future<void> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      // ✅ 내 위치도 퍼뜨려서 저장
      final fuzzy = _fuzzyLocation(position.latitude, position.longitude);
      setState(() {
        _currentPosition = fuzzy;
      });
    }
  }

  Future<void> _loadMatesFromDB() async {
    final supabase = Supabase.instance.client;

    try {
      final data = await supabase
          .from('guides')
          .select('*, users(*)')
          .not('latitude', 'is', null);

      List<Map<String, dynamic>> fetchedGuides =
          List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          _adGuides = fetchedGuides
              .where((g) => (g['ad_level'] ?? 0) > 0)
              .toList();
          _generalMates = fetchedGuides
              .where((g) => (g['ad_level'] ?? 0) == 0)
              .toList();

          _markers.clear();

          // ✅ 내 위치 마커도 퍼뜨려서 표시
          if (_currentPosition != null) {
            _markers.add(
              Marker(
                markerId: const MarkerId('my_location'),
                position: _currentPosition!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
                infoWindow: const InfoWindow(title: '나의 위치 (동네)'),
              ),
            );
          }

          // ✅ 다른 가이드 마커도 퍼뜨려서 표시
          for (var guide in fetchedGuides) {
            final fuzzyPos = _fuzzyLocation(
              guide['latitude'],
              guide['longitude'],
            );
            _markers.add(
              Marker(
                markerId: MarkerId(guide['id'].toString()),
                position: fuzzyPos,
                icon: (guide['ad_level'] ?? 0) > 0
                    ? BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange,
                      )
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
      backgroundColor: Colors.transparent,
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
                Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundImage: NetworkImage(
                        getProfileImage(user['profile_image']),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                user['nickname'] ?? '이름 없음',
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
                            "${user['location_name'] ?? user['nationality'] ?? '위치 미설정'} • ${user['age'] ?? '??'}세",
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

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    guide['guide_bio'] ?? user['bio'] ?? "반가워요!",
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 15),

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

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
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
    final screenHeight = MediaQuery.of(context).size.height;
    final initialSheetSize = 0.3;

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
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _dongchonDong,
                    zoom: 13.0,
                  ),
                  onMapCreated: (controller) => _controller = controller,
                  // ✅ 기본 내 위치 점 비활성화 (직접 마커로 표시)
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  markers: _markers,
                ),

                Positioned(
                  bottom: (screenHeight * initialSheetSize) + 16,
                  right: 16,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    mini: true,
                    elevation: 4,
                    onPressed: _moveToCurrentPosition,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),

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

  // ✅ 내 위치 버튼 → 퍼뜨린 위치로 이동
  Future<void> _moveToCurrentPosition() async {
    if (_controller == null || _currentPosition == null) return;
    _controller!.animateCamera(
      CameraUpdate.newLatLngZoom(_currentPosition!, 15.0),
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
                image: NetworkImage(getProfileImage(user['profile_image'])),
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
              user['nickname'] ?? '이름 없음',
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
            backgroundImage: NetworkImage(
              getProfileImage(user['profile_image']),
            ),
          ),
          title: Text(user['nickname'] ?? '이름 없음'),
          subtitle: Text(user['bio'] ?? "반가워요!"),
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }
}
