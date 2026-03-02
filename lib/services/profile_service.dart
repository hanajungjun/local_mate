import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ProfileService {
  final _supabase = Supabase.instance.client;

  // --- [추가] WebP 변환 및 압축 로직 ---
  Future<File?> _convertToWebp(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.webp';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      format: CompressFormat.webp,
      quality: 80, // 용량과 화질의 적절한 타협점
    );

    return result != null ? File(result.path) : null;
  }

  // --- [추가] 스토리지 파일 삭제 로직 ---
  Future<void> _deleteOldImagesFromServer(List<String> urlsToDelete) async {
    if (urlsToDelete.isEmpty) return;

    final List<String> paths = urlsToDelete.map((url) {
      // URL에서 파일 경로(폴더명/파일명)만 추출
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      // 'public/profile-images/' 이후의 경로를 추출해야 합니다.
      return pathSegments
          .skip(pathSegments.indexOf('profile-images') + 1)
          .join('/');
    }).toList();

    try {
      await _supabase.storage.from('profile-images').remove(paths);
      print('✅ 스토리지에서 삭제 완료: $paths');
    } catch (e) {
      print('❌ 스토리지 삭제 실패: $e');
    }
  }

  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    return await _supabase
        .from('users')
        .select('*, guides(*)')
        .eq('auth_uid', user.id)
        .maybeSingle();
  }

  Future<List<String>> uploadProfileImages(List<AssetEntity> assets) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("로그인이 필요합니다.");

    final List<String> uploadedUrls = [];

    for (int i = 0; i < assets.length; i++) {
      final asset = assets[i];
      final File? originFile = await asset.originFile;
      if (originFile == null) continue;

      // ✅ WebP 변환 실행
      final webpFile = await _convertToWebp(originFile);
      if (webpFile == null) continue;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // ✅ 확장자를 .webp로 변경
      final storagePath = '${user.id}/profile_${timestamp}_$i.webp';

      await _supabase.storage
          .from('profile-images')
          .upload(
            storagePath,
            webpFile,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/webp', // ✅ 컨텐츠 타입 변경
            ),
          );

      final url = _supabase.storage
          .from('profile-images')
          .getPublicUrl(storagePath);
      uploadedUrls.add(url);
    }

    return uploadedUrls;
  }

  Future<void> updateProfile({
    required String nickname,
    required String bio,
    int? age,
    String? gender,
    String? nationality,
    String? mbti,
    List<String>? languages,
    List<String>? travelStyle,
    List<String>? interests,
    List<String>? serverImageUrls, // 현재 화면에 남은 기존 이미지들
    List<AssetEntity>? newSelectedAssets,
    String? guideBio,
    List<String>? locationNames,
    String? residencePeriod,
    List<String>? specialties,
    Map<String, int>? languageLevels,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("세션이 만료되었습니다.");

    // --- 1. 스토리지 정리 (삭제된 이미지 실제 제거) ---
    final oldProfileData = await getMyProfile();
    if (oldProfileData != null && oldProfileData['profile_image'] != null) {
      final List<String> previousUrls = List<String>.from(
        oldProfileData['profile_image'],
      );
      final List<String> currentServerUrls = serverImageUrls ?? [];

      // 기존에 있었는데, 현재 서버 리스트(사용자가 남겨둔 것)에 없는 것들을 골라냄
      final toDelete = previousUrls
          .where((url) => !currentServerUrls.contains(url))
          .toList();
      await _deleteOldImagesFromServer(toDelete);
    }

    // 2. 새 이미지 업로드
    List<String> finalImageUrls = List<String>.from(serverImageUrls ?? []);
    if (newSelectedAssets != null && newSelectedAssets.isNotEmpty) {
      final uploadedUrls = await uploadProfileImages(newSelectedAssets);
      finalImageUrls = [...finalImageUrls, ...uploadedUrls];
    }

    // 3. Users 테이블 Upsert
    final userRes = await _supabase
        .from('users')
        .upsert({
          'auth_uid': user.id,
          'nickname': nickname,
          'bio': bio,
          'age': age,
          'gender': gender,
          'nationality': nationality,
          'mbti': mbti,
          'languages': languages,
          'travel_style': travelStyle,
          'interests': interests,
          'profile_image': finalImageUrls,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'auth_uid')
        .select('id')
        .single();

    final String userId = userRes['id'];

    // --- 4. Guides 테이블 Upsert (조건문 제거 및 로직 수정) ---
    // 이제 if 조건 없이 항상 시도하거나, 가이드 정보가 하나라도 있으면 업데이트합니다.
    // 사용자가 내용을 비우면 비운 채로(null이나 빈 배열) DB에 반영됩니다.
    await _supabase.from('guides').upsert({
      'id': userId,
      'guide_bio': guideBio ?? '',
      'location_names': locationNames ?? [],
      'residence_period': residencePeriod ?? '',
      'specialties': specialties ?? [],
      'language_levels': languageLevels ?? {},
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
