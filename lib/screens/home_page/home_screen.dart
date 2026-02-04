import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:oreon/screens/chat_page/chat_screen.dart';
import '../nerby_page/nearby_contacts_screen.dart';
import '../setting_page/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    ChatsScreen(),
    StableNearbyContactsScreen(),
    SettingsScreen(),
  ];

  bool get _showFab => _currentIndex == 0 || _currentIndex == 1;
  IconData get _fabIcon => _currentIndex == 0 ? Icons.edit : Icons.radar;


  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const RepaintBoundary(
            child: _StaticBackgroundGlow(),
          ),
          IndexedStack(
            index: _currentIndex,
            children: _screens.map((screen) => KeyedSubtree(key: ValueKey(screen.runtimeType), child: screen)).toList(),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _CompactGlassmorphicBottomNav(
        currentIndex: _currentIndex,
        onTabChanged: _onTabChanged,
      ),
    );
  }
}

class _CompactGlassmorphicBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  const _CompactGlassmorphicBottomNav({
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 70, // Smaller, compact height
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onTabChanged,
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            selectedItemColor: Colors.tealAccent,
            unselectedItemColor: Colors.white.withOpacity(0.6),
            iconSize: 28,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                activeIcon: Icon(Icons.chat_bubble),
                label: 'Chats', // Label still required but hidden
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.radar_outlined),
                activeIcon: Icon(Icons.radar),
                label: 'Spot',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
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
    return const Positioned(
      top: -150,
      left: -150,
      child: SizedBox(
        width: 500,
        height: 500,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.teal,
                Colors.transparent,
              ],
              stops: [0.0, 0.7],
            ),
          ),
        ),
      ),
    );
  }
}