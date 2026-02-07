import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:oreon/models/chat_model.dart';
import 'package:oreon/models/message_model.dart' hide ConnectionType;
import 'package:oreon/services/WIFI_Direct/wdirect_service.dart';
import 'package:oreon/const/const.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  String _userName = 'User Name';
  String _userBio = 'No bio yet';
  String _userEmail = 'user@example.com';
  String _userUsername = 'User';
  String _userPhone = '+1234567890';
  String _userSeed = '';
  String _userUUID = '';
  File ? _avatarPicture;

  // Getters
  String get userName => _userName;
  String get userBio => _userBio;
  String get userEmail => _userEmail;
  String get userUsername => _userUsername;
  String get userPhone => _userPhone;
  String get userSeed => _userSeed;
  String get userUUID => _userUUID;
  File ? get avatarPicture => _avatarPicture;

  // Load data from SharedPreferences
  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('name') ?? 'User Name';
    _userBio = prefs.getString('user_bio') ?? 'No bio yet';
    _userUsername = prefs.getString('username') ?? 'User';
    _userEmail = prefs.getString('user_email') ?? 'user@example.com';
    _userPhone = prefs.getString('user_phone') ?? '+1234567890';
    _userSeed = prefs.getString('user_seed') ?? '';
    _userUUID = prefs.getString('user_uuid') ?? '';
    String? avatarPath = prefs.getString('avatar_picture');
    _avatarPicture = avatarPath != null && avatarPath.isNotEmpty ? File(avatarPath) : null;
    notifyListeners();
  }

  // Update all user data at once
  Future<void> updateUserData({
    required String name,
    required String bio,
    required String email,
    required String username,
    required String phone,
    String? avatarPicture,
    required String? uuid,
    String? seed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    _userName = name;
    _userBio = bio;
    _userEmail = email;
    _userPhone = phone;
    _userUsername = username;
    _avatarPicture = avatarPicture != null ? File(avatarPicture) : null;
    _userSeed = seed ?? '';
    _userUUID = uuid ?? '';

    await prefs.setString('name', name);
    await prefs.setString('user_bio', bio);
    await prefs.setString('user_email', email);
    await prefs.setString('username', username);
    await prefs.setString('user_phone', phone);
    await prefs.setString('avatar_picture', _avatarPicture?.path ?? '');
    await prefs.setString('user_seed', _userSeed);
    await prefs.setString('user_uuid', _userUUID);

    notifyListeners();
  }

  // Update individual fields
  Future<void> updateUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    _userName = name;
    await prefs.setString('name', name);
    notifyListeners();
  }

  Future<void> updateUserBio(String bio) async {
    final prefs = await SharedPreferences.getInstance();
    _userBio = bio;
    await prefs.setString('user_bio', bio);
    notifyListeners();
  }

  Future<void> updateAvatarPicture(String path) async {
    final prefs = await SharedPreferences.getInstance();
    _avatarPicture = File(path);
    await prefs.setString('avatar_picture', path);
    notifyListeners();
  }

  Future<void> updateSeed(String seed) async {
    final prefs = await SharedPreferences.getInstance();
    _userSeed = seed;
    await prefs.setString('user_seed', seed);
    notifyListeners();
  }
}

class SettingsProvider extends ChangeNotifier {
  bool _bluetoothEnabled = true;
  bool _wifiEnabled = true;
  bool _notificationsEnabled = true;
  bool _autoConnect = false;

  // Getters
  bool get bluetoothEnabled => _bluetoothEnabled;
  bool get wifiEnabled => _wifiEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get autoConnect => _autoConnect;

  // Load settings from SharedPreferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _bluetoothEnabled = prefs.getBool('bluetooth_enabled') ?? true;
    _wifiEnabled = prefs.getBool('wifi_enabled') ?? true;
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    _autoConnect = prefs.getBool('auto_connect') ?? false;
    notifyListeners();
  }

  // Toggle methods
  Future<void> toggleBluetooth(bool value) async {
    _bluetoothEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bluetooth_enabled', value);
    notifyListeners();
  }

  Future<void> toggleWifi(bool value) async {
    _wifiEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wifi_enabled', value);
    notifyListeners();
  }

  Future<void> toggleNotifications(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    notifyListeners();
  }

  Future<void> toggleAutoConnect(bool value) async {
    _autoConnect = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_connect', value);
    notifyListeners();
  }
}

