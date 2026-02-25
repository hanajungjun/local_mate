class WordEntry {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;

  WordEntry({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
  });

  factory WordEntry.fromMap(String id, Map<String, dynamic> data) {
    return WordEntry(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] as String?,
    );
  }
}
