import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/services/discover_service.dart';
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
  static bool _hasShownUpdateDialog = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasShownUpdateDialog) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _askUpdateGuideLocation();
        });
      }
    });
  }

  // --- 위치 업데이트 관련 로직 ---
  Future<void> _askUpdateGuideLocation() async {
    _hasShownUpdateDialog = true;
    final bool? shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "📍 활동 위치 업데이트",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "현재 내 위치를 가이드 활동 지역의 중심 좌표로 설정하시겠습니까?\n주변 여행자들에게 내 위치가 더 정확하게 노출됩니다.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("나중에", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.travelingPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("변경하기", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldUpdate == true) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        final user = supabase.auth.currentUser;
        if (user == null) return;
        final userRes = await supabase
            .from('users')
            .select('id')
            .eq('auth_uid', user.id)
            .single();
        await supabase
            .from('guides')
            .update({
              'latitude': position.latitude,
              'longitude': position.longitude,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userRes['id']);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("✨ 위치 업데이트 완료!")));
          _determinePosition();
        }
      } catch (e) {
        debugPrint("❌ 에러: $e");
      }
    }
  }

  // --- 데이터 로드 로직 ---
  Future<void> _initMapData() async {
    await _determinePosition();
    await _loadRequestsFromDB(
      _currentPosition?.latitude ?? _defaultPos.latitude,
      _currentPosition?.longitude ?? _defaultPos.longitude,
    );
  }

  Future<void> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        final myPos = LatLng(position.latitude, position.longitude);
        setState(() => _currentPosition = myPos);
        _controller?.animateCamera(CameraUpdate.newLatLngZoom(myPos, 14.0));
      }
    } catch (e) {
      debugPrint("❌ 위치 에러: $e");
    }
  }

  Future<void> _loadRequestsFromDB(double lat, double lng) async {
    try {
      final fetched = await DiscoverService().fetchTravelRequests(limit: 50);
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
            final bool isApplied = req['is_applied'] ?? false;
            final double hue = isApplied
                ? BitmapDescriptor.hueYellow
                : (_markerHues[req['companion_type']] ??
                      BitmapDescriptor.hueAzure);

            _markers.add(
              Marker(
                markerId: MarkerId(req['id'].toString()),
                position: LatLng(
                  (req['latitude'] as num).toDouble(),
                  (req['longitude'] as num).toDouble(),
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(hue),
                onTap: () => _showRequestCard(req),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint("❌ 로드 에러: $e");
    }
  }

  void _onCameraIdle() async {
    if (_controller == null) return;
    final bounds = await _controller!.getVisibleRegion();
    final centerLat =
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
    final centerLng =
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
    await _loadRequestsFromDB(centerLat, centerLng);
  }

  // --- UI 컴포넌트 ---
  Widget _buildInfoTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestCard(Map<String, dynamic> req) {
    final writer = req['users'] as Map<String, dynamic>?;
    final bool isApplied = req['is_applied'] ?? false;
    final List offersData = req['offers'] as List? ?? [];
    final int offerCount = offersData
        .where((o) => o['status'] != 'rejected')
        .length;
    final bool isFull = offerCount >= 5;

    final List profileImages = writer?['profile_image'] as List? ?? [];
    final String? profileUrl = profileImages.isNotEmpty
        ? profileImages[0].toString()
        : null;

    final String travelAtRaw = req['travel_at'] ?? '';
    String displayDate = '날짜 미정';
    if (travelAtRaw.isNotEmpty) {
      try {
        DateTime dt = DateTime.parse(travelAtRaw).toLocal();
        final weeks = ['월', '화', '수', '목', '금', '토', '일'];
        displayDate =
            "${dt.month}.${dt.day} (${weeks[dt.weekday - 1]}) ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: (profileUrl != null)
                      ? NetworkImage(profileUrl)
                      : null,
                  child: (profileUrl == null) ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "${writer?['nickname'] ?? ''} • ${_companionLabel(req['companion_type'] ?? '')}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "${req['budget'] ?? 0} P",
                  style: const TextStyle(
                    color: AppColors.travelingPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildInfoTag(
                  Icons.location_on_outlined,
                  req['location_name'] ?? '',
                  Colors.grey,
                ),
                const SizedBox(width: 8),
                _buildInfoTag(
                  Icons.calendar_today_outlined,
                  displayDate,
                  AppColors.travelingPurple,
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              req['content'] ?? '',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
              maxLines: 2,
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (isApplied || isFull)
                    ? null
                    : () {
                        Navigator.pop(context);
                        _showOfferModal(context, req);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isApplied
                      ? Colors.orange
                      : AppColors.travelingPurple,
                  disabledBackgroundColor: isApplied
                      ? Colors.orange.withOpacity(0.5)
                      : Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  isApplied
                      ? "이미 제안한 공고입니다"
                      : (isFull ? "제안 마감 ($offerCount/5)" : "가이드 제안 보내기 →"),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOfferModal(BuildContext context, Map<String, dynamic> req) {
    final priceController = TextEditingController(
      text: req['budget']?.toString(),
    );
    final messageController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "가이드 제안하기",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "금액(P)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "메시지",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  final res = await DiscoverService().sendOffer(
                    requestId: req['id'],
                    price: int.tryParse(priceController.text) ?? 0,
                    message: messageController.text,
                  );
                  if (res == null && context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text("✅ 제안 완료!")));
                    _initMapData();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.travelingPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "제안 전송하기",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 유틸리티 함수들 ---
  void _snapToNearest() {
    if (!_sheetController.isAttached) return;
    final extent = _sheetController.size;
    double target;
    if (extent < (_minSheet + _midSheet) / 2)
      target = _minSheet;
    else if (extent < (_midSheet + _maxSheet) / 2)
      target = _midSheet;
    else
      target = _maxSheet;

    if ((extent - target).abs() > 0.02) {
      _sheetController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
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

  Widget _buildHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_sheetController.isAttached) {
          final target = _sheetController.size <= _minSheet + 0.05
              ? _midSheet
              : _minSheet;
          _sheetController.animateTo(
            target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
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
                // 하단 리스트 시트
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
}
