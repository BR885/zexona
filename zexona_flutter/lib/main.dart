import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'chat_list_screen.dart';
import 'chat_screen.dart';
import 'search_users_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserManager {
  static String? userId;
  static String? displayName;
  static String? email;
  
  static Future<void> setUser(String id, String name, String? emailAddress) async {
    userId = id;
    displayName = name;
    email = emailAddress;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', id);
    await prefs.setString('displayName', name);
    if (emailAddress != null) {
      await prefs.setString('email', emailAddress);
    }
    print('👤 User saved: $displayName (ID: $userId)');
  }
  
  static Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId');
    displayName = prefs.getString('displayName') ?? 'User';
    email = prefs.getString('email');
    if (userId != null) {
      print('👤 User loaded: $displayName (ID: $userId)');
    }
  }
  
  static bool get isLoggedIn => userId != null && userId!.isNotEmpty;
  
  static String get userIdOrEmpty => userId ?? '';
  static String get displayNameOrEmpty => displayName ?? 'User';
  
  static Future<void> clear() async {
    userId = null;
    displayName = null;
    email = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('displayName');
    await prefs.remove('email');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserManager.loadUser();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zexona',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.purple,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      initialRoute: UserManager.isLoggedIn ? '/home' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/chats': (context) => const ChatListScreen(),
        '/search': (context) => const SearchUsersScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/chat') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: args['chatId'],
              chatName: args['chatName'],
              isGroup: args['isGroup'] ?? false,
            ),
          );
        }
        return null;
      },
    );
  }
}