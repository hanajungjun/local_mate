import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapViewPage extends StatefulWidget {
  const MapViewPage({super.key});

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  GoogleMapController? _controller;
  LatLng? _currentPosition;

  // 1. 지도에 표시할 마커 세트
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _loadDummyMates(); // 2. 가짜 데이터 로드
  }

  // 📍 현재 내 위치 가져오기
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    }
  }

  // 📍 당근마켓 스타일 동네 메이트 가짜 데이터
  void _loadDummyMates() {
    setState(() {
      _markers.addAll([
        Marker(
          markerId: const MarkerId('mate_deungchon'),
          position: const LatLng(37.5509, 126.8495), // 등촌동 중심
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          onTap: () => _showMateInfo('등촌동 메이트', '현지인 맛집 킬러입니다!'),
        ),
        Marker(
          markerId: const MarkerId('mate_yeoksam'),
          position: const LatLng(37.5006, 127.0362), // 역삼동 중심
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          onTap: () => _showMateInfo('역삼동 메이트', '강남 핫플 가이드 해드려요.'),
        ),
      ]);
    });
  }

  // 📍 마커 클릭 시 하단에서 정보창 띄우기 (당근 스타일)
  void _showMateInfo(String name, String bio) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                bio,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('채팅하기'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Mates Around Me'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: 12.0, // 동네들이 잘 보이게 약간 멀리서 봅니다
              ),
              onMapCreated: (controller) => _controller = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _markers,
            ),
    );
  }
}
