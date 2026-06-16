import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import '../../providers/auth_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserProvider).value?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login to view chats'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showNewChatDialog(context, ref, userId),
          ),
        ],
      ),
      body: StreamBuilder<List<ChatRoom>>(
        stream: ref.watch(chatServiceProvider).getChatRooms(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final chatRooms = snapshot.data ?? [];

          if (chatRooms.isEmpty) {
            return const Center(child: Text('No messages yet'));
          }

          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final room = chatRooms[index];
              final unreadCount = room.unreadCount[userId] ?? 0;

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: room.imageUrl != null
                      ? NetworkImage(room.imageUrl!)
                      : null,
                  child: room.imageUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(room.name),
                subtitle: room.lastMessage != null
                    ? Text(
                        room.lastMessage!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (room.lastMessageTime != null)
                      Text(
                        _formatTimestamp(room.lastMessageTime!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () => context.push(
                  '/student/dashboard/chat/${room.id}',
                  extra: room,
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(timestamp);
    } else if (difference.inDays > 0) {
      return DateFormat('E').format(timestamp);
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  Future<void> _showNewChatDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    // New chat dialog implementation
    // This should show a list of available users/staff to chat with
  }
}