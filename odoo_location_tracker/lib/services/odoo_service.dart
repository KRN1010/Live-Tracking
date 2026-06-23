import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OdooService {
  static String? _odooUrl;
  static String? _sessionId;

  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _odooUrl = prefs.getString('odoo_url');
    _sessionId = prefs.getString('session_id');
  }

  static String? get odooUrl => _odooUrl;

  /// Authenticate with Odoo and return session id
  static Future<Map<String, dynamic>> login({
    required String url,
    required String database,
    required String username,
    required String password,
  }) async {
    final cleanUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');

    try {
      final response = await http.post(
        Uri.parse('$cleanUrl/web/session/authenticate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'id': 1,
          'params': {
            'db': database,
            'login': username,
            'password': password,
          },
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      final result = data['result'];

      if (result == null || result['uid'] == null) {
        return {
          'success': false,
          'error': 'Invalid credentials. Please check your username and password.',
        };
      }

      // Extract session id from cookie
      final cookie = response.headers['set-cookie'] ?? '';
      final sessionMatch = RegExp(r'session_id=([^;]+)').firstMatch(cookie);
      final sessionId = sessionMatch?.group(1) ?? '';

      // Save to prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('odoo_url', cleanUrl);
      await prefs.setString('session_id', sessionId);
      await prefs.setString('database', database);
      await prefs.setString('username', username);
      await prefs.setString('employee_name', result['name'] ?? username);
      await prefs.setInt('uid', result['uid']);

      _odooUrl = cleanUrl;
      _sessionId = sessionId;

      return {'success': true, 'name': result['name']};
    } catch (e) {
      return {
        'success': false,
        'error': 'Could not connect to Odoo. Check the URL and try again.\n$e',
      };
    }
  }

  /// Send a location ping to Odoo
  static Future<bool> sendPing({
    required double lat,
    required double lng,
    double accuracy = 0,
    double speed = 0,
    double heading = 0,
    double altitude = 0,
  }) async {
    if (_odooUrl == null || _sessionId == null) {
      await loadFromPrefs();
    }
    if (_odooUrl == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_odooUrl/web/location/ping'),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$_sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'id': 1,
          'params': {
            'lat': lat,
            'lng': lng,
            'accuracy': accuracy,
            'speed': speed,
            'heading': heading,
            'altitude': altitude,
          },
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      return data['result']?['status'] == 'ok';
    } catch (e) {
      // Silently fail — will retry on next interval
      return false;
    }
  }

  /// Mark user as offline in Odoo
  static Future<void> markOffline() async {
    if (_odooUrl == null || _sessionId == null) return;
    try {
      await http.post(
        Uri.parse('$_odooUrl/web/location/offline'),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'session_id=$_sessionId',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'id': 1,
          'params': {},
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Logout — clear session and mark offline
  static Future<void> logout() async {
    await markOffline();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_id');
    await prefs.remove('odoo_url');
    await prefs.remove('database');
    await prefs.remove('employee_name');
    _odooUrl = null;
    _sessionId = null;
  }
}
