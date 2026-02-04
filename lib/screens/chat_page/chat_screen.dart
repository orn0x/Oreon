import 'package:flutter/material.dart';

import '../../models/chat_model.dart';
import 'chat_detail_screen.dart';

class ChatsScreen extends StatefulWidget {
  // Fixed: Made parameters optional with default values
  final String? userId;
  final String? avatarUrl;
  
  const ChatsScreen({
    super.key, 
    this.userId, 
    this.avatarUrl,
  });

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen>
    with SingleTickerProviderStateMixin {
  bool _isScanning = true;
  late AnimationController _radarController;

  // Sample chats with connection type and "distance" feel
  final List<Chat> _chats = [];

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    // If userId is provided, navigate to chat detail automatically
    if (widget.userId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToChatDetail(widget.userId!, widget.avatarUrl);
      });
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  void _navigateToChatDetail(String userId, String? avatarUrl) {
    // Find existing chat or create new one
    final existingChat = _chats.firstWhere(
      (chat) => chat.id == userId,
      orElse: () => Chat(
        id: userId,
        contactName: 'New Contact',
        lastMessage: 'Start chatting',
        timestamp: DateTime.now(),
        unreadCount: 0,
        connectionType: ConnectionType.wifi,
        avatarText: 'N',
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(chat: existingChat),
      ),
    );
  }

  void _toggleScanning() {
    setState(() {
      _isScanning = !_isScanning;
      if (_isScanning) {
        _radarController.repeat();
      } else {
        _radarController.stop();
      }
    });
  }

  String _getConnectionLabel(ConnectionType type) {
    switch (type) {
      case ConnectionType.bluetooth:
        return 'Nearby • Bluetooth';
      case ConnectionType.wifi:
        return 'Local • WiFi Direct';
      case ConnectionType.centralized:
        return 'Online • Server';
      default:
        return 'Online';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const RepaintBoundary(child: _StaticBackgroundGlow()),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: _chats.isEmpty ? _buildEmptyState() : _buildChatList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.teal.withOpacity(0.2),
              child: Text(
                chat.avatarText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                color: Colors.tealAccent.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (chat.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${chat.unreadCount}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(chat.timestamp),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatDetailScreen(chat: chat),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sensors_off,
            size: 80,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 24),
          Text(
            "No active chats",
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Start scanning to discover nearby contacts",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
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
      top: -150,
      left: -150,
      child: Container(
        width: 500,
        height: 500,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.teal.withOpacity(0.1),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}