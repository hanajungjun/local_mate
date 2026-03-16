import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

enum NearbyRange {
  close, // 3km
  mid, // 5km
  far, // 10km
}

class GuideMatchingService {
  final _supabase = Supabase.instance.client;

  /// ✅ 지역명 텍스트로 검색
  Future<List<Map<String, dynamic>>> getRequestsByLocation(
    String locationQuery,
  ) async {
    try {
      var query = _supabase
          .from('travel_requests')
          .select(
            '*, users!travel_requests_writer_id_fkey(id, nickname, profile_image, nationality)',
          )
          .eq('status', 'searching')
          .gte('travel_at', DateTime.now().toIso8601String());

      if (locationQuery.trim().isNotEmpty) {
        query = query.ilike('location_name', '%${locationQuery.trim()}%');
      }

      final data = await query.order('travel_at', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('❌ 여행 공고 로드 실패: $e');
      return [];
    }
  }

  /// ✅ GPS 좌표 기반 주변 공고 검색
  /// travel_requests의 latitude/longitude 컬럼으로 거리 계산 후 필터링
  Future<({List<Map<String, dynamic>> results, String locationLabel})>
  getNearbyRequests(NearbyRange range) async {
    // 1. 위치 권한
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 거부되었어요. 설정에서 허용해주세요.');
    }

    // 2. 현재 위치
    final position = await Geolocator.getCurrentPosition();
    final myLat = position.latitude;
    final myLng = position.longitude;

    // 3. 범위(km) 설정
    final double radiusKm = switch (range) {
      NearbyRange.close => 3.0,
      NearbyRange.mid => 5.0,
      NearbyRange.far => 10.0,
    };

    // 4. 역지오코딩으로 현재 위치 라벨
    String locationLabel = '내 주변';
    try {
      final placemarks = await placemarkFromCoordinates(myLat, myLng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.subLocality,
          p.locality,
          p.administrativeArea,
        ].where((s) => s != null && s.isNotEmpty).toList();
        locationLabel = parts.join(' ');
      }
    } catch (_) {}

    // 5. 좌표 있는 공고 전체 가져오기
    final data = await _supabase
        .from('travel_requests')
        .select(
          '*, users!travel_requests_writer_id_fkey(id, nickname, profile_image, nationality)',
        )
        .eq('status', 'searching')
        .gte('travel_at', DateTime.now().toIso8601String())
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .order('travel_at', ascending: true);

    final all = List<Map<String, dynamic>>.from(data);

    // 6. 클라이언트에서 거리 필터링
    final nearby = all.where((req) {
      final lat = req['latitude'] as double?;
      final lng = req['longitude'] as double?;
      if (lat == null || lng == null) return false;

      final distanceMeters = Geolocator.distanceBetween(myLat, myLng, lat, lng);
      return distanceMeters <= radiusKm * 1000;
    }).toList();

    // 7. 거리순 정렬
    nearby.sort((a, b) {
      final distA = Geolocator.distanceBetween(
        myLat,
        myLng,
        a['latitude'] as double,
        a['longitude'] as double,
      );
      final distB = Geolocator.distanceBetween(
        myLat,
        myLng,
        b['latitude'] as double,
        b['longitude'] as double,
      );
      return distA.compareTo(distB);
    });

    return (results: nearby, locationLabel: locationLabel);
  }

  /// ✅ 인기 지역 칩 목록
  static const List<String> popularLocations = [
    '전체',
    '📍 주변',
    '서울',
    '부산',
    '제주',
    '강릉',
    '경주',
    '전주',
    '수원',
  ];
}
