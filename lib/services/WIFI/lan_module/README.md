## LAN Module - Complete Documentation

### Overview

A self-contained, production-ready Flutter module for LAN (Local Area Network) chat functionality. The module enables devices to discover each other and exchange messages without requiring internet connectivity.

**Key Features:**
- 🔍 mDNS-based device discovery (`_oreonchat._tcp` service type)
- 💬 TCP-based message transfer between devices
- 🔌 Complete separation of concerns (discovery, messaging, connection management)
- 🛡️ Platform-specific implementations for Android and iOS
- 📡 Stream-based API for reactive programming
- 🚀 Zero external UI dependencies (backend only)
- 💾 Self-contained with no app-level dependencies

### Architecture

```
lan_module/
├── lan_module.dart              # Public entry point (exports only)
├── lan_controller.dart          # Main public API class
├── models/
│   ├── lan_device.dart          # Device representation
│   └── lan_message.dart         # Message representation
├── discovery/
│   └── mdns_discovery.dart      # mDNS service discovery
├── connection/
│   ├── tcp_server.dart          # TCP server for incoming messages
│   └── tcp_client.dart          # TCP client for outgoing messages
├── platform/
│   ├── ANDROID_SETUP.md         # Android configuration guide
│   ├── IOS_SETUP.md             # iOS configuration guide
│   ├── android/
│   │   └── mdns_impl.dart       # Android platform channel interface
│   └── ios/
│       └── mdns_impl.dart       # iOS platform channel interface
└── PUBSPEC_DEPENDENCIES.yaml   # Required dependencies
```

### Public API

The module exposes a single class for external use:

```dart
class LanController {
  /// Starts the LAN controller (must be called first)
  Future<void> start();
  
  /// Stops the LAN controller (call when done)
  Future<void> stop();
  
  /// Stream of discovered devices
  Stream<LanDevice> get discoveredDevices;
  
  /// Stream of incoming messages
  Stream<LanMessage> get incomingMessages;
  
  /// Connect to a device (optional, establishes connection early)
  Future<void> connect(LanDevice device);
  
  /// Send a message to a device
  void sendMessage(LanDevice device, String message);
  
  /// Dispose resources
  Future<void> dispose();
}
```

### Quick Start

#### 1. Add Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  device_info_plus: ^10.1.0
  network_info_plus: ^5.0.0
  uuid: ^4.0.0
```

Run:
```bash
flutter pub get
```

#### 2. Android Configuration

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

Add to `android/app/build.gradle`:

```gradle
android {
    ...
    defaultConfig {
        ...
        minSdkVersion 21
    }
}
```

#### 3. iOS Configuration

Add to `ios/Runner/Info.plist`:

```xml
<key>NSBonjourServices</key>
<array>
  <string>_oreonchat._tcp</string>
</array>

<key>NSLocalNetworkUsageDescription</key>
<string>Oreon needs access to your local network to discover and communicate with nearby devices for LAN chat.</string>

<key>NSBonjourUsageDescription</key>
<string>Oreon uses Bonjour to discover nearby devices for chat.</string>
```

#### 4. Basic Usage

```dart
import 'package:polygone_app/lan_module/lan_module.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create controller
  final lanController = LanController();
  
  // Start the module
  await lanController.start();
  
  // Listen for discovered devices
  lanController.discoveredDevices.listen((device) {
    print('Found device: ${device.name} at ${device.ipAddress}:${device.port}');
  });
  
  // Listen for incoming messages
  lanController.incomingMessages.listen((message) {
    print('${message.senderName}: ${message.content}');
  });
  
  runApp(MyApp());
}
```

#### 5. Sending Messages

```dart
// Get a discovered device
final targetDevice = await lanController.discoveredDevices.first;

// Send a message
lanController.sendMessage(targetDevice, 'Hello from Oreon!');
```

#### 6. Cleanup

```dart
// When app closes or chat is no longer needed
await lanController.stop();
await lanController.dispose();
```

### Models

#### LanDevice

Represents a discovered device:

```dart
class LanDevice {
  final String id;                    // Unique identifier
  final String name;                  // Device name
  final String ipAddress;             // IP address
  final int port;                     // TCP port
  final DateTime discoveredAt;        // Discovery timestamp
  final bool isLocalDevice;           // Is this device local
}
```

#### LanMessage

Represents a received message:

```dart
class LanMessage {
  final String id;                    // Message ID
  final String senderName;            // Sender device name
  final String senderIp;              // Sender IP address
  final String content;               // Message text
  final DateTime timestamp;           // Message creation time
}
```

### Message Protocol

Messages are transmitted as JSON over TCP:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "senderName": "Device Name",
  "senderIp": "192.168.1.100",
  "content": "Message text",
  "timestamp": "2026-02-11T10:30:00.000Z"
}
```

