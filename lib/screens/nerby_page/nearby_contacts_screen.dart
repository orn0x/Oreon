import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:oreon/screens/chat_page/chat_detail_screen_wifi.dart';
import 'package:oreon/screens/chat_page/chat_detail_screen_blue.dart';
import 'package:oreon/services/Bluetooth/bluetooth_service.dart';
import 'package:oreon/models/bluetooth_device.dart';
import 'package:provider/provider.dart';
import 'package:oreon/const/const.dart';
import 'package:oreon/models/chat_model.dart';
import 'package:oreon/services/WIFI_Direct/wdirect_service.dart';
import 'package:oreon/providers/providers.dart';

class StableNearbyContactsScreen extends StatefulWidget {
  const StableNearbyContactsScreen({super.key});

  @override
  State<StableNearbyContactsScreen> createState() => _StableNearbyContactsScreenState();
}

class _StableNearbyContactsScreenState extends State<StableNearbyContactsScreen>
    with SingleTickerProviderStateMixin {
  late WiFiDirectController _wifiController;
  late BluetoothService _bluetoothService;
  late AnimationController _radarController;
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  Timer? _scanTimeout;
  Timer? _periodicRefreshTimer;

  List<DeviceWrapper> _filteredContacts = [];

  bool _isDisposed = false;
  bool _showOnlyAppContacts = false;
  StreamSubscription? _bluetoothSubscription;

  static const Duration _scanDuration = Duration(seconds: 25);

  @override
  void initState() {
    super.initState();
    _wifiController = WiFiDirectController();
    _bluetoothService = BluetoothService();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _searchController.addListener(_onSearchChanged);
    _wifiController.nearbyDevices.addListener(_onDevicesChanged);

    _bluetoothSubscription = _bluetoothService.onDeviceFound.listen((_) {
      _onDevicesChanged();
    });

    _initializeController();
  }

  Future<void> _initializeController() async {
    try {
      await _wifiController.initialize();
      if (mounted && !_isDisposed) {
        _filterContacts();
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        _showSnackBar('Failed to initialize WiFi Direct: $e', isError: true);
      }
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted && !_isDisposed) {
      setState(fn);
    }
  }

  void _onDevicesChanged() {
    _filterContacts();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounce?.cancel();
    _scanTimeout?.cancel();
    _periodicRefreshTimer?.cancel();
    _bluetoothSubscription?.cancel();
    _wifiController.nearbyDevices.removeListener(_onDevicesChanged);
    _wifiController.dispose();
    _bluetoothService.dispose();
    _radarController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _filterContacts();
    });
  }

  void _startScanning() {
    if (_isDisposed) return;

    try {
      _radarController.repeat();
      _wifiController.startDiscovery();
      _bluetoothService.startDiscovery();

      _scanTimeout?.cancel();
      _scanTimeout = Timer(_scanDuration, () {
        if (mounted && !_isDisposed && _wifiController.isScanning.value) {
          _stopScanning(auto: true);
        }
      });

      // Optional: periodic refresh while scanning
      _periodicRefreshTimer?.cancel();
      _periodicRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
        if (mounted && !_isDisposed && _wifiController.isScanning.value) {
          _filterContacts();
        }
      });
    } catch (e) {
      _showSnackBar('Failed to start scanning: $e', isError: true);
    }
  }

  void _stopScanning({bool auto = false}) {
    if (_isDisposed) return;

    _scanTimeout?.cancel();
    _periodicRefreshTimer?.cancel();

    try {
      _radarController.stop();
      _radarController.reset();
      _wifiController.stopDiscovery();
      _bluetoothService.cancelDiscovery();

      if (auto && mounted && !_isDisposed) {
        final wifiCount = _wifiController.nearbyDevices.value.length;
        final btCount = _bluetoothService.discoveredDevices.length;
        final total = wifiCount + btCount;
        if (total > 0) {
          _showSnackBar('Scan finished • Found $total devices');
        }
      }
    } catch (e) {
      _showSnackBar('Failed to stop scanning: $e', isError: true);
    }
  }

  void _filterContacts() {
    if (_isDisposed || !mounted) return;

    try {
      final query = _searchController.text.trim().toLowerCase();

      final combined = <DeviceWrapper>[];

      // WiFi Direct devices
      for (final device in _wifiController.nearbyDevices.value) {
          combined.add(DeviceWrapper.fromWifi(device));
      }

      // Bluetooth devices
      for (final device in _bluetoothService.discoveredDevices) {
          combined.add(DeviceWrapper.fromBluetooth(device));
      }

      // Remove duplicates & assign stable distance
      final seen = <String>{};
      final uniqueDevices = <DeviceWrapper>[];

      for (final device in combined) {
        if (seen.add(device.id)) {
          uniqueDevices.add(device);
          // Stable distance — generate only once
        }
      }

      _safeSetState(() {
        var results = uniqueDevices;
        
        // Apply app filter if enabled
        if (_showOnlyAppContacts) {
          results = results.where((d) => d.isFromApp).toList();
        }
        
        // Apply search filter
        if (query.isNotEmpty) {
          results = results
              .where((d) => d.name.toLowerCase().contains(query))
              .toList();
        }
        
        _filteredContacts = results;
      });
    } catch (e) {
      _showSnackBar('Error filtering devices: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted || _isDisposed) return;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 15))),
          ],
        ),
        backgroundColor: isError ? Colors.red.withValues(alpha: 0.9) : Colors.teal.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleScanning() {
    HapticFeedback.mediumImpact();

    if (_wifiController.isScanning.value) {
      _stopScanning();
    } else {
      _startScanning();
    }
  }

  String _getTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 15) return 'now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void _addContactToChat(DeviceWrapper device) {
    try {
      HapticFeedback.lightImpact();

      final chatProvider = context.read<ChatListProvider>();
      final chat = Chat(
        identifier: device.appIdentifier,
        id: device.id,
        contactName: device.name.isEmpty ? 'Unknown' : device.name,
        lastMessage: device.isBluetooth
            ? 'Bluetooth connection'
            : 'WiFi Direct connection',
        timestamp: DateTime.now(),
        unreadCount: 0,
        connectionType:
            device.isBluetooth ? ConnectionType.bluetooth : ConnectionType.wifi,
        avatarText: device.name.isNotEmpty ? device.name[0].toUpperCase() : 'U',
        avatarImageBytes: device.imageBytes,
        deviceId: device.id,
      );

      chatProvider.addOrUpdateChat(chat);

      // Navigate to appropriate chat detail screen based on connection type
      final detailScreen = device.isBluetooth
          ? ChatDetailScreenBlue(chat: chat)
          : ChatDetailScreenWifi(chat: chat);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => detailScreen),
      );

      _showSnackBar('Added ${chat.contactName} to chats');
    } catch (e) {
      _showSnackBar('Error adding contact: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Nearby Devices',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 26, color: Colors.white),
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _wifiController.isScanning,
            builder: (context, isScanning, _) {
              return Row(
                children: [
                  if (isScanning)
                    const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(Colors.tealAccent),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.filter_list_rounded,
                      color: _showOnlyAppContacts ? Colors.tealAccent : Colors.white70,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _safeSetState(() {
                        _showOnlyAppContacts = !_showOnlyAppContacts;
                      });
                      _filterContacts();
                    },
                    tooltip: _showOnlyAppContacts ? 'Showing app contacts only' : 'Show all contacts',
                  ),
                  IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        isScanning ? Icons.stop_circle_rounded : Icons.radar_rounded,
                        key: ValueKey(isScanning),
                        color: isScanning ? Colors.redAccent : Colors.tealAccent,
                        size: 32,
                      ),
                    ),
                    onPressed: _toggleScanning,
                  ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_wifiController.isScanning.value) {
            _stopScanning();
            await Future.delayed(const Duration(milliseconds: 600));
          }
          _startScanning();
        },
        color: Colors.tealAccent,
        backgroundColor: const Color(0xFF1A1D24),
        child: Stack(
          children: [
            const _StaticBackgroundGlow(),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: _wifiController.isScanning,
                    builder: (context, isScanning, _) => _buildStatusCard(isScanning),
                  ),
                  if (_filteredContacts.isNotEmpty) _buildSearchBar(),
                  Expanded(
                    child: _filteredContacts.isEmpty
                        ? ValueListenableBuilder<bool>(
                            valueListenable: _wifiController.isScanning,
                            builder: (context, isScanning, _) =>
                                _buildEmptyState(isScanning),
                          )
                        : _buildContactList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isScanning) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isScanning ? 0.07 : 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(72, 72),
                  painter: RadarPainter(_radarController, isScanning),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isScanning ? Colors.tealAccent : Colors.grey[700],
                    shape: BoxShape.circle,
                    boxShadow: isScanning
                        ? [BoxShadow(color: Colors.tealAccent.withValues(alpha: 0.5), blurRadius: 12)]
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isScanning ? "Scanning..." : "Ready",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isScanning
                      ? "${_filteredContacts.length} device${_filteredContacts.length == 1 ? '' : 's'} found"
                      : "Waiting for nearby devices",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search devices...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.tealAccent.withValues(alpha: 0.8)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                    HapticFeedback.lightImpact();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildContactList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredContacts.length,
      itemBuilder: (context, index) {
        final device = _filteredContacts[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _addContactToChat(device),
              splashColor: Colors.teal.withValues(alpha: 0.15),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: device.isBluetooth
                            ? Colors.blue.withValues(alpha: 0.35)
                            : Colors.teal.withValues(alpha: 0.35),
                        backgroundImage:
                            device.imageBytes != null ? MemoryImage(device.imageBytes!) : null,
                        child: device.imageBytes == null
                            ? Text(
                                device.name.isNotEmpty ? device.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 22, color: Colors.white),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: device.isBluetooth ? ConstApp.Bluetooth : ConstApp.Wifi,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0D0F14), width: 2.2),
                          ),
                          child: Icon(
                            device.isBluetooth ? Icons.bluetooth : Icons.wifi,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          device.name.isEmpty ? 'Unknown Device' : device.name,
                          style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (device.isFromApp)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.tealAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'App',
                            style: TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      children: [
                        Icon(
                          device.isBluetooth ? Icons.bluetooth : Icons.wifi,
                          size: 15,
                          color: device.isBluetooth ? Colors.blue[300] : Colors.tealAccent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '• ${device.isBluetooth ? "Bluetooth" : "WiFi Direct"}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13.5),
                        ),
                        const Spacer(),
                        Text(
                          _getTimeAgo(device.timestamp),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isScanning) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isScanning ? Icons.radar_rounded : Icons.people_outline_rounded,
              size: 90,
              color: Colors.white.withValues(alpha: 0.18),
            ),
            const SizedBox(height: 28),
            Text(
              isScanning ? "Scanning nearby..." : "No devices found",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isScanning
                  ? "Keep the screen on and stay in range"
                  : "Pull down to refresh or enable scanning",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class DeviceWrapper {
  final String appIdentifier;
  final String id;
  final String name;
  final DateTime timestamp;
  final Uint8List? imageBytes;
  final bool isBluetooth;
  final bool isFromApp;

  DeviceWrapper({
    required this.appIdentifier,
    required this.id,
    required this.name,
    required this.timestamp,
    this.imageBytes,
    required this.isBluetooth,
    required this.isFromApp,
  });

  factory DeviceWrapper.fromWifi(DiscoveredDevice device) {
    final currentAppId = device.appIdentifier; // Use the device's app identifier for WiFi Direct
    return DeviceWrapper(
      appIdentifier: currentAppId,
      id: device.id,
      name: device.name.isEmpty ? 'Unknown' : device.name,
      timestamp: device.timestamp,
      imageBytes: device.imageBytes,
      isBluetooth: false,
      isFromApp: device.appIdentifier == currentAppId,
    );
  }

  factory DeviceWrapper.fromBluetooth(BluetoothDeviceModel device) {
    final currentAppId = device.appIdentifier; // Use the device's app identifier for Bluetooth
    return DeviceWrapper(
      appIdentifier: currentAppId,
      id: device.address,
      name: device.name.isNotEmpty ? device.name : 'Unknown',
      timestamp: DateTime.now(),
      imageBytes: null,
      isBluetooth: true,
      isFromApp: device.appIdentifier == currentAppId,
    );
  }
}

class RadarPainter extends CustomPainter {
  final Animation<double> animation;
  final bool isScanning;

  RadarPainter(this.animation, this.isScanning) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 6;

    final ringPaint = Paint()
      ..color = Colors.tealAccent.withValues(alpha: isScanning ? 0.18 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawCircle(center, maxRadius * 0.3, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.6, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.9, ringPaint);

    if (!isScanning) return;

    final sweepPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.tealAccent.withValues(alpha: 0.55), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    final sweepPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: maxRadius),
        -1.57 + (animation.value * 6.28),
        1.4,
        false,
      )
      ..close();

    canvas.drawPath(sweepPath, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) =>
      isScanning != oldDelegate.isScanning || animation.value != oldDelegate.animation.value;
}

class _StaticBackgroundGlow extends StatelessWidget {
  const _StaticBackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -180,
      left: -180,
      child: IgnorePointer(
        child: Container(
          width: 560,
          height: 560,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Colors.teal.withValues(alpha: 0.09), Colors.transparent],
              stops: const [0.0, 0.7],
            ),
          ),
        ),
      ),
    );
  }
}