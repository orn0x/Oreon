import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oreon/const/const.dart';
import 'package:oreon/main.dart';
import 'package:oreon/providers/providers.dart';

// Main WiFi Direct Controller
class WiFiDirectController {
  static final WiFiDirectController _instance = WiFiDirectController._internal();

  factory WiFiDirectController() {
    return _instance;
  }

  WiFiDirectController._internal();

  late DiscoveryService _discoveryService;
  late MessagingService _messagingService;
  late String _deviceId;

  final ValueNotifier<bool> isScanning = ValueNotifier(false);
  final ValueNotifier<bool> isChatting = ValueNotifier(false);
  final ValueNotifier<List<DiscoveredDevice>> nearbyDevices = ValueNotifier([]);
  final ValueNotifier<bool> isOnline = ValueNotifier(false);

  // Streams
  final _messageController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get messageStream => _messageController.stream;

  // Debug mode flag
  bool _debugMode = false;

  Future<void> initialize() async {
    final username = prefs.getString("username") ?? 'User';
    final uniqueId = '${DateTime.now().millisecondsSinceEpoch}_${username.hashCode.abs()}';
    _deviceId = 'Device_${ConstApp().appIdentifier()}_$uniqueId';
    _discoveryService = DiscoveryService(_deviceId);
    _messagingService = MessagingService(_deviceId);
    
    // Set initial online status
    isOnline.value = true;

    debugPrint('WiFiDirectController initialized with ID: $_deviceId');
  }

  // Discovery methods
  Future<void> startDiscovery() async {
    if (isScanning.value) {
      debugPrint('⚠️ Discovery already running');
      return;
    }
    
    isScanning.value = true;
    debugPrint('🔍 Starting discovery - current device count: ${nearbyDevices.value.length}');
    
    try {
      await _discoveryService.startBroadcast();
      
      _discoveryService.onDeviceDiscovered.listen((device) {
        debugPrint('📱 Device discovered in controller: ${device.name} (${device.id})');
        
        final devices = List<DiscoveredDevice>.from(nearbyDevices.value);
        final existingIndex = devices.indexWhere((d) => d.id == device.id);
        
        if (existingIndex >= 0) {
          // Update existing device
          devices[existingIndex] = device;
          debugPrint('🔄 Updated existing device: ${device.name}');
        } else {
          // Add new device
          devices.add(device);
          debugPrint('➕ Added new device: ${device.name}');
        }
        
        nearbyDevices.value = devices;
        debugPrint('📊 Total devices: ${nearbyDevices.value.length}');
        
        // Log all devices
        for (var d in nearbyDevices.value) {
          debugPrint('   - ${d.name} (${d.id.substring(0, 8)}...)');
        }
      });
      
    } catch (e) {
      debugPrint('❌ Failed to start discovery: $e');
      isScanning.value = false;
    }
  }

  Future<void> stopDiscovery() async {
    if (!isScanning.value) return;
    
    debugPrint('🛑 Stopping discovery...');
    isScanning.value = false;
    
    try {
      await _discoveryService.stopBroadcast();
      debugPrint('✅ Discovery stopped');
    } catch (e) {
      debugPrint('❌ Error stopping discovery: $e');
    }
  }
  
  // Create test avatar image
  Uint8List _createTestImage(Color color) {
    final pixels = <int>[];
    for (int i = 0; i < 32 * 32; i++) {
      pixels.addAll([color.red, color.green, color.blue, 255]);
    }
    return Uint8List.fromList(pixels);
  }

  // Clear all discovered devices
  void clearDevices() {
    nearbyDevices.value = [];
    debugPrint('🧹 Cleared all devices');
  }

  // Messaging methods
  Future<void> startMessaging() async {
    if (isChatting.value) return;
    isChatting.value = true;
    
    await _messagingService.startListener();
    _messagingService.onMessageReceived.listen((message) {
      _messageController.add(message);
    });
  }

  Future<void> stopMessaging() async {
    isChatting.value = false;
    await _messagingService.stopListener();
  }

  Future<void> sendMessage(ChatMessage message) async {
    try {
      await _messagingService.broadcast(message);
      debugPrint('✅ Message sent: ${message.text}');
    } catch (e) {
      debugPrint('❌ Failed to send message: $e');
      rethrow;
    }
  }

  void dispose() {
    _discoveryService.dispose();
    _messagingService.dispose();
    _messageController.close();
    isScanning.value = false;
    isChatting.value = false;
    isOnline.value = false;
  }
}

