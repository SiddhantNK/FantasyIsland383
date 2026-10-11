/// Local authentication service for role-based access.
/// Stores current user session in-memory (no external dependencies).
enum UserRole { driver, dispatcher }

class AuthUser {
  final String name;
  final UserRole role;
  final String vehicleId; // Only relevant for drivers

  const AuthUser({required this.name, required this.role, this.vehicleId = 'V01'});

  bool get isDriver => role == UserRole.driver;
  bool get isDispatcher => role == UserRole.dispatcher;

  String get roleLabel => role == UserRole.driver ? 'Driver' : 'Dispatcher';
}

class AuthService {
  static AuthUser? _currentUser;

  static AuthUser? get currentUser => _currentUser;
  static bool get isLoggedIn => _currentUser != null;
  static bool get isDriver => _currentUser?.isDriver ?? false;
  static bool get isDispatcher => _currentUser?.isDispatcher ?? false;

  /// Demo login — no password needed, just pick a role.
  static void loginAsDriver({String name = 'Driver', String vehicleId = 'V01'}) {
    _currentUser = AuthUser(name: name, role: UserRole.driver, vehicleId: vehicleId);
  }

  static void loginAsDispatcher({String name = 'Dispatcher'}) {
    _currentUser = AuthUser(name: name, role: UserRole.dispatcher);
  }

  static void logout() {
    _currentUser = null;
  }
}
