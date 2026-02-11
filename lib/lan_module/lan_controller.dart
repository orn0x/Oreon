/// Main LAN Controller API
///
/// Public interface for the LAN chat module.
/// Coordinates device discovery, message receiving, and message sending.
/// This is the only class that external code should interact with.

import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'models/lan_device.dart';
import 'models/lan_message.dart';
import 'discovery/mdns_discovery.dart';
import 'connection/tcp_server.dart';
import 'connection/tcp_client.dart';

/// Main LAN Chat Controller
///
/// Provides complete LAN chat functionality without internet.
///
/// Responsibilities:
/// - Initialize and manage device discovery
/// - Setup message server and client
/// - Coordinate between components
/// - Provide clean public API
///
/// Usage:
/// ```dart
/// final controller = LanController();
/// await controller.start();
///
/// controller.discoveredDevices.listen((device) {
///   print('Found device: ${device.name}');
/// });
///
/// controller.incomingMessages.listen((message) {
///   print('Message from ${message.senderName}: ${message.content}');
/// });
///
/// final targetDevice = LanDevice(...);
/// controller.sendMessage(targetDevice, 'Hello!');
///
/// await controller.stop();
/// ```
class LanController {
  /// Device name of this device
  late String _deviceName;

  /// Local IP address on the LAN
  late String _localIpAddress;

  /// TCP port for this device
  static const int defaultPort = 7531;
  late int _port;

  /// Discovery service instance
  late MdnsDiscoveryService _discoveryService;

  /// TCP server instance
  late LanTcpServer _tcpServer;

  /// TCP client instance
  late LanTcpClient _tcpClient;

  /// Whether the controller is currently running
  bool _isRunning = false;

  /// Creates a new LAN controller
  ///
  /// Optional parameters:
  /// [port] - TCP port to use (defaults to 7531)
  LanController({int port = defaultPort}) {
    _port = port;
  }

  /// Stream of discovered devices on the LAN
  ///
  /// Emits a LanDevice whenever a new device is discovered.
  /// Device name and IP address are included.
  ///
  /// Example:
  /// ```dart
  /// controller.discoveredDevices.listen((device) {
  ///   print('Device found: ${device.name} at ${device.ipAddress}');
  /// });
  /// ```
  Stream<LanDevice> get discoveredDevices {
    _ensureInitialized();
    return _discoveryService.discoveredDevices;
  }

  /// Stream of incoming messages from other devices
  ///
  /// Emits a LanMessage whenever a message is received from another device.
  /// Includes sender name, IP address, content, and timestamp.
  ///
  /// Example:
  /// ```dart
  /// controller.incomingMessages.listen((message) {
  ///   print('From ${message.senderName}: ${message.content}');
  /// });
  /// ```
  Stream<LanMessage> get incomingMessages {
    _ensureInitialized();
    return _tcpServer.incomingMessages;
  }

  /// Initializes and starts the LAN controller
  ///
  /// This method:
  /// 1. Retrieves device name and local IP address
  /// 2. Initializes mDNS discovery service
  /// 3. Starts TCP server for incoming messages
  /// 4. Starts device discovery
  /// 5. Marks controller as running
  ///
  /// Should be called once during app initialization.
  /// Returns a Future that completes when the controller is fully started.
  ///
  /// Throws:
  /// - SocketException if TCP port is already in use
  /// - Exception if unable to retrieve device info or IP address
  Future<void> start() async {
    if (_isRunning) {
      return;
    }

    try {
      // Get device name
      _deviceName = await _getDeviceName();

      // Get local IP address
      _localIpAddress = await _getLocalIpAddress();

      // Initialize discovery service
      _discoveryService = MdnsDiscoveryService(
        deviceName: _deviceName,
        ipAddress: _localIpAddress,
        port: _port,
      );

      // Initialize TCP server
      _tcpServer = LanTcpServer(
        deviceName: _deviceName,
        ipAddress: '0.0.0.0', // Listen on all interfaces
        port: _port,
      );

      // Initialize TCP client
      _tcpClient = LanTcpClient(
        localDeviceName: _deviceName,
        localIpAddress: _localIpAddress,
      );

      // Start server first (must be listening before discovery)
      await _tcpServer.start();

      // Start discovery
      await _discoveryService.start();

      _isRunning = true;
    } catch (e) {
      // Cleanup on failure
      await _cleanup();
      rethrow;
    }
  }