// Discovery Service
class DiscoveryService {
  final String deviceId;
  final int broadcastPort = 6363;
  final Duration broadcastInterval = const Duration(seconds: 3);

  RawDatagramSocket? _listenSocket;
  Timer? _broadcastTimer;
  
  // Cache for processed image
  String? _cachedImageBase64;
  bool _imageProcessed = false;
  
  // Debug mode flag
  bool _debugMode = false;
  
  final _deviceDiscoveredController = StreamController<DiscoveredDevice>.broadcast();
  Stream<DiscoveredDevice> get onDeviceDiscovered => _deviceDiscoveredController.stream;

  DiscoveryService(this.deviceId);
  
  // Set debug mode
  void setDebugMode(bool enabled) {
    _debugMode = enabled;
    debugPrint('🔧 DiscoveryService debug mode: ${enabled ? 'ON' : 'OFF'}');
  }

  Future<void> startBroadcast() async {
    try {
      debugPrint('🚀 Starting device discovery service...');
      
      // Process image once at startup
      await _processImage();
      
      // Start listening first
      await _startListener();
      
      // Start broadcasting
      _broadcastTimer = Timer.periodic(broadcastInterval, (_) => _sendBroadcast());
      
      // Send initial broadcast
      await _sendBroadcast();
      
      debugPrint('✅ Discovery service started successfully');
    } catch (e) {
      debugPrint('❌ Failed to start discovery service: $e');
      rethrow;
    }
  }

