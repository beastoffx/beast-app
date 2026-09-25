import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final bool isFromCache;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.isFromCache = false,
  });
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // GET Request with Automatic Offline Cache Fallback
  Future<ApiResponse<dynamic>> get(String endpoint, {bool useCache = true}) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cache_$endpoint';

    try {
      final response = await http
          .get(url, headers: _buildHeaders())
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        // Update offline cache
        if (useCache) {
          await prefs.setString(cacheKey, response.body);
        }
        return ApiResponse(success: true, data: decoded['data'] ?? decoded);
      } else {
        final decoded = jsonDecode(response.body);
        final errMsg = decoded['error'] ?? 'Request failed (${response.statusCode})';
        return ApiResponse(success: false, error: errMsg);
      }
    } catch (e) {
      // Offline fallback for any network error or timeout
      if (useCache) {
        final cached = prefs.getString(cacheKey);
        if (cached != null) {
          final decoded = jsonDecode(cached);
          return ApiResponse(
            success: true,
            data: decoded['data'] ?? decoded,
            isFromCache: true,
          );
        }
      }
      return ApiResponse(
        success: false,
        error: 'Unable to reach academy server. Please check your internet connection.',
      );
    }
  }

  // POST Request
  Future<ApiResponse<dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    try {
      final response = await http
          .post(url, headers: _buildHeaders(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          success: true,
          data: decoded['data'] ?? decoded,
        );
      } else {
        return ApiResponse(
          success: false,
          error: decoded['error'] ?? 'Action failed (${response.statusCode})',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        error: 'Failed to process request. Please check connection.',
      );
    }
  }

  // PUT Request
  Future<ApiResponse<dynamic>> put(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    try {
      final response = await http
          .put(url, headers: _buildHeaders(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          success: true,
          data: decoded['data'] ?? decoded,
        );
      } else {
        return ApiResponse(
          success: false,
          error: decoded['error'] ?? 'Update failed (${response.statusCode})',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        error: 'Connection error while saving updates.',
      );
    }
  }

  // DELETE Request
  Future<ApiResponse<dynamic>> delete(String endpoint) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    try {
      final response = await http
          .delete(url, headers: _buildHeaders())
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          success: true,
          data: decoded['data'] ?? decoded,
        );
      } else {
        return ApiResponse(
          success: false,
          error: decoded['error'] ?? 'Delete operation failed.',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        error: 'Failed to delete record. Please check connection.',
      );
    }
  }
}
