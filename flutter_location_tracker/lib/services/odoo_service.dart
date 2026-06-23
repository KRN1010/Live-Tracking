import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OdooService {
  static Future<bool> login(String url, String db, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$url/web/session/authenticate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'db': db,
            'login': email,
            'password': password,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] != null && data['result']['uid'] != null) {
          final cookies = response.headers['set-cookie'];
          final sessionId = _extractSessionId(cookies ?? '');
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('odoo_url', url);
          await prefs.setString('session_id', sessionId);
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('odoo_url');
    final sessionId = prefs.getString('session_id');
    if (url != null && sessionId != null) {
      try {
        await http.post(
          Uri.parse('$url/web/location/offline'),
          headers: {
            'Content-Type': 'application/json',
            'Cookie': 'session_id=$sessionId',
          },
          body: jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'params': {}}),
        );
      } catch (e) {}
    }
    await prefs.remove('session_id');
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_id') != null;
  }

  static Future<void> pingLocation(double lat, double lng, double accuracy, double speed, double heading, double altitude) async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('odoo_url');
    final sessionId = prefs.getString('session_id');

    if (url != null && sessionId != null) {
      try {
        await http.post(
          Uri.parse('$url/web/location/ping'),
          headers: {
            'Content-Type': 'application/json',
            'Cookie': 'session_id=$sessionId',
          },
          body: jsonEncode({
            'jsonrpc': '2.0',
            'method': 'call',
            'params': {
              'lat': lat,
              'lng': lng,
              'accuracy': accuracy,
              'speed': speed,
              'heading': heading,
              'altitude': altitude,
            }
          }),
        );
      } catch (e) {
        print('Error pinging Odoo: $e');
      }
    }
  }

  static String _extractSessionId(String cookies) {
    final parts = cookies.split(';');
    for (final part in parts) {
      if (part.trim().startsWith('session_id=')) {
        return part.trim().substring('session_id='.length);
      }
    }
    return '';
  }
}