  Future<void> _processImage() async {
    if (_imageProcessed) return;
    
    try {
      debugPrint('🖼️ Processing user avatar image...');
      
      final imagePath = prefs.getString('avatar_picture');
      if (imagePath == null || imagePath.isEmpty) {
        debugPrint('ℹ️ No avatar image path found');
        _cachedImageBase64 = '';
        _imageProcessed = true;
        return;
      }
      
      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('⚠️ Avatar file does not exist: $imagePath');
        _cachedImageBase64 = '';
        _imageProcessed = true;
        return;
      }
      
      final imageBytes = await file.readAsBytes();
      debugPrint('📊 Original image size: ${(imageBytes.length / 1024).toStringAsFixed(2)}KB');
      
      // Compress image for UDP transmission
      final compressedBytes = await _compressImageForUDP(imageBytes);
      _cachedImageBase64 = base64Encode(compressedBytes);
      
      final finalSizeKB = (_cachedImageBase64!.length / 1024).toStringAsFixed(2);
      debugPrint('✅ Image processed and cached: ${finalSizeKB}KB (base64)');
      
      _imageProcessed = true;
    } catch (e) {
      debugPrint('❌ Error processing image: $e');
      _cachedImageBase64 = '';
      _imageProcessed = true;
    }
  }

  Future<Uint8List> _compressImageForUDP(Uint8List originalBytes) async {
    try {
      // Target: max 8KB for image to keep total UDP packet under 16KB
      const int maxImageSize = 8192; // 8KB
      
      if (originalBytes.length <= maxImageSize) {
        return originalBytes;
      }
      
      // Simple compression by sampling (in production, use image package)
      final compressionRatio = maxImageSize / originalBytes.length;
      final targetLength = (originalBytes.length * compressionRatio).round();
      
      final compressed = Uint8List(targetLength);
      for (int i = 0; i < targetLength; i++) {
        final sourceIndex = (i / compressionRatio).round();
        if (sourceIndex < originalBytes.length) {
          compressed[i] = originalBytes[sourceIndex];
        }
      }
      
      debugPrint('🗜️ Compressed image: ${(originalBytes.length/1024).toStringAsFixed(2)}KB → ${(compressed.length/1024).toStringAsFixed(2)}KB');
      return compressed;
    } catch (e) {
      debugPrint('❌ Image compression failed: $e');
      // Return minimal valid data
      return Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);
    }
  }

  Future<void> _startListener() async {
    try {
      _listenSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        broadcastPort,
        reuseAddress: true,
      );
      
      debugPrint('👂 Listening on port $broadcastPort');
      
      _listenSocket!.listen(
        _handleIncomingData,
        onError: (error) => debugPrint('❌ Listen socket error: $error'),
        onDone: () => debugPrint('📪 Listen socket closed'),
      );
      
    } catch (e) {
      debugPrint('❌ Failed to start listener: $e');
      rethrow;
    }
  }

  void _handleIncomingData(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    
    try {
      final datagram = _listenSocket?.receive();
      if (datagram == null || datagram.data.isEmpty) return;
      
      debugPrint('📦 Received ${datagram.data.length} bytes from ${datagram.address}');
      
      final jsonString = utf8.decode(datagram.data);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Validate message
      if (data['action'] != 'discovery' || data['deviceId'] == null) {
        debugPrint('⚠️ Invalid discovery message format');
        return;
      }
      
      // Skip own messages (unless debug mode is enabled)
      if (data['deviceId'] == deviceId) {
        if (!_debugMode) {
          debugPrint('⏭️ Skipping own broadcast');
          return;
        } else {
          debugPrint('🔧 Debug mode: Processing own broadcast');
        }
      }
      
      // Process discovered device
      String deviceName = data['deviceName'] as String? ?? 'Unknown Device';
      
      // Add debug prefix if this is own device in debug mode
      if (data['deviceId'] == deviceId && _debugMode) {
        deviceName = '🔧 [SELF] $deviceName';
      }
      
      Uint8List? imageBytes;
      
      if (data['imageBytes'] != null && (data['imageBytes'] as String).isNotEmpty) {
        try {
          imageBytes = base64Decode(data['imageBytes'] as String);
          debugPrint('🖼️ Decoded image: ${(imageBytes.length/1024).toStringAsFixed(2)}KB');
        } catch (e) {
          debugPrint('❌ Failed to decode image: $e');
        }
      }
      
      final device = DiscoveredDevice(
        appIdentifier: data['appIdentifier'] as String? ?? 'UnknownApp',
        id: data['deviceId'] as String,
        name: deviceName,
        timestamp: DateTime.now(),
        imageBytes: imageBytes,
      );
      
      debugPrint('✅ Device discovered: $deviceName');
      _deviceDiscoveredController.add(device);
      
    } catch (e) {
      debugPrint('❌ Error processing incoming data: $e');
    }
  }

  Future<void> _sendBroadcast() async {
    try {
      final deviceName = prefs.getString("name") ?? "Unknown User";
      
      final broadcastData = {
        'action': 'discovery',
        'deviceId': deviceId,
        'deviceName': deviceName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'imageBytes': _cachedImageBase64 ?? '',
      };
      
      final jsonData = jsonEncode(broadcastData);
      final bytes = utf8.encode(jsonData);
      
      debugPrint('📡 Broadcasting: ${deviceName} (${(bytes.length/1024).toStringAsFixed(2)}KB)');
      
      // Create temporary broadcast socket
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      
      final addresses = await _getBroadcastAddresses();
      bool success = false;
      
      for (final address in addresses) {
        try {
          final sent = socket.send(bytes, InternetAddress(address), broadcastPort);
          if (sent > 0) {
            debugPrint('✅ Sent to $address: $sent bytes');
            success = true;
          }
        } catch (e) {
          debugPrint('❌ Failed to send to $address: $e');
        }
      }
      
      socket.close();
      
      if (!success) {
        debugPrint('⚠️ All broadcast attempts failed');
      }
      
    } catch (e) {
      debugPrint('❌ Broadcast error: $e');
    }
  }

  Future<List<String>> _getBroadcastAddresses() async {
    final addresses = <String>[];
    
    try {
      // Get network interfaces
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          final parts = ip.split('.');
          
          if (parts.length == 4) {
            // Generate broadcast addresses
            addresses.add('${parts[0]}.${parts[1]}.${parts[2]}.255');
            addresses.add('${parts[0]}.${parts[1]}.255.255');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting network interfaces: $e');
    }
    
    // Add common broadcast addresses
    addresses.addAll([
      '255.255.255.255',
      '192.168.1.255',
      '192.168.0.255',
      '10.0.0.255',
      '172.16.255.255',
      '127.0.0.1',
    ]);
    
    // Remove duplicates
    return addresses.toSet().toList();
  }

  Future<void> stopBroadcast() async {
    _broadcastTimer?.cancel();
    _listenSocket?.close();
    _listenSocket = null;
    debugPrint('🛑 Discovery broadcast stopped');
  }

  void dispose() {
    _broadcastTimer?.cancel();
    _listenSocket?.close();
    _deviceDiscoveredController.close();
  }
}

// Messaging Service
class MessagingService {
  final String deviceId;
  final int messagePort = 9877;

  RawDatagramSocket? _messageSocket;
  final Set<String> _sentMessageIds = {};

  final _messageReceivedController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get onMessageReceived => _messageReceivedController.stream;

