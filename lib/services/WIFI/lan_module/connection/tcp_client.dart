// import 'dart:async';
// import 'dart:io';
// import 'dart:convert';
// import 'package:uuid/uuid.dart';
// import '../models/lan_device.dart';
// import '../models/lan_message.dart';

// class LanTcpClient {
//   /// The device name of this client (sender)
//   final String localDeviceName;

//   /// The local device's IP address
//   final String localIpAddress;

//   /// Cache of active connections to remote devices
//   /// Key: "ipAddress:port", Value: Socket
//   final Map<String, Socket> _connectionCache = {};

//   /// Connection attempt timeouts
//   static const Duration connectionTimeout = Duration(seconds: 5);

//   /// Message send timeout
//   static const Duration sendTimeout = Duration(seconds: 10);

//   /// UUID generator for message IDs
//   static const uuid = Uuid();

//   /// Creates a new TCP client instance
//   ///
//   /// [localDeviceName] - Name of this device (included in sent messages)
//   /// [localIpAddress] - This device's local IP address
//   LanTcpClient({required this.localDeviceName, required this.localIpAddress});

//   /// Sends a message to a remote device
//   ///
//   /// This method:
//   /// 1. Establishes a TCP connection to the remote device (or reuses cached)
//   /// 2. Serializes the message to JSON
//   /// 3. Sends the message with a newline terminator
//   /// 4. Closes the connection (optional caching for reuse)
//   ///
//   /// [device] - The target device to send to
//   /// [content] - The message content
//   ///
//   /// Returns a Future that completes when the message is sent.
//   /// Throws SocketException if connection fails.
//   Future<void> sendMessage(LanDevice device, String content) async {
//     // Validate input
//     if (content.isEmpty) {
//       throw ArgumentError('Message content cannot be empty');
//     }

//     // Create message object
//     final message = LanMessage(
//       id: uuid.v4(),
//       senderName: localDeviceName,
//       senderIp: localIpAddress,
//       content: content,
//     );

//     // Get or establish connection
//     final socket = await _getConnection(device);

//     try {
//       // Serialize message to JSON
//       final json = jsonEncode(message.toJson());

//       // Send with newline terminator (protocol requirement)
//       socket.write('$json\n');
//       await socket.flush();
//     } catch (e) {
//       // Connection error, remove from cache and rethrow
//       _removeConnection(device);
//       rethrow;
//     }
//   }

//   /// Gets or establishes a TCP connection to a device
//   ///
//   /// Checks the connection cache first. If no cached connection exists,
//   /// attempts to establish a new connection with retry logic.
//   ///
//   /// [device] - The device to connect to
//   ///
//   /// Returns a Socket connected to the device.
//   /// Throws SocketException if connection cannot be established.
//   Future<Socket> _getConnection(LanDevice device) async {
//     final cacheKey = '${device.ipAddress}:${device.port}';

//     // Check if connection is cached and still valid
//     if (_connectionCache.containsKey(cacheKey)) {
//       final socket = _connectionCache[cacheKey]!;
//       if (!socket.done.isCompleted) {
//         return socket; // Connection is still active
//       } else {
//         // Cached connection is dead, remove it
//         _connectionCache.remove(cacheKey);
//       }
//     }

//     // Establish new connection
//     Socket socket;
//     try {
//       socket = await Socket.connect(
//         device.ipAddress,
//         device.port,
//         timeout: connectionTimeout,
//       ).timeout(connectionTimeout);
//     } catch (e) {
//       throw SocketException(
//         'Failed to connect to ${device.name} (${device.ipAddress}:${device.port}): $e',
//       );
//     }

//     // Configure socket options
//     socket.setOption(SocketOption.tcpNoDelay, true);

//     // Listen for socket closure to clean up cache
//     socket.done.then(
//       (_) {
//         _connectionCache.remove(cacheKey);
//       },
//       onError: (_) {
//         _connectionCache.remove(cacheKey);
//       },
//     );

//     // Cache the connection for future use
//     _connectionCache[cacheKey] = socket;

//     return socket;
//   }

//   /// Removes a device connection from the cache
//   ///
//   /// [device] - The device whose connection should be removed
//   void _removeConnection(LanDevice device) {
//     final cacheKey = '${device.ipAddress}:${device.port}';
//     _connectionCache.remove(cacheKey);
//   }

//   /// Closes a specific device connection
//   ///
//   /// [device] - The device to disconnect from
//   ///
//   /// Returns a Future that completes when the connection is closed.
//   Future<void> closeConnection(LanDevice device) async {
//     final cacheKey = '${device.ipAddress}:${device.port}';
//     if (_connectionCache.containsKey(cacheKey)) {
//       final socket = _connectionCache.remove(cacheKey)!;
//       try {
//         await socket.close();
//       } catch (e) {
//         // Already closed
//       }
//     }
//   }

//   /// Closes all active connections
//   ///
//   /// Returns a Future that completes when all connections are closed.
//   Future<void> closeAllConnections() async {
//     final futures = <Future<void>>[];

//     for (final socket in _connectionCache.values) {
//       futures.add(
//         Future(() async {
//           try {
//             await socket.close();
//           } catch (e) {
//             // Ignore errors during cleanup
//           }
//         }),
//       );
//     }

//     _connectionCache.clear();
//     await Future.wait(futures);
//   }

