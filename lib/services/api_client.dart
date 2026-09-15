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
      : baseUrl = baseUrl ?? (Platform.isAndroid ? 'http://10.0.2.2:4000' : 'http://127.0.0.1:4000');

  String baseUrl;
  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Future<void> login({required String email, required String password}) async {
    final body = await _post('/api/auth/login', {'email': email, 'password': password}, authenticated: false);
    final receivedToken = body['token'];
    if (receivedToken is! String || receivedToken.isEmpty) {
      throw ApiException('The server did not return a session token.');
    }
    token = receivedToken;
  }

  Future<void> register({required String email, required String displayName, required String password}) async {
    await _post('/api/auth/register', {
      'email': email,
      'displayName': displayName,
      'password': password,
    }, authenticated: false);
    await login(email: email, password: password);
  }

  Future<AiPlan> plan(String instruction, List<Map<String, dynamic>> results) async {
    final body = await _post('/api/mobile/plan', {
      'instruction': instruction,
      if (results.isNotEmpty) 'toolResults': results,
    });
    final rawOperations = body['operations'];
    if (rawOperations is! List) throw ApiException('The server returned an invalid AI plan.');
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

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> payload, {bool authenticated = true}) async {
    if (authenticated && token == null) throw ApiException('Sign in before using the AI assistant.');
    try {
      final response = await http.post(_uri(path), headers: _headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 30));
      final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
      if (decoded is! Map) throw ApiException('The server returned an invalid response.');
      final body = Map<String, dynamic>.from(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = body['error'];
        throw ApiException(error is Map && error['message'] is String ? error['message'] as String : 'Request failed (${response.statusCode}).');
      }
      return body;
    } on SocketException {
      throw ApiException('Cannot reach the backend. Check the server address in Settings.');
    } on HttpException {
      throw ApiException('The backend connection was interrupted.');
    } on FormatException {
      throw ApiException('The backend returned invalid JSON.');
    }
  }
}