  MessagingService(this.deviceId);

  Future<void> startListener() async {
    try {
      _messageSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        messagePort,
        reuseAddress: true,
      );

      debugPrint('📨 Message listener started on port $messagePort');

      _messageSocket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final datagram = _messageSocket!.receive();
            if (datagram != null && datagram.data.isNotEmpty) {
              try {
                final data = utf8.decode(datagram.data);
                final decoded = jsonDecode(data) as Map<String, dynamic>;

                if (decoded['type'] == 'message') {
                  final senderId = decoded['sender'] as String?;
                  final messageId = decoded['id'] as String?;
                  
                  // Skip own messages and duplicates
                  if (senderId != null && 
                      senderId != deviceId && 
                      messageId != null &&
                      !_sentMessageIds.contains(messageId)) {
                    final message = ChatMessage.fromJson(decoded);
                    debugPrint('✅ Message from ${message.sender}: ${message.text}');
                    _messageReceivedController.add(message);
                  }
                }
              } catch (e) {
                debugPrint('❌ Message parse error: $e');
              }
            }
          }
        },
        onError: (error) => debugPrint('❌ Message listener error: $error'),
      );
    } catch (e) {
      debugPrint('❌ Message listener setup error: $e');
    }
  }

  Future<void> broadcast(ChatMessage message) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final messageWithSender = ChatMessage(
        appIdentifier: ConstApp().appIdentifier(),
        id: message.id,
        text: message.text,
        sender: deviceId,
        chatId: message.chatId,
        timestamp: message.timestamp,
        type: message.type,
      );

      _sentMessageIds.add(messageWithSender.id);
      
      final messageData = jsonEncode(messageWithSender.toJson());
      final messageBytes = utf8.encode(messageData);
      
      debugPrint('📤 Broadcasting message: "${message.text}" (ID: ${message.id})');
      
      final addresses = ['255.255.255.255', '192.168.1.255', '192.168.0.255', '10.0.0.255'];
      
      bool success = false;
      for (String addr in addresses) {
        try {
          final sent = socket.send(messageBytes, InternetAddress(addr), messagePort);
          if (sent > 0) {
            debugPrint('✅ Message sent to $addr: $sent bytes');
            success = true;
          }
        } catch (e) {
          debugPrint('⚠️ Error sending to $addr: $e');
        }
      }
      
      socket.close();
      
      if (!success) {
        debugPrint('❌ Message broadcast failed for all addresses');
      }
    } catch (e) {
      debugPrint('❌ Message broadcast error: $e');
      rethrow;
    }
  }

  Future<void> stopListener() async {
    _messageSocket?.close();
    _messageSocket = null;
  }

  void dispose() {
    _messageSocket?.close();
    _messageReceivedController.close();
    _sentMessageIds.clear();
  }
}

class DiscoveredDevice {
  final String appIdentifier;
  final String id;
  final String name;
  final DateTime timestamp;
  final Uint8List? imageBytes;

  DiscoveredDevice({
    required this.appIdentifier,
    required this.id,
    required this.name,
    required this.timestamp,
    this.imageBytes,
  });

  Map<String, dynamic> toJson() => {
        'appIdentifier': appIdentifier,
        'id': id,
        'name': name,
        'timestamp': timestamp.toIso8601String(),
        'imageBytes': imageBytes != null ? base64Encode(imageBytes!) : null,
      };

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) =>
      DiscoveredDevice(
        appIdentifier: json['appIdentifier'] as String,
        id: json['id'] as String,
        name: json['name'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        imageBytes: json['imageBytes'] != null
            ? base64Decode(json['imageBytes'] as String)
            : null,
      );
}

class ChatMessage {
  final String appIdentifier;
  final String id;
  final String text;
  final String sender;
  final String chatId;
  final DateTime timestamp;
  final String type;

  ChatMessage({
    required this.appIdentifier,
    required this.id,
    required this.text,
    required this.sender,
    required this.chatId,
    required this.timestamp,
    this.type = 'message',
  });

  Map<String, dynamic> toJson() => {
        'appIdentifier': appIdentifier,
        'id': id,
        'type': type,
        'text': text,
        'sender': sender,
        'chatId': chatId,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        appIdentifier: json['appIdentifier'] as String,
        id: json['id'] as String,
        text: json['text'] as String,
        sender: json['sender'] as String,
        chatId: json['chatId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        type: json['type'] as String? ?? 'message',
      );
}