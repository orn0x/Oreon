/// Example: Backend-Only LAN Chat Service
///
/// This example demonstrates using the LAN module purely as a backend service
/// without any UI components. Suitable for service layers, state management,
/// or headless applications.
///
/// This approach separates the LAN communication logic from UI concerns
/// and can be tested independently.

import 'dart:async';

import 'package:oreon/services/WIFI/lan_module/lan_controller.dart';
import 'package:oreon/services/WIFI/lan_module/models/lan_device.dart';
import 'package:oreon/services/WIFI/lan_module/models/lan_message.dart';

/// Backend service for LAN chat operations
///
/// Manages all LAN communication without any UI dependencies.
/// Can be injected into providers, viewmodels, or service layers.
class LanChatService {
  /// Singleton instance
  static final LanChatService _instance = LanChatService._internal();

  factory LanChatService() {
    return _instance;
  }

  LanChatService._internal();

  /// The underlying LAN controller
  late LanController _controller;

  /// Device cache with metadata
  final Map<String, LanDevice> _deviceCache = {};

  /// Message history by device IP
  final Map<String, List<LanMessage>> _messageHistory = {};

  /// Device status tracking
  final Map<String, DeviceStatus> _deviceStatus = {};

  /// Stream controllers for external listeners
  late StreamController<LanDeviceEvent> _deviceEventController;
  late StreamController<LanMessageEvent> _messageEventController;

  /// Service state
  bool _isInitialized = false;
  bool _isRunning = false;

  /// Getters
  bool get isInitialized => _isInitialized;
  bool get isRunning => _isRunning;
  Stream<LanDeviceEvent> get deviceEvents => _deviceEventController.stream;
  Stream<LanMessageEvent> get messageEvents => _messageEventController.stream;
  List<LanDevice> get discoveredDevices => _deviceCache.values.toList();
  Map<String, List<LanMessage>> get messageHistory => Map.from(_messageHistory);

  /// Initializes the LAN chat service
  ///
  /// Must be called once before using the service.
  /// Typically called during app initialization.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _deviceEventController = StreamController<LanDeviceEvent>.broadcast();
      _messageEventController = StreamController<LanMessageEvent>.broadcast();

      _controller = LanController();
      await _controller.start();
      _isRunning = true;

      // Set up device discovery listener
      _controller.discoveredDevices.listen(
        _onDeviceDiscovered,
        onError: _onDiscoveryError,
      );

