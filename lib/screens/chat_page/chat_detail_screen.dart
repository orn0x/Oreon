import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../models/chat_model.dart';

class ChatDetailScreen extends StatefulWidget {
  final Chat chat;

  const ChatDetailScreen({
    super.key,
    required this.chat,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
  with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  List<Message> _messages = [];
  bool _isTyping = false;
  bool _isOnline = false;
  bool _isConnecting = false;

  // WebSocket for real-time messaging
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _typingTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // Change this to your actual WebSocket URL
  static const String _wsUrl = 'ws://10.0.0.1:8080/ws/chat';

  // Animation for typing indicator
  late AnimationController _typingAnimController;
  late Animation<double> _typingAnimation;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _connectWebSocket();
    _setupTypingAnimation();

    // Mark messages as read
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          for (var msg in _messages) {
            if (!msg.isFromMe && !msg.isRead) {
              msg.isRead = true;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _disconnectWebSocket();
    _typingTimer?.cancel();
    _typingAnimController.dispose();
    super.dispose();
  }

  void _setupTypingAnimation() {
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _typingAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _typingAnimController, curve: Curves.easeInOut),
    );
  }

  void _loadMessages() {
    // Load sample messages - replace with actual database/API call
    setState(() async {
      _messages = await WebSocketChannel.connect(Uri.parse(_wsUrl)).stream
          .map((data) => jsonDecode(data) as Map<String, dynamic>)
          .map((json) => Message(
                id: json['id'],
                text: json['text'],
                timestamp: DateTime.parse(json['timestamp']),
                isFromMe: json['isFromMe'],
                isRead: json['isRead'],
                status: MessageStatus.values[json['status']],
              ))
          .toList();
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _connectWebSocket() {
    if (_channel != null) return;

    setState(() => _isConnecting = true);

    try {
      final uri = Uri.parse(_wsUrl);
      _channel = WebSocketChannel.connect(uri);

      // Send connection message
      _channel!.sink.add(jsonEncode({
        "action": "connect",
        "userId": "current_user_id", // Replace with actual user ID
        "chatId": widget.chat.id,
      }));

      _subscription = _channel!.stream.listen(
        (dynamic rawMessage) {
          if (!mounted) return;

          String text;
          if (rawMessage is String) {
            text = rawMessage;
          } else if (rawMessage is List<int>) {
            text = utf8.decode(rawMessage);
          } else {
            return;
          }

          try {
            final decoded = jsonDecode(text) as Map<String, dynamic>;

            switch (decoded['type']) {
              case 'message':
                _handleIncomingMessage(decoded['data']);
                break;

              case 'typing':
                setState(() => _isTyping = decoded['isTyping'] ?? false);
                break;

              case 'read_receipt':
                _updateMessageStatus(
                    decoded['messageId'], MessageStatus.read);
                break;

              case 'delivered_receipt':
                _updateMessageStatus(
                    decoded['messageId'], MessageStatus.delivered);
                break;

              case 'user_status':
                setState(() => _isOnline = decoded['online'] ?? false);
                break;
            }
          } catch (e) {
            debugPrint('WebSocket parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _handleDisconnect();
        },
      );

      setState(() {
        _isConnecting = false;
        _isOnline = true;
        _reconnectAttempts = 0;
      });
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _handleDisconnect();
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final message = Message(
      id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: data['text'] ?? '',
      timestamp: DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String()),
      isFromMe: false,
      isRead: false,
      status: MessageStatus.delivered,
    );

    setState(() {
      _messages.add(message);
    });

    _scrollToBottom();
    HapticFeedback.lightImpact();

    // Send read receipt
    _sendReadReceipt(message.id);
  }

  void _updateMessageStatus(String messageId, MessageStatus status) {
    setState(() {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index].status = status;
        if (status == MessageStatus.read) {
          _messages[index].isRead = true;
        }
      }
    });
  }

  void _handleDisconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;

    setState(() {
      _isConnecting = false;
      _isOnline = false;
    });

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final delay = Duration(seconds: 2 * _reconnectAttempts);

      _reconnectTimer = Timer(delay, () {
        if (mounted) {
          _connectWebSocket();
        }
      });
    }
  }

  void _disconnectWebSocket() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
      isFromMe: true,
      isRead: false,
      status: MessageStatus.sending,
    );

    setState(() {
      _messages.add(message);
      _messageController.clear();
    });

    _scrollToBottom();
    HapticFeedback.lightImpact();

    // Send via WebSocket
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        "action": "send_message",
        "messageId": message.id,
        "chatId": widget.chat.id,
        "text": text,
        "timestamp": message.timestamp.toIso8601String(),
      }));

      // Update status to sent after small delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            message.status = MessageStatus.sent;
          });
        }
      });

      // Simulate delivery after 1 second
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            message.status = MessageStatus.delivered;
          });
        }
      });
    }

    _stopTypingIndicator();
  }

  void _sendTypingIndicator() {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        "action": "typing",
        "chatId": widget.chat.id,
        "isTyping": true,
      }));
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), _stopTypingIndicator);
  }

  void _stopTypingIndicator() {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        "action": "typing",
        "chatId": widget.chat.id,
        "isTyping": false,
      }));
    }
  }

  void _sendReadReceipt(String messageId) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        "action": "read_receipt",
        "chatId": widget.chat.id,
        "messageId": messageId,
      }));
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _getConnectionLabel() {
    switch (widget.chat.connectionType) {
      case ConnectionType.bluetooth:
        return 'Bluetooth';
      case ConnectionType.wifi:
        return 'WiFi Direct';
      case ConnectionType.centralized:
        return 'Server';
      default:
        return 'Online';
    }
  }

  Color _getConnectionColor() {
    switch (widget.chat.connectionType) {
      case ConnectionType.bluetooth:
        return Colors.blueAccent;
      case ConnectionType.wifi:
        return Colors.tealAccent;
      case ConnectionType.centralized:
        return Colors.purpleAccent;
      default:
        return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                const RepaintBoundary(child: _StaticBackgroundGlow()),
                _buildMessageList(),
              ],
            ),
          ),
          if (_isTyping) _buildTypingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0F14).withOpacity(0.95),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.teal.withOpacity(0.3),
                child: Text(
                  widget.chat.avatarText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0D0F14),
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chat.contactName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _getConnectionColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isOnline ? _getConnectionLabel() : 'Offline',
                      style: TextStyle(
                        color: _getConnectionColor().withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam_outlined, color: Colors.white70),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video call feature coming soon')),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.call_outlined, color: Colors.white70),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Voice call feature coming soon')),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          onPressed: () => _showOptionsMenu(),
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final showTimestamp = index == 0 ||
            message.timestamp.difference(_messages[index - 1].timestamp).inMinutes > 15;

        return Column(
          children: [
            if (showTimestamp) _buildTimestampDivider(message.timestamp),
            _buildMessageBubble(message),
          ],
        );
      },
    );
  }

  Widget _buildTimestampDivider(DateTime timestamp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatTimestampDivider(timestamp),
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
        ],
      ),
    );
  }

  String _formatTimestampDivider(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  Widget _buildMessageBubble(Message message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            message.isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isFromMe) const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptions(message),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: message.isFromMe
                      ? Colors.tealAccent.withOpacity(0.2)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft:
                        Radius.circular(message.isFromMe ? 20 : 4),
                    bottomRight:
                        Radius.circular(message.isFromMe ? 4 : 20),
                  ),
                  border: Border.all(
                    color: message.isFromMe
                        ? Colors.tealAccent.withOpacity(0.3)
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatMessageTime(message.timestamp),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                        if (message.isFromMe) ...[
                          const SizedBox(width: 4),
                          _buildMessageStatusIcon(message.status),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (message.isFromMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMessageStatusIcon(MessageStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        color = Colors.white.withOpacity(0.4);
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        color = Colors.white.withOpacity(0.6);
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.white.withOpacity(0.6);
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.tealAccent;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = Colors.redAccent;
        break;
    }

    return Icon(icon, size: 14, color: color);
  }

  String _formatMessageTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            '${widget.chat.contactName} is typing',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          FadeTransition(
            opacity: _typingAnimation,
            child: Row(
              children: List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F14),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: Colors.tealAccent.withOpacity(0.8)),
              onPressed: () {
                _showAttachmentOptions();
              },
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  style: const TextStyle(color: Colors.white),
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (text) {
                    if (text.isNotEmpty) {
                      _sendTypingIndicator();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.tealAccent.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.black87,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D26),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAttachmentOption(
              Icons.photo_library,
              'Photo',
              Colors.purpleAccent,
              () {},
            ),
            _buildAttachmentOption(
              Icons.video_library,
              'Video',
              Colors.redAccent,
              () {},
            ),
            _buildAttachmentOption(
              Icons.insert_drive_file,
              'File',
              Colors.blueAccent,
              () {},
            ),
            _buildAttachmentOption(
              Icons.location_on,
              'Location',
              Colors.greenAccent,
              () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label sharing coming soon')),
        );
      },
    );
  }

  void _showMessageOptions(Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D26),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white70),
              title: const Text('Copy', style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied')),
                );
              },
            ),
            if (message.isFromMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  setState(() => _messages.remove(message));
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D26),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: Colors.white70),
              title: const Text('View Profile', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off, color: Colors.white70),
              title: const Text('Mute', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.redAccent),
              title: const Text('Block', style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class Message {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isFromMe;
  bool isRead;
  MessageStatus status;

  Message({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isFromMe,
    required this.isRead,
    required this.status,
  });
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class _StaticBackgroundGlow extends StatelessWidget {
  const _StaticBackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -150,
      right: -150,
      child: Container(
        width: 500,
        height: 500,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.teal.withOpacity(0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}