import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReRouteApp());
}

class ReRouteApp extends StatefulWidget {
  const ReRouteApp({super.key});

  @override
  State<ReRouteApp> createState() => _ReRouteAppState();
}

class _ReRouteAppState extends State<ReRouteApp> {
  bool _loggedIn = false;

  void _onLoginSuccess() {
    setState(() => _loggedIn = true);
  }

  void _onLogout() {
    AuthService.logout();
    setState(() => _loggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReRoute - Dynamic Delivery Optimization',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _loggedIn
          ? HomeScreen(onLogout: _onLogout)
          : LoginScreen(onLoginSuccess: _onLoginSuccess),
    );
  }
}
