import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { driver, dispatcher }

class AuthUser {
  final String name;
  final String email;
  final UserRole role;
  final String vehicleId;

  const AuthUser({
    required this.name,
    required this.email,
    required this.role,
    this.vehicleId = 'V01',
  });

  bool get isDriver => role == UserRole.driver;
  bool get isDispatcher => role == UserRole.dispatcher;
  String get roleLabel => isDriver ? 'Driver' : 'Dispatcher';
}

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  static AuthUser? get currentUser {
    final user = _client.auth.currentUser;
    return user == null ? null : _fromUser(user);
  }

  static bool get isLoggedIn => _client.auth.currentSession != null;
  static bool get isDriver => currentUser?.isDriver ?? false;
  static bool get isDispatcher => currentUser?.isDispatcher ?? false;

  static AuthUser _fromUser(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final role = metadata['role'] == 'driver' ? UserRole.driver : UserRole.dispatcher;
    return AuthUser(
      name: (metadata['name'] as String?)?.trim().isNotEmpty == true
          ? metadata['name'] as String
          : user.email ?? 'ReRoute user',
      email: user.email ?? '',
      role: role,
      vehicleId: metadata['vehicle_id'] as String? ?? 'V01',
    );
  }

  static Future<AuthUser> signIn({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = response.user;
    if (user == null) throw const AuthException('Sign in failed. Please try again.');
    return _fromUser(user);
  }

  static Future<void> signUp({
    required String email,
    required String password,
    required String role,
    required String vehicleId,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'name': email.trim().split('@').first,
        'role': role,
        'vehicle_id': role == 'driver' ? vehicleId : 'V01',
      },
    );
    if (response.user == null) {
      throw const AuthException('Account creation failed. Please try again.');
    }
  }

  static Future<void> logout() => _client.auth.signOut();
}
