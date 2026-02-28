import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class ProfileService {
  final _supabase = Supabase.instance.client;

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
      final File? file = await asset.originFile;
      if (file == null) continue;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = '${user.id}/profile_${timestamp}_$i.jpg';

      await _supabase.storage
          .from('profile-images')
          .upload(
            storagePath,
            file,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
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
    List<String>? serverImageUrls,
    List<AssetEntity>? newSelectedAssets,
    String? guideBio,
    List<String>? locationNames, // ✅ [0]=우리동네, [1][2]=추가지역
    String? residencePeriod,
    List<String>? specialties,
    Map<String, int>? languageLevels,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("세션이 만료되었습니다. 다시 로그인해주세요.");

    // 1. 이미지 업로드
    List<String> finalImageUrls = List<String>.from(serverImageUrls ?? []);
    if (newSelectedAssets != null && newSelectedAssets.isNotEmpty) {
      final uploadedUrls = await uploadProfileImages(newSelectedAssets);
      finalImageUrls = [...finalImageUrls, ...uploadedUrls];
    }

    // 2. Users 테이블 Upsert
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

    // 3. Guides 테이블 Upsert
    if ((locationNames != null && locationNames.isNotEmpty) ||
        residencePeriod != null ||
        guideBio != null) {
      await _supabase.from('guides').upsert({
        'id': userId,
        'guide_bio': guideBio,
        'location_names': locationNames ?? [], // ✅ text[] 배열로 저장
        'residence_period': residencePeriod,
        'specialties': specialties,
        'language_levels': languageLevels,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }
}
