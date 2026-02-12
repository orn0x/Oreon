import 'dart:typed_data';
import 'package:oreon/services/WIFI/lan_module/models/lan_device.dart';

class DeviceWrapper {
  final String id;
  final String name;
  final String appIdentifier;
  final bool isBluetooth;
  final bool isFromApp;
  final Uint8List? imageBytes;
  final DateTime timestamp;
  final String ipAddress;
  final int port;

  DeviceWrapper({
    required this.id,
    required this.name,
    required this.appIdentifier,
    required this.isBluetooth,
    required this.isFromApp,
    this.imageBytes,
    required this.timestamp,
    required this.ipAddress,
    required this.port,
  });

  factory DeviceWrapper.fromLan(LanDevice device) {
    return DeviceWrapper(
      id: device.id,
      name: device.name,
      appIdentifier: device.id,
      isBluetooth: false,
      isFromApp: true,
      imageBytes: null,
      timestamp: DateTime.now(),
      ipAddress: device.ipAddress,
      port: device.port,
    );
  }

  factory DeviceWrapper.fromWifi(LanDevice device) {
    return DeviceWrapper(
      id: device.id,
      name: device.name,
      appIdentifier: device.id,
      isBluetooth: false,
      isFromApp: true,
      imageBytes: null,
      timestamp: DateTime.now(),
      ipAddress: device.ipAddress,
      port: device.port,
    );
  }

  factory DeviceWrapper.fromBluetooth(Map<String, dynamic> device) {
    return DeviceWrapper(
      id: device['id'] ?? 'unknown',
      name: device['name'] ?? 'Unknown Device',
      appIdentifier: device['id'] ?? 'unknown',
      isBluetooth: true,
      isFromApp: device['isFromApp'] ?? false,
      imageBytes: device['image'] as Uint8List?,
      timestamp: DateTime.now(),
      ipAddress: '0.0.0.0',
      port: 0,
    );
  }
}