import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oreon/screens/home_page/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:oreon/const/const.dart';
import 'package:oreon/models/chat_model.dart';
import 'package:oreon/screens/chat_page/chat_detail_screen.dart';
import 'package:oreon/screens/chat_page/chat_screen.dart';
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
  late AnimationController _radarController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<DiscoveredDevice> _filteredContacts = [];
  final Map<String, double> _deviceDistances = {};
  final Random _random = Random();
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _wifiController = WiFiDirectController();
    _initializeController();
    
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _searchController.addListener(_onSearchChanged);
    
    // Listen to device changes with proper error handling
    _wifiController.nearbyDevices.addListener(_onDevicesChanged);
  }

  Future<void> _initializeController() async {
    try {
      await _wifiController.initialize();
      if (mounted && !_isDisposed) {
        _filterContacts();
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        _showSnackBar('Failed to initialize WiFi Direct: ${e.toString()}', isError: true);
      }
    }
  }

  void _onDevicesChanged() {
    if (!_isDisposed && mounted) {
      _filterContacts();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounce?.cancel();
    
    // Safely remove listeners
    try {
      _wifiController.nearbyDevices.removeListener(_onDevicesChanged);
    } catch (e) {
      // Listener might already be removed
    }
    
    _wifiController.dispose();
    _radarController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_isDisposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!_isDisposed) {
        _filterContacts();
      }
    });
  }

  void _startScanning() {
    if (_isDisposed) return;
    try {
      _radarController.repeat();
      _wifiController.startDiscovery();
    } catch (e) {
      _showSnackBar('Failed to start scanning: ${e.toString()}', isError: true);
    }
  }

  void _stopScanning({bool auto = false}) {
    if (_isDisposed) return;
    try {
      _radarController.stop();
      _radarController.reset();
      _wifiController.stopDiscovery();

      if (auto && mounted && !_isDisposed && _wifiController.nearbyDevices.value.isNotEmpty) {
        _showSnackBar('Scan finished • Found ${_wifiController.nearbyDevices.value.length} devices');
      }
    } catch (e) {
      _showSnackBar('Failed to stop scanning: ${e.toString()}', isError: true);
    }
  }

  void _filterContacts() {
    if (_isDisposed || !mounted) return;
    
    try {
      final query = _searchController.text.trim().toLowerCase();
      final allDevices = _wifiController.nearbyDevices.value;
      
      // Generate stable distances for each device
      for (final device in allDevices) {
        _deviceDistances.putIfAbsent(device.id, () => _random.nextDouble() * 100);
      }
      
      if (mounted && !_isDisposed) {
        setState(() {
          if (query.isEmpty) {
            _filteredContacts = List.from(allDevices);
          } else {
            _filteredContacts = allDevices
                .where((device) => device.name.toLowerCase().contains(query))
                .toList();
          }
        });
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        _showSnackBar('Error filtering contacts: ${e.toString()}', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted || _isDisposed) return;
    
    try {
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
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          backgroundColor: isError 
              ? Colors.red.withOpacity(0.9)
              : Colors.teal.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // Ignore snackbar errors if widget is disposed
    }
  }

  void _toggleScanning() {
    if (_isDisposed) return;
    try {
      HapticFeedback.mediumImpact();
      _wifiController.isScanning.value ? _stopScanning() : _startScanning();
    } catch (e) {
      _showSnackBar('Failed to toggle scanning: ${e.toString()}', isError: true);
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  IconData _getSignalIcon(String strength) {
    return switch (strength) {
      'strong' => Icons.wifi_rounded,
      'medium' => Icons.wifi_2_bar_rounded,
      _ => Icons.wifi_1_bar_rounded,
    };
  }

  Color _getSignalColor(String strength) {
    return switch (strength) {
      'strong' => const Color(0xFF4CAF50),
      'medium' => const Color(0xFFFFA726),
      _ => const Color(0xFFEF5350),
    };
  }

  String _getTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 10) return 'now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
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
          'Nearby',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 26,
            color: Colors.white,
          ),
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _wifiController.isScanning,
            builder: (context, isScanning, child) {
              return Row(
                children: [
                  if (isScanning)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(Colors.tealAccent.withOpacity(0.8)),
                        ),
                      ),
                    ),
                  // Add test devices button for debugging
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: Colors.orange.withOpacity(0.8),
                      size: 28,
                    ),
                    onPressed: () {
                      _wifiController.addTestDevices();
                      _showSnackBar('Added test devices for debugging', isError: false);
                    },
                    tooltip: 'Add Test Devices',
                  ),
                  // Debug mode toggle button
                  IconButton(
                    icon: Icon(
                      Icons.bug_report,
                      color: Colors.purple.withOpacity(0.8),
                      size: 26,
                    ),
                    onPressed: () {
                      _wifiController.toggleDebugMode();
                      _showSnackBar('Debug mode toggled - shows own device', isError: false);
                    },
                    tooltip: 'Toggle Debug Mode (Show Self)',
                  ),
                  IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Icon(
                        isScanning ? Icons.stop_circle_rounded : Icons.radar_rounded,
                        key: ValueKey(isScanning),
                        color: isScanning ? Colors.redAccent : Colors.tealAccent,
                        size: 32,
                      ),
                    ),
                    onPressed: _toggleScanning,
                    tooltip: isScanning ? 'Stop Scanning' : 'Start Scanning',
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
            await Future.delayed(const Duration(milliseconds: 500));
          }
          _startScanning();
        },
        color: Colors.tealAccent,
        backgroundColor: const Color(0xFF1A1D24),
        strokeWidth: 3,
        child: Stack(
          children: [
            const RepaintBoundary(child: _StaticBackgroundGlow()),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: _wifiController.isScanning,
                    builder: (context, isScanning, _) {
                      return _buildStatusCard(isScanning);
                    },
                  ),
                  if (_filteredContacts.isNotEmpty) _buildSearchBar(),
                  Expanded(
                    child: _filteredContacts.isEmpty 
                        ? ValueListenableBuilder<bool>(
                            valueListenable: _wifiController.isScanning,
                            builder: (context, isScanning, _) {
                              return _buildEmptyState(isScanning);
                            },
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
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isScanning ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(isScanning ? 0.15 : 0.08),
          width: 1.5,
        ),
        boxShadow: isScanning
            ? [
                BoxShadow(
                  color: Colors.tealAccent.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 0,
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(80, 80),
                  painter: RadarPainter(_radarController, isScanning),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isScanning ? Colors.tealAccent : Colors.grey[600],
                    shape: BoxShape.circle,
                    boxShadow: isScanning
                        ? [
                            BoxShadow(
                              color: Colors.tealAccent.withOpacity(0.6),
                              blurRadius: 12,
                              spreadRadius: 2,
                            )
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    isScanning
                        ? "Scanning..."
                        : "Ready",
                    key: ValueKey(isScanning),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ValueListenableBuilder<List<DiscoveredDevice>>(
                  valueListenable: _wifiController.nearbyDevices,
                  builder: (context, devices, _) {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        isScanning
                            ? "${devices.length} devices found"
                            : "WiFi Direct Ready",
                        key: ValueKey('$isScanning-${devices.length}'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 15,
                        ),
                      ),
                    );
                  },
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
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search by name...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.tealAccent.withOpacity(0.7)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Colors.white60),
                  onPressed: () {
                    _searchController.clear();
                    HapticFeedback.lightImpact();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.tealAccent.withOpacity(0.5), width: 2),
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
        final distance = _deviceDistances[device.id] ?? 0.0;
        final strength = distance < 15 ? 'strong' : distance < 40 ? 'medium' : 'weak';
        final timeAgo = _getTimeAgo(device.timestamp);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                
                // Add discovered device to chat list via provider
                final chatProvider = context.read<ChatListProvider>();
                final chat = Chat(
                  identifier: ConstApp().appIdentifier(),
                  id: device.id,
                  contactName: device.name.isEmpty ? 'Unknown Device' : device.name,
                  lastMessage: 'Start chatting via WiFi Direct',
                  timestamp: DateTime.now(),
                  unreadCount: 0,
                  connectionType: ConnectionType.wifi,
                  avatarText: device.name.isNotEmpty ? device.name[0].toUpperCase() : 'U',
                  avatarImageBytes: device.imageBytes,
                  deviceId: device.id,
                );
                
                chatProvider.addOrUpdateChat(chat);
                
                // Navigate to chat screen to see the new contact
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomeScreen(),
                  ),
                );
                
                _showSnackBar('Added ${chat.contactName} to chats!', isError: false);
              },
              splashColor: Colors.tealAccent.withOpacity(0.1),
              highlightColor: Colors.tealAccent.withOpacity(0.05),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.teal.withOpacity(0.3),
                        backgroundImage: device.imageBytes != null
                            ? MemoryImage(device.imageBytes!)
                            : null,
                        child: device.imageBytes == null
                            ? (device.name.isEmpty ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 30,
                              ) : Text(
                          device.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ))
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _getSignalColor(strength),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0D0F14),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _getSignalIcon(strength),
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    device.name.isEmpty ? 'Unknown Device' : device.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.tealAccent.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${_formatDistance(distance)} • WiFi Direct",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 28,
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
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Icon(
                isScanning
                    ? Icons.radar_rounded
                    : _searchController.text.trim().isEmpty
                        ? Icons.people_outline_rounded
                        : Icons.search_off_rounded,
                key: ValueKey('$isScanning-${_searchController.text}'),
                size: 100,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                isScanning
                    ? "Searching nearby..."
                    : _searchController.text.trim().isEmpty
                        ? "No contacts yet"
                        : "No matches found",
                key: ValueKey('$isScanning-${_searchController.text}'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                isScanning
                    ? "Stay in the area for best results"
                    : _searchController.text.trim().isEmpty
                        ? "Try searching for a different name"
                        : "No nearby devices match your search",
                key: ValueKey('desc-$isScanning-${_searchController.text}'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 15,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
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
    final maxRadius = size.width / 2 - 8;

    // Draw static rings
    final ringPaint = Paint()
      ..color = Colors.tealAccent.withOpacity(isScanning ? 0.15 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, maxRadius * 0.35, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.65, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.90, ringPaint);

    if (!isScanning) return;

    // Animated sweep
    final sweepPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.tealAccent.withOpacity(0.5),
          Colors.tealAccent.withOpacity(0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    final sweepPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: maxRadius),
        -1.57 + (animation.value * 6.28),
        1.2,
        false,
      )
      ..close();

    canvas.drawPath(sweepPath, sweepPaint);

    // Pulse effect
    final pulsePaint = Paint()
      ..color = Colors.tealAccent.withOpacity(0.3 * (1 - animation.value))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, maxRadius * 0.85 * animation.value, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return isScanning != oldDelegate.isScanning || 
           animation.value != oldDelegate.animation.value;
  }
}

class _StaticBackgroundGlow extends StatelessWidget {
  const _StaticBackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -200,
      left: -200,
      child: IgnorePointer(
        child: Container(
          width: 600,
          height: 600,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.teal.withOpacity(0.08),
                Colors.transparent,
              ],
              stops: const [0.0, 0.75],
            ),
          ),
        ),
      ),
    );
  }
}