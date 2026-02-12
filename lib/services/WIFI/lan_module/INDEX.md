## LAN Module - Documentation Index

Welcome to the Oreon LAN Chat Module! This self-contained Flutter module provides complete LAN-based device discovery and messaging without internet dependency.

### 📚 Documentation Guide

Start here based on your needs:

#### 👤 I Just Want to Use It
1. **Quick Start** → [QUICK_REFERENCE.md](QUICK_REFERENCE.md) (5 min read)
2. **Basic Usage** → [examples/basic_example.dart](examples/basic_example.dart)
3. **Integration** → [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) (Step 1 only)

#### 🏗️ I'm Integrating Into Oreon
1. **Overview** → This file
2. **Integration Guide** → [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) (All steps)
3. **Platform Setup** → [platform/ANDROID_SETUP.md](platform/ANDROID_SETUP.md) or [platform/IOS_SETUP.md](platform/IOS_SETUP.md)
4. **Example Pattern** → [examples/backend_service_example.dart](examples/backend_service_example.dart)

#### 🔧 I'm a Developer Maintaining This
1. **Complete Docs** → [README.md](README.md)
2. **API Reference** → See inline comments in source files
3. **Implementation Details** → See [lan_controller.dart](lan_controller.dart) and connection modules
4. **Architecture** → See folder structure below

