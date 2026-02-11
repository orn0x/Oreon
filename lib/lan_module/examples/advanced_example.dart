/// Example: Advanced LAN Chat with StateManagement
///
/// This example demonstrates more advanced usage patterns:
/// - Error handling and recovery
/// - Connection state management
/// - Message filtering and processing
/// - Device connection details

import 'package:flutter/material.dart';
import 'package:polygone_app/lan_module/lan_module.dart';

/// Provider-like class for managing LAN controller state
class LanControllerProvider extends ChangeNotifier {
  late LanController _controller;

  /// Current state
  bool _isRunning = false;
  final List<LanDevice> _devices = [];
  final List<LanMessage> _messages = [];
  LanDevice? _selectedDevice;
  String? _error;

  /// Getters
  bool get isRunning => _isRunning;
  List<LanDevice> get devices => List.unmodifiable(_devices);
  List<LanMessage> get messages => List.unmodifiable(_messages);
  LanDevice? get selectedDevice => _selectedDevice;
  String? get error => _error;

  /// Initializes the controller
  Future<void> initialize() async {
    try {
      _error = null;
      _controller = LanController();

      await _controller.start();
      _isRunning = true;

      // Listen for device discoveries
      _controller.discoveredDevices.listen(
        _onDeviceDiscovered,
        onError: _onError,
        cancelOnError: false,
      );

      // Listen for incoming messages
      _controller.incomingMessages.listen(
        _onMessageReceived,
        onError: _onError,
        cancelOnError: false,
      );

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isRunning = false;
      notifyListeners();
    }
  }

  /// Called when a device is discovered
  void _onDeviceDiscovered(LanDevice device) {
    if (!_devices.any((d) => d.id == device.id)) {
      _devices.add(device);
      notifyListeners();
    }
  }

  /// Called when a message is received
  void _onMessageReceived(LanMessage message) {
    _messages.add(message);
    // Keep only last 100 messages
    if (_messages.length > 100) {
      _messages.removeAt(0);
    }
    notifyListeners();
  }

  /// Called when an error occurs
  void _onError(dynamic error) {
    _error = error.toString();
    notifyListeners();
  }

  /// Sends a message to a device
  Future<void> sendMessage(LanDevice device, String content) async {
    try {
      _controller.sendMessage(device, content);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Pre-connects to a device
  Future<void> connectToDevice(LanDevice device) async {
    try {
      await _controller.connect(device);
      _selectedDevice = device;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Gets messages from a specific device
  List<LanMessage> getMessagesFromDevice(LanDevice device) {
    return _messages.where((m) => m.senderIp == device.ipAddress).toList();
  }

  /// Gets all unique senders
  List<String> get uniqueSenders =>
      _messages.map((m) => m.senderName).toSet().toList();

  /// Shuts down the controller
  Future<void> shutdown() async {
    try {
      await _controller.stop();
      await _controller.dispose();
      _isRunning = false;
      _devices.clear();
      _messages.clear();
      _selectedDevice = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}

/// Advanced chat UI with provider pattern
class AdvancedChatExample extends StatefulWidget {
  const AdvancedChatExample({Key? key}) : super(key: key);

  @override
  State<AdvancedChatExample> createState() => _AdvancedChatExampleState();
}

class _AdvancedChatExampleState extends State<AdvancedChatExample> {
  late LanControllerProvider _provider;
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _provider = LanControllerProvider();
    _provider.initialize();
  }

  @override
  void dispose() {
    _provider.shutdown();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _provider.isRunning
                  ? 'LAN Chat (${_provider.devices.length} devices)'
                  : 'LAN Chat (Initializing...)',
            ),
            elevation: 2,
          ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_provider.error != null) {
      return _buildErrorView();
    }

    if (!_provider.isRunning) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      children: [
        /// Device list sidebar
        Container(
          width: 250,
          color: Colors.grey[100],
          child: _buildDeviceList(),
        ),

        /// Messages and input area
        Expanded(
          child: Column(
            children: [
              // Selected device header
              if (_provider.selectedDevice != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Row(
                    children: [
                      Icon(Icons.devices, color: Colors.blue[900]),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _provider.selectedDevice!.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${_provider.selectedDevice!.ipAddress}:'
                            '${_provider.selectedDevice!.port}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Select a device to chat',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),

              // Messages area
              Expanded(child: _buildMessagesView()),

              // Input area
              _buildInputArea(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceList() {
    if (_provider.devices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Searching for devices...'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _provider.devices.length,
      itemBuilder: (context, index) {
        final device = _provider.devices[index];
        final isSelected = _provider.selectedDevice?.id == device.id;
        final messageCount = _provider.getMessagesFromDevice(device).length;

        return Container(
          color: isSelected ? Colors.blue : null,
          child: ListTile(
            title: Text(
              device.name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '$messageCount messages',
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.grey,
              ),
            ),
            trailing: Icon(
              Icons.phone,
              color: isSelected ? Colors.white : Colors.green,
            ),
            onTap: () {
              _provider.connectToDevice(device);
            },
          ),
        );
      },
    );
  }

  Widget _buildMessagesView() {
    final device = _provider.selectedDevice;
    if (device == null) {
      return const Center(child: Text('Select a device'));
    }

    final messages = _provider.getMessagesFromDevice(device);
    if (messages.isEmpty) {
      return const Center(child: Text('No messages yet'));
    }

    return ListView.builder(
      reverse: true,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.content, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '${message.timestamp.hour}:'
                    '${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    final canSend = _provider.selectedDevice != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: canSend ? 'Type message...' : 'Select a device',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              enabled: canSend,
              onSubmitted: canSend ? (_) => _sendMessage() : null,
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            onPressed: canSend ? _sendMessage : null,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 48, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red[400],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _provider.error ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _provider.initialize();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final device = _provider.selectedDevice;
    if (device == null) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      await _provider.sendMessage(device, message);
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
