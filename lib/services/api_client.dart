import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SmartFileApi {
  SmartFileApi({String? baseUrl})
    : baseUrl =
          baseUrl ??
          (Platform.isAndroid
              // Physical Android devices reach the development machine over
              // the local network. Change this when the computer's LAN IP
              // changes; the same value can also be edited in Settings.
              ? 'http://192.168.1.158:4000'
              : 'http://127.0.0.1:4000');

  String baseUrl;
  String? token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Uri _uri(String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Future<void> login({required String email, required String password}) async {
    final body = await _post('/api/auth/login', {
      'email': email,
      'password': password,
    }, authenticated: false);
    final receivedToken = body['token'];
    if (receivedToken is! String || receivedToken.isEmpty) {
      throw ApiException('The server did not return a session token.');
    }
    token = receivedToken;
  }

  Future<void> register({
    required String email,
    required String displayName,
    required String password,
  }) async {
    await _post('/api/auth/register', {
      'email': email,
      'displayName': displayName,
      'password': password,
    }, authenticated: false);
    await login(email: email, password: password);
  }

  Future<AiPlan> plan(
    String instruction,
    List<Map<String, dynamic>> results,
  ) async {
    final body = await _post('/api/mobile/plan', {
      'instruction': instruction,
      if (results.isNotEmpty) 'toolResults': results,
    });
    final rawOperations = body['operations'];
    if (rawOperations is! List)
      throw ApiException('The server returned an invalid AI plan.');
    return AiPlan(
      reply: body['reply'] is String ? body['reply'] as String : null,
      operations: rawOperations.whereType<Map>().map((raw) {
        final map = Map<String, dynamic>.from(raw);
        return PlannedOperation(
          id: map['id'] as String,
          name: map['name'] as String,
          input: Map<String, dynamic>.from(map['input'] as Map),
          requiresApproval: map['requiresApproval'] == true,
        );
      }).toList(),
    );
  }

  Future<Map<String, dynamic>> bootstrap() => _get('/api/mobile/bootstrap');

  Future<Map<String, dynamic>> _get(String path) async {
    if (token == null)
      throw ApiException('Sign in before loading your account.');
    try {
      final response = await http
          .get(_uri(path), headers: _headers)
          .timeout(const Duration(seconds: 15));
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (decoded is! Map)
        throw ApiException('The server returned an invalid response.');
      final body = Map<String, dynamic>.from(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = body['error'];
        throw ApiException(
          error is Map && error['message'] is String
              ? error['message'] as String
              : 'Request failed (${response.statusCode}).',
        );
      }
      return body;
    } on SocketException {
      throw ApiException(
        'Cannot reach the backend. Check the server address in Settings.',
      );
    } on http.ClientException {
      throw ApiException(
        'Cannot reach the backend. Check that the backend is running and the server address is correct.',
      );
    } on TimeoutException {
      throw ApiException(
        'The backend took too long to respond. Check that it is running and reachable.',
      );
    } on HttpException {
      throw ApiException('The backend connection was interrupted.');
    } on FormatException {
      throw ApiException('The backend returned invalid JSON.');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload, {
    bool authenticated = true,
  }) async {
    if (authenticated && token == null)
      throw ApiException('Sign in before using the AI assistant.');
    try {
      final response = await http
          .post(_uri(path), headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 30));
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (decoded is! Map)
        throw ApiException('The server returned an invalid response.');
      final body = Map<String, dynamic>.from(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = body['error'];
        throw ApiException(
          error is Map && error['message'] is String
              ? error['message'] as String
              : 'Request failed (${response.statusCode}).',
        );
      }
      return body;
    } on SocketException {
      throw ApiException(
        'Cannot reach the backend. Check the server address in Settings.',
      );
    } on http.ClientException {
      throw ApiException(
        'Cannot reach the backend. Check that the backend is running and the server address is correct.',
      );
    } on TimeoutException {
      throw ApiException(
        'The backend took too long to respond. Check that it is running and reachable.',
      );
    } on HttpException {
      throw ApiException('The backend connection was interrupted.');
    } on FormatException {
      throw ApiException('The backend returned invalid JSON.');
    }
  }
}
