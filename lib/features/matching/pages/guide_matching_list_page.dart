import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/core/utils/image_utils.dart';
import 'package:localmate/services/guide_matching_service.dart';
import 'guide_offer_dialog.dart';

class GuideMatchingListPage extends StatefulWidget {
  const GuideMatchingListPage({super.key});

  @override
  State<GuideMatchingListPage> createState() => _GuideMatchingListPageState();
}

class _GuideMatchingListPageState extends State<GuideMatchingListPage> {
  final GuideMatchingService _service = GuideMatchingService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = false;
  String _selectedLocation = '전체';
  String _nearbyLabel = '';

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── 텍스트 검색 ───────────────────────────
  Future<void> _load(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final result = await _service.getRequestsByLocation(query);

    if (!mounted) return;
    setState(() {
      _requests = result;
      _isLoading = false;
    });
  }

  // ─── 주변 버튼 → 범위 바텀시트 ─────────────
  void _showNearbyBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '범위 선택',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              '내 위치 기준으로 공고를 찾아드려요',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            _nearbyOption(
              icon: '🎯',
              label: '가까운 동네',
              sub: '반경 3km 이내',
              range: NearbyRange.close,
            ),
            const SizedBox(height: 10),
            _nearbyOption(
              icon: '🗺️',
              label: '조금 더 넓게',
              sub: '반경 5km 이내',
              range: NearbyRange.mid,
            ),
            const SizedBox(height: 10),
            _nearbyOption(
              icon: '🌏',
              label: '넓은 범위',
              sub: '반경 10km 이내',
              range: NearbyRange.far,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _nearbyOption({
    required String icon,
    required String label,
    required String sub,
    required NearbyRange range,
  }) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        await _loadNearby(range);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ─── 주변 공고 로드 ─────────────────────────
  Future<void> _loadNearby(NearbyRange range) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _selectedLocation = '📍 주변';
      _nearbyLabel = '';
      _searchController.clear();
    });

    try {
      final result = await _service.getNearbyRequests(range);
      if (!mounted) return;
      setState(() {
        _requests = result.results;
        _nearbyLabel = result.locationLabel;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // ─── 칩 탭 ─────────────────────────────────
  void _onChipTap(String location) {
    if (location == '📍 주변') {
      _showNearbyBottomSheet();
      return;
    }
    setState(() {
      _selectedLocation = location;
      _nearbyLabel = '';
    });
    _searchController.clear();
    _load(location == '전체' ? '' : location);
  }

  void _onSearch(String value) {
    setState(() {
      _selectedLocation = '전체';
      _nearbyLabel = '';
    });
    _load(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '주변 여행 요청',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildLocationChips(),
          // 주변 검색 시 지역 라벨
          if (_selectedLocation == '📍 주변' && _nearbyLabel.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(left: 20, bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 13, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    '$_nearbyLabel 주변 공고',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    onRefresh: () async {
                      if (_selectedLocation == '📍 주변') return;
                      await _load(
                        _selectedLocation == '전체' ? '' : _selectedLocation,
                      );
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) =>
                          _buildRequestCard(context, _requests[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── 검색바 ─────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearch,
        decoration: InputDecoration(
          hintText: '지역명으로 검색 (예: 제주, 행궁동)',
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _onChipTap(_selectedLocation);
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ─── 지역 칩 ─────────────────────────────────
  Widget _buildLocationChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: GuideMatchingService.popularLocations.map((loc) {
            final isSelected = _selectedLocation == loc;
            final isNearby = loc == '📍 주변';
            return GestureDetector(
              onTap: () => _onChipTap(loc),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isNearby ? Colors.blue : AppColors.travelingPurple)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: isNearby && !isSelected
                      ? Border.all(color: Colors.blue.shade200)
                      : null,
                ),
                child: Text(
                  loc,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : (isNearby ? Colors.blue : Colors.black87),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── 공고 카드 ───────────────────────────────
  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
    final user = request['users'] ?? {};
    final nickname = user['nickname'] ?? '여행자';
    final profileImage = getProfileImage(user['profile_image']);
    final title = request['title'] ?? '';
    final content = request['content'] ?? '';
    final locationName = request['location_name'] ?? '';
    final budget = request['budget'];
    final headcount = request['headcount'] ?? 1;
    final companionType = _companionLabel(request['companion_type']);

    final travelAt = DateTime.tryParse(request['travel_at'] ?? '');
    final dDay = travelAt != null
        ? travelAt.difference(DateTime.now()).inDays
        : null;
    final dDayLabel = dDay != null ? (dDay == 0 ? 'D-Day' : 'D-$dDay') : '';

    final createdAt = DateTime.tryParse(request['created_at'] ?? '');
    final timeAgo = createdAt != null ? _timeAgo(createdAt) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(profileImage),
                backgroundColor: Colors.blueGrey,
                onBackgroundImageError: (_, __) {},
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$locationName • $timeAgo',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (dDayLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.travelingPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    dDayLabel,
                    style: TextStyle(
                      color: AppColors.travelingPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildTag('👥 $headcount명'),
              if (companionType.isNotEmpty) _buildTag(companionType),
              if (budget != null && budget > 0)
                _buildTag('💰 ${_formatBudget(budget)}'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => GuideOfferDialog(request: request),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.travelingPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                '가이드 제안 보내기',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '이 지역의 여행 공고가 없어요',
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            '다른 지역을 검색해보세요!',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.black54),
      ),
    );
  }

  String _companionLabel(String? type) {
    switch (type) {
      case 'alone':
        return '🙋 혼자';
      case 'family':
        return '👨‍👩‍👧 가족';
      case 'friend':
        return '👫 친구';
      case 'couple':
        return '💑 커플';
      default:
        return '';
    }
  }

  String _formatBudget(int budget) {
    if (budget >= 10000) {
      return '${(budget / 10000).toStringAsFixed(0)}만원';
    }
    return '${budget}원';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}
