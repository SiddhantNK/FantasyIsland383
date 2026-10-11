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
  final AuthSession _session = AuthSession();

  @override
  void initState() {
    super.initState();
    _session.restore();
    _session.addListener(_onSession);
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (_session.restoring) {
      home = const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (_session.isLoggedIn) {
      home = HomeScreen(session: _session);
    } else {
      home = LoginScreen(session: _session);
    }

    return MaterialApp(
      title: 'ReRoute - Dynamic Delivery Optimization',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: home,
    );
  }
}
