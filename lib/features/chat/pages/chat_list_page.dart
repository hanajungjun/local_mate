import 'package:flutter/material.dart';
import 'package:localmate/services/discover_service.dart';
import 'package:localmate/services/chat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_room_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final DiscoverService _discoverService = DiscoverService();
  final ChatService _chatService = ChatService();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _matches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    // ✅ 실시간 리스너: 채팅방이 새로 생기면 상단 '새로운 메이트' 목록을 자동 갱신
    _supabase.from('chat_rooms').stream(primaryKey: ['id']).listen((_) {
      if (mounted) _loadInitialData();
    });
  }

  // 상단 '새로운 메이트' (아직 대화 안 한 매칭 후보) 로드
  Future<void> _loadInitialData() async {
    try {
      final allMatches = await _discoverService.fetchMatches();
      final myId = _supabase.auth.currentUser!.id;

      // 현재 내가 참여 중인 모든 채팅방의 상대방 ID 목록 가져오기
      final roomsResponse = await _supabase
          .from('chat_rooms')
          .select('participant_a, participant_b')
          .or('participant_a.eq.$myId,participant_b.eq.$myId');

      final existingChatUserIds = (roomsResponse as List).map((room) {
        return room['participant_a'] == myId
            ? room['participant_b'].toString()
            : room['participant_a'].toString();
      }).toSet();

      if (mounted) {
        setState(() {
          // 이미 채팅 중인 사람은 상단 바에서 제외
          _matches = allMatches.where((user) {
            return !existingChatUserIds.contains(user['id']);
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ 데이터 로딩 실패: $e");
    }
  }

  // 채팅방으로 이동 (생성 포함)
  Future<void> _navigateToChat(
    String targetId, [
    Map<String, dynamic>? user,
  ]) async {
    final myId = _supabase.auth.currentUser!.id;
    final roomId = await _chatService.getOrCreateRoom(myId, targetId);

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomPage(
            roomId: roomId,
            targetUser: user ?? {'id': targetId, 'nickname': '메이트'},
          ),
        ),
      );
      _loadInitialData(); // 돌아오면 상단 바 갱신
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: CustomScrollView(
          slivers: [
            // 1. 상단: 새로운 메이트 (가로 스크롤)
            SliverToBoxAdapter(child: _buildMatchBar()),

            // 2. 하단: 실시간 채팅 목록 (세로 리스트)
            SliverToBoxAdapter(
              child: const Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  "채팅 목록",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            _buildChatListSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text("새로운 메이트", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 110,
          child: _matches.isEmpty
              ? _buildEmptyMatchPlaceholder()
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _matches.length,
                  itemBuilder: (context, index) {
                    final user = _matches[index];
                    return GestureDetector(
                      onTap: () => _navigateToChat(user['id'], user),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundImage: NetworkImage(
                                (user['profile_image'] != null &&
                                        (user['profile_image'] as List)
                                            .isNotEmpty)
                                    ? user['profile_image'][0]
                                    : 'https://picsum.photos/200',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user['nickname'] ?? 'Mate',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const Divider(thickness: 1, height: 1),
      ],
    );
  }

  Widget _buildEmptyMatchPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.grey.shade100,
            child: Icon(Icons.add, color: Colors.grey.shade400),
          ),
          const SizedBox(width: 16),
          Text(
            "새로운 메이트를 매칭해보세요!",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildChatListSection() {
    final myId = _supabase.auth.currentUser!.id;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.getChatRoomsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final rooms = snapshot.data ?? [];
        if (rooms.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: Text("진행 중인 대화가 없습니다.")),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final room = rooms[index];
            final String targetId = room['other_participant_id'];

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, color: Colors.white),
              ),
              // 💡 닉네임은 현재 targetId만 알 수 있으므로, 실제 서비스 시 users 테이블과 조인된 데이터를 사용하세요.
              title: Text("매칭된 메이트 (${targetId.substring(0, 5)})"),
              subtitle: Text(
                room['last_message'] ?? "대화를 시작해보세요!",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                room['created_at'] != null
                    ? room['created_at'].toString().substring(11, 16)
                    : "",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () => _navigateToChat(targetId),
            );
          }, childCount: rooms.length),
        );
      },
    );
  }
}
