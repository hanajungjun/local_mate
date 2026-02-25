// import 'package:flutter/material.dart';
// import 'package:local_mate/core/constants/app_colors.dart';

// class SchedulePage extends StatelessWidget {
//   const SchedulePage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       appBar: AppBar(
//         title: const Text(
//           "내 일정",
//           style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: Colors.white,
//         elevation: 0,
//       ),
//       body: Column(
//         children: [
//           // 📅 미니 캘린더 영역 (주간 뷰 형태)
//           Container(
//             padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
//             color: Colors.white,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: List.generate(7, (index) => _buildCalendarDay(index)),
//             ),
//           ),

//           // 📝 시간대별 일정 리스트
//           Expanded(
//             child: ListView(
//               padding: const EdgeInsets.all(20),
//               children: [
//                 _buildTimeSlot("오전 10:00", "망원동 맛집 투어", "가이드: 김로컬", true),
//                 _buildTimeSlot("오후 02:00", "연남동 출사", "가이드: 사진작가", false),
//                 _buildTimeSlot("오후 06:00", "확정된 일정이 없습니다.", "", false),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCalendarDay(int index) {
//     bool isToday = index == 3; // 예시로 오늘 날짜 표시
//     return Column(
//       children: [
//         Text(
//           ["월", "화", "수", "목", "금", "토", "일"][index],
//           style: const TextStyle(fontSize: 12),
//         ),
//         const SizedBox(height: 8),
//         Container(
//           padding: const EdgeInsets.all(10),
//           decoration: BoxDecoration(
//             color: isToday ? AppColors.travelingBlue : Colors.transparent,
//             shape: BoxShape.circle,
//           ),
//           child: Text(
//             "${23 + index}",
//             style: TextStyle(
//               color: isToday ? Colors.white : Colors.black,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildTimeSlot(String time, String title, String sub, bool isActive) {
//     return IntrinsicHeight(
//       child: Row(
//         children: [
//           SizedBox(
//             width: 70,
//             child: Text(
//               time,
//               style: const TextStyle(fontSize: 12, color: Colors.grey),
//             ),
//           ),
//           VerticalDivider(
//             color: isActive ? AppColors.travelingBlue : Colors.grey.shade300,
//             thickness: 2,
//           ),
//           const SizedBox(width: 15),
//           Expanded(
//             child: Container(
//               margin: const EdgeInsets.only(bottom: 15),
//               padding: const EdgeInsets.all(15),
//               decoration: BoxDecoration(
//                 color: isActive
//                     ? AppColors.travelingBlue.withOpacity(0.05)
//                     : Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(
//                   color: isActive
//                       ? AppColors.travelingBlue
//                       : Colors.grey.shade200,
//                 ),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     title,
//                     style: const TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   if (sub.isNotEmpty)
//                     Text(
//                       sub,
//                       style: const TextStyle(fontSize: 12, color: Colors.grey),
//                     ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
