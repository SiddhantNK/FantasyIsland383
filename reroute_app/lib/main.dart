import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/supabase_config.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const ReRouteApp());
}

class ReRouteApp extends StatefulWidget {
  const ReRouteApp({super.key});

  @override
  State<ReRouteApp> createState() => _ReRouteAppState();
}

class _ReRouteAppState extends State<ReRouteApp> {
  bool _initialized = false;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    final hasSession = await AuthService.restoreSession();
    if (mounted) {
      setState(() {
        _loggedIn = hasSession;
        _initialized = true;
      });
    }
  }

  void _onLoginSuccess() {
    setState(() => _loggedIn = true);
  }

  Future<void> _onLogout() async {
    await AuthService.logout();
    setState(() => _loggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          backgroundColor: AppTheme.bgLight,
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        ),
      );
    }

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
