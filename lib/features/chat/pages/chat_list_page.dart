import 'package:flutter/material.dart';
import 'package:localmate/services/discover_service.dart';
import 'package:localmate/services/chat_service.dart'; // 💡 추가
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_room_page.dart'; // 채팅방 페이지 import

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final DiscoverService _discoverService = DiscoverService();
  final ChatService _chatService = ChatService(); // 💡 서비스 인스턴스 생성

  List<Map<String, dynamic>> _matches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    // 1. 전체 매칭된 유저 가져오기
    final allMatches = await _discoverService.fetchMatches();
    final myId = Supabase.instance.client.auth.currentUser!.id;

    // 2. 현재 내가 참여 중인 대화방 목록 가져오기 (가상 테이블 사용 가능)
    final roomsResponse = await Supabase.instance.client
        .from('chat_rooms')
        .select('participant_a, participant_b');

    // 3. 이미 대화 중인 상대방의 ID들만 Set으로 추출
    final existingChatUserIds = (roomsResponse as List).map((room) {
      return room['participant_a'] == myId
          ? room['participant_b']
          : room['participant_a'];
    }).toSet();

    if (mounted) {
      setState(() {
        // 💡 핵심: 전체 매칭 중 '이미 대화방이 있는 사람'은 제외!
        _matches = allMatches.where((user) {
          return !existingChatUserIds.contains(user['id']);
        }).toList();

        _isLoading = false;
      });
    }
  }

  // 🎯 프사 클릭 시 실행될 로직
  void _startChat(Map<String, dynamic> targetUser) async {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    final targetId = targetUser['id'];

    // 💡 서비스에서 방 가져오기 또는 생성
    final roomId = await _chatService.getOrCreateRoom(myId, targetId);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ChatRoomPage(roomId: roomId, targetUser: targetUser),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildMatchBar(), // 1. 상단 매칭 바
                Expanded(child: _buildChatList()), // 2. 하단 채팅 목록
              ],
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
              ? _buildEmptyMatchPlaceholder() // 💡 비어있을 때 보여줄 가이드 UI
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _matches.length,
                  itemBuilder: (context, index) {
                    final user = _matches[index];
                    return GestureDetector(
                      onTap: () => _startChat(user),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundImage: NetworkImage(
                                user['profile_image'][0],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user['nickname'] ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const Divider(),
      ],
    );
  }

  // 💡 새로운 메이트가 없을 때 보여줄 예쁜 플레이스홀더
  Widget _buildEmptyMatchPlaceholder() {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.grey.shade200,
                child: Icon(Icons.add, color: Colors.grey.shade400, size: 30),
              ),
              const SizedBox(height: 8),
              const Text(
                "찾아보기",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Text(
            "새로운 메이트를 매칭해보세요!",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.getChatRoomsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rooms = snapshot.data ?? [];
        if (rooms.isEmpty)
          return const Center(child: Text("아직 진행 중인 대화가 없어요."));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            // 💡 View에서 계산해준 상대방 ID를 바로 사용합니다!
            final String targetId = room['other_participant_id'];

            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, color: Colors.white),
              ),
              // 💡 임시로 Anna라고 띄우지만, 나중에 'users' 테이블과 Join하면 진짜 이름이 나옵니다.
              title: Text("대화 상대: Anna (${targetId.substring(0, 4)})"),
              subtitle: const Text("최근 대화 내용을 확인하세요."),
              trailing: Text(
                room['created_at'] != null
                    ? (room['created_at'] as String).substring(11, 16)
                    : "방금",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () {
                // 💡 클릭 시 Anna님과의 대화방으로 즉시 이동!
                _startChat({'id': targetId, 'nickname': 'Anna'});
              },
            );
          },
        );
      },
    );
  }
}
