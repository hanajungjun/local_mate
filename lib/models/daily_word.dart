class DailyWord {
  final String id; // uuid
  final String date; // YYYYMMDD
  final DateTime dateTimestamp;
  final String title;
  final String description;
  final String? imageUrl; // nullable 처리
  final DateTime updatedAt;

  DailyWord({
    required this.id,
    required this.date,
    required this.dateTimestamp,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.updatedAt,
  });

  /// ----------------------------------------------------------------------
  ///  🔧 날짜 문자열 정규화 (예: "2025 12 03" → "20251203")
  /// ----------------------------------------------------------------------
  static String normalizeDate(String input) {
    // 공백/개행 제거
    final cleaned = input
        .trim()
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll(' ', '');

    // YYYY-MM-DD 또는 YYYY/MM/DD → YYYYMMDD로 변환
    final digits = cleaned.replaceAll(RegExp(r'[^0-9]'), '');

    // 최종 8자리면 성공
    if (digits.length == 8) return digits;

    // 6자리면 → 20xx 붙이기 (예: 251203 → 20251203)
    if (digits.length == 6) return '20$digits';

    return cleaned; // fallback
  }

  /// ----------------------------------------------------------------------
  ///  🔧 Map → DailyWord 변환
  /// ----------------------------------------------------------------------
  factory DailyWord.fromMap(Map<String, dynamic> map) {
    final rawDate = map['date']?.toString() ?? '';

    return DailyWord(
      id: map['id'].toString(),
      date: normalizeDate(rawDate),

      dateTimestamp: map['date_timestamp'] != null
          ? DateTime.parse(map['date_timestamp'])
          : DateTime.now(),

      title: map['title'] ?? '',
      description: map['description'] ?? '',

      // DB에서 NULL일 수 있으므로 nullable 적용
      imageUrl: map['image_url']?.toString(),

      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
    );
  }

  /// ----------------------------------------------------------------------
  ///  🔧 Insert용 Map (id 제외)
  /// ----------------------------------------------------------------------
  Map<String, dynamic> toInsertMap() {
    return {
      'date': normalizeDate(date),
      'date_timestamp': dateTimestamp.toIso8601String(),
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