      // Set up message listener
      _controller.incomingMessages.listen(
        _onMessageReceived,
        onError: _onMessageError,
      );

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  /// Called when a device is discovered
  void _onDeviceDiscovered(LanDevice device) {
    final key = device.ipAddress;
    final isNew = !_deviceCache.containsKey(key);

    _deviceCache[key] = device;
    _deviceStatus[key] = DeviceStatus(
      device: device,
      discoveredAt: DateTime.now(),
      lastSeen: DateTime.now(),
      isOnline: true,
    );

    // Emit event
    _deviceEventController.add(
      LanDeviceEvent(
        type: isNew ? DeviceEventType.discovered : DeviceEventType.updated,
        device: device,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Called when a discovery error occurs
  void _onDiscoveryError(dynamic error) {
    _deviceEventController.addError(error);
  }

  /// Called when a message is received
  void _onMessageReceived(LanMessage message) {
    final senderIp = message.senderIp;

    // Initialize message history for this device if needed
    _messageHistory.putIfAbsent(senderIp, () => []);

    // Add message to history
    _messageHistory[senderIp]!.add(message);

    // Update device last seen time
    if (_deviceStatus.containsKey(senderIp)) {
      _deviceStatus[senderIp]!.lastSeen = DateTime.now();
    }

    // Emit event
    _messageEventController.add(
      LanMessageEvent(
        type: MessageEventType.received,
        message: message,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Called when a message error occurs
  void _onMessageError(dynamic error) {
    _messageEventController.addError(error);
  }

  /// Sends a message to a device
  ///
  /// Returns a Future that completes when the message is sent.
  Future<void> sendMessageToDevice(LanDevice device, String content) async {
    if (!_isRunning) {
      throw StateError('Service not running');
    }

    try {
      _controller.sendMessage(device, content);

      // Emit outgoing message event
      _messageEventController.add(
        LanMessageEvent(
          type: MessageEventType.sent,
          message: LanMessage(
            id: 'local-${DateTime.now().millisecondsSinceEpoch}',
            senderName: _controller.deviceName,
            senderIp: _controller.localIpAddress,
            content: content,
          ),
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      _messageEventController.addError(e);
      rethrow;
    }
  }

  /// Broadcasts a message to all discovered devices
  ///
  /// Sends the same message to every discovered device.
  /// Returns a Future that completes when all sends are initiated.
  Future<void> broadcastMessage(String content) async {
    final futures = _deviceCache.values.map((device) {
      return sendMessageToDevice(device, content).catchError((_) {
        // Continue broadcasting even if one device fails
      });
    });

    await Future.wait(futures);
  }

  /// Gets messages from a specific device
  ///
  /// Returns a list of messages received from the device, or empty list
  /// if no messages have been received.
  List<LanMessage> getMessagesFromDevice(String ipAddress) {
    return List.unmodifiable(_messageHistory[ipAddress] ?? []);
  }

  /// Gets device by IP address
  ///
  /// Returns the device if found, null otherwise.
  LanDevice? getDeviceByIp(String ipAddress) {
    return _deviceCache[ipAddress];
  }

  /// Gets device status by IP address
  ///
  /// Returns the device status if device has been discovered, null otherwise.
  DeviceStatus? getDeviceStatus(String ipAddress) {
    return _deviceStatus[ipAddress];
  }

  /// Gets all devices with their current status
  List<DeviceStatus> getAllDeviceStatuses() {
    return _deviceStatus.values.toList();
  }

  /// Clears message history for a specific device
  ///
  /// [ipAddress] - IP address of the device
  void clearMessageHistory(String ipAddress) {
    _messageHistory.remove(ipAddress);
  }

  /// Clears all message history
  void clearAllHistory() {
    _messageHistory.clear();
  }

  /// Searches for a device by name
  ///
  /// Returns matching devices (case-insensitive substring match).
  List<LanDevice> searchDevicesByName(String query) {
    final lowerQuery = query.toLowerCase();
    return _deviceCache.values
        .where((d) => d.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Gets connected device count
  int get connectedDeviceCount =>
      _deviceStatus.values.where((status) => status.isOnline).length;

  /// Gets total message count
  int get totalMessageCount =>
      _messageHistory.values.fold(0, (sum, messages) => sum + messages.length);

  /// Shuts down the service
  ///
  /// Must be called when the service is no longer needed.
  /// Cleans up all resources and streams.
  Future<void> shutdown() async {
    if (!_isInitialized) return;

    try {
      await _controller.stop();
      await _controller.dispose();

      await _deviceEventController.close();
      await _messageEventController.close();

      _isRunning = false;

      _deviceCache.clear();
      _messageHistory.clear();
      _deviceStatus.clear();
    } catch (e) {
      // Ensure cleanup even if errors occur
      _isRunning = false;
      rethrow;
    }
  }

  /// Gets a snapshot of current state for debugging
  Map<String, dynamic> getStateSnapshot() => {
    'isInitialized': _isInitialized,
    'isRunning': _isRunning,
    'discoveredDevices': _deviceCache.length,
    'totalMessages': totalMessageCount,
    'connectedDevices': connectedDeviceCount,
    'localDeviceName': _controller.deviceName,
    'localIpAddress': _controller.localIpAddress,
  };
}

/// Device status information
class DeviceStatus {
  final LanDevice device;
  final DateTime discoveredAt;
  DateTime lastSeen;
  final bool isOnline;

  DeviceStatus({
    required this.device,
    required this.discoveredAt,
    required this.lastSeen,
    required this.isOnline,
  });

  /// Time since device was last seen
  Duration get timeSinceLastSeen => DateTime.now().difference(lastSeen);

  /// Whether device is likely offline (not seen for more than 30 seconds)
  bool get isLikelyOffline => timeSinceLastSeen.inSeconds > 30;
}

/// Device event types
enum DeviceEventType { discovered, updated, lost }

/// Device discovery event
class LanDeviceEvent {
  final DeviceEventType type;
  final LanDevice device;
  final DateTime timestamp;

  LanDeviceEvent({
    required this.type,
    required this.device,
    required this.timestamp,
  });
}

/// Message event types
enum MessageEventType { sent, received }

/// Message event
class LanMessageEvent {
  final MessageEventType type;
  final LanMessage message;
  final DateTime timestamp;

  LanMessageEvent({
    required this.type,
    required this.message,
    required this.timestamp,
  });
}

// ============================================================================
// Example Usage in a service/provider pattern
// ============================================================================

/// Example of using the backend service in a provider
void exampleServiceUsage() async {
  // Get the singleton service
  final lanService = LanChatService();

  // Initialize
  await lanService.initialize();

  // Listen to device events
  lanService.deviceEvents.listen((event) {
    print('Device ${event.type}: ${event.device.name}');
  });

  // Listen to message events
  lanService.messageEvents.listen((event) {
    print(
      'Message ${event.type}: ${event.message.senderName} - '
      '${event.message.content}',
    );
  });

  // Wait for device to be discovered
  await Future.delayed(Duration(seconds: 2));

  // Send message to first discovered device
  final devices = lanService.discoveredDevices;
  if (devices.isNotEmpty) {
    await lanService.sendMessageToDevice(devices.first, 'Hello!');
  }

  // Broadcast to all devices
  await lanService.broadcastMessage('Broadcast message');

  // Check service state
  print('State: ${lanService.getStateSnapshot()}');

  // Get device messages
  if (devices.isNotEmpty) {
    final messages = lanService.getMessagesFromDevice(devices.first.ipAddress);
    print('Received ${messages.length} messages');
  }

  // Cleanup
  await lanService.shutdown();
}
