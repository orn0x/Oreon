import 'package:flutter/material.dart';
import 'dart:ui'; // For ImageFilter
import '../../main.dart'; // Import to access global 'prefs'

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _bluetoothEnabled;
  late bool _wifiEnabled;
  late bool _notificationsEnabled;
  late bool _autoConnect;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _bluetoothEnabled = prefs.getBool('bluetooth_enabled') ?? true;
      _wifiEnabled = prefs.getBool('wifi_enabled') ?? true;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _autoConnect = prefs.getBool('auto_connect') ?? false;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          const RepaintBoundary(child: _StaticBackgroundGlow()),

          SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 40),
              children: [
                // Profile Section (non-interactive, no ripple needed)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.teal.withOpacity(0.3),
                        child: const Text(
                          'U',
                          style: TextStyle(
                            fontSize: 48,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'User Name',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'Edit Profile',
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                _buildSectionHeader('Connection Settings'),
                _buildSwitchTile(
                  title: 'Bluetooth',
                  subtitle: 'Enable Bluetooth mesh connectivity',
                  icon: Icons.bluetooth,
                  value: _bluetoothEnabled,
                  onChanged: (value) {
                    setState(() => _bluetoothEnabled = value);
                    _savePreference('bluetooth_enabled', value);
                  },
                ),
                _buildSwitchTile(
                  title: 'WiFi Direct',
                  subtitle: 'Enable local WiFi peer-to-peer connections',
                  icon: Icons.wifi,
                  value: _wifiEnabled,
                  onChanged: (value) {
                    setState(() => _wifiEnabled = value);
                    _savePreference('wifi_enabled', value);
                  },
                ),
                _buildSwitchTile(
                  title: 'Auto-Connect',
                  subtitle: 'Automatically join known nearby networks',
                  icon: Icons.sync,
                  value: _autoConnect,
                  onChanged: (value) {
                    setState(() => _autoConnect = value);
                    _savePreference('auto_connect', value);
                  },
                ),

                _buildSectionDivider(),

                _buildSectionHeader('Notifications'),
                _buildSwitchTile(
                  title: 'Push Notifications',
                  subtitle: 'Receive alerts for messages and connections',
                  icon: Icons.notifications_outlined,
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    _savePreference('notifications_enabled', value);
                  },
                ),

                _buildSectionDivider(),

                _buildSectionHeader('Privacy & Security'),
                _buildNavigationTile(
                  title: 'Privacy Policy',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () {},
                ),
                _buildNavigationTile(
                  title: 'Security Settings',
                  icon: Icons.shield_outlined,
                  onTap: () {},
                ),

                _buildSectionDivider(),

                _buildSectionHeader('About'),
                _buildNavigationTile(
                  title: 'About Oreon',
                  iconWidget: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 36,
                        height: 36,
                        color: Colors.teal.withOpacity(0.4),
                        child: const Icon(Icons.chat, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  onTap: _showAboutDialog,
                ),
                _buildNavigationTile(
                  title: 'Help & Support',
                  icon: Icons.help_outline,
                  onTap: () {},
                ),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white38),
                      const SizedBox(width: 16),
                      const Text(
                        'Version',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const Spacer(),
                      Text(
                        '1.0.0 • December 2025',
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.tealAccent.withOpacity(0.9),
        ),
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        height: 1,
        thickness: 0.5,
        indent: 16,
        endIndent: 16,
        color: Colors.white.withOpacity(0.08),
      ),
    );
  }

  // Updated Switch Tile with rounded ripple
  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.hardEdge, // Clips ripple to rounded shape
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            secondary: Icon(icon, color: Colors.tealAccent.withOpacity(0.8), size: 28),
            title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
            value: value,
            onChanged: onChanged,
            activeColor: Colors.tealAccent,
            activeTrackColor: Colors.tealAccent.withOpacity(0.3),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            hoverColor: Colors.transparent,
            // Ripple is now clipped by parent Material
          ),
        ),
      ),
    );
  }

  // Updated Navigation Tile with rounded ripple
  Widget _buildNavigationTile({
    required String title,
    required VoidCallback onTap,
    IconData? icon,
    Widget? iconWidget,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.hardEdge, // Ensures ripple follows rounded corners
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: iconWidget ??
                Icon(icon, color: Colors.white70, size: 28),
            title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: onTap,
            hoverColor: Colors.transparent,
            splashColor: Colors.tealAccent.withOpacity(0.2),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              color: Colors.teal.withOpacity(0.4),
                              child: const Icon(Icons.chat, color: Colors.white, size: 32),
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        const Text(
                          'About Oreon',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Oreon is a privacy-first, multi-protocol messaging app designed for seamless communication — online or offline.\n\n'
                      'Supports:\n'
                      '• Bluetooth Mesh Networks\n'
                      '• WiFi Direct & Local LAN\n'
                      '• Centralized Servers\n'
                      '• Decentralized P2P\n\n'
                      'Built for resilience. Focused on privacy.\n'
                      'Always connected.',
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.7,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Version 1.0.0 • December 2025',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.tealAccent.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.tealAccent.withOpacity(0.4)),
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
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
      left: -150,
      child: Container(
        width: 500,
        height: 500,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.teal.withOpacity(0.1),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}