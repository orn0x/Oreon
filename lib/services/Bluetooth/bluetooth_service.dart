import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:oreon/services/Bluetooth/message_processor.dart';

// ────────────────────────────────────────────────
//  Standard Nordic UART Service (very common for chat/serial)
// ────────────────────────────────────────────────
final Guid nordicUartService = Guid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
final Guid nordicTxChar     = Guid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E"); // write
final Guid nordicRxChar     = Guid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E"); // notify

class BluetoothServiceManager {
  static final BluetoothServiceManager _instance = BluetoothServiceManager._internal();
  factory BluetoothServiceManager() => _instance;
  BluetoothServiceManager._internal();

  final MessageProcessor _messageProcessor = MessageProcessor();

  final List<BluetoothDevice> _connectedDevices = [];
  final Map<String, BluetoothCharacteristic> _txCharacteristics = {}; // device id → TX char

  final List<StreamSubscription> _subscriptions = [];

  final _deviceConnectController = StreamController<BluetoothDevice>.broadcast();
  final _deviceDisconnectController = StreamController<BluetoothDevice>.broadcast();
  final _dataReceiveController = StreamController<Map<String, dynamic>>.broadcast();
  final _deviceFoundController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<BluetoothDevice> get onDeviceConnected => _deviceConnectController.stream;
  Stream<BluetoothDevice> get onDeviceDisconnected => _deviceDisconnectController.stream;
  Stream<Map<String, dynamic>> get onDataReceived => _dataReceiveController.stream;
  Stream<Map<String, dynamic>> get onDeviceFound => _deviceFoundController.stream;

  Future<bool> initialize() async {
    try {
      await _requestPermissions();

      // Monitor adapter state
      FlutterBluePlus.adapterState.listen((state) {
        debugPrint("Bluetooth adapter state: $state");
      });

      final isOn = await FlutterBluePlus.adapterState.firstWhere(
        (s) => s != BluetoothAdapterState.turningOn,
        orElse: () => BluetoothAdapterState.off,
      );

      if (isOn != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
      }

      return true;
    } catch (e) {
      debugPrint("Initialization failed: $e");
      return false;
    }
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        Permission.locationWhenInUse, // often still needed on Android 12+
    ].request();

    if (statuses.values.any((s) => !s.isGranted)) {
      throw Exception("Required Bluetooth permissions not granted");
    }
  }

  Future<void> startScanning({
    Duration timeout = const Duration(seconds: 12),
    List<Guid>? withServices,
  }) async {
    try {
      await FlutterBluePlus.stopScan();

      // You can pass custom service UUID if needed
      final services = withServices ?? [nordicUartService];

      debugPrint("Scanning for devices with services: $services");

      // Listen to scan results once
      final sub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          _deviceFoundController.add({
            'device': r.device,
            'rssi': r.rssi,
            'name': r.device.advName,
            'serviceUuids': r.advertisementData.serviceUuids,
          });
        }
      });

      _subscriptions.add(sub);

      await FlutterBluePlus.startScan(
        timeout: timeout,
        withServices: services,
        androidUsesFineLocation: true,
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      debugPrint("Scan error: $e");
      rethrow;
    }
  }

  Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint("Stop scan error: $e");
    }
  }

  Future<bool> connect2Device(BluetoothDevice device) async {
    try {
      if (_connectedDevices.any((d) => d.id == device.id)) {
        debugPrint("Already connected to ${device.advName}");
        return true;
      }

      debugPrint("Connecting to ${device.advName} (${device.id})...");

      // Request higher MTU on Android (flutter_blue_plus defaults to 512 anyway)
      if (defaultTargetPlatform == TargetPlatform.android) {
        await device.requestMtu(512);
      }

      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
        license: License.free
      );

      // Discover services
      final services = await device.discoverServices();

      BluetoothCharacteristic? txChar;
      BluetoothCharacteristic? rxChar;

      for (final service in services) {
        if (service.uuid == nordicUartService) { // or your custom chatServiceUuid
          for (final char in service.characteristics) {
            if (char.uuid == nordicTxChar) txChar = char;
            if (char.uuid == nordicRxChar) rxChar = char;
          }
        }
      }

      if (txChar == null || rxChar == null) {
        await device.disconnect();
        throw Exception("Required UART characteristics not found");
      }

      // Subscribe to notifications
      if (rxChar.properties.notify || rxChar.properties.indicate) {
        await rxChar.setNotifyValue(true);

        final sub = rxChar.onValueReceived.listen((value) {
          _handleIncomingData(value, device);
        });

        _subscriptions.add(sub);
      }

      _txCharacteristics[device.remoteId.str] = txChar;
      _connectedDevices.add(device);

      _deviceConnectController.add(device);
      debugPrint("Connected: ${device.advName}");

      // Monitor disconnection
      final connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _cleanupDevice(device);
        }
      });
      _subscriptions.add(connSub);

      return true;
    } catch (e) {
      debugPrint("Connection failed: $e");
      await device.disconnect();
      return false;
    }
  }

  void _handleIncomingData(List<int> bytes, BluetoothDevice device) {
    try {
      // Try UTF-8 decode (common for chat)
      final text = utf8.decode(bytes, allowMalformed: true).trim();

      _dataReceiveController.add({
        'device': device,
        'rawBytes': bytes,
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint("Received from ${device.advName}: $text");
    } catch (e) {
      debugPrint("Data decode error: $e");
    }
  }

  Future<bool> sendChatMessage(
    BluetoothDevice device,
    String text, {
    String sender = "You",
  }) async {
    final message = {
      'type': 'chat',
      'text': text,
      'sender': sender,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    return await sendData(device, message);
  }

  Future<bool> sendData(
    BluetoothDevice device,
    Map<String, dynamic> message, {
    bool withoutResponse = false,
  }) async {
    final txChar = _txCharacteristics[device.remoteId.str];
    if (txChar == null) {
      debugPrint("No TX characteristic for ${device.advName}");
      return false;
    }

    try {
      final json = jsonEncode(message);
      var bytes = utf8.encode(json);

      debugPrint("Sending ${bytes.length} bytes to ${device.advName}");

      // Use MTU-aware chunking
      final mtu = await device.mtu.first; // current negotiated MTU
      final chunkSize = mtu - 3; // safe overhead

      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        final chunk = bytes.sublist(i, end);

        await txChar.write(
          Uint8List.fromList(chunk),
          withoutResponse: withoutResponse && txChar.properties.writeWithoutResponse,
        );

        if (end < bytes.length) {
          await Future.delayed(const Duration(milliseconds: 8));
        }
      }

      debugPrint("Data sent successfully");
      return true;
    } catch (e) {
      debugPrint("Send failed: $e");
      return false;
    }
  }

  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      _cleanupDevice(device);
    } catch (e) {
      debugPrint("Disconnect error: $e");
    }
  }

  void _cleanupDevice(BluetoothDevice device) {
    _connectedDevices.removeWhere((d) => d.id == device.id);
    _txCharacteristics.remove(device.remoteId.str);
    _deviceDisconnectController.add(device);
    debugPrint("Disconnected: ${device.advName}");
  }

  Future<void> dispose() async {
    for (final device in List.of(_connectedDevices)) {
      await disconnectDevice(device);
    }

    await stopScanning();

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    await _deviceConnectController.close();
    await _deviceDisconnectController.close();
    await _dataReceiveController.close();
    await _deviceFoundController.close();
  }
}