import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
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
  final _locationFocusNode = FocusNode();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _headcount = 1;
  String _companionType = 'alone';
  bool _isSubmitting = false;
  bool _isLocating = false;
  bool _isGeocoding = false;

  double? _latitude;
  double? _longitude;

  // ✅ 검색 결과 후보 목록
  List<Location> _locationCandidates = [];
  List<String> _candidateLabels = [];

  @override
  void initState() {
    super.initState();
    _locationFocusNode.addListener(() {
      if (!_locationFocusNode.hasFocus) {
        _searchAddress(_locationController.text);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _contentController.dispose();
    _budgetController.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  // ✅ 주소 검색 → 후보 여러 개면 선택 바텀시트 표시
  Future<void> _searchAddress(String address) async {
    if (address.trim().isEmpty) return;

    setState(() {
      _isGeocoding = true;
      _locationCandidates = [];
      _candidateLabels = [];
      _latitude = null;
      _longitude = null;
    });

    try {
      final locations = await locationFromAddress(address.trim());
      if (locations.isEmpty || !mounted) return;

      if (locations.length == 1) {
        // 결과 1개면 바로 확정
        _applyLocation(locations.first, address.trim());
      } else {
        // 결과 여러 개면 역지오코딩으로 라벨 만들어서 선택 유도
        final labels = <String>[];
        for (final loc in locations) {
          try {
            final marks = await placemarkFromCoordinates(
              loc.latitude,
              loc.longitude,
            );
            if (marks.isNotEmpty) {
              final p = marks.first;
              final parts = [
                p.subLocality,
                p.locality,
                p.subAdministrativeArea,
                p.administrativeArea,
              ].where((s) => s != null && s.isNotEmpty).toList();
              labels.add(parts.join(' '));
            } else {
              labels.add(
                '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}',
              );
            }
          } catch (_) {
            labels.add(
              '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}',
            );
          }
        }

        if (!mounted) return;
        setState(() {
          _locationCandidates = locations;
          _candidateLabels = labels;
        });

        // 선택 바텀시트 띄우기
        _showCandidateSheet();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _latitude = null;
          _longitude = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  // ✅ 후보 선택 바텀시트
  void _showCandidateSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '어느 지역인가요?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '"${_locationController.text}" 검색 결과 ${_locationCandidates.length}개',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ...List.generate(_locationCandidates.length, (i) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _applyLocation(_locationCandidates[i], _candidateLabels[i]);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _candidateLabels[i],
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ✅ 위치 확정 적용
  void _applyLocation(Location location, String label) {
    setState(() {
      _latitude = location.latitude;
      _longitude = location.longitude;
      // 라벨이 원래 입력값보다 구체적이면 필드도 업데이트
      if (label != _locationController.text) {
        _locationController.text = label;
      }
      _locationCandidates = [];
      _candidateLabels = [];
    });
  }

  // ✅ GPS → 역지오코딩
  Future<void> _fillCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) AppToast.error(context, '위치 권한이 거부되었어요. 설정에서 허용해주세요.');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        if (mounted) AppToast.error(context, '주소를 가져올 수 없어요.');
        return;
      }

      final place = placemarks.first;
      final parts = <String>[];
      if (place.subLocality != null && place.subLocality!.isNotEmpty) {
        parts.add(place.subLocality!);
      }
      if (place.locality != null && place.locality!.isNotEmpty) {
        parts.add(place.locality!);
      }
      if (place.administrativeArea != null &&
          place.administrativeArea!.isNotEmpty) {
        parts.add(place.administrativeArea!);
      }

      if (mounted) {
        setState(() {
          _locationController.text = parts.join(' ');
          _latitude = position.latitude;
          _longitude = position.longitude;
          _locationCandidates = [];
          _candidateLabels = [];
        });
      }
    } catch (e) {
      if (mounted) AppToast.error(context, '위치를 가져오는 데 실패했어요.');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    focusNode: _locationFocusNode,
                    decoration: InputDecoration(
                      hintText: "예: 서울 강서구",
                      suffixIcon: _isGeocoding
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue,
                                ),
                              ),
                            )
                          : _latitude != null
                          ? const Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 18,
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    // 직접 수정하면 좌표 초기화
                    onChanged: (_) {
                      if (_latitude != null) {
                        setState(() {
                          _latitude = null;
                          _longitude = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLocating ? null : _fillCurrentLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.blue.shade200),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: _isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.my_location, size: 18),
                              SizedBox(height: 2),
                              Text("현재위치", style: TextStyle(fontSize: 11)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            // 상태 안내
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _isGeocoding
                  ? const Row(
                      children: [
                        Icon(Icons.sync, size: 13, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(
                          '위치 정보 변환 중...',
                          style: TextStyle(fontSize: 11, color: Colors.orange),
                        ),
                      ],
                    )
                  : _latitude != null
                  ? Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 13,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '위치 확정 (${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      children: [
                        Icon(Icons.info_outline, size: 13, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          '입력 후 다음 항목 터치 시 자동 변환돼요',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
            ),

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

    if (_isGeocoding) {
      AppToast.error(context, "위치 정보 변환 중이에요. 잠시 후 다시 시도해주세요.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
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
        latitude: _latitude,
        longitude: _longitude,
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
