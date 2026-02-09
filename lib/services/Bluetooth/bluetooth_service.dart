import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:oreon/const/const.dart';
import 'package:oreon/main.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/bluetooth_device.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();

  fbp.BluetoothDevice? _connectedDevice;
  fbp.BluetoothCharacteristic? _txCharacteristic;
  fbp.BluetoothCharacteristic? _rxCharacteristic;

  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _rxSubscription;

  final StreamController<String> _messageController = StreamController<String>.broadcast();
  final StreamController<BluetoothDeviceModel> _deviceFoundController = StreamController<BluetoothDeviceModel>.broadcast();
  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();
  final List<BluetoothDeviceModel> _discoveredDevices = [];

  // Add retry mechanism
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 3;
  Timer? _reconnectTimer;

  // Add connection status getter
  String get connectionStatus {
    if (_connectedDevice == null) return 'Disconnected';
    return 'Connected';
  }

  factory BluetoothService() {
    return _instance;
  }

  BluetoothService._internal();

  // Getters
  bool get isConnected => _connectedDevice != null;
  Stream<String> get onMessageReceived => _messageController.stream;
  Stream<BluetoothDeviceModel> get onDeviceFound => _deviceFoundController.stream;
  Stream<bool> get onConnectionStateChanged => _connectionStateController.stream;
  List<BluetoothDeviceModel> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  // Request permissions
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    return statuses[Permission.bluetooth]!.isGranted &&
        statuses[Permission.location]!.isGranted;
  }

  // Check if Bluetooth is enabled
  Future<bool> isBluetoothEnabled() async {
    try {
      final state = fbp.FlutterBluePlus.adapterStateNow;
      return state == fbp.BluetoothAdapterState.on;
    } catch (e) {
      return false;
    }
  }

  // Get device name
  Future<String?> getDeviceName() async {
    try {
      return "Device_${ConstApp().appIdentifier()}_${prefs.getString("user_id")}";
    } catch (e) {
      return null;
    }
  }

  // Start discovery
  Future<void> startDiscovery() async {
    try {
      // Don't clear devices - persist them across scans
      // Cancel any existing subscription
      await _scanSubscription?.cancel();

      // Stop any ongoing scan
      await fbp.FlutterBluePlus.stopScan();

      // Listen to scan results BEFORE starting scan
      _scanSubscription = fbp.FlutterBluePlus.onScanResults.listen(
        (results) {
          for (fbp.ScanResult result in results) {
            final deviceId = result.device.remoteId.toString();
            final deviceName = result.device.platformName.isNotEmpty
                ? result.device.platformName
                : 'Unknown (${deviceId.substring(0, 8)})';

            // Check if device already in list
            final existingIndex = _discoveredDevices.indexWhere((d) => d.address == deviceId);

            if (existingIndex == -1) {
              // New device found
              final device = BluetoothDeviceModel(
                address: deviceId,
                name: deviceName,
                isConnected: false,
                rssi: result.rssi,
                appIdentifier: '',
              );
              _discoveredDevices.add(device);
              _deviceFoundController.add(device);
            } else {
              // Update RSSI for existing device
              _discoveredDevices[existingIndex] = BluetoothDeviceModel(
                address: deviceId,
                name: deviceName,
                isConnected: false,
                rssi: result.rssi,
                appIdentifier: _discoveredDevices[existingIndex].appIdentifier,
              );
              // Notify listeners of update
              _deviceFoundController.add(_discoveredDevices[existingIndex]);
            }
          }
        },
      );

      // Now start the scan
      await fbp.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidScanMode: fbp.AndroidScanMode.lowLatency,
      );
    } catch (e) {
      // Handle discovery error silently
    }
  }

  // Cancel discovery
  Future<void> cancelDiscovery() async {
    try {
      await _scanSubscription?.cancel();
      await fbp.FlutterBluePlus.stopScan();
      // Keep discovered devices persisted
    } catch (e) {
      // Handle error
    }
  }

  // Clear discovered devices (call when starting fresh)
  void clearDiscoveredDevices() {
    _discoveredDevices.clear();
  }

  // Enhanced connect with retry logic
  Future<bool> connectToDevice(String deviceAddress) async {
    try {
      final deviceId = fbp.DeviceIdentifier(deviceAddress);
      final device = fbp.BluetoothDevice(remoteId: deviceId);

      await device.connect(license: fbp.License.free);
      _connectedDevice = device;
      _reconnectAttempts = 0; // Reset on successful connection

      // Get services
      final services = await device.discoverServices();

      for (fbp.BluetoothService btService in services) {
        for (fbp.BluetoothCharacteristic characteristic in btService.characteristics) {
          if (characteristic.properties.write) {
            _txCharacteristic = characteristic;
          }
          if (characteristic.properties.notify || characteristic.properties.read) {
            _rxCharacteristic = characteristic;
            if (characteristic.properties.notify) {
              try {
                await characteristic.setNotifyValue(true);
              } catch (e) {
                debugPrint('⚠️ Notification setup failed: $e');
              }
            }
          }
        }
      }

      // Listen for incoming messages
      if (_rxCharacteristic != null) {
        _rxSubscription = _rxCharacteristic!.onValueReceived.listen((value) {
          final message = String.fromCharCodes(value);
          _messageController.add(message);
        });
      }

      // Monitor connection state with auto-reconnect
      _connectionStateSubscription = device.connectionState.listen((state) {
        final connected = state == fbp.BluetoothConnectionState.connected;
        _connectionStateController.add(connected);
        if (!connected) {
          _handleDisconnection(deviceAddress);
        }
      });

      _connectionStateController.add(true);
      return true;
    } catch (e) {
      debugPrint('❌ Connection failed: $e');
      _handleConnectionError(deviceAddress);
      return false;
    }
  }

  // Handle disconnection with auto-reconnect
  void _handleDisconnection(String deviceAddress) {
    debugPrint('⚠️ Device disconnected, attempting reconnect...');
    _cleanupConnection();
    _attemptReconnect(deviceAddress);
  }

  // Handle connection errors
  void _handleConnectionError(String deviceAddress) {
    debugPrint('❌ Connection error, will retry...');
    _cleanupConnection();
    _attemptReconnect(deviceAddress);
  }

  // Attempt to reconnect with exponential backoff
  void _attemptReconnect(String deviceAddress) {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ Max reconnection attempts reached');
      _connectionStateController.add(false);
      return;
    }

    _reconnectAttempts++;
    final delaySeconds = (2 ^ _reconnectAttempts).clamp(1, 16); // Exponential backoff: 2, 4, 8, 16 seconds
    
    debugPrint('🔄 Scheduling reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in ${delaySeconds}s');
    
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      connectToDevice(deviceAddress);
    });
  }

  // Disconnect
  Future<void> disconnect() async {
    try {
      await _rxSubscription?.cancel();
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      _cleanupConnection();
    } catch (e) {
      _cleanupConnection();
    }
  }

  void _cleanupConnection() {
    _connectedDevice = null;
    _txCharacteristic = null;
    _rxCharacteristic = null;
    _connectionStateController.add(false);
  }

  // Send message
  Future<bool> sendMessage(String message) async {
    try {
      if (_txCharacteristic != null && _connectedDevice != null) {
        final bytes = message.codeUnits;
        await _txCharacteristic!.write(bytes, withoutResponse: true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _scanSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _rxSubscription?.cancel();
    _reconnectTimer?.cancel();
    _messageController.close();
    _deviceFoundController.close();
    _connectionStateController.close();
    disconnect();
  }
}