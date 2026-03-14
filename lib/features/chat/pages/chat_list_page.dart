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

    _supabase.from('chat_rooms').stream(primaryKey: ['id']).listen((_) {
      if (mounted) _loadInitialData();
    });

    _supabase.from('likes').stream(primaryKey: ['id']).listen((_) {
      if (mounted) _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    try {
      final allMatches = await _discoverService.fetchMatches();
      final myId = _supabase.auth.currentUser!.id;

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

  // ✅ 채팅방 이동 함수 (닉네임 데이터 포함)
  Future<void> _navigateToChat(
    String targetId,
    Map<String, dynamic> targetUser,
  ) async {
    final myId = _supabase.auth.currentUser!.id;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final roomId = await _chatService.getOrCreateRoom(myId, targetId);

      if (mounted) {
        Navigator.pop(context); // 로딩 닫기
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomPage(
              roomId: roomId,
              targetUser: targetUser, // ✅ 여기서 넘겨준 닉네임이 채팅방 상단에 뜸!
            ),
          ),
        );
        _loadInitialData();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("❌ 채팅방 이동 실패: $e");
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
            SliverToBoxAdapter(child: _buildMatchBar()),
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

  Widget _buildChatListSection() {
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

            return FutureBuilder<Map<String, dynamic>>(
              future: _supabase
                  .from('users')
                  .select('id, nickname, profile_image')
                  .eq('id', targetId)
                  .single(),
              builder: (context, userSnapshot) {
                final userData = userSnapshot.data;
                final String nickname = userData?['nickname'] ?? "메이트";

                // ✅ 에러 방지용: null 체크와 isEmpty 체크를 확실하게 bool로 변환
                final bool hasProfile =
                    userData != null &&
                    userData['profile_image'] != null &&
                    (userData['profile_image'] as List).isNotEmpty;

                final String? profileImg = hasProfile
                    ? userData!['profile_image'][0]
                    : null;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    backgroundImage: profileImg != null
                        ? NetworkImage(profileImg)
                        : null,
                    backgroundColor: Colors.blueAccent,
                    child: profileImg == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  title: Text(
                    nickname,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    room['last_message'] ?? "대화를 시작해보세요!",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _navigateToChat(targetId, {
                    'id': targetId,
                    'nickname': nickname,
                    'profile_image': userData?['profile_image'],
                  }),
                );
              },
            );
          }, childCount: rooms.length),
        );
      },
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
}
