import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api_service.dart';

class AuthSession extends ChangeNotifier {
  static const _tokenKey = 'reroute_auth_token';
  static const _userKey = 'reroute_auth_user';
  static const _urlKey = 'reroute_api_url';

  UserModel? user;
  bool restoring = true;
  String? error;

  bool get isLoggedIn => user != null && ApiService.token != null;
  bool get isDispatcher => user?.isDispatcher ?? false;
  bool get isDriver => user?.isDriver ?? false;

  Future<void> restore() async {
    restoring = true;
    error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_urlKey);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        ApiService.baseUrl = savedUrl;
      }
      final token = prefs.getString(_tokenKey);
      if (token == null || token.isEmpty) {
        user = null;
        ApiService.token = null;
        return;
      }
      ApiService.token = token;
      user = await ApiService.me();
      await _persist(token, user!);
    } catch (_) {
      await logout(notify: false);
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    error = null;
    notifyListeners();
    final result = await ApiService.login(email, password);
    ApiService.token = result.token;
    user = result.user;
    await _persist(result.token, result.user);
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String role,
    String? vehicleId,
  }) async {
    error = null;
    notifyListeners();
    final result = await ApiService.register(
      email: email,
      password: password,
      name: name,
      role: role,
      vehicleId: vehicleId,
    );
    ApiService.token = result.token;
    user = result.user;
    await _persist(result.token, result.user);
    notifyListeners();
  }

  Future<void> saveBaseUrl(String url) async {
    ApiService.baseUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, ApiService.baseUrl);
    notifyListeners();
  }

  Future<void> logout({bool notify = true}) async {
    user = null;
    ApiService.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    if (notify) notifyListeners();
  }

  Future<void> _persist(String token, UserModel saved) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(saved.toJson()));
    await prefs.setString(_urlKey, ApiService.baseUrl);
  }
}
