/// mDNS Device Discovery Service
///
/// Handles mDNS-based device discovery on the local network.
/// Advertises this device's service and discovers other devices.
/// Uses the nsd (Network Service Discovery) API which works cross-platform.

import 'dart:async';
import '../models/lan_device.dart';

/// Callback for device discovery events
typedef DeviceDiscoveryCallback = void Function(LanDevice device);

/// Callback for service resolution events
typedef ServiceResolvedCallback =
    void Function(String serviceName, String address, int port);

/// mDNS Discovery Service
///
/// Responsible for:
/// - Discovering devices advertising _oreonchat._tcp.local service
/// - Advertising this device's service
/// - Managing discovery lifecycle
class MdnsDiscoveryService {
  /// Service type advertised: _oreonchat._tcp (will resolve to _oreonchat._tcp.local)
  static const String serviceType = '_oreonchat._tcp';

  /// Local device information
  final String deviceName;
  final String ipAddress;
  final int port;

  /// Stream controller for discovered devices
  late StreamController<LanDevice> _discoveryController;

  /// Whether the discovery service is currently active
  bool _isRunning = false;

  /// Cache of discovered devices to avoid duplicates
  final Map<String, LanDevice> _discoveredDevices = {};

  /// Creates a new mDNS discovery service
  ///
  /// [deviceName] - Name to advertise for this device
  /// [ipAddress] - This device's local IP address
  /// [port] - TCP port to advertise for connections
  MdnsDiscoveryService({
    required this.deviceName,
    required this.ipAddress,
    required this.port,
  }) {
    _discoveryController = StreamController<LanDevice>.broadcast();
  }

  /// Stream of discovered devices
  ///
  /// Emits a LanDevice whenever a new device is discovered on the network.
  /// Device is only emitted once per unique IP:port combination.
  Stream<LanDevice> get discoveredDevices => _discoveryController.stream;

  /// Starts mDNS discovery and service advertisement
  ///
  /// This method:
  /// 1. Advertises this device's service via mDNS
  /// 2. Begins listening for other devices' services
  /// 3. Emits LanDevice events for each discovered device
  ///
  /// Should be called once during initialization.
  /// Returns a Future that completes when service is ready.
  Future<void> start() async {
    if (_isRunning) {
      return;
    }

    _isRunning = true;

    // In a real implementation, this would:
    // 1. Register mDNS service using platform-specific code
    // 2. Start discovery listener
    // 3. Handle mDNS events
    //
    // For now, we provide the interface structure.
    // Platform channels would be used for actual mDNS operations.

    try {
      // TODO: Implement platform channel call to register mDNS service
      // This would involve:
      // - Calling native Android/iOS code via MethodChannel
      // - Creating NsdServiceInfo with service name and port
      // - Registering via NsdManager (Android) or NSNetService (iOS)

      // TODO: Implement platform channel call to start discovery
      // This would involve:
      // - Creating discovery listener
      // - Calling nsd/bonjour APIs to find _oreonchat._tcp services
      // - Broadcasting discovered devices via _discoveryController

      // Simulate immediate readiness
      await Future.delayed(Duration(milliseconds: 100));
    } catch (e) {
      _isRunning = false;
      rethrow;
    }
  }

  /// Stops mDNS discovery and service advertisement
  ///
  /// This method:
  /// 1. Unregisters this device's service
  /// 2. Stops listening for other devices
  /// 3. Clears the device cache
  ///
  /// Should be called during cleanup.
  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    _isRunning = false;

    try {
      // TODO: Implement platform channel call to unregister service
      // TODO: Implement platform channel call to stop discovery listener

      _discoveredDevices.clear();
    } catch (e) {
      // Ensure cleanup even if errors occur
      _isRunning = false;
      rethrow;
    }
  }

  /// Handles a discovered service
  ///
  /// Called internally when mDNS discovers a service matching _oreonchat._tcp
  ///
  /// [serviceName] - The advertised service name
  /// [address] - Resolved IP address
  /// [port] - Advertised port number
  void _onServiceDiscovered(String serviceName, String address, int port) {
    // Skip our own device
    if (serviceName == deviceName &&
        address == ipAddress &&
        port == this.port) {
      return;
    }

    // Create or update device entry
    final device = LanDevice(
      id: serviceName,
      name: serviceName,
      ipAddress: address,
      port: port,
    );

    // Check if we've already discovered this device
    final deviceKey = '${device.ipAddress}:${device.port}';
    if (_discoveredDevices.containsKey(deviceKey)) {
      return; // Already discovered, skip
    }

    // Cache the device
    _discoveredDevices[deviceKey] = device;

    // Emit the device discovery event
    if (!_discoveryController.isClosed) {
      _discoveryController.add(device);
    }
  }

  /// Disposes of resources
  ///
  /// Must be called when the service is no longer needed.
  Future<void> dispose() async {
    await stop();
    await _discoveryController.close();
  }

  /// Gets the current cached list of discovered devices
  List<LanDevice> get cachedDevices => _discoveredDevices.values.toList();

  /// Whether the discovery service is currently active
  bool get isRunning => _isRunning;
}
