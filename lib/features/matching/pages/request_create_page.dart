import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 날짜 포맷용
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/core/widgets/popup/app_toast.dart';

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
  int _headcount = 1;
  bool _isSubmitting = false;

  // 날짜 선택기
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
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
              onTap: _selectDate,
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
                          ? "날짜 선택"
                          : DateFormat('yyyy-MM-dd').format(_selectedDate!),
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
            _buildLabel("상세 요청사항"),
            _buildTextField(
              _contentController,
              "원하는 여행 코스나 가이드에게 바라는 점을 적어주세요",
              maxLines: 5,
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

  // UI 헬퍼
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

  // 저장 로직
  Future<void> _submit() async {
    if (_titleController.text.isEmpty ||
        _locationController.text.isEmpty ||
        _selectedDate == null) {
      AppToast.error(context, "필수 항목을 모두 입력해주세요.");
      return;
    }
    // TODO: UserService.createTravelRequest 호출 로직 추가 예정
    setState(() => _isSubmitting = true);
    // ... 저장 후 이동
  }
}
