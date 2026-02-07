import 'package:flutter/material.dart';
import 'package:oreon/main.dart';
import 'package:oreon/providers/providers.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadUserData();
      context.read<SettingsProvider>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

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
              physics: const BouncingScrollPhysics(),
              children: [
                // Profile Section
                _ProfileCard(userProvider: userProvider),
                const SizedBox(height: 32),

                // Connection Settings
                _buildSectionHeader('Connection Settings'),
                _buildSwitchTile(
                  title: 'Bluetooth',
                  subtitle: 'Enable Bluetooth mesh connectivity',
                  icon: Icons.bluetooth,
                  value: settingsProvider.bluetoothEnabled,
                  onChanged: settingsProvider.toggleBluetooth,
                ),
                _buildSwitchTile(
                  title: 'WiFi Direct',
                  subtitle: 'Enable local WiFi peer-to-peer connections',
                  icon: Icons.wifi,
                  value: settingsProvider.wifiEnabled,
                  onChanged: settingsProvider.toggleWifi,
                ),
                _buildSwitchTile(
                  title: 'Auto-Connect',
                  subtitle: 'Automatically join known nearby networks',
                  icon: Icons.sync,
                  value: settingsProvider.autoConnect,
                  onChanged: settingsProvider.toggleAutoConnect,
                ),

                _buildSectionDivider(),

                // Notifications
                _buildSectionHeader('Notifications'),
                _buildSwitchTile(
                  title: 'Push Notifications',
                  subtitle: 'Receive alerts for messages and connections',
                  icon: Icons.notifications_outlined,
                  value: settingsProvider.notificationsEnabled,
                  onChanged: settingsProvider.toggleNotifications,
                ),

                _buildSectionDivider(),

                // Privacy & Security
                _buildSectionHeader('Login '),
                _buildNavigationTile(
                  title: 'Logout',
                  icon: Icons.logout,
                  onTap: () async {
                    Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
                  },
                ),
                _buildNavigationTile(
                  title: 'Delete Account',
                  icon: Icons.delete_outline,
                  onTap: () async {
                    await prefs.clear();
                    await ChatListProvider().cleanAllChats();
                    Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
                  },
                ),

                _buildSectionDivider(),

                // About
                _buildSectionHeader('About'),
                _buildNavigationTile(
                  title: 'About Oreon',
                  iconWidget: _buildAppIcon(),
                  onTap: () => _showAboutDialog(context),
                ),
                _buildNavigationTile(
                  title: 'Help & Support',
                  icon: Icons.help_outline,
                  onTap: () => _showInfoDialog(
                    context,
                    'Help & Support',
                    'Need assistance? Contact us at support@oreon.app',
                  ),
                ),

                // Version Info
                _buildVersionCard(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppIcon() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child:   CircleAvatar(
        backgroundColor: Colors.transparent,
        radius: 28,
        child: Image.asset(
        'assets/logo/logo_white_wout.png',
        width: 56,
        height: 56,
        ),
      ),
    );
  }

  Widget _buildVersionCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.tealAccent.withOpacity(0.6)),
          const SizedBox(width: 16),
          const Text(
            'Version',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const Spacer(),
          Text(
            '1.0.0 • December 2025',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
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
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            secondary: Icon(icon, color: Colors.tealAccent.withOpacity(0.8), size: 28),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            value: value,
            onChanged: onChanged,
            activeColor: Colors.tealAccent,
            activeTrackColor: Colors.tealAccent.withOpacity(0.3),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            hoverColor: Colors.transparent,
            splashRadius: 0,
          ),
        ),
      ),
    );
  }

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
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.tealAccent.withOpacity(0.1),
          highlightColor: Colors.tealAccent.withOpacity(0.05),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: iconWidget ?? Icon(icon, color: Colors.white70, size: 28),
              title: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.4)),
            ),
          ),
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => _GlassDialog(
        title: title,
        content: content,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
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
                        CircleAvatar(
                          backgroundColor: Colors.transparent,
                          radius: 28,
                          child: Image.asset(
                          'assets/logo/logo_white_wout.png',
                          width: 56,
                          height: 56,
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
                        child: const Text(
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

// Extracted Profile Card Widget
class _ProfileCard extends StatelessWidget {
  final UserProvider userProvider;

  const _ProfileCard({required this.userProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            backgroundImage: userProvider.avatarPicture != null
                ? FileImage(userProvider.avatarPicture!)
                : null,
          ),
          const SizedBox(height: 20),
          Text(
            userProvider.userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            userProvider.userSeed.isNotEmpty ? 'Seed: ${userProvider.userSeed.substring(0, 8)}...' : 'No seed set',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            child: const Text(
              'Edit Profile',
              style: TextStyle(
                color: Colors.tealAccent,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable Glass Dialog Widget
class _GlassDialog extends StatelessWidget {
  final String title;
  final String content;

  const _GlassDialog({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
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
              padding: const EdgeInsets.all(32),
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
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    content,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
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
                      child: const Text(
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
      child: IgnorePointer(
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
      ),
    );
  }
}