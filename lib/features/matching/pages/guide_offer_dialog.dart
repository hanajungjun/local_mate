import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuideOfferDialog extends StatefulWidget {
  final Map<String, dynamic> request;

  const GuideOfferDialog({super.key, required this.request});

  @override
  State<GuideOfferDialog> createState() => _GuideOfferDialogState();
}

class _GuideOfferDialogState extends State<GuideOfferDialog> {
  final _supabase = Supabase.instance.client;
  final _priceController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendOffer() async {
    final price = int.tryParse(_priceController.text.replaceAll(',', ''));
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('올바른 금액을 입력해주세요')));
      return;
    }

    setState(() => _isSending = true);

    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) throw Exception('로그인이 필요해요');

      await _supabase.from('offers').insert({
        'request_id': widget.request['id'],
        'guide_id': myId,
        'price': price,
        'message': _messageController.text.trim(),
        'status': 'pending',
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('제안을 보냈어요! 🎉')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('제안 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.request['title'] ?? '';
    final budget = widget.request['budget'];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '가이드 제안 보내기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (budget != null && budget > 0) ...[
              const SizedBox(height: 4),
              Text(
                '여행자 희망 예산: ${_formatBudget(budget)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.travelingPurple,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // 제안 금액
            const Text(
              '제안 금액',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '예: 50000',
                suffixText: '원',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 메시지
            const Text(
              '한마디 메시지 (선택)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: '여행자에게 간단히 소개해주세요!',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 20),

            // 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _sendOffer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.travelingPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '제안 보내기',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBudget(int budget) {
    if (budget >= 10000) {
      return '${(budget / 10000).toStringAsFixed(0)}만원';
    }
    return '${budget}원';
  }
}