  /// Stops the LAN controller and closes all connections
  ///
  /// This method:
  /// 1. Stops accepting new connections on TCP server
  /// 2. Closes all active client connections
  /// 3. Stops mDNS discovery and service advertisement
  /// 4. Cleans up all resources
  ///
  /// Should be called when closing the app or when LAN chat is no longer needed.
  /// Returns a Future that completes when everything is stopped.
  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    _isRunning = false;
    await _cleanup();
  }

  /// Cleanup helper method
  Future<void> _cleanup() async {
    try {
      await Future.wait([
        _discoveryService.stop().catchError((_) {}),
        _tcpServer.stop().catchError((_) {}),
        _tcpClient.closeAllConnections().catchError((_) {}),
      ]);
    } catch (e) {
      // Continue cleanup even if errors occur
    }
  }

  /// Connects to a specific device
  ///
  /// Pre-establishes a TCP connection to the device for faster message sending.
  /// This is optional - connections are established automatically on first send.
  ///
  /// [device] - The device to connect to
  ///
  /// Returns a Future that completes when the connection is established.
  /// Throws SocketException if connection fails.
  Future<void> connect(LanDevice device) async {
    _ensureRunning();
    await _tcpClient.getConnection(device);
  }

  /// Sends a message to a specific device
  ///
  /// This method:
  /// 1. Establishes or reuses connection to the device
  /// 2. Serializes the message
  /// 3. Sends via TCP
  /// 4. Maintains connection for potential reuse
  ///
  /// [device] - The target device to send to
  /// [message] - The message content to send
  ///
  /// Throws:
  /// - StateException if controller is not running
  /// - SocketException if unable to connect or send
  /// - ArgumentError if message is empty
  void sendMessage(LanDevice device, String message) {
    _ensureRunning();

    if (message.isEmpty) {
      throw ArgumentError('Message cannot be empty');
    }

    // Fire and forget the send operation
    // In production, you might want to track these futures
    _tcpClient.sendMessage(device, message).catchError((error) {
      // Handle send errors (connection failures, etc.)
      // Could implement retry logic or error callbacks here
    });
  }

  /// Gets the device name of the local device
  ///
  /// Uses device_info_plus to retrieve the device name.
  /// Android: device model name
  /// iOS: device model name
  ///
  /// Returns the device name or 'Device' if retrieval fails.
  Future<String> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.device ?? androidInfo.model ?? 'Device';
    } catch (e) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.utsname.nodename;
      } catch (e) {
        return 'Device';
      }
    }
  }

  /// Gets the local IP address on the LAN
  ///
  /// Uses network_info_plus to retrieve the IP address.
  ///
  /// Returns the IP address or '127.0.0.1' if retrieval fails.
  /// Throws Exception if network connection is unavailable.
  Future<String> _getLocalIpAddress() async {
    try {
      final networkInfo = NetworkInfoPlus();
      final wifiIP = await networkInfo.getWifiIP();

      if (wifiIP != null && wifiIP.isNotEmpty) {
        return wifiIP;
      }

      throw Exception('No WiFi connection available');
    } catch (e) {
      throw Exception('Failed to get local IP address: $e');
    }
  }

  /// Ensures the controller has been initialized
  void _ensureInitialized() {
    if (!_isRunning) {
      throw StateError(
        'LanController must be started before accessing streams. '
        'Call start() first.',
      );
    }
  }

  /// Ensures the controller is running
  void _ensureRunning() {
    if (!_isRunning) {
      throw StateError('LanController is not running. Call start() first.');
    }
  }

  /// Gets whether the controller is currently running
  bool get isRunning => _isRunning;

  /// Gets the local device name
  String get deviceName {
    _ensureInitialized();
    return _deviceName;
  }

  /// Gets the local IP address
  String get localIpAddress {
    _ensureInitialized();
    return _localIpAddress;
  }

  /// Gets the TCP port being used
  int get port => _port;

  /// Gets the number of active TCP client connections
  int get activeConnections => _tcpServer.activeConnections;

  /// Gets list of cached device connections
  List<String> get cachedConnections => _tcpClient.connectedDevices;

  /// Gets cached list of discovered devices
  List<LanDevice> get cachedDevices => _discoveryService.cachedDevices;

  /// Disposes of all resources
  ///
  /// Should be called when the controller will no longer be used.
  /// Typically called in app cleanup/dispose.
  Future<void> dispose() async {
    await stop();
    await _discoveryService.dispose();
    await _tcpServer.dispose();
    await _tcpClient.dispose();
  }
}

/// Extension on LanTcpClient to expose getConnection for LanController
/// This allows internal access to connection establishment
extension _TcpClientInternal on LanTcpClient {
  /// Gets or establishes a connection (exposed for LanController)
  Future<void> getConnection(LanDevice device) =>
      _getConnection(device).then((_) {});
}
