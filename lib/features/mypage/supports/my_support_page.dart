import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MySupportPage extends StatelessWidget {
  const MySupportPage({super.key});

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('URL 실행 에러: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "지원",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 1. 고객센터 섹션
                  _buildSectionTitle("고객센터"),
                  _menuTile(
                    "공지사항",
                    () => _launchURL(
                      'https://hanajungjun.github.io/travel-memoir-docs/notice.html',
                    ),
                  ),
                  _menuTile(
                    "도움말",
                    () => _launchURL(
                      'https://hanajungjun.github.io/travel-memoir-docs/faq.html',
                    ),
                  ),

                  const Divider(thickness: 8, color: Color(0xFFF5F5F5)),

                  // 2. 개발자 정보 섹션
                  _buildSectionTitle("개발자 정보"),
                  _menuTile(
                    "문의 이메일",
                    () => _launchURL('mailto:HajungTech@gmail.com'),
                    trailingText: 'HajungTech@gmail.com',
                  ),
                  // ✅ [복구] 회사소개 메뉴 추가
                  _menuTile(
                    "회사소개",
                    () => _launchURL(
                      'https://hanajungjun.github.io/travel-memoir-docs/support.html',
                    ),
                  ),

                  const Divider(thickness: 8, color: Color(0xFFF5F5F5)),

                  // 3. 약관 및 정책 섹션
                  _buildSectionTitle("약관 및 정책"),
                  _menuTile(
                    "개인정보 처리방침",
                    () => _launchURL(
                      'https://hanajungjun.github.io/travel-memoir-docs/',
                    ),
                  ),
                  _menuTile(
                    "서비스 이용약관",
                    () => _launchURL(
                      'https://hanajungjun.github.io/travel-memoir-docs/terms.html',
                    ),
                  ),
                  _menuTile(
                    "오픈소스 라이선스",
                    () => showLicensePage(context: context),
                  ),
                ],
              ),
            ),
          ),

          // ❹ 하단 영역 (인스타그램 + 버전 정보)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () =>
                      _launchURL('https://www.instagram.com/hajungtech/'),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    size: 28,
                    color: Color(0xFF949494),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "로컬메이트",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Version 1.0.0 (100)",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _menuTile(String title, VoidCallback onTap, {String? trailingText}) {
    return ListTile(
      onTap: onTap,
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                trailingText,
                style: const TextStyle(fontSize: 13, color: Color(0xFF289AEB)),
              ),
            ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
