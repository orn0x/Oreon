import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/lan_device.dart';

class MdnsDiscoveryService {
  static const String serviceType = '_oreonchat._tcp';
  static const MethodChannel _platform =
      MethodChannel('com.example.polygone_app/mdns');

  final String deviceName;
  final String ipAddress;
  final int port;

  final StreamController<LanDevice> _discoveryController =
      StreamController<LanDevice>.broadcast();

  final Map<String, LanDevice> _discoveredDevices = {};

  bool _isRunning = false;
  bool _handlerAttached = false;

  MdnsDiscoveryService({
    required this.deviceName,
    required this.ipAddress,
    required this.port,
  });

  Stream<LanDevice> get discoveredDevices => _discoveryController.stream;

  bool get isRunning => _isRunning;

  List<LanDevice> get cachedDevices =>
      _discoveredDevices.values.toList(growable: false);

  // --------------------------
  // Start
  // --------------------------

  Future<void> start() async {
    if (_isRunning) {
      debugPrint('[MDNS] Already running');
      return;
    }

    debugPrint('[MDNS] Starting service...');
    _attachHandler();
    _isRunning = true;

    try {
      await _platform.invokeMethod('mdns.advertise', {
        'serviceName': deviceName,
        'serviceType': serviceType,
        'port': port,
      });

      debugPrint('[MDNS] Advertising as $deviceName:$port');

      await _platform.invokeMethod('mdns.discover', {
        'serviceType': serviceType,
      });

      debugPrint('[MDNS] Discovery started for $serviceType');
    } catch (e) {
      debugPrint('[MDNS] Start failed: $e');
      _isRunning = false;
      rethrow;
    }
  }

  // --------------------------
  // Stop
  // --------------------------

  Future<void> stop() async {
    if (!_isRunning) {
      debugPrint('[MDNS] Stop called but not running');
      return;
    }

    debugPrint('[MDNS] Stopping service...');
    _isRunning = false;

    try {
      await _platform.invokeMethod('mdns.stop');
      debugPrint('[MDNS] Platform stop invoked');
    } catch (e) {
      debugPrint('[MDNS] Stop error: $e');
    } finally {
      _discoveredDevices.clear();
      debugPrint('[MDNS] Cleared cached devices');
    }
  }

  // --------------------------
  // Platform handler
  // --------------------------

  void _attachHandler() {
    if (_handlerAttached) {
      debugPrint('[MDNS] Handler already attached');
      return;
    }

    debugPrint('[MDNS] Attaching platform handler');

    _platform.setMethodCallHandler((call) async {
      if (!_isRunning) return null;

      debugPrint('[MDNS] Platform call: ${call.method}');
      final args = Map<String, dynamic>.from(call.arguments ?? {});
      debugPrint('[MDNS] Arguments: $args');

      switch (call.method) {
        case 'onServiceDiscovered':
          final serviceName = args['serviceName'] as String?;
          final address = args['address'] as String?;
          final port = args['port'] as int?;

          if (serviceName != null && address != null && port != null) {
            _handleServiceDiscovered(serviceName, address, port);
          }
          break;

        case 'onServiceLost':
          final serviceName = args['serviceName'] as String?;
          if (serviceName != null) {
            _handleServiceLost(serviceName);
          }
          break;

        case 'onDiscoveryStarted':
          debugPrint('[MDNS] Discovery started callback');
          break;

        case 'onDiscoveryStartFailed':
          debugPrint('[MDNS] Discovery start FAILED');
          break;

        case 'onRegistered':
          debugPrint('[MDNS] Service registered successfully');
          break;

        case 'onRegistrationFailed':
          debugPrint('[MDNS] Service registration FAILED');
          break;
      }

      return null;
    });

    _handlerAttached = true;
  }

  // --------------------------
  // Internal logic
  // --------------------------

  void _handleServiceDiscovered(
      String serviceName, String address, int port) {
    debugPrint('[MDNS] Discovered: $serviceName at $address:$port');

    // Ignore self
    if (serviceName == deviceName &&
        address == ipAddress &&
        port == this.port) {
      debugPrint('[MDNS] Ignored self device');
      return;
    }

    final deviceKey = '$address:$port';

    if (_discoveredDevices.containsKey(deviceKey)) {
      debugPrint('[MDNS] Device already cached: $deviceKey');
      return;
    }

    final device = LanDevice(
      id: serviceName,
      name: serviceName,
      ipAddress: address,
      port: port,
    );

    _discoveredDevices[deviceKey] = device;

    debugPrint('[MDNS] Added device: $deviceKey');
    debugPrint('[MDNS] Total devices: ${_discoveredDevices.length}');

    if (!_discoveryController.isClosed) {
      _discoveryController.add(device);
    }
  }

  void _handleServiceLost(String serviceName) {
    debugPrint('[MDNS] Service lost: $serviceName');

    final keysToRemove = _discoveredDevices.entries
        .where((e) => e.value.name == serviceName)
        .map((e) => e.key)
        .toList();

    for (final key in keysToRemove) {
      _discoveredDevices.remove(key);
      debugPrint('[MDNS] Removed device: $key');
    }

    debugPrint('[MDNS] Remaining devices: ${_discoveredDevices.length}');
  }

  // --------------------------
  // Dispose
  // --------------------------

  Future<void> dispose() async {
    debugPrint('[MDNS] Disposing service');
    await stop();
    await _discoveryController.close();
  }
}