class ChatListProvider extends ChangeNotifier {
  List<Chat> _chats = [];
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<Chat> get chats => List.unmodifiable(_chats);
  List<Chat> get recentChats => _chats.where((chat) => chat.lastMessage.isNotEmpty).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  List<Chat> get wifiDirectChats => _chats.where((chat) => chat.connectionType == ConnectionType.wifi).toList();
  List<Chat> get bluetoothChats => _chats.where((chat) => chat.connectionType == ConnectionType.bluetooth).toList();
  int get unreadCount => _chats.fold(0, (sum, chat) => sum + chat.unreadCount);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize with sample chats
  Future<void> initializeChats() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Load saved chats from SharedPreferences or initialize with defaults
      await loadChatsFromStorage();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadChatsFromStorage() async {
    await _loadChats();
    
    // If no saved chats, initialize with sample data
    if (_chats.isEmpty) {
      _chats = [];
    }
  }

  // Add or update a chat by Chat object
  void addOrUpdateChat(Chat chat) {
    final existingChatIndex = _chats.indexWhere((c) => c.id == chat.id);
    
    if (existingChatIndex >= 0) {
      // Update existing chat
      _chats[existingChatIndex] = chat;
    } else {
      // Add new chat at the beginning for recent chats
      _chats.insert(0, chat);
    }
    
    notifyListeners();
    _saveChats();
  }

  // Add a new chat
  Chat addChat({
    required String contactName,
    required String deviceId,
    String? avatarUrl,
    Uint8List? imageBytes,
    ConnectionType connectionType = ConnectionType.wifi,
  }) {
    final existingChatIndex = _chats.indexWhere((chat) => chat.id == deviceId);
    
    if (existingChatIndex >= 0 && _chats[existingChatIndex].contactName != contactName) {
      // Update existing chat
      _chats[existingChatIndex] = Chat(
        identifier: ConstApp().appIdentifier(),
        id: deviceId,
        contactName: contactName,
        lastMessage: 'Connected via ${connectionType == ConnectionType.wifi ? "WiFi Direct" : "Bluetooth"}',
        timestamp: DateTime.now(),
        unreadCount: 0,
        connectionType: connectionType,
        avatarText: contactName.isNotEmpty ? contactName[0].toUpperCase() : 'U',
        avatarUrl: avatarUrl,
        imageBytes: imageBytes,
        deviceId: deviceId,
        avatarImageBytes: imageBytes,
      );
      notifyListeners();
      return _chats[existingChatIndex];
    } else {
      // Create new chat
      final newChat = Chat(
        identifier: ConstApp().appIdentifier(),
        id: deviceId,
        contactName: contactName,
        lastMessage: 'Connected via ${connectionType == ConnectionType.wifi ? "WiFi Direct" : "Bluetooth"}',
        timestamp: DateTime.now(),
        unreadCount: 0,
        connectionType: connectionType,
        avatarText: contactName.isNotEmpty ? contactName[0].toUpperCase() : 'U',
        avatarUrl: avatarUrl,
        imageBytes: imageBytes,
        deviceId: deviceId,
        avatarImageBytes: imageBytes,
      );
      
      _chats.insert(0, newChat); // Add at the beginning for recent chats
      notifyListeners();
      return newChat;
    }
  }

  void removeChat(String chatId) {
    _chats.removeWhere((chat) => chat.id == chatId);
    notifyListeners();
  }

  Future<void> cleanAllChats() async {
    _chats.clear();
    notifyListeners();
  }

  void updateChatLastMessage(String chatId, String lastMessage, {int? unreadCount}) {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index != -1) {
      final chat = _chats[index];
      _chats[index] = Chat(
        identifier: chat.identifier,
        id: chat.id,
        contactName: chat.contactName,
        lastMessage: lastMessage,
        timestamp: DateTime.now(),
        unreadCount: unreadCount ?? chat.unreadCount,
        connectionType: chat.connectionType,
        avatarText: chat.avatarText,
        avatarUrl: chat.avatarUrl,
        imageBytes: chat.imageBytes,
        deviceId: chat.deviceId,
        avatarImageBytes: chat.avatarImageBytes,
      );
      
      // Move to top for recent activity
      final updatedChat = _chats.removeAt(index);
      _chats.insert(0, updatedChat);
      notifyListeners();
      _saveChats();
    }
  }
  
  void markChatAsRead(String chatId) {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index != -1) {
      final chat = _chats[index];
      _chats[index] = Chat(
        identifier: chat.identifier,
        id: chat.id,
        contactName: chat.contactName,
        lastMessage: chat.lastMessage,
        timestamp: chat.timestamp,
        unreadCount: 0, // Mark as read
        connectionType: chat.connectionType,
        avatarText: chat.avatarText,
        avatarUrl: chat.avatarUrl,
        imageBytes: chat.imageBytes,
      );
      notifyListeners();
    }
  }
  
  Chat? getChatById(String chatId) {
    try {
      return _chats.firstWhere((chat) => chat.id == chatId);
    } catch (e) {
      return null;
    }
  }
  
  void clearChats() {
    _chats.clear();
    notifyListeners();
    _saveChats();
  }

  // Save chats to shared preferences
  Future<void> _saveChats() async {
    final prefs = await SharedPreferences.getInstance();
    final chatData = _chats.map((chat) => chat.toJson()).toList();
    await prefs.setString('chats_data', jsonEncode(chatData));
  }

  // Load chats from shared preferences
  Future<void> _loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final chatDataString = prefs.getString('chats_data');
    if (chatDataString != null) {
      final List<dynamic> chatDataList = jsonDecode(chatDataString);
      _chats.clear();
      _chats.addAll(chatDataList.map((data) => Chat.fromJson(data)).toList());
      notifyListeners();
    }
  }
}

