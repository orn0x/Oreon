/// TCP Server for Incoming Messages
///
/// Provides a TCP server that listens for incoming messages from other devices.
/// Handles multiple concurrent connections and parses incoming message protocol.

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../models/lan_message.dart';

/// TCP Message Protocol
/// Format: JSON string followed by newline
/// {
///   "id": "unique-message-id",
///   "senderName": "device-name",
///   "senderIp": "192.168.1.100",
///   "content": "message text",
///   "timestamp": "2026-02-11T10:30:00.000Z"
/// }

/// TCP Server for receiving LAN messages
///
/// Responsible for:
/// - Listening for incoming TCP connections
/// - Parsing and validating incoming messages
/// - Emitting received messages via stream
/// - Managing client connections
class LanTcpServer {
  /// The device name of this server
  final String deviceName;

  /// The IP address this server binds to
  final String ipAddress;

  /// The port this server listens on
  final int port;

  /// Internal TCP server instance
  ServerSocket? _serverSocket;

  /// Stream controller for incoming messages
  late StreamController<LanMessage> _messageController;

  /// Active client socket connections
  final Set<Socket> _activeConnections = {};

  /// Whether the server is currently running
  bool _isRunning = false;

  /// Creates a new TCP server instance
  ///
  /// [deviceName] - Name of this device (included in sent messages)
  /// [ipAddress] - IP address to bind to (typically '0.0.0.0')
  /// [port] - Port to listen on for incoming connections
  LanTcpServer({
    required this.deviceName,
    required this.ipAddress,
    required this.port,
  }) {
    _messageController = StreamController<LanMessage>.broadcast();
  }

  /// Stream of incoming messages
  ///
  /// Emits a LanMessage for each message received from a connected device.
  Stream<LanMessage> get incomingMessages => _messageController.stream;

  /// Starts the TCP server
  ///
  /// This method:
  /// 1. Creates a server socket on the specified port
  /// 2. Begins listening for incoming connections
  /// 3. Spawns handlers for each new connection
  ///
  /// Returns a Future that completes when the server is listening.
  /// Throws SocketException if the port is already in use.
  Future<void> start() async {
    if (_isRunning) {
      return;
    }

    try {
      // Create and bind the server socket
      _serverSocket = await ServerSocket.bind(ipAddress, port);
      _isRunning = true;

      // Start accepting connections asynchronously
      _serverSocket!.listen(
        _handleNewConnection,
        onError: _handleServerError,
        cancelOnError: false,
      );
    } catch (e) {
      _isRunning = false;
      rethrow;
    }
  }

  /// Stops the TCP server
  ///
  /// This method:
  /// 1. Closes all active client connections
  /// 2. Closes the server socket
  /// 3. Clears the message stream
  ///
  /// Returns a Future that completes when the server is fully stopped.
  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    _isRunning = false;

    try {
      // Close all active connections
      for (final socket in _activeConnections.toList()) {
        await socket.close();
      }
      _activeConnections.clear();

      // Close the server socket
      if (_serverSocket != null) {
        await _serverSocket!.close();
        _serverSocket = null;
      }
    } catch (e) {
      // Log error but ensure cleanup
      rethrow;
    }
  }

  /// Handles a new incoming connection
  ///
  /// Called when a client device connects to this server.
  /// Sets up message listening for the connection.
  ///
  /// [socket] - The connected socket
  void _handleNewConnection(Socket socket) {
    _activeConnections.add(socket);

    // Get client address for logging
    final clientAddress = socket.remoteAddress.address;
    final clientPort = socket.remotePort;

    // Set socket options for better reliability
    socket.setOption(SocketOption.tcpNoDelay, true);

    // Listen for incoming data
    socket.listen(
      (List<int> data) {
        _handleIncomingData(socket, data, clientAddress);
      },
      onError: (error) {
        _handleConnectionError(socket, error, clientAddress);
      },
      onDone: () {
        _handleConnectionClosed(socket, clientAddress);
      },
    );
  }

  /// Handles incoming data from a client
  ///
  /// Parses the incoming message protocol and validates the message.
  /// If valid, emits the message via the stream.
  ///
  /// [socket] - The socket from which data arrived
  /// [data] - The raw bytes received
  /// [clientAddress] - The client's IP address
  void _handleIncomingData(
    Socket socket,
    List<int> data,
    String clientAddress,
  ) {
    try {
      // Convert bytes to string
      final rawString = utf8.decode(data);

      // Split by newline in case multiple messages were received
      final lines = rawString.split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        // Parse JSON message
        final json = jsonDecode(line) as Map<String, dynamic>;

        // Validate required fields
        if (!_validateMessage(json)) {
          return;
        }

        // Create LanMessage from JSON
        final message = LanMessage.fromJson(json);

        // Emit the message
        if (!_messageController.isClosed) {
          _messageController.add(message);
        }
      }
    } catch (e) {
      // Invalid message format, silently ignore or log
      // Could add debug logging here
    }
  }

  /// Validates a message JSON payload
  ///
  /// Checks that all required fields are present and have correct types.
  ///
  /// Returns true if valid, false otherwise.
  bool _validateMessage(Map<String, dynamic> json) {
    try {
      // Check required fields exist
      if (!json.containsKey('id') ||
          !json.containsKey('senderName') ||
          !json.containsKey('senderIp') ||
          !json.containsKey('content') ||
          !json.containsKey('timestamp')) {
        return false;
      }

      // Check types
      if (json['id'] is! String ||
          json['senderName'] is! String ||
          json['senderIp'] is! String ||
          json['content'] is! String ||
          json['timestamp'] is! String) {
        return false;
      }

      // Validate timestamp is ISO8601
      DateTime.parse(json['timestamp'] as String);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Handles connection errors
  ///
  /// Called when an error occurs on a client connection.
  /// Closes the socket and removes it from active connections.
  ///
  /// [socket] - The socket with the error
  /// [error] - The error that occurred
  /// [clientAddress] - The client's IP address
  void _handleConnectionError(
    Socket socket,
    dynamic error,
    String clientAddress,
  ) {
    _activeConnections.remove(socket);
    try {
      socket.close();
    } catch (e) {
      // Already closed
    }
  }

  /// Handles connection closure
  ///
  /// Called when a client disconnects from this server.
  /// Removes the socket from active connections.
  ///
  /// [socket] - The closed socket
  /// [clientAddress] - The client's IP address
  void _handleConnectionClosed(Socket socket, String clientAddress) {
    _activeConnections.remove(socket);
  }

  /// Handles server socket errors
  ///
  /// Called when an error occurs on the server socket itself.
  ///
  /// [error] - The error that occurred
  void _handleServerError(dynamic error) {
    // Server errors are typically fatal (port already in use, etc.)
    // Could trigger shutdown or recovery
  }

  /// Disposes of all resources
  ///
  /// Must be called when the server is no longer needed.
  Future<void> dispose() async {
    await stop();
    await _messageController.close();
  }

  /// Whether the server is currently running
  bool get isRunning => _isRunning;

  /// Number of active client connections
  int get activeConnections => _activeConnections.length;
}
