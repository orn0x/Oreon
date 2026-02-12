import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oreon/services/WIFI/lan_module/lan_module.dart';
import 'package:provider/provider.dart';
import 'package:oreon/models/chat_model.dart';
import 'package:oreon/providers/providers.dart';
import 'package:oreon/main.dart';

class ChatDetailScreenWifi extends StatefulWidget {
  final Chat chat;

  const ChatDetailScreenWifi({
    super.key,
    required this.chat,
  });

  @override
  State<ChatDetailScreenWifi> createState() => _ChatDetailScreenWifiState();
}

class _ChatDetailScreenWifiState extends State<ChatDetailScreenWifi>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  bool _isTyping = false;
  bool _isInitialized = false;
  Timer? _typingTimer;
  StreamSubscription? _messageStreamSubscription;
  StreamSubscription? _deviceStreamSubscription;
  String? _myDeviceId;
  String? _myDeviceName;
  LanDevice? _targetDevice;
  String? _targetDeviceIp;
  final List<LanDevice> _discoveredDevices = [];
  final LanController _wifiController = LanController.instance;

  // Animation for typing indicator
  late AnimationController _typingAnimController;
  late Animation<double> _typingAnimation;

  @override
  void initState() {
    super.initState();
    _setupTypingAnimation();
    _initializeWiFiDirect();

    // Mark messages as read
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });
  }

  Future<void> _initializeWiFiDirect() async {
    try {
      debugPrint('🚀 Initializing WiFi Direct for chat: ${widget.chat.id}');
      
      // Start the LAN controller and wait for full initialization
      await _wifiController.start();
      
      // Give the controller a moment to discover devices
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Initialize target device from chat's deviceWrapper if available
      if (widget.chat.deviceWrapper != null) {
        setState(() {
          _targetDevice = LanDevice(
            id: widget.chat.deviceWrapper!.id,
            name: widget.chat.deviceWrapper!.name,
            ipAddress: widget.chat.deviceWrapper!.ipAddress,
            port: widget.chat.deviceWrapper!.port,
          );
          _targetDeviceIp = widget.chat.deviceWrapper!.ipAddress;
        });
        debugPrint('✅ Target device initialized from chat deviceWrapper');
        debugPrint('   Device: ${_targetDevice!.name}');
        debugPrint('   IP: ${_targetDeviceIp}');
      }
      
      // Get my actual device ID and name
      _myDeviceName = prefs.getString("name") ?? "Unknown User";
      
      _myDeviceId = 'Device_${prefs.getString("username") ?? "User"}_${prefs.getString("user_uuid") ?? "unknown"}';
      
      debugPrint('✅ WiFi Direct initialized');
      debugPrint('   Chat ID: ${widget.chat.id}');
      debugPrint('   Local IP: ${_wifiController.localIpAddress}');
      debugPrint('   Server Port: ${_wifiController.port}');
      
      // Subscribe to incoming messages AFTER controller is fully ready
      debugPrint('👂 Setting up message stream listener...');
      _messageStreamSubscription = _wifiController.incomingMessages.listen(
        (lanMessage) {
          debugPrint('🔔 Message stream event triggered');
          debugPrint('   Message ID: ${lanMessage.id}');
          debugPrint('   From: ${lanMessage.senderName}');
          debugPrint('   Content: ${lanMessage.content}');
          debugPrint('   Sender IP: ${lanMessage.senderIp}');
          _handleIncomingMessage(lanMessage);
        },
        onError: (error) {
          debugPrint('❌ Message stream error: $error');
        },
        onDone: () {
          debugPrint('📪 Message stream closed');
        },
      );
      
      // Subscribe to device discovery to track target device
      debugPrint('👁️ Setting up device discovery listener...');
      _deviceStreamSubscription = _wifiController.discoveredDevices.listen(
        (device) {
          debugPrint('📍 Device discovered: ${device.name} at ${device.ipAddress}');
          debugPrint('   Device ID: ${device.id}');
          debugPrint('   Device Port: ${device.port}');
          debugPrint('   Contact we seek: ${widget.chat.contactName}');
          
          // Add to discovered devices list
          if (!_discoveredDevices.any((d) => d.id == device.id)) {
            setState(() {
              _discoveredDevices.add(device);
            });
            debugPrint('✅ Added device to discovered list');
          }
          
          // Auto-select first discovered device as target (only if not already set from deviceWrapper)
          if (_targetDevice == null) {
            setState(() {
              _targetDevice = device;
              _targetDeviceIp = device.ipAddress;
            });
            debugPrint('✅ Auto-selected first discovered device as target');
          }
          
          // Also try to match by contact name
          if (device.name.toLowerCase().contains(widget.chat.contactName.toLowerCase()) || 
              device.name == widget.chat.contactName) {
            setState(() {
              _targetDevice = device;
              _targetDeviceIp = device.ipAddress;
            });
            debugPrint('✅ Target device matched by name');
          }
        },
        onError: (error) {
          debugPrint('❌ Device discovery error: $error');
        },
      );
      
      debugPrint('✅ Message stream listener and device discovery attached');
      
      if (mounted) {
        setState(() => _isInitialized = true);
      }
      
    } catch (e) {
      debugPrint('❌ WiFi Direct initialization failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize WiFi Direct: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _initializeWiFiDirect,
            ),
          ),
        );
      }
    }
  }

  void _handleIncomingMessage(LanMessage lanMessage) {
    debugPrint('📨 Incoming LAN message received:');
    debugPrint('   From: ${lanMessage.senderName}');
    debugPrint('   Content: ${lanMessage.content}');
    debugPrint('   Sender IP: ${lanMessage.senderIp}');
    debugPrint('   My Name: $_myDeviceName');
    debugPrint('   My Device ID: $_myDeviceId');
    
    // Skip our own messages (strict check)
    if (lanMessage.senderName == _myDeviceName) {
      debugPrint('⏭️ Skipping own message (sender matches: $_myDeviceName)');
      return;
    }
    
    debugPrint('✅ Message passed all filters, adding to provider');
    
    // Use deviceWrapper IP if available, otherwise use senderIp
    if (widget.chat.deviceWrapper != null) {
      final senderIp = widget.chat.deviceWrapper!.ipAddress;
      if (senderIp.isNotEmpty && senderIp != '0.0.0.0') {
        setState(() {
          _targetDeviceIp = senderIp;
          // Update target device with deviceWrapper info if we don't have one
          _targetDevice ??= LanDevice(
            id: widget.chat.deviceWrapper!.id,
            name: widget.chat.deviceWrapper!.name,
            ipAddress: widget.chat.deviceWrapper!.ipAddress,
            port: widget.chat.deviceWrapper!.port,
          );
        });
        debugPrint('💾 Stored sender IP from deviceWrapper: $_targetDeviceIp');
      }
    } else if (lanMessage.senderIp != '0.0.0.0') {
      setState(() {
        _targetDeviceIp = lanMessage.senderIp;
      });
      debugPrint('💾 Stored sender IP from message: $_targetDeviceIp');
    }
    
    if (mounted) {
      try {
        final messageProvider = context.read<MessageProvider>();
        final existingMessages = messageProvider.getMessagesForChat(widget.chat.id);
        debugPrint('   Existing messages in chat: ${existingMessages.length}');
        
        // Check if message already exists
        final isDuplicate = existingMessages.any((m) => m.id == lanMessage.id);
        
        if (isDuplicate) {
          debugPrint('⏭️ Message already exists (ID: ${lanMessage.id}), skipping duplicate');
          return;
        }
        
        debugPrint('📝 Creating Message object from LanMessage');
        debugPrint('   ID: ${lanMessage.id}');
        debugPrint('   Text: ${lanMessage.content}');
        debugPrint('   Sender: ${lanMessage.senderName}');
        
        // Add message to provider
        messageProvider.addMessage(
          chatId: widget.chat.id,
          text: lanMessage.content,
          isFromMe: false,
          messageId: lanMessage.id,
          timestamp: lanMessage.timestamp,
        );
        
        debugPrint('✅ Message added to provider successfully');
        
        // Verify message was added
        final updatedMessages = messageProvider.getMessagesForChat(widget.chat.id);
        debugPrint('   Messages after add: ${updatedMessages.length}');
        
        // Scroll to bottom
        _scrollToBottom();
        
      } catch (e) {
        debugPrint('❌ Error adding message to provider: $e');
        debugPrint('   Stack trace: ${e.toString()}');
      }
    } else {
      debugPrint('⚠️ Widget not mounted, cannot add message');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _messageStreamSubscription?.cancel();
    _deviceStreamSubscription?.cancel();
    _typingTimer?.cancel();
    _typingAnimController.dispose();
    // Don't stop the singleton controller - it's shared across screens
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
    context.read<MessageProvider>().markChatAsRead(widget.chat.id);
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      debugPrint('⚠️ Empty message, not sending');
      return;
    }

    if (!_isInitialized) {
      debugPrint('⚠️ WiFi not initialized, cannot send message');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WiFi Direct not ready, please wait...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    debugPrint('📤 Send message triggered');
    debugPrint('   Text: $text');
    debugPrint('   Target Device: ${_targetDevice?.name}');
    debugPrint('   Target IP: $_targetDeviceIp');
    debugPrint('   Discovered Devices: ${_discoveredDevices.length}');

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

    // Send via WiFi Direct
    _sendMessageViaWiFiDirect(text);
  }

  Future<void> _sendMessageViaWiFiDirect(String messageText) async {
    try {
      debugPrint('🔍 Checking target device availability...');
      debugPrint('   Target Device: ${_targetDevice?.name}');
      debugPrint('   Target IP: $_targetDeviceIp');
      debugPrint('   Discovered Devices Count: ${_discoveredDevices.length}');

      // If no target device, try to use first discovered device
      if (_targetDevice == null) {
        debugPrint('⚠️ No target device selected yet');
        
        if (_discoveredDevices.isEmpty) {
          debugPrint('❌ No devices discovered');
          throw Exception(
            'No devices discovered yet. Make sure the other device is online and has the app running.'
          );
        }

        // Use first discovered device
        _targetDevice = _discoveredDevices.first;
        _targetDeviceIp = _targetDevice!.ipAddress;
        debugPrint('✅ Using first discovered device: ${_targetDevice!.name}');
      }

      debugPrint('📡 Broadcasting message via WiFi Direct');
      debugPrint('   Text: $messageText');
      debugPrint('   Target: ${_targetDevice!.name}');
      debugPrint('   Target IP: ${_targetDevice!.ipAddress}');
      debugPrint('   Target Port: ${_targetDevice!.port}');
      debugPrint('   Sender: $_myDeviceName');

      // Send message using LanController API
      _wifiController.sendMessage(_targetDevice!, messageText);
      debugPrint('✅ Message sent successfully');
      
    } catch (e) {
      debugPrint('❌ Error sending message: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _sendMessageViaWiFiDirect(messageText),
            ),
          ),
        );
      }
    }
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_discoveredDevices.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.teal.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.devices, color: Colors.tealAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Found ${_discoveredDevices.length} device(s) • Target: ${_targetDevice?.name ?? "None"}',
                      style: const TextStyle(color: Colors.tealAccent, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_discoveredDevices.length > 1)
                    DropdownButton<LanDevice>(
                      value: _targetDevice,
                      items: _discoveredDevices.map((device) {
                        return DropdownMenuItem<LanDevice>(
                          value: device,
                          child: Text(device.name),
                        );
                      }).toList(),
                      onChanged: (device) {
                        if (device != null) {
                          setState(() {
                            _targetDevice = device;
                            _targetDeviceIp = device.ipAddress;
                          });
                          debugPrint('🎯 Selected device: ${device.name}');
                        }
                      },
                      underline: const SizedBox(),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
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
          CircleAvatar(
            child: Text(widget.chat.avatarText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.chat.contactName, style: const TextStyle(color: Colors.white)),
                Text(
                  _isInitialized
                      ? (_targetDevice != null ? 'Connected' : 'Searching devices...')
                      : 'Initializing...',
                  style: TextStyle(
                    color: _isInitialized
                        ? (_targetDevice != null ? Colors.greenAccent : Colors.orange)
                        : Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
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
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${messages.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                Icon(Icons.message_outlined, size: 48, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
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
              style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: message.isFromMe ? Colors.tealAccent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: message.isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatMessageTime(message.timestamp),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
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
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.tealAccent,
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
            onPressed: () => _showAttachmentOptions(),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  _sendTypingIndicator();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.tealAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.tealAccent, size: 20),
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
          _buildAttachmentOption(Icons.image, 'Photo', Colors.blueAccent, () {}),
          _buildAttachmentOption(Icons.videocam, 'Video', Colors.redAccent, () {}),
          _buildAttachmentOption(Icons.music_note, 'Audio', Colors.purpleAccent, () {}),
          _buildAttachmentOption(Icons.insert_drive_file, 'File', Colors.orangeAccent, () {}),
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
            leading: const Icon(Icons.copy, color: Colors.tealAccent),
            title: const Text('Copy', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message copied')),
              );
            },
          ),
          if (message.isFromMe)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('Delete', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                context.read<MessageProvider>().deleteMessage(widget.chat.id, message.id);
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chat ID: ${widget.chat.id}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text('Contact: ${widget.chat.contactName}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Text('My Device: $_myDeviceName', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text('My ID: $_myDeviceId', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Text('Discovered Devices: ${_discoveredDevices.length}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (_discoveredDevices.isNotEmpty)
                ..._discoveredDevices.map((d) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text('• ${d.name} (${d.ipAddress})', style: const TextStyle(color: Colors.tealAccent, fontSize: 11)),
                )),
              const SizedBox(height: 8),
              Text('Target Device: ${_targetDevice?.name ?? "None"}', style: TextStyle(color: _targetDevice != null ? Colors.greenAccent : Colors.orange, fontSize: 12)),
              Text('Target IP: ${_targetDeviceIp ?? "Not set"}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Text('Status: ${_isInitialized ? "Ready" : "Initializing..."}', style: TextStyle(color: _isInitialized ? Colors.greenAccent : Colors.orange, fontSize: 12)),
              Consumer<MessageProvider>(
                builder: (context, messageProvider, _) {
                  final messages = messageProvider.getMessagesForChat(widget.chat.id);
                  return Text('Messages: ${messages.length}', style: const TextStyle(color: Colors.white70, fontSize: 12));
                },
              ),
            ],
          ),
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