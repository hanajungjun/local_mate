import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuideMapPage extends StatefulWidget {
  const GuideMapPage({super.key});

  @override
  State<GuideMapPage> createState() => _GuideMapPageState();
}

class _GuideMapPageState extends State<GuideMapPage> {
  final supabase = Supabase.instance.client;
  GoogleMapController? _controller;
  LatLng? _currentPosition;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  static const LatLng _defaultPos = LatLng(37.4219, -122.0840);
  static const double _minSheet = 0.2;
  static const double _midSheet = 0.35;
  static const double _maxSheet = 0.85;

  final Set<Marker> _markers = {};
  List<Map<String, dynamic>> _requests = [];

  static const Map<String, double> _markerHues = {
    'alone': BitmapDescriptor.hueAzure,
    'couple': BitmapDescriptor.hueRose,
    'friend': BitmapDescriptor.hueGreen,
    'family': BitmapDescriptor.hueOrange,
  };

  static const Map<String, String> _typeEmoji = {
    'alone': '🙋',
    'couple': '❤️',
    'friend': '👯',
    'family': '👨‍👩‍👧',
  };

  @override
  void initState() {
    super.initState();
    _initMapData();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  void _snapToNearest() {
    if (!_sheetController.isAttached) return;
    final extent = _sheetController.size;

    double target;
    if (extent < (_minSheet + _midSheet) / 2) {
      target = _minSheet;
    } else if (extent < (_midSheet + _maxSheet) / 2) {
      target = _midSheet;
    } else {
      target = _maxSheet;
    }

    if ((extent - target).abs() > 0.02) {
      _sheetController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _initMapData() async {
    await _determinePosition();
    final lat = _currentPosition?.latitude ?? _defaultPos.latitude;
    final lng = _currentPosition?.longitude ?? _defaultPos.longitude;
    await _loadRequestsFromDB(lat, lng);
  }

  Future<void> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        final myPos = LatLng(position.latitude, position.longitude);
        setState(() => _currentPosition = myPos);
        _controller?.animateCamera(CameraUpdate.newLatLngZoom(myPos, 14.0));
      }
    } catch (e) {
      debugPrint("❌ 위치 가져오기 실패: $e");
    }
  }

  Future<void> _loadRequestsFromDB(
    double lat,
    double lng, {
    double radiusDegrees = 0.1,
  }) async {
    try {
      final result = await supabase.rpc(
        'get_nearby_requests',
        params: {
          'center_lat': lat,
          'center_lng': lng,
          'radius_degrees': radiusDegrees,
        },
      );

      final fetched = List<Map<String, dynamic>>.from(result as List);

      if (mounted) {
        setState(() {
          _requests = fetched;
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

          for (var req in fetched) {
            final companionType = req['companion_type'] as String? ?? 'alone';
            final hue = _markerHues[companionType] ?? BitmapDescriptor.hueAzure;

            _markers.add(
              Marker(
                markerId: MarkerId(req['id'].toString()),
                position: LatLng(
                  (req['display_lat'] as num).toDouble(),
                  (req['display_lng'] as num).toDouble(),
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(hue),
                onTap: () => _showRequestCard(req),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint("❌ 여행 요청 로드 실패: $e");
    }
  }

  void _onCameraIdle() async {
    if (_controller == null) return;
    final bounds = await _controller!.getVisibleRegion();
    final centerLat =
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
    final centerLng =
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
    final latDelta =
        (bounds.northeast.latitude - bounds.southwest.latitude) / 2 * 1.1;
    final lngDelta =
        (bounds.northeast.longitude - bounds.southwest.longitude) / 2 * 1.1;
    final radiusDegrees = max(latDelta, lngDelta);
    await _loadRequestsFromDB(
      centerLat,
      centerLng,
      radiusDegrees: radiusDegrees,
    );
  }

  void _showRequestCard(Map<String, dynamic> req) {
    final companionType = req['companion_type'] as String? ?? 'alone';
    final emoji = _typeEmoji[companionType] ?? '🙋';

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
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.travelingPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req['title'] ?? '제목 없음',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          req['location_name'] ?? '위치 미정',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildChip(
                    Icons.people_outline,
                    _companionLabel(companionType),
                    AppColors.travelingPurple,
                  ),
                  const SizedBox(width: 10),
                  if (req['budget'] != null)
                    _buildChip(
                      Icons.attach_money,
                      '₩${_formatBudget(req['budget'])}',
                      Colors.green,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // TODO: 공고 상세 페이지로 이동
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.travelingPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "공고 상세 보기 →",
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
        );
      },
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _companionLabel(String type) {
    switch (type) {
      case 'alone':
        return '혼자';
      case 'couple':
        return '커플';
      case 'friend':
        return '친구';
      case 'family':
        return '가족';
      default:
        return type;
    }
  }

  String _formatBudget(dynamic budget) {
    if (budget == null) return '미정';
    final int b = (budget as num).toInt();
    if (b >= 10000) return '${(b / 10000).toStringAsFixed(0)}만';
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '주변 여행 요청',
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
                    target: _currentPosition ?? _defaultPos,
                    zoom: 13.0,
                  ),
                  onMapCreated: (controller) => _controller = controller,
                  onCameraIdle: _onCameraIdle,
                  markers: _markers,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                ),

                // 내 위치 버튼
                Positioned(
                  bottom: 180,
                  right: 20,
                  child: GestureDetector(
                    onTap: _determinePosition,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: AppColors.travelingPurple,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                // 범례
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🙋 혼자', style: TextStyle(fontSize: 12)),
                        Text('❤️ 커플', style: TextStyle(fontSize: 12)),
                        Text('👯 친구', style: TextStyle(fontSize: 12)),
                        Text('👨‍👩‍👧 가족', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),

                // ✅ GestureDetector로 드래그 끝 감지 → 스냅
                GestureDetector(
                  onVerticalDragEnd: (_) => _snapToNearest(),
                  child: DraggableScrollableSheet(
                    controller: _sheetController,
                    initialChildSize: _midSheet,
                    minChildSize: _minSheet,
                    maxChildSize: _maxSheet,
                    snap: false,
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
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "주변 여행 요청",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "${_requests.length}건",
                                    style: const TextStyle(
                                      color: AppColors.travelingPurple,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_requests.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  "이 지역에 여행 요청이 없어요.",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _requests.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final req = _requests[index];
                                  final companionType =
                                      req['companion_type'] as String? ??
                                      'alone';
                                  final emoji =
                                      _typeEmoji[companionType] ?? '🙋';
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 5,
                                    ),
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.travelingPurple
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                    title: Text(
                                      req['title'] ?? '제목 없음',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      req['location_name'] ?? '위치 미정',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                    trailing: req['budget'] != null
                                        ? Text(
                                            '₩${_formatBudget(req['budget'])}',
                                            style: const TextStyle(
                                              color: AppColors.travelingPurple,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                    onTap: () => _showRequestCard(req),
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_sheetController.isAttached) {
          final current = _sheetController.size;
          final target = current <= _minSheet + 0.05 ? _midSheet : _minSheet;
          _sheetController.animateTo(
            target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      },
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
          if (_sheetController.isAttached) {
            _sheetController.animateTo(
              _midSheet,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
      },
      child: Container(
        width: double.infinity,
        height: 40,
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Container(
          width: 45,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey[400],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
