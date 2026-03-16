import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:localmate/services/map_service.dart';
import 'package:localmate/services/discover_service.dart';
import 'package:localmate/core/utils/image_utils.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:localmate/core/utils/travel_utils.dart';

class MapViewPage extends StatefulWidget {
  const MapViewPage({super.key});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  GoogleMapController? _controller;
  LatLng? _currentPosition;

  static const LatLng _googleHQ = LatLng(37.4219, -122.0840);

  final Set<Marker> _markers = {};
  final MapService _mapService = MapService();
  final DiscoverService _discoverService = DiscoverService();

  List<Map<String, dynamic>> _adGuides = [];
  List<Map<String, dynamic>> _generalMates = [];

  @override
  void initState() {
    super.initState();
    _initMapData();
  }

  Future<void> _initMapData() async {
    await _determinePosition();
    final lat = _currentPosition?.latitude ?? _googleHQ.latitude;
    final lng = _currentPosition?.longitude ?? _googleHQ.longitude;
    await _loadMatesFromDB(lat, lng);
  }

  Future<void> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      final myPos = LatLng(position.latitude, position.longitude);
      setState(() => _currentPosition = myPos);
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(myPos, 14.0));
    }
  }

  Future<void> _loadMatesFromDB(
    double lat,
    double lng, {
    double radiusDegrees = 0.1,
  }) async {
    final fetchedGuides = await _mapService.getNearbyGuides(
      lat,
      lng,
      radiusDegrees: radiusDegrees,
    );

    if (mounted) {
      setState(() {
        _adGuides = fetchedGuides
            .where((g) => (g['ad_level'] ?? 0) > 0)
            .toList();
        _generalMates = fetchedGuides
            .where((g) => (g['ad_level'] ?? 0) == 0)
            .toList();

        _markers.clear();

        if (_currentPosition != null) {
          _markers.add(
            Marker(
              markerId: const MarkerId('my_location'),
              position: _currentPosition!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
            ),
          );
        }

        for (var guide in fetchedGuides) {
          final bool isAd = (guide['ad_level'] ?? 0) > 0;
          _markers.add(
            Marker(
              markerId: MarkerId(guide['id'].toString()),
              position: LatLng(guide['latitude'], guide['longitude']),
              zIndex: isAd ? 2.0 : 1.0,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                isAd ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueAzure,
              ),
              onTap: () => _showMateInfo(guide),
            ),
          );
        }
      });
    }
  }

  void _onCameraIdle() async {
    if (_controller == null) return;

    LatLngBounds bounds = await _controller!.getVisibleRegion();

    final double centerLat =
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
    final double centerLng =
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2;

    final double latDelta =
        (bounds.northeast.latitude - bounds.southwest.latitude) / 2 * 1.1;
    final double lngDelta =
        (bounds.northeast.longitude - bounds.southwest.longitude) / 2 * 1.1;
    final double radiusDegrees = max(latDelta, lngDelta);

    await _loadMatesFromDB(centerLat, centerLng, radiusDegrees: radiusDegrees);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    const initialSheetSize = 0.35;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '주변 로컬 메이트',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _currentPosition == null && !kDebugMode
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _googleHQ,
                    zoom: 13.0,
                  ),
                  onMapCreated: (controller) => _controller = controller,
                  onCameraIdle: _onCameraIdle,
                  markers: _markers,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                ),

                Positioned(
                  bottom: (screenHeight * initialSheetSize) + 20,
                  right: 20,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    mini: true,
                    onPressed: _determinePosition,
                    child: const Icon(
                      Icons.my_location,
                      color: AppColors.travelingBlue,
                    ),
                  ),
                ),

                DraggableScrollableSheet(
                  initialChildSize: initialSheetSize,
                  minChildSize: 0.15,
                  maxChildSize: 0.85,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(25),
                        ),
                        boxShadow: [
                          BoxShadow(blurRadius: 15, color: Colors.black12),
                        ],
                      ),
                      child: ListView(
                        controller: scrollController,
                        children: [
                          _buildHandle(),
                          if (_adGuides.isNotEmpty) ...[
                            _buildSectionTitle("프리미엄 메이트 ✨", Colors.orange),
                            _buildAdSlider(),
                            const Divider(height: 30),
                          ],
                          _buildSectionTitle("주변의 모든 메이트", Colors.black87),
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

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAdSlider() {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: _adGuides.length,
        itemBuilder: (context, index) {
          final guide = _adGuides[index];
          final user = guide['users'];
          return GestureDetector(
            onTap: () => _showMateInfo(guide),
            child: Container(
              width: 130,
              margin: const EdgeInsets.only(right: 12),
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
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "AD",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user['nickname'] ?? '이름 없음',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGeneralList() {
    if (_generalMates.isEmpty && _adGuides.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 50),
        alignment: Alignment.center,
        child: const Text(
          "이 지역에는 아직 활동 중인 메이트가 없어요.",
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _generalMates.length,
      itemBuilder: (context, index) {
        final mate = _generalMates[index];
        final user = mate['users'];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 5,
          ),
          leading: CircleAvatar(
            radius: 25,
            backgroundImage: NetworkImage(
              getProfileImage(user['profile_image']),
            ),
          ),
          title: Text(
            user['nickname'] ?? '이름 없음',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            // 기존: "${user['nationality'] ?? '로컬'} • ${user['age'] ?? '??'}세",
            // ✅ 수정: TravelUtils 적용!
            "${TravelUtils.formatNationality(user['nationality'])} • ${user['age'] ?? '??'}세",
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => _showMateInfo(mate),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 45,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showMateInfo(Map<String, dynamic> guide) {
    final user = guide['users'] ?? {};
    final List<dynamic> interests = user['interests'] ?? [];
    final bool isAd = (guide['ad_level'] ?? 0) > 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        // ✅ StatefulBuilder로 모달 내부 상태 관리
        bool liked = false;
        bool isLiking = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  if (isAd) ...[
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
                                "${TravelUtils.formatNationality(user['nationality'])} • ${user['age'] ?? '??'}세",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12, // 리스트니까 12 정도로 줄이는 게 예뻐요
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ✅ 하트 버튼: 탭 시 sendLike 호출
                        GestureDetector(
                          onTap: (isLiking || liked)
                              ? null
                              : () async {
                                  setModalState(() => isLiking = true);
                                  try {
                                    await _discoverService.sendLike(
                                      user['id'].toString(),
                                    );
                                    setModalState(() => liked = true);
                                  } catch (e) {
                                    debugPrint('❌ 좋아요 실패: $e');
                                  } finally {
                                    setModalState(() => isLiking = false);
                                  }
                                },
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: isLiking
                                ? const SizedBox(
                                    key: ValueKey('loading'),
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.pink,
                                    ),
                                  )
                                : Icon(
                                    liked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    key: ValueKey(liked),
                                    color: Colors.pink,
                                    size: 28,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "메이트 소개",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        guide['guide_bio'] ?? user['bio'] ?? "반갑습니다!",
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (interests.isNotEmpty) ...[
                      const Text(
                        "관심 키워드",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: interests
                            .map(
                              (item) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "#$item",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 25),
                    ],
                    // ✅ 좋아요 전: 비활성 안내 문구 / 좋아요 후: 완료 메시지
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: liked ? () => Navigator.pop(context) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: liked
                              ? Colors.pink
                              : Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          liked ? "좋아요를 보냈어요 💕" : "하트를 눌러 좋아요를 보내세요",
                          style: TextStyle(
                            color: liked ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
      },
    );
  }
}
