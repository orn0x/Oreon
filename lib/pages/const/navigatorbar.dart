import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class NavigatorbarLine extends StatefulWidget {
  const NavigatorbarLine({super.key});

  @override
  State<NavigatorbarLine> createState() => _NavigatorbarState();
}

class _NavigatorbarState extends State<NavigatorbarLine> {
  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      destinations: 
        [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
            selectedIcon: Icon(Icons.home),
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            label: 'Search',
            selectedIcon: Icon(Icons.search),
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.user),
            label: 'Profile',
            selectedIcon: Icon(LucideIcons.user600),
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.settings600),
            label: 'Settings',
            selectedIcon: Icon(LucideIcons.settings),
          ),
        ]
      );
  }
}

class NavigationDestinationPage {
  const NavigationDestinationPage({required this.icon, required this.label, required this.selectedIcon});

  final Icon icon;
  final String label;
  final Widget selectedIcon ;
}