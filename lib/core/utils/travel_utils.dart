import 'package:country_picker/country_picker.dart';

class TravelUtils {
  /// 🌍 국가 코드를 받아 "🇰🇷 대한민국" 형태로 변환
  static String formatNationality(String? code) {
    if (code == null || code.isEmpty) return "🌐 지구인";

    // 이미 한글 이름이 들어온 경우 그대로 반환
    if (code.contains(' ')) return code;

    try {
      // CountryService를 통해 국기 이모지와 이름을 가져옴
      final country = CountryService().findByCode(code);
      if (country != null) {
        return "${country.flagEmoji} ${country.name}";
      }
    } catch (e) {
      return code; // 에러 나면 그냥 코드값이라도 보여줌
    }

    return code;
  }
}