Each message is followed by a newline `\n` character as a delimiter.

### Technical Details

#### Device Discovery

1. **mDNS Service Type**: `_oreonchat._tcp.local`
2. **Service Name**: Device name (e.g., "John's iPhone")
3. **Port**: 7531 (configurable)

The module advertises the local device and discovers other devices. The discovery service is always running when the controller is active.

#### Message Transfer

1. **TCP Server**: Listens on port 7531 for incoming messages
2. **TCP Client**: Establishes connections to other devices on port 7531
3. **Connection Caching**: Maintains open connections for faster message sending
4. **Timeout**: 5 seconds for connection establishment, 10 seconds for sending

#### Multicast Lock (Android)

On Android 7+, the module automatically:
- Acquires a multicast lock when mDNS starts
- Releases it when mDNS stops

This ensures reliable mDNS discovery on the local network.

### Error Handling

```dart
try {
  await lanController.start();
} on SocketException catch (e) {
  print('Network error: $e');
} on Exception catch (e) {
  print('Unexpected error: $e');
}

// Send messages with error handling
lanController.sendMessage(device, 'Hello').catchError((error) {
  print('Failed to send message: $error');
});
```

### Performance Considerations

- **Connection Pooling**: TCP connections are cached and reused
- **Multicast Lock**: Automatically managed on Android
- **Stream-based**: Use `.take()`, `.where()`, `.map()` for filtering
- **Resource Cleanup**: Always call `dispose()` when done

### Limitations

1. **No internet required**: Only works on local networks
2. **WiFi only**: Requires WiFi or hotspot connection
3. **No encryption**: Messages sent in plaintext (add SSL/TLS if needed)
4. **Same subnet**: Devices must be on the same local network
5. **TCP-based**: May require adjustment in enterprise networks with restrictions

### Troubleshooting

#### Devices Not Discovered

**Android:**
- Ensure CHANGE_WIFI_MULTICAST_STATE permission is granted
- Check that devices are on the same WiFi network
- Verify firewall allows local network traffic

**iOS:**
- Accept the local network privacy prompt
- Check NSBonjourServices in Info.plist
- Verify NSLocalNetworkUsageDescription is set

#### Messages Not Received

- Check TCP port 7531 is not blocked by firewall
- Ensure receiver is explicitly listening to `incomingMessages` stream
- Verify IP addresses for devices match network

#### Connection Hangs

- Increase timeout values if network is slow
- Check for network congestion
- Verify TCP port availability on both devices

### Advanced Usage

#### Custom Port

```dart
final controller = LanController(port: 8080);
```

#### Monitoring Connection State

```dart
controller.discoveredDevices.listen((device) {
  print('Active connections: ${controller.activeConnections}');
  print('Cached devices: ${controller.cachedDevices.length}');
});
```

#### Manual Connection Management

```dart
// Pre-connect to avoid latency on first message
await controller.connect(device);

// Send multiple messages
controller.sendMessage(device, 'Message 1');
controller.sendMessage(device, 'Message 2');
```

### Files Reference

| File | Purpose |
|------|---------|
| `lan_module.dart` | Public API exports |
| `lan_controller.dart` | Main controller class |
| `models/lan_device.dart` | Device model |
| `models/lan_message.dart` | Message model |
| `discovery/mdns_discovery.dart` | mDNS discovery service |
| `connection/tcp_server.dart` | TCP message server |
| `connection/tcp_client.dart` | TCP client for sending |
| `platform/android/mdns_impl.dart` | Android interface |
| `platform/ios/mdns_impl.dart` | iOS interface |

### Testing

Example test setup:

```dart
void main() {
  group('LAN Module Tests', () {
    late LanController controller;

    setUp(() {
      controller = LanController();
    });

    tearDown(() async {
      await controller.dispose();
    });

    test('Controller starts successfully', () async {
      await controller.start();
      expect(controller.isRunning, true);
    });

    test('Device discovery stream emits events', () async {
      await controller.start();
      
      expect(
        controller.discoveredDevices.first,
        isA<LanDevice>(),
      );

      await controller.stop();
    });
  });
}
```

### Version Information

- **Dart**: 3.0+
- **Flutter**: 3.0+
- **Android**: API 21+
- **iOS**: 12.0+

### License

This module is part of the Oreon application and follows the same license.

### Support

For issues or questions:
1. Check platform-specific setup guides
2. Review error messages and exceptions
3. Verify network configuration
4. Check device connectivity

---

**Last Updated**: February 11, 2026
