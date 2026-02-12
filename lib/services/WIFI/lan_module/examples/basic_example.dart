/// Example: Basic LAN Chat Usage
///
/// This file demonstrates the simplest way to use the LAN module
/// for device discovery and messaging.

import 'package:flutter/material.dart';
import 'package:oreon/services/WIFI/lan_module/lan_controller.dart';
import 'package:oreon/services/WIFI/lan_module/models/lan_device.dart';
import 'package:oreon/services/WIFI/lan_module/models/lan_message.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'LAN Chat Example', home: const ChatExample());
  }
}

class ChatExample extends StatefulWidget {
  const ChatExample({Key? key}) : super(key: key);

  @override
  State<ChatExample> createState() => _ChatExampleState();
}

class _ChatExampleState extends State<ChatExample> {
  /// The main LAN controller instance
  late LanController _controller;

  /// List of discovered devices
  final List<LanDevice> _discoveredDevices = [];

  /// List of received messages
  final List<LanMessage> _messages = [];

  /// Selected device for sending messages
  LanDevice? _selectedDevice;

  /// Message input controller
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeLanModule();
  }

  /// Initializes the LAN module
  Future<void> _initializeLanModule() async {
    _controller = LanController();

    try {
      // Start the controller
      await _controller.start();
      print('LAN controller started');

      // Listen for discovered devices
      _controller.discoveredDevices.listen((device) {
        setState(() {
          // Only add if not already in list
          if (!_discoveredDevices.any((d) => d.id == device.id)) {
            _discoveredDevices.add(device);
            print('Device discovered: ${device.name}');
          }
        });
      });

      // Listen for incoming messages
      _controller.incomingMessages.listen((message) {
        setState(() {
          _messages.add(message);
          print('Message from ${message.senderName}: ${message.content}');
        });
      });
    } catch (e) {
      print('Error starting LAN controller: $e');
    }
  }

  /// Sends a message to the selected device
  Future<void> _sendMessage() async {
    if (_selectedDevice == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a device')));
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }

    try {
      // Send the message
      _controller.sendMessage(_selectedDevice!, message);
      _messageController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent to ${_selectedDevice!.name}')),
      );
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LAN Chat Example')),
      body: Column(
        children: [
          /// Device List Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Discovered Devices',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: _discoveredDevices.isEmpty
                      ? const Center(child: Text('No devices discovered'))
                      : ListView.builder(
                          itemCount: _discoveredDevices.length,
                          itemBuilder: (context, index) {
                            final device = _discoveredDevices[index];
                            final isSelected = _selectedDevice?.id == device.id;

                            return ListTile(
                              title: Text(device.name),
                              subtitle: Text(
                                '${device.ipAddress}:${device.port}',
                              ),
                              tileColor: isSelected ? Colors.blue[100] : null,
                              onTap: () {
                                setState(() {
                                  _selectedDevice = device;
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          /// Messages Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Messages',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(child: Text('No messages'))
                      : ListView.builder(
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            
                            return ListTile(
                              title: Text(message.senderName),
                              subtitle: Text(message.content),
                              trailing: Text(
                                '${message.timestamp.hour}:${message.timestamp.minute}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          /// Message Input Section
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sendMessage,
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
