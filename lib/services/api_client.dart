import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
      : baseUrl = baseUrl ??
            (Platform.isAndroid
                ? 'http://127.0.0.1:4000'
                : 'http://127.0.0.1:4000');

  String baseUrl;
  String? token;
  UserAccount? currentUser;
  bool isDemoMode = false;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Future<UserAccount> login({
    required String email,
    required String password,
  }) async {
    isDemoMode = false;
    final body = await _post('/api/auth/login', {
      'email': email,
      'password': password,
    }, authenticated: false);
    final receivedToken = body['token'];
    if (receivedToken is! String || receivedToken.isEmpty) {
      throw ApiException('The server did not return a session token.');
    }
    token = receivedToken;

    final rawUser = body['user'];
    if (rawUser is Map) {
      currentUser = UserAccount(
        id: rawUser['id']?.toString() ?? 'user-1',
        email: rawUser['email']?.toString() ?? email,
        displayName: rawUser['displayName']?.toString() ?? 'User',
      );
    } else {
      currentUser = UserAccount(
        id: 'user-1',
        email: email,
        displayName: email.split('@').first,
      );
    }
    return currentUser!;
  }

  Future<UserAccount> register({
    required String email,
    required String displayName,
    required String password,
  }) async {
    isDemoMode = false;
    await _post('/api/auth/register', {
      'email': email,
      'displayName': displayName,
      'password': password,
    }, authenticated: false);
    return await login(email: email, password: password);
  }

  UserAccount startDemoSession() {
    isDemoMode = true;
    token = 'demo-session-token';
    currentUser = const UserAccount(
      id: 'demo-user-1',
      email: 'alex.morgan@filemind.ai',
      displayName: 'Alex Morgan',
    );
    return currentUser!;
  }

  void logout() {
    token = null;
    currentUser = null;
    isDemoMode = false;
  }

  Future<AiPlan> plan(
    String instruction,
    List<Map<String, dynamic>> results,
  ) async {
    try {
      final body = await _post('/api/mobile/plan', {
        'instruction': instruction,
        if (results.isNotEmpty) 'toolResults': results,
      });
      final rawOperations = body['operations'];
      if (rawOperations is List) {
        final ops = rawOperations.whereType<Map>().map((raw) {
          final map = Map<String, dynamic>.from(raw);
          return PlannedOperation(
            id: map['id']?.toString() ?? 'op-${DateTime.now().millisecondsSinceEpoch}',
            name: map['name'] as String? ?? 'operation',
            input: Map<String, dynamic>.from(map['input'] as Map? ?? {}),
            requiresApproval: map['requiresApproval'] == true,
          );
        }).toList();

        final steps = <AiPlanStep>[];
        for (var i = 0; i < ops.length; i++) {
          final op = ops[i];
          steps.add(AiPlanStep(
            stepNumber: i + 1,
            title: op.summary,
            description: op.name,
            badgeText: 'Step ${i + 1}',
            isDestructive: op.requiresApproval,
          ));
        }

        return AiPlan(
          reply: body['reply'] is String ? body['reply'] as String : null,
          operations: ops,
          steps: steps,
          affectedCount: ops.length,
          sourcePath: '',
          destinationPath: '',
          estimatedSeconds: (ops.length * 0.5).ceil().clamp(1, 10),
          previewFiles: ops
              .map((op) => op.input['newName']?.toString() ?? op.input['path']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .take(3)
              .toList(),
        );
      }
    } catch (e) {
      debugPrint('Mobile plan server call failed: $e');
      if (!isDemoMode) rethrow;
    }

    return _generateLocalPlan(instruction);
  }

  AiPlan _generateLocalPlan(String instruction) {
    final lower = instruction.toLowerCase();
    final batchMatch = RegExp(
      r'rename\s+(?:all\s+)?(images?|photos?|pics?|files?|videos?|docs?|documents?)(?:\s+(?:starting\s+)?(?:from|form|to|as|like)\s+([a-zA-Z]+)(?:_(\d+)|\s+(\d+))?)?',
      caseSensitive: false,
    ).firstMatch(instruction);

    if (batchMatch != null) {
      final prefix = batchMatch.group(2) ?? 'image';
      final startIdx = int.tryParse(batchMatch.group(3) ?? batchMatch.group(4) ?? '1') ?? 1;
      return AiPlan(
        reply: 'I will rename all images starting from ${prefix}_$startIdx sequentially till the end.',
        operations: [
          PlannedOperation(
            id: 'op-local-1',
            name: 'rename_file',
            input: {'path': 'image.jpg', 'newName': '${prefix}_$startIdx.jpg'},
            requiresApproval: true,
          ),
        ],
        steps: [
          AiPlanStep(
            stepNumber: 1,
            title: 'Rename images starting from ${prefix}_$startIdx',
            description: 'Apply sequential numbering',
            badgeText: 'Step 1',
            isDestructive: true,
          ),
        ],
      );
    }

    if (lower.contains('organize') || lower.contains('sort')) {
      return const AiPlan(
        reply: 'I will organize your files into category subfolders.',
        operations: [
          PlannedOperation(
            id: 'op-local-1',
            name: 'organize_files',
            input: {'sourceDirectory': '.', 'strategy': 'by_type'},
            requiresApproval: true,
          ),
        ],
        steps: [
          AiPlanStep(
            stepNumber: 1,
            title: 'Organize files into folders',
            description: 'Sort by Documents, Photos, Videos, etc.',
            badgeText: 'Step 1',
            isDestructive: true,
          ),
        ],
      );
    }

    return const AiPlan(
      reply:
          'I am ready to help manage your device files. You can ask me to rename files, organize into folders, or clean up duplicates.',
      operations: [],
      steps: [],
    );
  }

  Future<Map<String, dynamic>> bootstrap() {
    if (isDemoMode) {
      return Future.value({
        'user': {
          'id': currentUser?.id ?? 'demo-user',
          'email': currentUser?.email ?? 'alex.morgan@filemind.ai',
          'displayName': currentUser?.displayName ?? 'Alex Morgan',
        },
        'ai': {'status': 'ok', 'provider': 'groq'},
        'privacy': {'mode': 'on-device'},
      });
    }
    return _get('/api/mobile/bootstrap');
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(_uri('/api/health'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    if (token == null) {
      throw ApiException('Sign in before loading your account.');
    }
    try {
      final response = await http
          .get(_uri(path), headers: _headers)
          .timeout(const Duration(seconds: 10));
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (decoded is! Map) {
        throw ApiException('The server returned an invalid response.');
      }
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
        'Cannot reach backend at $baseUrl. If using USB, ensure adb reverse is running or use Wi-Fi IP.',
      );
    } on http.ClientException {
      throw ApiException(
        'Cannot reach backend at $baseUrl. Check that server is running and address is reachable.',
      );
    } on TimeoutException {
      throw ApiException(
        'The backend at $baseUrl took too long to respond. Check server connection.',
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
    if (authenticated && token == null) {
      throw ApiException('Sign in before using the AI assistant.');
    }
    try {
      final response = await http
          .post(_uri(path), headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (decoded is! Map) {
        throw ApiException('The server returned an invalid response.');
      }
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
        'Cannot reach backend at $baseUrl. If using USB, ensure adb reverse is running or use Wi-Fi IP.',
      );
    } on http.ClientException {
      throw ApiException(
        'Cannot reach backend at $baseUrl. Check that server is running and address is reachable.',
      );
    } on TimeoutException {
      throw ApiException(
        'The backend at $baseUrl took too long to respond. Check server connection.',
      );
    } on HttpException {
      throw ApiException('The backend connection was interrupted.');
    } on FormatException {
      throw ApiException('The backend returned invalid JSON.');
    }
  }
}
