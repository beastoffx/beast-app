import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import '../core/services/api_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  UserModel? _user;
  StudentProfileModel? _studentProfile;
  Map<String, dynamic>? _teacherProfile;
  Map<String, dynamic>? _adminProfile;

  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  StudentProfileModel? get studentProfile => _studentProfile;
  Map<String, dynamic>? get teacherProfile => _teacherProfile;
  Map<String, dynamic>? get adminProfile => _adminProfile;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  String get role => _user?.role ?? '';
  bool get isStudent => _user?.isStudent ?? false;
  bool get isTeacher => _user?.isTeacher ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<void> initAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userJson = prefs.getString('auth_user');
    final profileJson = prefs.getString('auth_profile');

    if (token != null && userJson != null) {
      _api.setToken(token);
      _user = UserModel.fromJson(jsonDecode(userJson));
      if (profileJson != null && _user!.isStudent) {
        _studentProfile = StudentProfileModel.fromJson(jsonDecode(profileJson));
      }
      notifyListeners();

      // Refresh in background
      _refreshMe();
    }
  }

  Future<void> _refreshMe() async {
    final response = await _api.get(ApiConstants.me, useCache: false);
    if (response.success && response.data != null) {
      final userData = response.data['user'];
      final profileData = response.data['profile'];
      if (userData != null) {
        _user = UserModel.fromJson(userData);
        if (_user!.isStudent && profileData != null) {
          _studentProfile = StudentProfileModel.fromJson(profileData);
        }
        notifyListeners();
      }
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.post(ApiConstants.login, {
      'email': email.trim(),
      'password': password,
    });

    _isLoading = false;

    if (response.success && response.data != null) {
      final data = response.data;
      final token = data['token'];
      final userObj = data['user'];
      final profileObj = data['profile'];

      _api.setToken(token);
      _user = UserModel.fromJson(userObj);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('auth_user', jsonEncode(userObj));

      if (profileObj != null) {
        await prefs.setString('auth_profile', jsonEncode(profileObj));
        if (_user!.isStudent) {
          _studentProfile = StudentProfileModel.fromJson(profileObj);
        } else if (_user!.isTeacher) {
          _teacherProfile = profileObj;
        } else if (_user!.isAdmin) {
          _adminProfile = profileObj;
        }
      }

      notifyListeners();
      return true;
    } else {
      _errorMessage = response.error ?? 'Invalid email or password.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.post(ApiConstants.changePassword, {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });

    _isLoading = false;
    if (!response.success) {
      _errorMessage = response.error ?? 'Failed to update password.';
    }
    notifyListeners();
    return response.success;
  }

  Future<bool> recoverPassword(String email) async {
    final response = await _api.post(ApiConstants.recoverRequest, {'email': email});
    return response.success;
  }

  Future<void> logout() async {
    try {
      await _api.post(ApiConstants.logout, {});
    } catch (_) {}

    _api.setToken(null);
    _user = null;
    _studentProfile = null;
    _teacherProfile = null;
    _adminProfile = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    await prefs.remove('auth_profile');

    notifyListeners();
  }
}