#### 🧪 I Want to Test It
1. **Test Examples** → [examples/](examples/)
2. **Setup Instructions** → [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)
3. **Troubleshooting** → [README.md](README.md#troubleshooting)

#### 📦 I'm Packaging This
1. **Delivery Summary** → [DELIVERY_SUMMARY.md](DELIVERY_SUMMARY.md)
2. **File Manifest** → See folder structure
3. **Dependencies** → [PUBSPEC_DEPENDENCIES.yaml](PUBSPEC_DEPENDENCIES.yaml)

---

### 📁 Module Structure

```
lan_module/
│
├── 📋 DOCUMENTATION
│   ├── README.md                    # Complete reference (30 min)
│   ├── QUICK_REFERENCE.md          # Quick API reference (5 min)
│   ├── INTEGRATION_GUIDE.md        # Implementation steps (15 min)
│   ├── DELIVERY_SUMMARY.md         # Project summary
│   └── INDEX.md                    # This file
│
├── 📦 CORE MODULES
│   ├── lan_module.dart             # Public API exports
│   └── lan_controller.dart         # Main public API class
│
├── 🗂️ MODELS
│   ├── lan_device.dart             # Device representation
│   └── lan_message.dart            # Message representation
│
├── 🔍 DISCOVERY
│   └── discovery/
│       └── mdns_discovery.dart     # mDNS service discovery
│
├── 💬 MESSAGING
│   └── connection/
│       ├── tcp_server.dart         # Incoming message server
│       └── tcp_client.dart         # Outgoing message client
│
├── 🛠️ PLATFORM IMPLEMENTATIONS
│   └── platform/
│       ├── ANDROID_SETUP.md
│       ├── IOS_SETUP.md
│       ├── android/
│       │   └── mdns_impl.dart      # Android platform interface
│       └── ios/
│           └── mdns_impl.dart      # iOS platform interface
│
└── 💡 EXAMPLES
    ├── examples/
    │   ├── basic_example.dart      # Simple UI example
    │   ├── advanced_example.dart   # Advanced UI with state management
    │   └── backend_service_example.dart  # No-UI service pattern
    │
    └── platform/ (native code)
        ├── android/.../.../MdnsNativeImpl.kt    # Android implementation
        └── ios/.../MdnsNativeImpl.swift         # iOS implementation
```

---

### 🚀 5-Minute Quick Start

```dart
// 1. Import
import 'package:polygone_app/lan_module/lan_module.dart';

// 2. Create & Start
final lan = LanController();
await lan.start();

// 3. Listen for Devices
lan.discoveredDevices.listen((device) {
  print('Found: ${device.name}');
});

// 4. Listen for Messages
lan.incomingMessages.listen((msg) {
  print('${msg.senderName}: ${msg.content}');
});

// 5. Send a Message
lan.sendMessage(device, 'Hello!');

// 6. Cleanup
await lan.disposal();
```

---

### 📖 Documentation by Topic

#### Getting Started
- [Quick Reference](QUICK_REFERENCE.md) - API cheat sheet
- [Basic Example](examples/basic_example.dart) - Working code

#### Integration
- [Integration Guide](INTEGRATION_GUIDE.md) - Step-by-step
- [Android Setup](platform/ANDROID_SETUP.md) - Android specifics
- [iOS Setup](platform/IOS_SETUP.md) - iOS specifics

#### Advanced Usage
- [README.md](README.md) - Complete reference
- [Advanced Example](examples/advanced_example.dart) - UI with state management
- [Backend Service Example](examples/backend_service_example.dart) - No-UI pattern

#### Development
- [Source Code](lan_controller.dart) - Main API implementation
- [Models](models/) - Data structures
- [Services](discovery/, connection/) - Implementation details

---

### 🎯 Common Tasks

#### How do I...

**Send a message?**
```dart
lan.sendMessage(device, 'Your message');
```
→ See [QUICK_REFERENCE.md](QUICK_REFERENCE.md#basic-usage)

**Listen for messages?**
```dart
lan.incomingMessages.listen((msg) => print(msg));
```
→ See [README.md](README.md#api)

**Get discovered devices?**
```dart
lan.discoveredDevices.listen((device) => print(device));
```
→ See [examples/basic_example.dart](examples/basic_example.dart)

**Filter messages from a specific device?**
```dart
lan.incomingMessages
  .where((msg) => msg.senderIp == '192.168.1.100');
```
→ See [QUICK_REFERENCE.md](QUICK_REFERENCE.md#common-patterns)

**Integrate with my app?**
→ See [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)

**Set up Android?**
→ See [platform/ANDROID_SETUP.md](platform/ANDROID_SETUP.md)

**Set up iOS?**
→ See [platform/IOS_SETUP.md](platform/IOS_SETUP.md)

**Implement without UI (backend)?**
→ See [examples/backend_service_example.dart](examples/backend_service_example.dart)

---

### 📊 Module Overview

| Aspect | Details |
|--------|---------|
| **Purpose** | LAN chat without internet |
| **Discovery** | mDNS (_oreonchat._tcp) |
| **Messaging** | TCP on port 7531 |
| **Platforms** | Android (API 21+), iOS (12.0+) |
| **Dependencies** | device_info_plus, network_info_plus, uuid |
| **API Level** | Single public class (LanController) |
| **Async** | Stream-based, fully async |

---

### ✅ Implementation Checklist

#### Code Level
- [ ] Review module structure
- [ ] Understand data models (LanDevice, LanMessage)
- [ ] Know the public API (LanController)

#### Integration Level
- [ ] Add dependencies to pubspec.yaml
- [ ] Configure Android (permissions, native code)
- [ ] Configure iOS (Info.plist, native code)
- [ ] Initialize in your app
- [ ] Handle streams (devices and messages)
- [ ] Add error handling

#### Testing Level
- [ ] Test on Android device
- [ ] Test on iOS device
- [ ] Test device discovery
- [ ] Test message sending
- [ ] Test offline scenarios

#### Deployment Level
- [ ] Review performance
- [ ] Add security if needed
- [ ] Prepare release builds
- [ ] Document for team

---

### 🔗 Quick Links

| Document | Purpose | Read Time |
|----------|---------|-----------|
| [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | API cheat sheet | 5 min |
| [README.md](README.md) | Complete reference | 30 min |
| [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) | Implementation guide | 20 min |
| [DELIVERY_SUMMARY.md](DELIVERY_SUMMARY.md) | Project summary | 10 min |
| [examples/](examples/) | Working examples | varies |

---

### 💡 Key Concepts

#### Device Discovery
- Automatic via mDNS broadcast
- Devices emit presence every few seconds
- Real-time stream updates
- Works only on same WiFi network

#### Message Transfer
- TCP socket connections
- Connection pooling (reuse connections)
- JSON protocol with newline delimiters
- Fire-and-forget sending (no acknowledgment)

#### Architecture
- Single public class (LanController)
- Modular internal structure
- Separate discovery and messaging
- Platform-specific implementations exist separately

#### Streams
- Reactive programming model
- Filter, map, limit operations supported
- Error handling via onError callback
- Auto-cleanup via subscription management

---

### 🚨 Important Notes

⚠️ **No Internet Required**: Works purely on local network
⚠️ **No Encryption**: Messages sent in plaintext (add TLS for production)
⚠️ **Same Network**: Devices must be on same WiFi network
⚠️ **Permissions**: Android and iOS require explicit permissions

---

### 🤝 Support & Troubleshooting

#### Module not working?
1. Check [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)
2. Review platform setup ([Android](platform/ANDROID_SETUP.md), [iOS](platform/IOS_SETUP.md))
3. See [README.md](README.md#troubleshooting)

#### Need help using the API?
1. See [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
2. Check [examples/](examples/)
3. Read [README.md](README.md#api)

#### Want to understand internals?
1. Read source code comments
2. Review [lan_controller.dart](lan_controller.dart)
3. Check [discovery/](discovery/) and [connection/](connection/)

---

### 📝 File Manifest

**Core Dart Files (11)**:
- lan_module.dart
- lan_controller.dart
- models/lan_device.dart
- models/lan_message.dart
- discovery/mdns_discovery.dart
- connection/tcp_server.dart
- connection/tcp_client.dart
- platform/android/mdns_impl.dart
- platform/ios/mdns_impl.dart
- examples/basic_example.dart (+ 2 more)

**Native Code (2)**:
- android/app/src/main/kotlin/com/oreon/polygone_app/MdnsNativeImpl.kt
- ios/Runner/MdnsNativeImpl.swift

**Documentation (6)**:
- README.md
- QUICK_REFERENCE.md
- INTEGRATION_GUIDE.md
- DELIVERY_SUMMARY.md
- platform/ANDROID_SETUP.md
- platform/IOS_SETUP.md
- INDEX.md (this file)

**Configuration (1)**:
- PUBSPEC_DEPENDENCIES.yaml

---

### 🎓 Learning Path

**For New Users:**
1. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - 5 minutes
2. [examples/basic_example.dart](examples/basic_example.dart) - 10 minutes
3. [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) - Steps 1-2

**For Developers:**
1. [README.md](README.md) - Full reference
2. Source code - All modules
3. [examples/advanced_example.dart](examples/advanced_example.dart) - Patterns

**For Architects:**
1. [DELIVERY_SUMMARY.md](DELIVERY_SUMMARY.md) - Overview
2. Module structure - Folder organization
3. [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) - Technical requirements

---

### 📅 Version Info

- **Dart**: 3.0+
- **Flutter**: 3.0+
- **Android**: API 21+ (multicast lock support)
- **iOS**: 12.0+ (Bonjour support)

---

### 🎉 You're Ready!

You have a complete, production-ready LAN chat module. Choose your path:

→ **Just use it**: [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
→ **Integrate it**: [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)  
→ **Understand it**: [README.md](README.md)
→ **Deploy it**: [DELIVERY_SUMMARY.md](DELIVERY_SUMMARY.md)

---

*Last Updated: February 11, 2026*
