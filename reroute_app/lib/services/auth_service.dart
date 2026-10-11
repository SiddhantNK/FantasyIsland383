import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { driver, dispatcher }

class AuthUser {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? vehicleId; // Relevant for drivers (e.g. V01, V02, V03)

  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.vehicleId = 'V01',
  });

  bool get isDriver => role == UserRole.driver;
  bool get isDispatcher => role == UserRole.dispatcher;

  String get roleLabel => role == UserRole.driver ? 'Driver' : 'Dispatcher';
}

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;
  static AuthUser? _currentUser;

  static AuthUser? get currentUser => _currentUser;
  static bool get isLoggedIn => _currentUser != null;
  static bool get isDriver => _currentUser?.isDriver ?? false;
  static bool get isDispatcher => _currentUser?.isDispatcher ?? false;

  /// Fetch user profile from public.profiles table or fallback to auth metadata
  static Future<AuthUser?> _fetchProfile(User user) async {
    try {
      final res = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final metadata = user.userMetadata ?? {};
      final roleStr = (res?['role'] ?? metadata['role'] ?? 'driver').toString().toLowerCase();
      final role = roleStr == 'dispatcher' ? UserRole.dispatcher : UserRole.driver;
      final name = (res?['full_name'] ?? metadata['full_name'] ?? user.email?.split('@').first ?? 'User').toString();
      final vehicleId = (res?['vehicle_id'] ?? metadata['vehicle_id'] ?? (role == UserRole.driver ? 'V01' : null))?.toString();

      _currentUser = AuthUser(
        id: user.id,
        email: user.email ?? '',
        name: name,
        role: role,
        vehicleId: vehicleId,
      );
      return _currentUser;
    } catch (e) {
      // Fallback if profiles table is not yet created or unreachable
      final metadata = user.userMetadata ?? {};
      final roleStr = (metadata['role'] ?? 'driver').toString().toLowerCase();
      final role = roleStr == 'dispatcher' ? UserRole.dispatcher : UserRole.driver;
      final name = (metadata['full_name'] ?? user.email?.split('@').first ?? 'User').toString();
      final vehicleId = (metadata['vehicle_id'] ?? (role == UserRole.driver ? 'V01' : null))?.toString();

      _currentUser = AuthUser(
        id: user.id,
        email: user.email ?? '',
        name: name,
        role: role,
        vehicleId: vehicleId,
      );
      return _currentUser;
    }
  }

  /// Initialize and restore existing session if logged in
  static Future<bool> restoreSession() async {
    final session = _client.auth.currentSession;
    if (session != null) {
      await _fetchProfile(session.user);
      return true;
    }
    _currentUser = null;
    return false;
  }

  /// Sign Up with Email, Password and Role
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? vehicleId,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'role': role.name,
        'vehicle_id': role == UserRole.driver ? (vehicleId ?? 'V01') : null,
      },
    );

    if (response.user != null) {
      // Upsert profile in case database trigger hasn't completed or is missing
      try {
        await _client.from('profiles').upsert({
          'id': response.user!.id,
          'email': response.user!.email,
          'full_name': fullName.trim(),
          'role': role.name,
          'vehicle_id': role == UserRole.driver ? (vehicleId ?? 'V01') : null,
        });
      } catch (_) {
        // Silently continue if table trigger already handled it or RLS prevented
      }

      await _fetchProfile(response.user!);
    }
    return response;
  }

  /// Sign In with Email & Password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    if (response.user != null) {
      await _fetchProfile(response.user!);
    }
    return response;
  }

  /// Sign Out
  static Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
    _currentUser = null;
  }

  /// Quick Demo Sign-in for immediate testing
  static void demoLoginAsDriver({String vehicleId = 'V01'}) {
    _currentUser = AuthUser(
      id: 'demo-driver-id',
      email: 'driver@reroute.demo',
      name: 'Demo Driver ($vehicleId)',
      role: UserRole.driver,
      vehicleId: vehicleId,
    );
  }

  static void demoLoginAsDispatcher() {
    _currentUser = AuthUser(
      id: 'demo-dispatcher-id',
      email: 'dispatcher@reroute.demo',
      name: 'Fleet Dispatcher',
      role: UserRole.dispatcher,
    );
  }
}
