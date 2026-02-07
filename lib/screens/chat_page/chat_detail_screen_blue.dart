import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oreon/const/const.dart';
import 'package:oreon/services/Bluetooth/bluetooth_service.dart';
import 'package:provider/provider.dart';
import 'package:oreon/models/chat_model.dart';
import 'package:oreon/services/WIFI_Direct/wdirect_service.dart';
import 'package:oreon/providers/providers.dart';

class ChatDetailScreenBlue extends StatefulWidget {
  final Chat chat;

  const ChatDetailScreenBlue({
    super.key,
    required this.chat,
  });

  @override
  State<ChatDetailScreenBlue> createState() => _ChatDetailScreenBlueState();
}

class _ChatDetailScreenBlueState extends State<ChatDetailScreenBlue>
  with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  late BluetoothService _bluetoothService;
  bool _isTyping = false;
  Timer? _typingTimer;
  StreamSubscription? _messageStreamSubscription;
  String? _myDeviceId;
  String? _myDeviceName;

  // Animation for typing indicator
  late AnimationController _typingAnimController;
  late Animation<double> _typingAnimation;

  @override
  void initState() {
    super.initState();
    _setupTypingAnimation();
    _initializeBluetooth();

    // Mark messages as read
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });
  }

  Future<void> _initializeBluetooth() async {
    try {
      debugPrint('🚀 Initializing Bluetooth for chat: ${widget.chat.id}');
      _bluetoothService = BluetoothService();

      await _bluetoothService.requestPermissions();
      await _bluetoothService.isBluetoothEnabled();

      
      // Get my actual device ID and name from Bluetooth service
      _myDeviceName = await _bluetoothService.getDeviceName();
      
      _myDeviceId = _myDeviceName ?? "UnknownDevice_${DateTime.now().millisecondsSinceEpoch}";
      
      // Subscribe to incoming messages
        _messageStreamSubscription = _bluetoothService.onMessageReceived.listen((message) {
          debugPrint('📥 Received message from Bluetooth stream: $message');
          try {
            final messageMap = jsonDecode(message) as Map<String, dynamic>;
            final chatMessage = ChatMessage.fromJson(messageMap);
            _handleIncomingMessage(chatMessage);
          } catch (e) {
            debugPrint('❌ Failed to parse incoming message: $e');
          }
        });
      
      debugPrint('👂 Subscribed to message stream');
      
    } catch (e) {
      debugPrint('❌ Bluetooth initialization failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize Bluetooth: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _handleIncomingMessage(ChatMessage chatMessage) {
    debugPrint('📨 Incoming message received:');
    debugPrint('   From: ${chatMessage.sender}');
    debugPrint('   Text: ${chatMessage.text}');
    debugPrint('   ChatId: ${chatMessage.chatId}');
    debugPrint('   My ID: $_myDeviceId');
    
    // Check if this message is for our chat
    if (chatMessage.chatId != widget.chat.id) {
      debugPrint('⏭️ Message is for different chat, ignoring');
      return;
    }
    
    // Skip our own messages (already added by provider)
    if (chatMessage.sender == _myDeviceName) {
      debugPrint('⏭️ Skipping own message');
      return;
    }
    
    debugPrint('✅ Adding message to provider');
    
    if (mounted) {
      final messageProvider = context.read<MessageProvider>();
      
      // Check if message already exists
      final existingMessages = messageProvider.getMessagesForChat(widget.chat.id);
      final isDuplicate = existingMessages.any((m) => m.id == chatMessage.id);
      
      if (isDuplicate) {
        debugPrint('⏭️ Message already exists, skipping duplicate');
        return;
      }
      
      messageProvider.addMessage(
        chatId: widget.chat.id,
        text: chatMessage.text,
        isFromMe: false,
        messageId: chatMessage.id,
      );
      
      debugPrint('✅ Message added to chat');
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _messageStreamSubscription?.cancel();
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

  void _markMessagesAsRead() {
    final messageProvider = context.read<MessageProvider>();
    messageProvider.markChatAsRead(widget.chat.id);
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      debugPrint('⚠️ Empty message, not sending');
      return;
    }

    debugPrint('📤 Send message triggered');
    debugPrint('   Text: $text');

    final messageProvider = context.read<MessageProvider>();
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    debugPrint('   Message ID: $messageId');
    debugPrint('   Chat ID: ${widget.chat.id}');

    // Add message to provider immediately (optimistic update)
    messageProvider.addMessage(
      chatId: widget.chat.id,
      text: text,
      isFromMe: true,
      messageId: messageId,
    );

    _messageController.clear();
    _scrollToBottom();
    HapticFeedback.lightImpact();

    debugPrint('✅ Message added to provider');

    final chatMessage = ChatMessage(
      id: messageId,
      text: text,
      sender: _myDeviceName ?? "Unknown User",
      chatId: widget.chat.id,
      timestamp: DateTime.now(), appIdentifier: ConstApp().appIdentifier(),
    );

    // Send via Bluetooth
    _bluetoothService.sendMessage(jsonEncode(chatMessage.toJson()));
  }



  void _sendTypingIndicator() {
    _typingTimer?.cancel();
    if (!_isTyping) {
      setState(() => _isTyping = true);
    }
    _typingTimer = Timer(const Duration(seconds: 3), _stopTypingIndicator);
  }

  void _stopTypingIndicator() {
    _typingTimer?.cancel();
    if (mounted && _isTyping) {
      setState(() => _isTyping = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getConnectionLabel() {
    return 'Bluetooth';
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
      backgroundColor: const Color(0xFF0D0F14).withValues(alpha: 0.95),
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
                backgroundColor: Colors.teal.withValues(alpha: 0.3),
                backgroundImage: widget.chat.imageBytes != null
                    ? MemoryImage(widget.chat.imageBytes!)
                    : null,
                child: widget.chat.imageBytes == null
                    ? Text(
                      widget.chat.avatarText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    : null,
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
                
            ]),
          ),
        ],
      ),
      actions: [
        Consumer<MessageProvider>(
          builder: (context, messageProvider, child) {
            final messages = messageProvider.getMessagesForChat(widget.chat.id);
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${messages.length} msgs',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white70),
          onPressed: () => _showOptionsMenu(),
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    return Consumer<MessageProvider>(
      builder: (context, messageProvider, child) {
        final messages = messageProvider.getMessagesForChat(widget.chat.id);
        
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Send a message to start the conversation',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final showTimestamp = index == 0 ||
                message.timestamp.difference(messages[index - 1].timestamp).inMinutes > 15;

            return Column(
              children: [
                if (showTimestamp) _buildTimestampDivider(message.timestamp),
                _buildMessageBubble(message),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTimestampDivider(DateTime timestamp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatTimestampDivider(timestamp),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
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
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: message.isFromMe
                      ? Colors.tealAccent.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.06),
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
                        ? Colors.tealAccent.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.08),
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
                            color: Colors.white.withValues(alpha: 0.5),
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
        color = Colors.white.withValues(alpha: 0.4);
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        color = Colors.white.withValues(alpha: 0.6);
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.white.withValues(alpha: 0.6);
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
              color: Colors.white.withValues(alpha: 0.6),
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
                      color: Colors.tealAccent.withValues(alpha: 0.8),
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
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: Colors.tealAccent.withValues(alpha: 0.8)),
              onPressed: () {
                _showAttachmentOptions();
              },
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  style: const TextStyle(color: Colors.white),
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (text) {
                    if (text.isNotEmpty) {
                      _sendTypingIndicator();
                    } else {
                      _stopTypingIndicator();
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
                  color: Colors.tealAccent.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.tealAccent.withValues(alpha: 0.3),
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
          color: color.withValues(alpha: 0.2),
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                  final messageProvider = context.read<MessageProvider>();
                  messageProvider.deleteMessage(widget.chat.id, message.id);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D26),
        title: const Text('Chat Debug Info', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat ID: ${widget.chat.id}', style: const TextStyle(color: Colors.white70)),
            Text('Contact: ${widget.chat.contactName}', style: const TextStyle(color: Colors.white70)),
            Text('My Name: $_myDeviceName', style: const TextStyle(color: Colors.white70)),
            Text('My Device: $_myDeviceId', style: const TextStyle(color: Colors.white70)),
            Consumer<MessageProvider>(
              builder: (context, messageProvider, child) {
                final messages = messageProvider.getMessagesForChat(widget.chat.id);
                return Text('Messages: ${messages.length}', style: const TextStyle(color: Colors.white70));
              },
            ),
            Text('Connection: ${_getConnectionLabel()}', style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
      right: -150,
      child: Container(
        width: 500,
        height: 500,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.teal.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}