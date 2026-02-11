## LAN Module Integration Guide

This guide explains how to integrate the LAN module into your Oreon app.

### Step 1: Install Dependencies

Add these packages to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Existing dependencies...
  
  # LAN Module Dependencies
  device_info_plus: ^10.1.0
  network_info_plus: ^5.0.0
  uuid: ^4.0.0
```

Run:
```bash
flutter pub get
```

### Step 2: Android Configuration

#### 2.1 Update AndroidManifest.xml

Edit `android/app/src/main/AndroidManifest.xml` and add permissions:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Optional: For Android 12+ -->
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" />
```

#### 2.2 Enable Cleartext Traffic (if needed)

In `android/app/build.gradle`, ensure `minSdkVersion` is at least 21:

```groovy
android {
    ...
    defaultConfig {
        minSdkVersion 21
        ...
    }
}
```

#### 2.3 Add Kotlin Implementation

Copy the file `android/app/src/main/kotlin/com/oreon/polygone_app/MdnsNativeImpl.kt` 
(already created in the module).

#### 2.4 Update MainActivity

Edit `android/app/src/main/kotlin/com/oreon/polygone_app/MainActivity.kt`:

```kotlin
package com.oreon.polygone_app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    companion object {
        var flutterEngineRef: FlutterEngine? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Store reference for mDNS callbacks
        flutterEngineRef = flutterEngine
        
        // Initialize mDNS implementation
        val mdnsImpl = MdnsNativeImpl(this, flutterEngine)
        mdnsImpl.setupChannel()
    }
}
```

### Step 3: iOS Configuration

#### 3.1 Update Info.plist

Edit `ios/Runner/Info.plist` and add:

```xml
<key>NSBonjourServices</key>
<array>
  <string>_oreonchat._tcp</string>
</array>

<key>NSLocalNetworkUsageDescription</key>
<string>Oreon needs access to your local network to discover and communicate with nearby devices for LAN chat.</string>

<key>NSBonjourUsageDescription</key>
<string>Oreon uses Bonjour to discover nearby devices for chat on your local network.</string>
```

#### 3.2 Add Swift Implementation

Copy the file `ios/Runner/MdnsNativeImpl.swift` (already created in the module).

#### 3.3 Setup Method Channel

Edit `ios/Runner/GeneratedPluginRegistrant.swift` or your app delegate to initialize the channel:

```swift
import UIKit
import Flutter

@UIApplicationMain
@objc class GeneratedPluginRegistrant: NSObject {
    // ... existing code ...
}

// Add to your view controller or app delegate
override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let mdnsImpl = MdnsNativeImpl()
    mdnsImpl.setupChannel(controller: controller)
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

### Step 4: Application Integration

#### Option 1: Direct Usage (Simple)

In your main.dart:

```dart
import 'package:polygone_app/lan_module/lan_module.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final lanController = LanController();
  await lanController.start();
  
  runApp(MyApp(lanController: lanController));
}

class MyApp extends StatelessWidget {
  final LanController lanController;
  
  const MyApp({required this.lanController});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ChatScreen(lanController: lanController),
    );
  }
}
```

#### Option 2: Service/Provider Pattern (Recommended)

Create a service provider wrapper:

```dart
// lib/services/lan_chat_service.dart
import 'package:polygone_app/lan_module/lan_module.dart';

class LanChatService {
  static final LanChatService _instance = LanChatService._internal();
  
  factory LanChatService() => _instance;
  
  LanChatService._internal();
  
  late LanController _controller;
  
  Future<void> initialize() async {
    _controller = LanController();
    await _controller.start();
  }
  
  Stream<LanDevice> get discoveredDevices => _controller.discoveredDevices;
  Stream<LanMessage> get incomingMessages => _controller.incomingMessages;
  
  void sendMessage(LanDevice device, String message) {
    _controller.sendMessage(device, message);
  }
  
  Future<void> dispose() async {
    await _controller.dispose();
  }
}
```

Then in your widget:

```dart
class ChatScreen extends StatefulWidget {
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late LanChatService _lanService;
  
  @override
  void initState() {
    super.initState();
    _lanService = LanChatService();
    _lanService.initialize();
  }
  
