import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:oreon/const/const.dart';
import 'package:oreon/models/chat_model.dart';
import 'package:oreon/providers/providers.dart';
import 'package:oreon/services/WIFI/lan_module/lan_controller.dart';
import 'package:oreon/services/WIFI/lan_module/models/lan_device.dart';
import 'package:oreon/models/device_wrapper.dart';

// ============================================================================
// Radar Painter
// ============================================================================
class RadarPainter extends CustomPainter {
  final AnimationController controller;
  final bool isScanning;

  RadarPainter(this.controller, this.isScanning);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.tealAccent.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw concentric circles
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(
        center,
        maxRadius * (i / 3),
        paint,
      );
    }

    // Draw scanning line if scanning
    if (isScanning) {
      final angle = controller.value * 2 * 3.14159;
      final endX = center.dx + maxRadius * 0.9 * math.cos(angle);
      final endY = center.dy + maxRadius * 0.9 * math.sin(angle);

      final scanPaint = Paint()
        ..color = Colors.tealAccent.withValues(alpha: 0.8)
        ..strokeWidth = 2;

      canvas.drawLine(center, Offset(endX, endY), scanPaint);

      // Draw glow effect
      final glowPaint = Paint()
        ..color = Colors.tealAccent.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(Offset(endX, endY), 4, glowPaint);
    }
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) =>
      oldDelegate.controller.value != controller.value ||
      oldDelegate.isScanning != isScanning;
}

// ============================================================================
// Main Screen
// ============================================================================
class StableNearbyContactsScreen extends StatefulWidget {
  const StableNearbyContactsScreen({super.key});

  @override
  State<StableNearbyContactsScreen> createState() =>
      _StableNearbyContactsScreenState();
}