class MessageProvider extends ChangeNotifier {
  final Map<String, List<Message>> _chatMessages = {};
  final Map<String, bool> _typingStatus = {};
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _messageSubscription;
  WiFiDirectController? _wifiController;

  // Getters
  List<Message> getMessagesForChat(String chatId) {
    return List.unmodifiable(_chatMessages[chatId] ?? []);
  }
  
  bool isTyping(String chatId) => _typingStatus[chatId] ?? false;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int getTotalMessageCount() => _chatMessages.values.fold(0, (sum, messages) => sum + messages.length);
  int getUnreadCountForChat(String chatId) {
    final messages = _chatMessages[chatId] ?? [];
    return messages.where((msg) => !msg.isFromMe && !msg.isRead).length;
  }

  // Initialize message provider
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Initialize WiFi Direct controller
      _wifiController = WiFiDirectController();
      await _wifiController!.initialize();
      await _wifiController!.startMessaging();
      
      // Listen to incoming messages
      _messageSubscription = _wifiController!.messageStream.listen(_handleIncomingMessage);
      
      // Load existing messages from storage
      await loadMessagesFromStorage();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadMessagesFromStorage() async {
    // In production, load messages from local database
    // For now, initialize with sample messages for testing
    
    // Add sample messages for existing chats
    _chatMessages['user123'] = [
      Message(
        id: '1',
        text: 'Hey there! How are you doing?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        isFromMe: false,
        isRead: true,
        status: MessageStatus.delivered,
      ),
      Message(
        id: '2',
        text: 'I\'m doing great! Thanks for asking 😊',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        isFromMe: true,
        isRead: false,
        status: MessageStatus.sent,
      ),
    ];
  }
  
  void _handleIncomingMessage(ChatMessage message) {
    // Use the chatId from the message, or fall back to sender for legacy messages
    String chatId = message.chatId;
    if (chatId.isEmpty) {
      chatId = message.sender; // Fallback for older messages
    }
    
    debugPrint('📨 MessageProvider handling message from ${message.sender} for chat $chatId');
    
    final newMessage = Message(
      id: message.id,
      text: message.text,
      timestamp: message.timestamp,
      isFromMe: false,
      isRead: false,
      status: MessageStatus.delivered,
    );
    
    // Add message to chat
    if (_chatMessages[chatId] == null) {
      _chatMessages[chatId] = [];
    }
    _chatMessages[chatId]!.add(newMessage);
    
    debugPrint('✅ Message added to chat $chatId. Total messages: ${_chatMessages[chatId]!.length}');
    
    notifyListeners();
  }

  // Add a message to a chat
  Message addMessage({
    required String chatId,
    required String text,
    required bool isFromMe,
    String? messageId,
    DateTime? timestamp,
    MessageStatus status = MessageStatus.delivered,
  }) {
    final message = Message(
      id: messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      timestamp: timestamp ?? DateTime.now(),
      isFromMe: isFromMe,
      isRead: isFromMe, // Own messages are always read
      status: isFromMe ? MessageStatus.sending : status,
    );

    // Initialize chat messages list if doesn't exist
    if (_chatMessages[chatId] == null) {
      _chatMessages[chatId] = [];
    }
    
    _chatMessages[chatId]!.add(message);
    notifyListeners();

    // If it's my message, send via WiFi Direct
    if (isFromMe) {
      _sendViaWiFiDirect(chatId, message);
    }

    return message;
  }

  Future<void> _sendViaWiFiDirect(String chatId, Message message) async {
    try {
      final chatMessage = ChatMessage(
        id: message.id,
        text: message.text,
        sender: "Me", // This should be the actual device name
        chatId: chatId,
        timestamp: message.timestamp,
        type: 'message',
      );

      await _wifiController!.sendMessage(chatMessage);
      _updateMessageStatus(chatId, message.id, MessageStatus.sent);
      
      // Simulate delivery
      Future.delayed(const Duration(seconds: 2), () {
        _updateMessageStatus(chatId, message.id, MessageStatus.delivered);
      });
    } catch (e) {
      _updateMessageStatus(chatId, message.id, MessageStatus.failed);
    }
  }

  // Send a message
  Future<Message> sendMessage({
    required String chatId,
    required String text,
    required String senderName,
  }) async {
    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
      isFromMe: true,
      isRead: false,
      status: MessageStatus.sending,
    );