  @override
  void dispose() {
    _lanService.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<LanMessage>(
        stream: _lanService.incomingMessages,
        builder: (context, snapshot) {
          // Build UI with messages
        },
      ),
    );
  }
}
```

#### Option 3: State Management Integration (Advanced)

For use with GetIt, Provider, or Riverpod:

```dart
// Using GetIt
import 'get_it/get_it.dart';

void setupServiceLocator() {
  final lanService = LanChatService();
  lanService.initialize();
  getIt.registerSingleton(lanService);
}

// In your widget
class ChatScreen extends StatelessWidget {
  final _lanService = getIt<LanChatService>();
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _lanService.discoveredDevices,
      builder: (context, snapshot) {
        // Build UI
      },
    );
  }
}
```

### Step 5: Permission Handling

#### Android Runtime Permissions

Add permission handling for Android 6.0+:

```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestLanPermissions() async {
  final statuses = await [
    Permission.internet,
    Permission.changeWifiMulticast,
  ].request();
  
  return statuses.values.every((status) => status.isGranted);
}
```

### Step 6: Testing

Create a simple test to verify the module works:

```dart
// test/lan_module_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:polygone_app/lan_module/lan_module.dart';

void main() {
  group('LAN Module', () {
    late LanController controller;
    
    setUp(() {
      controller = LanController();
    });
    
    tearDown(() async {
      await controller.dispose();
    });
    
    test('Controller initializes', () async {
      await controller.start();
      expect(controller.isRunning, true);
    });
    
    test('Can send message without errors', () async {
      await controller.start();
      
      final device = LanDevice(
        id: 'test',
        name: 'Test Device',
        ipAddress: '192.168.1.100',
        port: 7531,
      );
      
      expect(
        () => controller.sendMessage(device, 'Test'),
        returnsNormally,
      );
    });
  });
}
```

### Step 7: Error Handling and Logging

Add error handling in your integration:

```dart
void initializeLan() async {
  try {
    final controller = LanController();
    await controller.start();
    
    controller.discoveredDevices.listen(
      (device) {
        print('Device found: ${device.name}');
      },
      onError: (error) {
        print('Discovery error: $error');
      },
    );
    
    controller.incomingMessages.listen(
      (message) {
        print('Message received: ${message.content}');
      },
      onError: (error) {
        print('Message error: $error');
      },
    );
  } catch (e) {
    print('LAN init failed: $e');
  }
}
```

### Step 8: Debugging

Enable verbose logging:

```dart
// Add to main.dart
import 'dart:developer' as developer;

void initializeLan() async {
  developer.Service.getInfo().then((serverInfo) {
    print('Dart VM Service: ${serverInfo.serverUri}');
  });
  
  // Proceed with initialization
  // ...
}
```

### Troubleshooting During Integration

#### Issue: Permissions Not Granted

**Solution**: Check that you've added all required permissions to AndroidManifest.xml and Info.plist.

#### Issue: Devices Not Discovered

**Solution**: 
1. Ensure all devices are on the same WiFi network
2. Check firewall settings
3. Verify device has granted local network permission

#### Issue: Messages Not Sending

**Solution**:
1. Check that target device is discoverable
2. Verify TCP port 7531 is open
3. Ensure devices have network connectivity

#### Issue: App Crashes on Start

**Solution**:
1. Check that `await controller.start()` is called
2. Verify all dependencies are installed
3. Check that platform code is properly integrated

### Best Practices

1. **Initialize Early**: Call `initialize()` in `main()` or startup screen
2. **Handle Errors**: Always add error handlers to streams
3. **Clean Up**: Always call `dispose()` in your cleanup handler
4. **Use Services**: Wrap in service/provider for cleaner integration
5. **Test Network**: Test on real devices, not just simulators
6. **Handle Offline**: Always assume network might fail
7. **Cache Devices**: Store discovered devices in local state
8. **Limit Messages**: Clear message history periodically

### Performance Tips

1. **Use `.take()`** to limit stream items
2. **Use `.where()`** to filter messages
3. **Cache connections** with `pre\-connection
4. **Clear history** periodically
5. **Use null safety** features

### Security Considerations

⚠️ **Current Implementation**:
- Messages sent as plaintext
- No authentication
- No encryption

**For Production**:
1. Add TLS/SSL for TCP connections
2. Implement device authentication
3. Add message signing
4. Implement rate limiting

---

**Last Updated**: February 11, 2026