class _StableNearbyContactsScreenState extends State<StableNearbyContactsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  Timer? _scanTimeout;
  Timer? _periodicRefreshTimer;
  Timer? _discoveryRefreshTimer;

  final List<DeviceWrapper> _lanDevices = [];
  final List<DeviceWrapper> _bluetoothDevices = [];
  List<DeviceWrapper> _filteredLanDevices = [];
  List<DeviceWrapper> _filteredBluetoothDevices = [];

  bool _isDisposed = false;
  bool _showOnlyAppContacts = false;
  bool _isScanning = false;
  StreamSubscription? _discoverySubscription;
  
  // Use singleton instance
  late final LanController lanController = LanController.instance;

  static const Duration _scanDuration = Duration(seconds: 25);
  static const Duration _discoveryRefreshInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _searchController.addListener(_onSearchChanged);
    _initializeController();
  }

  Future<void> _initializeController() async {
    try {
      // Check if already running
      if (lanController.isRunning) {
        debugPrint('✅ LAN Controller already running');
        if (mounted && !_isDisposed) {
          _subscribeToDiscovery();
        }
        return;
      }

      await lanController.start();

      if (mounted && !_isDisposed) {
        _subscribeToDiscovery();
        _loadInitialDevices();
        _filterContacts();
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        _showSnackBar('Failed to initialize LAN Controller: $e', isError: true);
      }
    }
  }

  void _subscribeToDiscovery() {
    // Cancel existing subscription
    _discoverySubscription?.cancel();
    
    // Listen to discovered devices stream
    _discoverySubscription = lanController.discoveredDevices.listen(
      (device) {
        _onDeviceDiscovered(device);
      },
      onError: (error) {
        if (mounted && !_isDisposed) {
          _showSnackBar('Discovery error: $error', isError: true);
        }
      },
      onDone: () {
        if (mounted && !_isDisposed) {
          debugPrint('📪 Discovery stream closed');
        }
      },
    );
  }

  Future<void> _loadInitialDevices() async {
    try {
      // Attempt to load any cached devices from controller
      if (mounted && !_isDisposed) {
        _filterContacts();
      }
    } catch (e) {
      debugPrint('Error loading initial devices: $e');
    }
  }

  void _onDeviceDiscovered(LanDevice device) {
    if (mounted && !_isDisposed) {
      _safeSetState(() {
        // Check if device already exists
        final existingIndex = _lanDevices.indexWhere((d) => d.id == device.id);

        if (existingIndex >= 0) {
          // Update existing device
          _lanDevices[existingIndex] = DeviceWrapper.fromLan(device);
        } else {
          // Add new device
          _lanDevices.add(DeviceWrapper.fromLan(device));
        }

        _filterContacts();
      });
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted && !_isDisposed) {
      setState(fn);
    }
  }

  Future<void> _closeDiscoveryChannel() async {
    try {
      debugPrint('🔌 Closing discovery channel...');
      
      // Cancel discovery subscription
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;
      
      debugPrint('✅ Discovery channel closed successfully');
    } catch (e) {
      debugPrint('❌ Error closing discovery channel: $e');
    }
  }

  Future<void> _cleanupScanResources() async {
    try {
      debugPrint('🧹 Cleaning up scan resources...');
      
      // Cancel all timers
      _scanTimeout?.cancel();
      _scanTimeout = null;
      
      _discoveryRefreshTimer?.cancel();
      _discoveryRefreshTimer = null;
      
      _periodicRefreshTimer?.cancel();
      _periodicRefreshTimer = null;
      
      // Close discovery channel
      await _closeDiscoveryChannel();
      
      debugPrint('✅ Scan resources cleaned up');
    } catch (e) {
      debugPrint('❌ Error cleaning up scan resources: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounce?.cancel();
    _scanTimeout?.cancel();
    _periodicRefreshTimer?.cancel();
    _discoveryRefreshTimer?.cancel();
    _discoverySubscription?.cancel();
    // Don't stop/dispose singleton - keep it running for other screens
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
      debugPrint('📡 Starting scan...');
      _radarController.repeat();
      _safeSetState(() {
        _isScanning = true;
      });

      _scanTimeout?.cancel();
      _scanTimeout = Timer(_scanDuration, () {
        if (mounted && !_isDisposed && _isScanning) {
          debugPrint('⏱️ Scan timeout reached');
          _stopScanning(auto: true);
        }
      });

      // Refresh discovery periodically during scan
      _discoveryRefreshTimer?.cancel();
      _discoveryRefreshTimer =
          Timer.periodic(_discoveryRefreshInterval, (_) {
        if (mounted && !_isDisposed && _isScanning) {
          _refreshDiscovery();
        }
      });

      _periodicRefreshTimer?.cancel();
      _periodicRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
        if (mounted && !_isDisposed && _isScanning) {
          _filterContacts();
        }
      });

      debugPrint('✅ Scan started successfully');
    } catch (e) {
      _showSnackBar('Failed to start scanning: $e', isError: true);
    }
  }

  Future<void> _refreshDiscovery() async {
    try {
      // Trigger device discovery refresh
      await lanController.start();
    } catch (e) {
      debugPrint('Error refreshing discovery: $e');
    }
  }

  void _stopScanning({bool auto = false}) {
    if (_isDisposed) return;

    debugPrint('🛑 Stopping scan${auto ? ' (auto)' : ''}...');

    try {
      _radarController.stop();
      _radarController.reset();

      _safeSetState(() {
        _isScanning = false;
      });

      // Clean up resources
      unawaited(_cleanupScanResources());

      if (auto && mounted && !_isDisposed) {
        final total = _lanDevices.length + _bluetoothDevices.length;
        if (total > 0) {
          _showSnackBar('Scan finished • Found $total devices');
        } else {
          _showSnackBar('Scan finished • No devices found');
        }
      }

      debugPrint('✅ Scan stopped successfully');
    } catch (e) {
      debugPrint('❌ Error stopping scan: $e');
      _showSnackBar('Failed to stop scanning: $e', isError: true);
    }
  }

  void _filterContacts() {
    if (_isDisposed || !mounted) return;

    final query = _searchController.text.trim().toLowerCase();

    _safeSetState(() {
      var lanResults = _lanDevices;
      var btResults = _bluetoothDevices;

      if (_showOnlyAppContacts) {
        lanResults = lanResults.where((d) => d.isFromApp).toList();
        btResults = btResults.where((d) => d.isFromApp).toList();
      }

      if (query.isNotEmpty) {
        lanResults = lanResults
            .where((d) => d.name.toLowerCase().contains(query))
            .toList();
        btResults = btResults
            .where((d) => d.name.toLowerCase().contains(query))
            .toList();
      }

      _filteredLanDevices = lanResults;
      _filteredBluetoothDevices = btResults;
    });
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
        backgroundColor: isError
            ? Colors.red.withValues(alpha: 0.9)
            : Colors.teal.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleScanning() {
    HapticFeedback.mediumImpact();

    if (_isScanning) {
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

      // Stop scanning when opening chat
      if (_isScanning) {
        _stopScanning();
      }

      final chatProvider = context.read<ChatListProvider>();
      
      // Create chat with lanController properly attached
      final chat = Chat(
        identifier: device.appIdentifier,
        id: device.id,
        contactName: device.name.isEmpty ? 'Unknown' : device.name,
        lastMessage: device.isBluetooth
            ? 'Bluetooth connection'
            : 'WiFi Direct connection',
        timestamp: DateTime.now(),
        unreadCount: 0,
        connectionType: device.isBluetooth
            ? ConnectionType.bluetooth
            : ConnectionType.wifi,
        avatarText:
            device.name.isNotEmpty ? device.name[0].toUpperCase() : 'U',
        avatarImageBytes: device.imageBytes,
        deviceId: device.id,
        deviceWrapper: device,
      );

      chatProvider.addOrUpdateChat(chat);

      Navigator.pushNamed(
        context,
        'clan',
        arguments: chat,
      );

      _showSnackBar('Added ${chat.contactName} to chats');
    } catch (e) {
      _showSnackBar('Error adding contact: $e', isError: true);
      debugPrint('Error adding contact: $e');
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
          style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 26, color: Colors.white),
        ),
        actions: [
          Row(
            children: [
              if (_isScanning)
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
                  color: _showOnlyAppContacts
                      ? Colors.tealAccent
                      : Colors.white70,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _safeSetState(() {
                    _showOnlyAppContacts = !_showOnlyAppContacts;
                  });
                  _filterContacts();
                },
                tooltip: _showOnlyAppContacts
                    ? 'Showing app contacts only'
                    : 'Show all contacts',
              ),
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _isScanning
                        ? Icons.stop_circle_rounded
                        : Icons.radar_rounded,
                    key: ValueKey(_isScanning),
                    color:
                        _isScanning ? Colors.redAccent : Colors.tealAccent,
                    size: 32,
                  ),
                ),
                onPressed: _toggleScanning,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_isScanning) {
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
                  _buildSearchBar(),
                  _buildStatusCard(_isScanning),
                  Expanded(
                    child: _buildDevicesTabs(),
                  ),
                ],
              ),
            ),
          ],
        ),
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
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.6)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.6)),
                  onPressed: () {
                    _searchController.clear();
                    _filterContacts();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.tealAccent, width: 1.5),
          ),
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
                    color:
                        isScanning ? Colors.tealAccent : Colors.grey[700],
                    shape: BoxShape.circle,
                    boxShadow: isScanning
                        ? [
                            BoxShadow(
                                color: Colors.tealAccent
                                    .withValues(alpha: 0.5),
                                blurRadius: 12)
                          ]
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
                      ? "${_filteredLanDevices.length + _filteredBluetoothDevices.length} device${(_filteredLanDevices.length + _filteredBluetoothDevices.length) == 1 ? '' : 's'} found"
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

  Widget _buildDevicesTabs() {
    final totalDevices =
        _filteredLanDevices.length + _filteredBluetoothDevices.length;

    if (totalDevices == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isScanning
                    ? Icons.radar_rounded
                    : Icons.people_outline_rounded,
                size: 90,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              const SizedBox(height: 28),
              Text(
                _isScanning ? "Scanning nearby..." : "No devices found",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _isScanning
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

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi),
                    const SizedBox(width: 8),
                    Text('WiFi (${_filteredLanDevices.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bluetooth),
                    const SizedBox(width: 8),
                    Text('Bluetooth (${_filteredBluetoothDevices.length})'),
                  ],
                ),
              ),
            ],
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.tealAccent,
            dividerColor: Colors.white.withValues(alpha: 0.1),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildLanDevicesList(),
                _buildBluetoothDevicesList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanDevicesList() {
    if (_filteredLanDevices.isEmpty) {
      return Center(
        child: Text(
          'No WiFi devices found',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredLanDevices.length,
      itemBuilder: (context, index) {
        final device = _filteredLanDevices[index];
        return _buildDeviceCard(device);
      },
    );
  }

  Widget _buildBluetoothDevicesList() {
    if (_filteredBluetoothDevices.isEmpty) {
      return Center(
        child: Text(
          'No Bluetooth devices found',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredBluetoothDevices.length,
      itemBuilder: (context, index) {
        final device = _filteredBluetoothDevices[index];
        return _buildDeviceCard(device);
      },
    );
  }

  Widget _buildDeviceCard(DeviceWrapper device) {
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
                    backgroundImage: device.imageBytes != null
                        ? MemoryImage(device.imageBytes!)
                        : null,
                    child: device.imageBytes == null
                        ? Text(
                            device.name.isNotEmpty
                                ? device.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 22, color: Colors.white),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: device.isBluetooth
                            ? ConstApp.Bluetooth
                            : ConstApp.Wifi,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF0D0F14), width: 2.2),
                      ),
                      child: Icon(
                        device.isBluetooth
                            ? Icons.bluetooth
                            : Icons.wifi,
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
                      device.name.isEmpty
                          ? 'Unknown Device'
                          : device.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (device.isFromApp)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            Colors.tealAccent.withValues(alpha: 0.2),
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
                      color: device.isBluetooth
                          ? Colors.blue[300]
                          : Colors.tealAccent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '• ${device.isBluetooth ? "Bluetooth" : "WiFi Direct"}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13.5),
                    ),
                    const Spacer(),
                    Text(
                      _getTimeAgo(device.timestamp),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticBackgroundGlow extends StatelessWidget {
  const _StaticBackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -150,
      right: -150,
      child: Container(
        width: 500,
        height: 500,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.tealAccent.withValues(alpha: 0.15),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}