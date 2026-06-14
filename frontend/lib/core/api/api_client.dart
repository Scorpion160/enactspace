import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String serverUrl = 'http://127.0.0.1:8000';
  static const String baseUrl = '$serverUrl/api';

  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> postForm(
    String path, {
    required Map<String, String> data,
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: data,
    );

    return _handleResponse(response);
  }

  Future<dynamic> postJson(
    String path, {
    required Map<String, dynamic> data,
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    return _handleResponse(response);
  }

  Future<dynamic> patchJson(
    String path, {
    required Map<String, dynamic> data,
    String? token,
  }) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    return _handleResponse(response);
  }

  Future<dynamic> get(String path, {String? token}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    return _handleResponse(response);
  }

  Future<dynamic> delete(String path, {String? token}) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    final dynamic body = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : {};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String message = 'Erreur serveur ${response.statusCode}';

    if (body is Map<String, dynamic>) {
      if (body['detail'] is String) {
        message = body['detail'];
      } else if (body['detail'] != null) {
        message = body['detail'].toString();
      }
    }

    throw ApiException(statusCode: response.statusCode, message: message);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
