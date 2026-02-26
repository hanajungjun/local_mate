String getProfileImage(dynamic profileImage) {
  if (profileImage == null) return 'https://picsum.photos/200';
  if (profileImage is List && profileImage.isNotEmpty) {
    return profileImage[0].toString();
  }
  return 'https://picsum.photos/200';
}
