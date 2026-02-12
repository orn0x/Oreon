import 'package:flutter/material.dart';
import 'package:oreon/models/chat_model.dart';
import 'package:oreon/providers/providers.dart';
import 'package:provider/provider.dart';

class ChatListWidget extends StatelessWidget {
  const ChatListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final chats = context.read<ChatListProvider>().chats;
    if (chats.isEmpty) {
      return const Center(
        child: Text(
          'No recent chats yet.\nStart a conversation!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 16,
          ),
        ),
      );
    }
    return _buildChatList(context, chats);
  }

  Widget _buildChatList(BuildContext context, List<Chat> chats) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        return Dismissible(
          key: ValueKey(chat.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) {
            context.read<ChatListProvider>().removeChat(chat.deviceId as String);
          },
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.teal.withOpacity(0.25),
                foregroundImage: chat.avatarImageBytes != null
                    ? MemoryImage(chat.avatarImageBytes!)
                    : null,
                child: chat.avatarImageBytes == null
                    ? Text(
                        chat.avatarText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              title: Text(
                chat.contactName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (chat.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.tealAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${chat.unreadCount}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimeAgo(chat.timestamp),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              onTap: () => _navigateToChat(context, chat),
            ),
          ),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${(difference.inDays / 7).floor()}w';
    }
  }

  void _navigateToChat(BuildContext context, Chat chat) {
    if(chat.connectionType == ConnectionType.wifi) {
      Navigator.pushNamed(context, '/wchat', arguments: chat);
    } else if(chat.connectionType == ConnectionType.bluetooth) {
      Navigator.pushNamed(context, '/bchat', arguments: chat);
    }
  }
}