//   /// Disposes of all resources
//   ///
//   /// Must be called when the client is no longer needed.
//   Future<void> dispose() async {
//     await closeAllConnections();
//   }

//   /// Gets the number of cached connections
//   int get cachedConnectionCount => _connectionCache.length;

//   /// Gets list of devices currently connected
//   List<String> get connectedDevices => _connectionCache.keys.toList();
// }

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/lan_device.dart';
import '../models/lan_message.dart';

class LanTcpClient {
  /// The device name of this client (sender)
  final String localDeviceName;

  /// The local device's IP address
  final String localIpAddress;

  /// Cache of active connections to remote devices
  /// Key: "ipAddress:port", Value: Socket
  final Map<String, Socket> _connectionCache = {};

  /// Connection attempt timeouts
  static const Duration connectionTimeout = Duration(seconds: 5);

  /// Message send timeout
  static const Duration sendTimeout = Duration(seconds: 10);

  /// UUID generator for message IDs
  static const uuid = Uuid();

  /// Creates a new TCP client instance
  ///
  /// [localDeviceName] - Name of this device (included in sent messages)
  /// [localIpAddress] - This device's local IP address
  LanTcpClient({required this.localDeviceName, required this.localIpAddress});

  /// Sends a message to a remote device
  ///
  /// This method:
  /// 1. Establishes a TCP connection to the remote device (or reuses cached)
  /// 2. Serializes the message to JSON
  /// 3. Sends the message with a newline terminator
  /// 4. Closes the connection (optional caching for reuse)
  ///
  /// [device] - The target device to send to
  /// [content] - The message content
  ///
  /// Returns a Future that completes when the message is sent.
  /// Throws SocketException if connection fails.
  Future<void> sendMessage(LanDevice device, String content) async {
    // Validate input
    if (content.isEmpty) {
      throw ArgumentError('Message content cannot be empty');
    }

    // Create message object
    final message = LanMessage(
      id: uuid.v4(),
      senderName: localDeviceName,
      senderIp: localIpAddress,
      content: content,
    );

    // Get or establish connection
    final socket = await _getConnection(device);

    try {
      // Serialize message to JSON
      final json = jsonEncode(message.toJson());

      // Send with newline terminator (protocol requirement)
      socket.write('$json\n');
      await socket.flush();
    } catch (e) {
      // Connection error, remove from cache and rethrow
      _removeConnection(device);
      rethrow;
    }
  }

  /// Gets or establishes a TCP connection to a device
  ///
  /// Checks the connection cache first. If no cached connection exists,
  /// attempts to establish a new connection with retry logic.
  ///
  /// [device] - The device to connect to
  ///
  /// Returns a Socket connected to the device.
  /// Throws SocketException if connection cannot be established.
  Future<Socket> _getConnection(LanDevice device) async {
    final cacheKey = '${device.ipAddress}:${device.port}';

    // Check if connection is cached and still valid
    if (_connectionCache.containsKey(cacheKey)) {
      final socket = _connectionCache[cacheKey]!;
      // Return cached socket (it will be removed on error)
      return socket;
    }

    // Establish new connection
    Socket socket;
    try {
      socket = await Socket.connect(
        device.ipAddress,
        device.port,
        timeout: connectionTimeout,
      ).timeout(connectionTimeout);
    } catch (e) {
      throw SocketException(
        'Failed to connect to ${device.name} (${device.ipAddress}:${device.port}): $e',
      );
    }

    // Configure socket options
    socket.setOption(SocketOption.tcpNoDelay, true);

    // Listen for socket closure to clean up cache
    socket.done.then(
      (_) {
        _connectionCache.remove(cacheKey);
      },
      onError: (_) {
        _connectionCache.remove(cacheKey);
      },
    );

    // Cache the connection for future use
    _connectionCache[cacheKey] = socket;

    return socket;
  }

  /// Removes a device connection from the cache
  ///
  /// [device] - The device whose connection should be removed
  void _removeConnection(LanDevice device) {
    final cacheKey = '${device.ipAddress}:${device.port}';
    _connectionCache.remove(cacheKey);
  }

  /// Closes a specific device connection
  ///
  /// [device] - The device to disconnect from
  ///
  /// Returns a Future that completes when the connection is closed.
  Future<void> closeConnection(LanDevice device) async {
    final cacheKey = '${device.ipAddress}:${device.port}';
    if (_connectionCache.containsKey(cacheKey)) {
      final socket = _connectionCache.remove(cacheKey)!;
      try {
        await socket.close();
      } catch (e) {
        // Already closed
      }
    }
  }

  /// Closes all active connections
  ///
  /// Returns a Future that completes when all connections are closed.
  Future<void> closeAllConnections() async {
    final futures = <Future<void>>[];

    for (final socket in _connectionCache.values) {
      futures.add(
        Future(() async {
          try {
            await socket.close();
          } catch (e) {
            // Ignore errors during cleanup
          }
        }),
      );
    }

    _connectionCache.clear();
    await Future.wait(futures);
  }

  /// Disposes of all resources
  ///
  /// Must be called when the client is no longer needed.
  Future<void> dispose() async {
    await closeAllConnections();
  }

  /// Gets the number of cached connections
  int get cachedConnectionCount => _connectionCache.length;

  /// Gets list of devices currently connected
  List<String> get connectedDevices => _connectionCache.keys.toList();
}
