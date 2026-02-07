import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WiFiService {
  String localIp = '192.168.0.255';
  String serverPort = '8080';
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 6;
  static const Duration baseReconnectDelay = Duration(seconds: 4);
  
  final ValueNotifier<bool> isConnecting = ValueNotifier(false);
  final ValueNotifier<bool> isScanning = ValueNotifier(false);
  
  // Stream for contact updates
  final _contactsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get contactsStream => _contactsController.stream;
  
  String get wsUrl => 'ws://$localIp:$serverPort';
  
  void startConnection(String userId, int durationSeconds) {
    if (_channel != null) return;
    
    isConnecting.value = true;
    isScanning.value = true;
    
    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);
      
      _channel!.sink.add(jsonEncode({
        "action": "start_scan",
        "userId": userId,
        "durationSeconds": durationSeconds,
      }));
      
      _setupStreamListener();
      isConnecting.value = false;
    } catch (e) {
      debugPrint("Connect failed: $e");
      _handleDisconnect();
    }
  }
  
  void _setupStreamListener() {
    _subscription = _channel!.stream.listen(
      (dynamic rawMessage) {
        String text;
        if (rawMessage is String) {
          text = rawMessage;
        } else if (rawMessage is List<int>) {
          text = utf8.decode(rawMessage);
        } else {
          debugPrint("Unsupported message type: ${rawMessage.runtimeType}");
          return;
        }
        
        try {
          final decoded = jsonDecode(text) as Map<String, dynamic>;
          _contactsController.add(decoded);
        } catch (e, st) {
          debugPrint("Parse error: $e\n$st");
        }
      },
      onError: (error) {
        debugPrint("WebSocket error: $error");
        _handleDisconnect();
      },
      onDone: () {
        debugPrint("WebSocket closed");
        _handleDisconnect();
      },
    );
  }
  
  void _handleDisconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    isConnecting.value = false;
    
    if (isScanning.value && _reconnectAttempts < maxReconnectAttempts) {
      _reconnectAttempts++;
      final multiplier = (1 << (_reconnectAttempts - 1)).clamp(1, 8);
      final delay = baseReconnectDelay * multiplier;
      
      debugPrint("Reconnect attempt #$_reconnectAttempts in ${delay.inSeconds}s");
      
      _reconnectTimer = Timer(delay, () {
        if (isScanning.value) {
          startConnection("user_${DateTime.now().millisecondsSinceEpoch}", 45);
        }
      });
    } else if (isScanning.value) {
      stopConnection();
    }
  }
  
  void stopConnection() {
    _subscription?.cancel();
    _channel?.sink.add(jsonEncode({"action": "stop_scan"}));
    _channel?.sink.close();
    _channel = null;
    _reconnectTimer?.cancel();
    
    isScanning.value = false;
    isConnecting.value = false;
    _reconnectAttempts = 0;
  }
  
  void dispose() {
    _subscription?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _contactsController.close();
  }
}
