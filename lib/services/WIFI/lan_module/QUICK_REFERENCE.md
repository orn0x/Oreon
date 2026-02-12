## LAN Module - Quick Reference Card

### Basic Usage

```dart
import 'package:polygone_app/lan_module/lan_module.dart';

// 1. Create and start
final controller = LanController();
await controller.start();

// 2. Listen for devices
controller.discoveredDevices.listen((device) {
  print('Found: ${device.name} at ${device.ipAddress}');
});

// 3. Listen for messages
controller.incomingMessages.listen((msg) {
  print('${msg.senderName}: ${msg.content}');
});

// 4. Send messages
controller.sendMessage(device, 'Hello!');

// 5. Cleanup
await controller.stop();
```

### Models

```dart
// Device Model
class LanDevice {
  final String id;
  final String name;
  final String ipAddress;
  final int port;          // Always: 7531
  final DateTime discoveredAt;
  final bool isLocalDevice;
}

// Message Model
class LanMessage {
  final String id;         // UUID
  final String senderName;
  final String senderIp;
  final String content;
  final DateTime timestamp;
}
```

### API Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `start()` | `Future<void>` | Initialize and activate |
| `stop()` | `Future<void>` | Deactivate gracefully |
| `dispose()` | `Future<void>` | Clean up resources |
| `connect(device)` | `Future<void>` | Pre-connect to device |
| `sendMessage(device, msg)` | `void` | Send message (fire & forget) |

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `discoveredDevices` | `Stream<LanDevice>` | New devices found |
| `incomingMessages` | `Stream<LanMessage>` | Received messages |
| `isRunning` | `bool` | Is active |
| `deviceName` | `String` | This device's name |
| `localIpAddress` | `String` | This device's IP |
| `cachedDevices` | `List<LanDevice>` | Known devices |

### Configuration

```dart
// Custom port (default: 7531)
final controller = LanController(port: 8080);

// Service type (always)
_oreonchat._tcp

// TCP timeout
5 seconds (connection)
10 seconds (sending)
```

### Error Handling

```dart
try {
  await controller.start();
} on SocketException {
  // Network error
} on Exception {
  // Other error
}

// Stream error handling
controller.incomingMessages.listen(
  (msg) => print(msg),
  onError: (error) => print('Error: $error'),
);
```

### Common Patterns

#### Get First Device
```dart
final device = await controller.discoveredDevices.first;
controller.sendMessage(device, 'Hi!');
```

#### Filter Messages
```dart
controller.incomingMessages
  .where((msg) => msg.senderName == 'Device Name')
  .listen((msg) => print(msg.content));
```

#### Broadcast Message
```dart
for (final device in controller.cachedDevices) {
  controller.sendMessage(device, 'Hello all!');
}
```

#### Wait for Device
```dart
final device = await controller.discoveredDevices
  .firstWhere((d) => d.name.contains('iPhone'));
```

#### Take Limit
```dart
controller.incomingMessages
  .take(10)
  .listen((msg) => print(msg));
```

### Android Permissions

Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### iOS Configuration

Add to `Info.plist`:
```xml
<key>NSBonjourServices</key>
<array><string>_oreonchat._tcp</string></array>

<key>NSLocalNetworkUsageDescription</key>
<string>LAN chat needs local network access</string>
```

### Dependencies

```yaml
dependencies:
  device_info_plus: ^10.1.0
  network_info_plus: ^5.0.0
  uuid: ^4.0.0
```

### Troubleshooting

| Problem | Check |
|---------|-------|
| No devices found | Same WiFi? Firewall? Permissions? |
| Messages not sent | Device online? Port 7531 open? |
| Crash on start | Dependencies installed? Permissions? |
| iOS privacy error | NSBonjourServices in Info.plist? |

### Example Integration

```dart
class ChatScreen extends StatefulWidget {
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late LanController _lan;

  @override
  void initState() {
    super.initState();
    _lan = LanController();
    _lan.start();
  }

  @override
  void dispose() {
    _lan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          StreamBuilder<LanDevice>(
            stream: _lan.discoveredDevices,
            builder: (context, snapshot) {
              return Text('Devices: ${snapshot.data?.name}');
            },
          ),
          StreamBuilder<LanMessage>(
            stream: _lan.incomingMessages,
            builder: (context, snapshot) {
              return Text('Message: ${snapshot.data?.content}');
            },
          ),
        ],
      ),
    );
  }
}
```

### Service Pattern

```dart
class LanService {
  static final LanService _instance = LanService._internal();
  factory LanService() => _instance;
  LanService._internal();

  final LanController _controller = LanController();

  Future<void> init() => _controller.start();

  Stream<LanDevice> get devices => _controller.discoveredDevices;
  Stream<LanMessage> get messages => _controller.incomingMessages;

  void send(LanDevice device, String msg) =>
      _controller.sendMessage(device, msg);
}

// Usage
final service = LanService();
await service.init();
service.devices.listen(print);
service.send(device, 'Hello');
```

### Testing

```dart
test('send message', () async {
  final controller = LanController();
  await controller.start();
  
  final device = LanDevice(
    id: 'test',
    name: 'Test',
    ipAddress: '192.168.1.1',
    port: 7531,
  );
  
  expect(
    () => controller.sendMessage(device, 'test'),
    returnsNormally,
  );
  
  await controller.dispose();
});
```

### Performance Tips

- Cache discovered devices
- Clear old messages periodically
- Use `.take()` to limit stream items
- Pre-connect with `.connect()` before sending many messages
- Call `dispose()` when done

### Security Reminders

⚠️ **Note**: Current implementation has NO encryption.

For production:
1. Add TLS/SSL
2. Add authentication
3. Implement rate limiting
4. Validate message format
5. Encrypt sensitive data

### API Contract

**Entry Point**: `lan_module.dart`
**Main Class**: `LanController`
**Service Type**: `_oreonchat._tcp.local`
**Default Port**: `7531`
**Message Protocol**: JSON + newline

### Files Overview

| File | Purpose |
|------|---------|
| `lan_module.dart` | Exports |
| `lan_controller.dart` | Main API |
| `models/lan_device.dart` | Device |
| `models/lan_message.dart` | Message |
| `discovery/mdns_discovery.dart` | Discovery |
| `connection/tcp_server.dart` | Receive |
| `connection/tcp_client.dart` | Send |

### Constants

```dart
const serviceType = '_oreonchat._tcp';
const defaultPort = 7531;
const connectionTimeout = Duration(seconds: 5);
const sendTimeout = Duration(seconds: 10);
```

### Lifecycle

```
   ┌─────────────┐
   │   Created   │
   └──────┬──────┘
          │
    ┌─────▼──────┐
    │ start()    │
    └─────┬──────┘
          │
    ┌─────▼──────────────────┐
    │ Running & Discovering  │
    │   - discoveredDevices  │
    │   - incomingMessages   │
    │   - sendMessage()      │
    └─────┬──────────────────┘
          │
    ┌─────▼──────┐
    │ stop()     │
    └─────┬──────┘
          │
    ┌─────▼──────┐
    │ dispose()  │
    └─────┬──────┘
          │
    ┌─────▼─────────┐
    │   Cleaned Up   │
    └────────────────┘
```

### Quick Checklist

- [ ] Added dependencies to pubspec.yaml
- [ ] Added Android permissions
- [ ] Added iOS Info.plist entries
- [ ] Created LanController
- [ ] Called `start()`
- [ ] Subscribe to streams
- [ ] Call `stop()` on cleanup
- [ ] Call `dispose()` on final cleanup

---

**For detailed info, see**: README.md, INTEGRATION_GUIDE.md
