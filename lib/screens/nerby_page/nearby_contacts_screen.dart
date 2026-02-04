import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for HapticFeedback (Android vibration)
import 'package:oreon/screens/chat_page/chat_screen.dart';
// Adjust import path to your ChatScreen
// ignore: depend_on_referenced_packages
import 'package:web_socket_channel/web_socket_channel.dart';

class StableNearbyContactsScreen extends StatefulWidget {
  const StableNearbyContactsScreen({super.key});

  @override
  State<StableNearbyContactsScreen> createState() => _StableNearbyContactsScreenState();
}

class _StableNearbyContactsScreenState extends State<StableNearbyContactsScreen>
    with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  bool _isConnecting = false;
  List<Map<String, dynamic>> _nearbyContacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];

  late AnimationController _radarController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  static const String _wsUrl = 'ws://192.168.1.103:8080/ws/nearby';

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 6;
  static const Duration _baseReconnectDelay = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _stopScanning();
    _radarController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _filterContacts);
  }

  void _startScanning() {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _nearbyContacts.clear();
      _filteredContacts.clear();
      _reconnectAttempts = 0;
    });

    _radarController.repeat();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    if (_channel != null) return;

    setState(() => _isConnecting = true);

    try {
      final uri = Uri.parse(_wsUrl);
      // ─── This is the recommended way ───
      _channel = WebSocketChannel.connect(uri);

      // Send start command to your Kotlin backend
      _channel!.sink.add(jsonEncode({
        "action": "start_scan",
        "userId": "android_user_${DateTime.now().millisecondsSinceEpoch}",
        "durationSeconds": 45,
      }));

      _subscription = _channel!.stream.listen(
        (dynamic rawMessage) {
          if (!mounted) return;

          String text;
          if (rawMessage is String) {
            text = rawMessage;
          } else if (rawMessage is List<int>) {
            text = utf8.decode(rawMessage);
          } else {
            debugPrint("Unsupported message type: ${rawMessage.runtimeType}");
            return;
          }

          try {
            final decoded = jsonDecode(text) as Map<String, dynamic>;

            switch (decoded['type']) {
              case 'user_found':
                final user = decoded['data'] as Map<String, dynamic>?;
                if (user == null) return;

                final distance = (user['distanceMeters'] as num?)?.toDouble() ?? 9999.0;

                setState(() {
                  if (!_nearbyContacts.any((c) => c['id'] == user['id'])) {
                    _nearbyContacts.add({
                      'id': user['id'],
                      'name': user['name'] ?? 'Unknown',
                      'dist': _formatDistance(distance),
                      'rawDistance': distance,
                      'type': user['connectionType'] ?? 'WiFi',
                      'strength': _getStrengthFromDistance(distance),
                      'avatarUrl': user['avatarUrl'],
                      'timestamp': DateTime.now(),
                    });
                    _sortContacts();
                    _filteredContacts = List.from(_nearbyContacts);
                  }
                });

                // Optional: vibrate on very close contact (Android)
                if (distance < 20) {
                  HapticFeedback.lightImpact();
                }
                break;

              case 'scan_complete':
                _stopScanning(auto: true);
                break;

              case 'error':
                final msg = decoded['message'] as String? ?? 'Scan error';
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                }
                _stopScanning();
                break;
            }
          } catch (e, st) {
            debugPrint("Parse error: $e\n$st");
          }
        },
        onError: (error) {
          debugPrint("WebSocket error: $error");
          _handleDisconnect();
        },
        onDone: () {
          debugPrint("WebSocket closed");
          _handleDisconnect();
        },
      );

      setState(() => _isConnecting = false);
    } catch (e) {
      debugPrint("Connect failed: $e");
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    setState(() => _isConnecting = false);

    if (_isScanning && _reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final multiplier = (1 << (_reconnectAttempts - 1)).clamp(1, 8);
      final delay = _baseReconnectDelay * multiplier;

      debugPrint("Reconnect attempt #$_reconnectAttempts in ${delay.inSeconds}s");

      _reconnectTimer = Timer(delay, () {
        if (mounted && _isScanning) {
          _connectWebSocket();
        }
      });
    } else if (_isScanning) {
      _stopScanning();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection lost. Tap radar to retry.')),
        );
      }
    }
  }

  void _stopScanning({bool auto = false}) {
    if (!_isScanning) return;

    _subscription?.cancel();
    _channel?.sink.add(jsonEncode({"action": "stop_scan"}));
    _channel?.sink.close();
    _channel = null;
    _reconnectTimer?.cancel();

    _radarController.stop();

    if (mounted) {
      setState(() {
        _isScanning = false;
        _isConnecting = false;
      });

      if (auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Scan finished'),
            backgroundColor: Colors.teal.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _toggleScanning() => _isScanning ? _stopScanning() : _startScanning();

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _getStrengthFromDistance(double distance) {
    if (distance < 15) return 'strong';
    if (distance < 40) return 'medium';
    return 'weak';
  }

  void _sortContacts() {
    _nearbyContacts.sort((a, b) {
      final da = a['rawDistance'] as double? ?? 9999.0;
      final db = b['rawDistance'] as double? ?? 9999.0;
      return da.compareTo(db);
    });
  }

  void _filterContacts() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredContacts = query.isEmpty
          ? List.from(_nearbyContacts)
          : _nearbyContacts
              .where((c) => (c['name'] as String).toLowerCase().contains(query))
              .toList();
    });
  }

  IconData _getSignalIcon(String strength) {
    return switch (strength) {
      'strong' => Icons.wifi_rounded,
      'medium' => Icons.wifi_2_bar_rounded,
      _ => Icons.wifi_off_rounded,
    };
  }

  Color _getSignalColor(String strength) {
    return switch (strength) {
      'strong' => Colors.greenAccent,
      'medium' => Colors.orangeAccent,
      _ => Colors.redAccent,
    };
  }

  String _getTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Nearby', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 26)),
        actions: [
          if (_isConnecting)
            const Padding(
              padding: EdgeInsets.only(right: 20),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.8, valueColor: AlwaysStoppedAnimation(Colors.tealAccent)),
              ),
            ),
          IconButton(
            icon: Icon(
              _isScanning ? Icons.stop_circle_rounded : Icons.radar_rounded,
              color: _isScanning ? Colors.redAccent : Colors.tealAccent,
              size: 36,
            ),
            onPressed: _toggleScanning,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_isScanning) {
            _stopScanning();
            await Future.delayed(const Duration(milliseconds: 500));
          }
          _startScanning();
        },
        color: Colors.tealAccent,
        backgroundColor: Colors.black87,
        child: Stack(
          children: [
            const _StaticBackgroundGlow(),
            SafeArea(
              child: Column(
                children: [
                  _buildStatusCard(),
                  _buildSearchBar(),
                  Expanded(
                    child: _filteredContacts.isEmpty ? _buildEmptyState() : _buildContactList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(_isScanning ? 0.11 : 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.13)),
        boxShadow: _isScanning
            ? [BoxShadow(color: Colors.tealAccent.withOpacity(0.28), blurRadius: 28, spreadRadius: 2)]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CustomPaint(
              painter: RadarPainter(_radarController, _isScanning),
              child: Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _isScanning ? Colors.tealAccent : Colors.grey[600],
                    shape: BoxShape.circle,
                    boxShadow: _isScanning
                        ? [BoxShadow(color: Colors.tealAccent.withOpacity(0.8), blurRadius: 16)]
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isScanning
                      ? "Scanning..."
                      : _isConnecting
                          ? "Connecting..."
                          : "Paused",
                  style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  _isScanning
                      ? "Discovering nearby Oreon users"
                      : _isConnecting
                          ? "Trying to reconnect..."
                          : "Tap radar to start discovery",
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15),
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
          hintText: 'Search names...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white60),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildContactList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _filteredContacts.length,
      itemBuilder: (context, index) {
        final contact = _filteredContacts[index];
        final avatarUrl = contact['avatarUrl'] as String?;
        final timeAgo = _getTimeAgo(contact['timestamp'] as DateTime);

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          color: Colors.white.withOpacity(0.06),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            leading: CircleAvatar(
              radius: 34,
              backgroundColor: Colors.teal.withOpacity(0.3),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      (contact['name'] as String)[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            title: Text(
              contact['name'] as String,
              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    _getSignalIcon(contact['strength'] as String),
                    size: 20,
                    color: _getSignalColor(contact['strength'] as String),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${contact['dist']} • ${contact['type']}",
                    style: TextStyle(color: Colors.tealAccent.withOpacity(0.9), fontSize: 15),
                  ),
                  const Spacer(),
                  Text(
                    timeAgo,
                    style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
                  ),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 30),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatsScreen(
                    userId: contact['id'] as String,
                    avatarUrl: avatarUrl,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isScanning ? Icons.radar_rounded : Icons.location_disabled_rounded,
              size: 120,
              color: Colors.white.withOpacity(0.15),
            ),
            const SizedBox(height: 32),
            Text(
              _isScanning
                  ? "Looking for nearby users..."
                  : _isConnecting
                      ? "Connecting..."
                      : _searchController.text.trim().isEmpty
                          ? "No one nearby"
                          : "No matches",
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _isScanning
                  ? "Stay in the area for best results"
                  : _isConnecting
                      ? "Retrying connection..."
                      : _searchController.text.trim().isEmpty
                          ? "Pull down or tap radar to scan"
                          : "Try a different name",
              style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 16, height: 1.4),
              textAlign: TextAlign.center,
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
    if (!isScanning) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 12;

    final ringPaint = Paint()
      ..color = Colors.tealAccent.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawCircle(center, maxRadius * 0.3, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.65, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.92, ringPaint);

    final sweepPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.tealAccent.withOpacity(0.6), Colors.transparent],
        stops: const [0.0, 0.75],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5;

    canvas.drawCircle(center, maxRadius * animation.value, sweepPaint);

    final fadePaint = Paint()
      ..color = Colors.tealAccent.withOpacity(0.4 - animation.value * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawCircle(center, maxRadius * 0.88 * animation.value, fadePaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter old) => isScanning || animation.value != old.animation.value;
}

class _StaticBackgroundGlow extends StatelessWidget {
  const _StaticBackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -220,
      left: -220,
      child: Container(
        width: 700,
        height: 700,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Colors.teal.withOpacity(0.08), Colors.transparent],
            stops: const [0.0, 0.8],
          ),
        ),
      ),
    );
  }
}