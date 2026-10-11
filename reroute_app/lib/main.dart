import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'Missing Supabase configuration. Run Flutter with '
      '--dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...',
    );
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const ReRouteApp());
}

class ReRouteApp extends StatelessWidget {
  const ReRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReRoute - Dynamic Delivery Optimization',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (AuthService.isLoggedIn) {
            return HomeScreen(onLogout: AuthService.logout);
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
