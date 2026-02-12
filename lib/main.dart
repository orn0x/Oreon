import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oreon/models/chat_model.dart';
import 'package:oreon/providers/providers.dart';
import 'package:oreon/screens/chat_page/chat_detail_screen_wifi.dart';
import 'package:oreon/screens/nerby_page/nearby_contacts_screen.dart';
import 'package:oreon/screens/profile_page/profile_screen.dart';
import 'package:oreon/screens/signin_page/signin.dart';
import 'package:oreon/services/WIFI/lan_module/examples/backend_service_example.dart';
import 'package:oreon/services/WIFI/lan_module/lan_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oreon/screens/home_page/home_screen.dart';
import 'package:oreon/screens/settings_page/settings_screen.dart';

late SharedPreferences prefs;
late MessageProvider _messageProvider;
late ChatListProvider _chatListProvider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  prefs = await SharedPreferences.getInstance();
  
  // Initialize LAN Controller singleton
  LanController.instance;

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const OreonApp());
}

class OreonApp extends StatelessWidget {
  const OreonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = ChatListProvider();
            _chatListProvider = provider;
            provider.initializeChats();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = MessageProvider();
            _messageProvider = provider;
            provider.initialize();
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Oreon',
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
            surface: Colors.black,
            background: Colors.black,
          ),
          scaffoldBackgroundColor: Colors.black,
          brightness: Brightness.dark,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white70),
            titleLarge: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: Colors.teal.withOpacity(0.3),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          ),
        ),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/signin': (context) => const SignInScreen(),
          '/nearby': (context) => const StableNearbyContactsScreen(),
          'clan' : (context) => ChatDetailScreenWifi(chat: ModalRoute.of(context)!.settings.arguments as Chat),
        },
      ),
    );
  }
}