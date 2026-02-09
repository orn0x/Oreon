import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:oreon/const/const.dart';
import 'package:oreon/models/chat_model.dart';
import 'package:oreon/providers/providers.dart';
import 'chat_detail_screen_wifi.dart';
import 'chat_detail_screen_blue.dart';

class ChatsScreen extends StatefulWidget {
  final Chat? chat;
  // final Uint8List? contactImageBytes;

  const ChatsScreen({
    super.key,
    this.chat,
  });

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    if (widget.chat != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addDiscoveredContact();
      });
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  void _addDiscoveredContact() {
    final chatProvider = context.read<ChatListProvider>();

    final newChat = Chat(
      identifier: widget.chat!.identifier,
      id: widget.chat!.id,
      contactName: widget.chat!.contactName,
      lastMessage: "",
      timestamp: DateTime.now(),
      unreadCount: 0,
      connectionType: ConnectionType.wifi,
      avatarText: widget.chat!.contactName[0].toUpperCase(),
      deviceId: widget.chat!.deviceId,
      avatarImageBytes: widget.chat!.avatarImageBytes,
    );

    chatProvider.addOrUpdateChat(newChat);
  }

  void _navigateToChat(Chat chat) {
    Widget screen;

    switch (chat.connectionType) {
      case ConnectionType.bluetooth:
        screen = ChatDetailScreenBlue(chat: chat);
        break;
      case ConnectionType.wifi:
        screen = ChatDetailScreenWifi(chat: chat);
        break;
      case ConnectionType.centralized:
        screen = ChatDetailScreenWifi(chat: chat);
        break;
      default:
        screen = ChatDetailScreenWifi(chat: chat);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _deleteContact(Chat chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1d26),
        title: Text(
          'Delete ${chat.contactName}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This contact will be removed from your chat list.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.tealAccent)),
          ),
          TextButton(
            onPressed: () {
              final chatProvider = context.read<ChatListProvider>();
              chatProvider.removeChat(chat.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatListProvider, WiFiDirectProvider>(
      builder: (context, chatProvider, wifiProvider, _) {
        final isScanning = wifiProvider.isScanning; // ← real state from provider

        return Scaffold(
          backgroundColor: const Color(0xFF0D0F14),
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(
              'Chats',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Stack(
            children: [
              const _StaticBackgroundGlow(),
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: chatProvider.chats.isEmpty
                          ? _buildEmptyState(isScanning)
                          : _buildChatList(chatProvider.chats),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatList(List<Chat> chats) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        return Dismissible(
          key: ValueKey(chat.id),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            final chatProvider = context.read<ChatListProvider>();
            chatProvider.removeChat(chat.id);
          },
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.teal.withValues(alpha: 0.25),
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
              subtitle: Text(
                _getConnectionLabel(chat.connectionType),
                style: TextStyle(
                  color: Colors.tealAccent.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
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
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    iconSize: 20,
                    onPressed: () => _deleteContact(chat),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              onTap: () => _navigateToChat(chat),
            ),
          ),
        );
      },
    );
  }

  String _getConnectionLabel(ConnectionType type) {
    return switch (type) {
      ConnectionType.bluetooth => 'Nearby • Bluetooth',
      ConnectionType.wifi => 'Local • WiFi',
      ConnectionType.centralized => 'Online',
      _ => 'Unknown',
    };
  }

  Widget _buildEmptyState(bool isScanning) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedOpacity(
            opacity: isScanning ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 600),
            child: Icon(
              isScanning ? Icons.radar : Icons.sensors_off,
              size: 90,
              color: isScanning ? Colors.tealAccent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            isScanning ? "Scanning nearby devices..." : "No active chats",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isScanning
                ? "Looking for people nearby on the same WiFi"
                : "Start scanning to discover nearby contacts",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticBackgroundGlow extends StatelessWidget {
  const _StaticBackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -180,
      left: -180,
      child: Container(
        width: 600,
        height: 600,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.teal.withValues(alpha: 0.12),
              Colors.transparent,
            ],
            stops: const [0.0, 0.7],
          ),
        ),
      ),
    );
  }
}