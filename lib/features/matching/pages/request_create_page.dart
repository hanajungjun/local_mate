import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/core/widgets/popup/app_toast.dart';
import 'package:localmate/services/user_service.dart';

class RequestCreatePage extends StatefulWidget {
  const RequestCreatePage({super.key});

  @override
  State<RequestCreatePage> createState() => _RequestCreatePageState();
}

class _RequestCreatePageState extends State<RequestCreatePage> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _contentController = TextEditingController();
  final _budgetController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _headcount = 1;
  String _companionType = 'alone'; // 기본값
  bool _isSubmitting = false;

  // 날짜 & 시간 선택 통합 로직
  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 12, minute: 0),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = pickedDate;
          _selectedTime = pickedTime;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "여행 공고 올리기",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel("어떤 여행인가요? (제목)"),
            _buildTextField(_titleController, "예: 망원동 노포 맛집 투어 가이드 구해요"),

            const SizedBox(height: 25),
            _buildLabel("어디로 가시나요?"),
            _buildTextField(_locationController, "예: 서울 마포구 망원동"),

            const SizedBox(height: 25),
            _buildLabel("언제 만나고 싶나요?"),
            InkWell(
              onTap: _selectDateTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDate == null
                          ? "날짜 및 시간 선택"
                          : "${DateFormat('yyyy-MM-dd').format(_selectedDate!)}  ${_selectedTime?.format(context) ?? ''}",
                    ),
                    const Icon(
                      Icons.calendar_month,
                      color: AppColors.travelingBlue,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),
            _buildLabel("누구와 함께하시나요?"),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _companionChip("혼자", "alone"),
                _companionChip("가족", "family"),
                _companionChip("친구", "friend"),
                _companionChip("연인", "couple"),
              ],
            ),

            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("인원수"),
                      DropdownButtonFormField<int>(
                        value: _headcount,
                        items: List.generate(
                          10,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text("${i + 1}명"),
                          ),
                        ),
                        onChanged: (val) => setState(() => _headcount = val!),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("희망 예산 (P)"),
                      _buildTextField(
                        _budgetController,
                        "단위: 포인트",
                        isNumber: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),
            _buildLabel("상세 요청사항"),
            _buildTextField(
              _contentController,
              "원하는 여행 코스나 가이드에게 바라는 점을 적어주세요",
              maxLines: 5,
            ),

            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.travelingBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "공고 등록하기",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 동행인 선택 칩 위젯
  Widget _companionChip(String label, String value) {
    bool isSelected = _companionType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _companionType = value);
      },
      selectedColor: AppColors.travelingBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    ),
  );

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    bool isNumber = false,
  }) => TextField(
    controller: ctrl,
    maxLines: maxLines,
    keyboardType: isNumber ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.all(12),
    ),
  );

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      AppToast.error(context, "필수 항목과 시간을 모두 선택해주세요.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 날짜와 시간을 합침
      final finalAt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      await UserService().createTravelRequest(
        title: _titleController.text.trim(),
        locationName: _locationController.text.trim(),
        travelAt: finalAt,
        content: _contentController.text.trim(),
        headcount: _headcount,
        companionType: _companionType,
        budget: int.tryParse(_budgetController.text) ?? 0,
      );

      if (!mounted) return;
      AppToast.success(context, "공고가 등록되었습니다!");
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, "등록 실패: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
