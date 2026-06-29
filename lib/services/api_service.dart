import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/storage.dart';

class ApiService {
  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (auth) {
      final token = await AppStorage.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.apiBaseUrl}$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final response = await http.put(
      Uri.parse('${AppConstants.apiBaseUrl}$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    bool auth = true,
  }) async {
    final response = await http.get(
      Uri.parse('${AppConstants.apiBaseUrl}$path'),
      headers: await _headers(auth: auth),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> delete(
    String path, {
    bool auth = true,
  }) async {
    final response = await http.delete(
      Uri.parse('${AppConstants.apiBaseUrl}$path'),
      headers: await _headers(auth: auth),
    );

    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw Exception(body['message'] ?? 'Request failed');
  }
}