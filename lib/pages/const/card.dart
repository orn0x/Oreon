import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatCard extends StatefulWidget {
  const ChatCard({super.key});

  @override
  State<ChatCard> createState() => _ChatCardState();
}

class _ChatCardState extends State<ChatCard> {
  String name = '';
  String message = '';
  String time = '';
  String avatarImagePath = '';
  int nbrNewMessages = 0;
  bool isOnline = false;
  bool isTyping = false;

  String get messagePreview => isTyping ? 'typing...' : message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Card(
          color: Colors.white,
          child: ListTile(
            leading: Row(
              children: [
                CircleAvatar(
                  backgroundImage: AssetImage(avatarImagePath),
                ),
                
              ],
            ),
            title: Text(name),
            subtitle: Text(messagePreview),
            trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.eye , size: 12),
                    Text(time, style: const TextStyle(fontSize: 12)),
                  ],
          ),
        )
      )
    );
  }
}