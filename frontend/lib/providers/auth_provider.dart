import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import '../core/services/api_service.dart';
import '../core/services/google_auth_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  UserModel? _user;
  StudentProfileModel? _studentProfile;
  Map<String, dynamic>? _teacherProfile;
  Map<String, dynamic>? _adminProfile;

  String? _pendingGoogleUid;
  String? _pendingGoogleEmail;
  String? _pendingGoogleName;
  String? _pendingGooglePicture;

  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  StudentProfileModel? get studentProfile => _studentProfile;
  Map<String, dynamic>? get teacherProfile => _teacherProfile;
  Map<String, dynamic>? get adminProfile => _adminProfile;

  String? get pendingGoogleUid => _pendingGoogleUid;
  String? get pendingGoogleEmail => _pendingGoogleEmail;
  String? get pendingGoogleName => _pendingGoogleName;
  String? get pendingGooglePicture => _pendingGooglePicture;

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

  // ==================== GOOGLE OAUTH & STUDENT ACTIVATION ====================

  /// Sign in using Google OAuth identity token
  /// Returns 'LINKED', 'UNLINKED', 'CANCELLED', or 'ERROR'
  Future<String> signInWithGoogle({String? manualIdToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String? idToken = manualIdToken;

    if (idToken == null) {
      final googleAccount = await GoogleAuthService.signIn();
      if (googleAccount == null) {
        _isLoading = false;
        notifyListeners();
        return 'CANCELLED';
      }

      idToken = await GoogleAuthService.getIdToken(googleAccount);
      if (idToken == null) {
        _isLoading = false;
        _errorMessage = 'Failed to retrieve Google identity token.';
        notifyListeners();
        return 'ERROR';
      }
    }

    final response = await _api.post(ApiConstants.authGoogle, {
      'idToken': idToken,
    });

    _isLoading = false;

    if (response.success && response.data != null) {
      final data = response.data;
      final status = data['status'];

      if (status == 'LINKED') {
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
        return 'LINKED';
      } else if (status == 'UNLINKED') {
        _pendingGoogleUid = data['googleUid'];
        _pendingGoogleEmail = data['email'];
        _pendingGoogleName = data['name'];
        _pendingGooglePicture = data['picture'];
        notifyListeners();
        return 'UNLINKED';
      }
    }

    _errorMessage = response.error ?? 'Google authentication failed.';
    notifyListeners();
    return 'ERROR';
  }

  /// Step 1 of Activation: Validate Student ID before requesting OTP
  Future<Map<String, dynamic>?> validateStudentId(String studentIdNumber) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.post(ApiConstants.activateStudent, {
      'studentIdNumber': studentIdNumber.trim().toUpperCase(),
      'googleUid': _pendingGoogleUid,
    });

    _isLoading = false;

    if (response.success && response.data != null) {
      notifyListeners();
      return response.data;
    } else {
      _errorMessage = response.error ?? 'Invalid Student ID.';
      notifyListeners();
      return null;
    }
  }

  /// Step 2 of Activation: Dispatch phone OTP
  Future<String?> sendActivationOtp(String studentIdNumber, String phone) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.post(ApiConstants.sendOtp, {
      'googleUid': _pendingGoogleUid,
      'studentIdNumber': studentIdNumber.trim().toUpperCase(),
      'phone': phone.trim(),
    });

    _isLoading = false;

    if (response.success && response.data != null) {
      notifyListeners();
      return response.data['sessionId'];
    } else {
      _errorMessage = response.error ?? 'Failed to send verification code.';
      notifyListeners();
      return null;
    }
  }

  /// Step 3 of Activation: Verify OTP and atomically activate account
  Future<bool> verifyActivationOtp({
    required String sessionId,
    required String otp,
    required String studentIdNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.post(ApiConstants.verifyOtp, {
      'sessionId': sessionId,
      'otp': otp.trim(),
      'googleUid': _pendingGoogleUid,
      'studentIdNumber': studentIdNumber.trim().toUpperCase(),
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
        }
      }

      // Reset pending state
      _pendingGoogleUid = null;
      _pendingGoogleEmail = null;
      _pendingGoogleName = null;
      _pendingGooglePicture = null;

      notifyListeners();
      return true;
    } else {
      _errorMessage = response.error ?? 'Verification failed.';
      notifyListeners();
      return false;
    }
  }
}
