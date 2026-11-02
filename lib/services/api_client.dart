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
      : baseUrl = baseUrl ?? 'http://127.0.0.1:8000' {
    if (baseUrl == null) {
      _loadPersistedBaseUrl();
    }
  }

  static final List<String> _candidatePrefFiles = [
    '/data/user/0/com.smartfile.app/files/smartfile_api_config.json',
    '/data/user/0/com.smartfile.app/app_flutter/smartfile_api_config.json',
    '${Directory.systemTemp.path}/smartfile_api_config.json',
  ];

  void _loadPersistedBaseUrl() {
    for (final path in _candidatePrefFiles) {
      try {
        final f = File(path);
        if (f.existsSync()) {
          final data = jsonDecode(f.readAsStringSync());
          if (data is Map &&
              data['baseUrl'] is String &&
              (data['baseUrl'] as String).isNotEmpty) {
            baseUrl = data['baseUrl'] as String;
            return;
          }
        }
      } catch (_) {}
    }
  }

  void persistBaseUrl(String url) {
    baseUrl = url.trim();
    for (final path in _candidatePrefFiles) {
      try {
        final f = File(path);
        if (!f.parent.existsSync()) {
          f.parent.createSync(recursive: true);
        }
        f.writeAsStringSync(jsonEncode({'baseUrl': baseUrl}));
      } catch (_) {}
    }
  }

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

  Future<String?> pingServer() async {
    try {
      final response = await http
          .get(_uri('/api/health'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null; // Successfully reached
      }
      return 'Server reached, but returned status ${response.statusCode}';
    } on SocketException catch (e) {
      return 'Cannot reach $baseUrl (${e.osError?.message ?? e.message}).\n'
          '• If using USB: run "adb reverse tcp:8000 tcp:8000" on PC.\n'
          '• If using Wi-Fi: use PC IP (http://192.168.45.231:8000).';
    } on TimeoutException {
      return 'Connection timed out to $baseUrl. Check PC firewall or IP address.';
    } catch (e) {
      return 'Connection failed: $e';
    }
  }

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

  Future<UserAccount> fetchCurrentUser() async {
    if (isDemoMode && currentUser != null) {
      return currentUser!;
    }
    final body = await _get('/api/auth/me');
    final rawUser = body['user'];
    if (rawUser is Map) {
      currentUser = UserAccount(
        id: rawUser['id']?.toString() ?? 'user-1',
        email: rawUser['email']?.toString() ?? '',
        displayName: rawUser['displayName']?.toString() ?? 'User',
      );
      return currentUser!;
    }
    throw ApiException('The server did not return a valid user profile.');
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
    final activeToken = token;
    final wasDemo = isDemoMode;
    token = null;
    currentUser = null;
    isDemoMode = false;

    if (activeToken != null && !wasDemo) {
      unawaited(
        http
            .post(
              _uri('/api/auth/logout'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $activeToken',
              },
            )
            .timeout(const Duration(seconds: 5))
            .catchError((_) => http.Response('', 500)),
      );
    }
  }

  Future<AiPlan> plan(
    String instruction,
    List<Map<String, dynamic>> results, {
    String? conversationId,
  }) async {
    try {
      Map<String, dynamic> body;
      if (token != null && !isDemoMode) {
        try {
          body = await _post('/api/ai/instructions', {
            'instruction': instruction,
            if (conversationId != null && conversationId.isNotEmpty)
              'conversationId': conversationId,
          });
        } catch (_) {
          body = await _post('/api/mobile/plan', {
            'instruction': instruction,
            if (results.isNotEmpty) 'toolResults': results,
          });
        }
      } else {
        body = await _post('/api/mobile/plan', {
          'instruction': instruction,
          if (results.isNotEmpty) 'toolResults': results,
        });
      }

      final rawOperations = body['operations'];
      if (rawOperations is List) {
        final ops = rawOperations.whereType<Map>().map((raw) {
          final map = Map<String, dynamic>.from(raw);
          return PlannedOperation(
            id: map['id']?.toString() ??
                'op-${DateTime.now().millisecondsSinceEpoch}',
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

        String? src;
        String? dst;
        if (ops.isNotEmpty) {
          final first = ops.first;
          if (first.name == 'rename_file') {
            src = first.input['path']?.toString();
            final last = ops.last;
            dst = '${first.input['newName']} ... ${last.input['newName']}';
          } else if (first.name == 'move_file') {
            src = first.input['sourcePath']?.toString() ??
                first.input['path']?.toString();
            dst = first.input['destinationPath']?.toString();
          } else if (first.name == 'organize_files') {
            src = first.input['sourceDirectory']?.toString() ?? 'Target folder';
            dst = 'Category subfolders';
          } else if (first.name == 'delete_file' || first.name == 'delete_item') {
            src = first.input['path']?.toString();
            dst = 'Permanent deletion';
          }
        }

        return AiPlan(
          reply: body['reply'] is String ? body['reply'] as String : null,
          operations: ops,
          steps: steps,
          affectedCount: ops.length,
          sourcePath: src ?? '',
          destinationPath: dst ?? '',
          estimatedSeconds: (ops.length * 0.5).ceil().clamp(1, 10),
          conversationId: body['conversationId']?.toString() ?? conversationId,
          previewFiles: ops
              .map((op) =>
                  op.input['newName']?.toString() ??
                  op.input['path']?.toString() ??
                  '')
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

  static final List<String> _candidateHistoryFiles = [
    '/data/user/0/com.smartfile.app/files/smartfile_chat_conversations.json',
    '/data/user/0/com.smartfile.app/app_flutter/smartfile_chat_conversations.json',
    '${Directory.systemTemp.path}/smartfile_chat_conversations.json',
  ];

  List<ChatConversation> loadLocalConversations() {
    for (final path in _candidateHistoryFiles) {
      try {
        final f = File(path);
        if (f.existsSync()) {
          final data = jsonDecode(f.readAsStringSync());
          if (data is List) {
            return data
                .whereType<Map>()
                .map((m) =>
                    ChatConversation.fromJson(Map<String, dynamic>.from(m)))
                .toList();
          }
        }
      } catch (_) {}
    }
    return [];
  }

  void saveLocalConversations(List<ChatConversation> conversations) {
    for (final path in _candidateHistoryFiles) {
      try {
        final f = File(path);
        if (!f.parent.existsSync()) {
          f.parent.createSync(recursive: true);
        }
        final raw = jsonEncode(conversations.map((c) => c.toJson()).toList());
        f.writeAsStringSync(raw);
      } catch (_) {}
    }
  }

  Future<List<ChatConversation>> fetchRemoteConversations() async {
    if (isDemoMode || token == null) return [];
    try {
      final response = await http
          .get(_uri('/api/ai/conversations'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final list = <ChatConversation>[];
          for (final item in decoded) {
            if (item is Map) {
              list.add(ChatConversation(
                id: item['id']?.toString() ?? '',
                title: item['title']?.toString() ?? 'Conversation',
                createdAt: DateTime.tryParse(item['createdAt']?.toString() ?? '') ??
                    DateTime.now(),
                updatedAt: DateTime.tryParse(item['updatedAt']?.toString() ?? '') ??
                    DateTime.now(),
              ));
            }
          }
          return list;
        }
      }
      return [];
    } catch (e) {
      debugPrint('fetchRemoteConversations failed: $e');
      return [];
    }
  }

  Future<ChatConversation?> fetchRemoteConversationDetail(
      String conversationId) async {
    if (isDemoMode || token == null) return null;
    try {
      final body = await _get('/api/ai/conversations/$conversationId');
      final rawMessages = body['messages'] as List? ?? [];
      final msgs = <ChatMessage>[];

      for (final m in rawMessages) {
        if (m is! Map) continue;
        final role = m['role']?.toString();
        final content = m['content']?.toString() ?? '';
        final isUser = role == 'user';
        final time =
            DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now();

        AiPlan? plan;
        final rawToolCalls = m['toolCalls'] as List? ?? [];
        if (rawToolCalls.isNotEmpty) {
          final ops = rawToolCalls.whereType<Map>().map((raw) {
            final map = Map<String, dynamic>.from(raw);
            return PlannedOperation(
              id: map['id']?.toString() ??
                  'op-${DateTime.now().millisecondsSinceEpoch}',
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

          String? src;
          String? dst;
          if (ops.isNotEmpty) {
            final first = ops.first;
            if (first.name == 'rename_file') {
              src = first.input['path']?.toString();
              final last = ops.last;
              dst = '${first.input['newName']} ... ${last.input['newName']}';
            } else if (first.name == 'move_file') {
              src = first.input['sourcePath']?.toString() ??
                  first.input['path']?.toString();
              dst = first.input['destinationPath']?.toString();
            } else if (first.name == 'organize_files') {
              src = first.input['sourceDirectory']?.toString() ?? 'Target folder';
              dst = 'Category subfolders';
            } else if (first.name == 'delete_file' || first.name == 'delete_item') {
              src = first.input['path']?.toString();
              dst = 'Permanent deletion';
            }
          }

          plan = AiPlan(
            reply: content,
            operations: ops,
            steps: steps,
            affectedCount: ops.length,
            sourcePath: src ?? '',
            destinationPath: dst ?? '',
            estimatedSeconds: (ops.length * 0.5).ceil().clamp(1, 10),
            conversationId: conversationId,
            previewFiles: ops
                .map((op) =>
                    op.input['newName']?.toString() ??
                    op.input['path']?.toString() ??
                    '')
                .where((s) => s.isNotEmpty)
                .take(3)
                .toList(),
          );
        }

        msgs.add(ChatMessage(
          text: content,
          isUser: isUser,
          time: time,
          plan: plan,
        ));
      }

      return ChatConversation(
        id: body['id']?.toString() ?? conversationId,
        title: body['title']?.toString() ?? 'Conversation',
        createdAt:
            DateTime.tryParse(body['createdAt']?.toString() ?? '') ?? DateTime.now(),
        updatedAt:
            DateTime.tryParse(body['updatedAt']?.toString() ?? '') ?? DateTime.now(),
        messages: msgs,
      );
    } catch (e) {
      debugPrint('fetchRemoteConversationDetail failed: $e');
      return null;
    }
  }

  Future<bool> deleteRemoteConversation(String conversationId) async {
    if (isDemoMode || token == null) return true;
    try {
      final response = await http
          .delete(_uri('/api/ai/conversations/$conversationId'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
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

  Future<Map<String, dynamic>> capabilities() {
    if (isDemoMode) {
      return Future.value({
        'protocolVersion': '1',
        'execution': 'client-side',
        'operations': [],
      });
    }
    return _get('/api/mobile/capabilities');
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(_uri('/api/health'))
          .timeout(const Duration(seconds: 10));
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
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot reach backend at $baseUrl (${e.osError?.message ?? e.message}).\n'
        '• If using USB: run "adb reverse tcp:8000 tcp:8000" on PC.\n'
        '• If using Wi-Fi: set Server URL to http://192.168.45.231:8000',
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
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot reach backend at $baseUrl (${e.osError?.message ?? e.message}).\n'
        '• If using USB: run "adb reverse tcp:8000 tcp:8000" on PC.\n'
        '• If using Wi-Fi: set Server URL to http://192.168.45.231:8000',
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