    // Add to local messages
    if (_chatMessages[chatId] == null) {
      _chatMessages[chatId] = [];
    }
    _chatMessages[chatId]!.add(message);
    notifyListeners();

    try {
      // Send via WiFi Direct
      final chatMessage = ChatMessage(
        id: message.id,
        text: text,
        sender: senderName,
        chatId: chatId,
        timestamp: message.timestamp,
        type: 'message',
      );

      await _wifiController!.sendMessage(chatMessage);
      
      // Update status to sent
      _updateMessageStatus(chatId, message.id, MessageStatus.sent);
      
      // Simulate delivery after delay
      Future.delayed(const Duration(seconds: 2), () {
        _updateMessageStatus(chatId, message.id, MessageStatus.delivered);
      });
      
    } catch (e) {
      // Update status to failed
      _updateMessageStatus(chatId, message.id, MessageStatus.failed);
      rethrow;
    }
    
    return message;
  }
  
  void _updateMessageStatus(String chatId, String messageId, MessageStatus status) {
    final messages = _chatMessages[chatId];
    if (messages != null) {
      final index = messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        messages[index].status = status;
        notifyListeners();
      }
    }
  }
  
  // Mark messages as read
  void markMessagesAsRead(String chatId) {
    final messages = _chatMessages[chatId];
    if (messages != null) {
      bool hasChanges = false;
      for (var message in messages) {
        if (!message.isFromMe && !message.isRead) {
          message.isRead = true;
          hasChanges = true;
        }
      }
      if (hasChanges) {
        notifyListeners();
      }
    }
  }
  
  // Alias for markMessagesAsRead for compatibility
  void markChatAsRead(String chatId) {
    markMessagesAsRead(chatId);
  }
  
  // Set typing status
  void setTypingStatus(String chatId, bool isTyping) {
    if (_typingStatus[chatId] != isTyping) {
      _typingStatus[chatId] = isTyping;
      notifyListeners();
    }
  }
  
  // Delete message
  void deleteMessage(String chatId, String messageId) {
    final messages = _chatMessages[chatId];
    if (messages != null) {
      messages.removeWhere((msg) => msg.id == messageId);
      notifyListeners();
    }
  }
  
  // Clear all messages for a chat
  void clearChatMessages(String chatId) {
    _chatMessages[chatId]?.clear();
    notifyListeners();
  }
  
  // Get last message for a chat
  Message? getLastMessage(String chatId) {
    final messages = _chatMessages[chatId];
    if (messages != null && messages.isNotEmpty) {
      return messages.last;
    }
    return null;
  }
  
  @override
  void dispose() {
    _messageSubscription?.cancel();
    _wifiController?.stopMessaging();
    super.dispose();
  }
}

// Message status enum
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

// Message model for provider
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

// WiFi Direct Provider for managing device discovery and connections
class WiFiDirectProvider extends ChangeNotifier {
  WiFiDirectController? _controller;
  List<DiscoveredDevice> _nearbyDevices = [];
  bool _isScanning = false;
  bool _isConnected = false;
  String? _error;
  StreamSubscription? _deviceSubscription;

  // Getters
  List<DiscoveredDevice> get nearbyDevices => List.unmodifiable(_nearbyDevices);
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  String? get error => _error;
  int get deviceCount => _nearbyDevices.length;
  
  // Initialize WiFi Direct
  Future<void> initialize() async {
    try {
      _controller = WiFiDirectController();
      await _controller!.initialize();
      
      // Listen to device discoveries
      _controller!.nearbyDevices.addListener(_updateNearbyDevices);
      
      _isConnected = true;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isConnected = false;
      notifyListeners();
    }
  }
  
  void _updateNearbyDevices() {
    _nearbyDevices = _controller?.nearbyDevices.value ?? [];
    notifyListeners();
  }
  
  // Start scanning for nearby devices
  Future<void> startScanning() async {
    if (_controller == null) {
      await initialize();
    }
    
    try {
      _isScanning = true;
      _error = null;
      notifyListeners();
      
      await _controller!.startDiscovery();
      
    } catch (e) {
      _error = e.toString();
      _isScanning = false;
      notifyListeners();
    }
  }
  
  // Stop scanning
  Future<void> stopScanning() async {
    if (_controller != null) {
      await _controller!.stopDiscovery();
    }
    _isScanning = false;
    notifyListeners();
  }
  
  // Toggle debug mode
  void toggleDebugMode() {
    _controller?.toggleDebugMode();
  }
  
  // Add test devices
  void addTestDevices() {
    _controller?.addTestDevices();
  }
  
  // Clear discovered devices
  void clearDevices() {
    _controller?.clearDevices();
  }
  
  @override
  void dispose() {
    _deviceSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}