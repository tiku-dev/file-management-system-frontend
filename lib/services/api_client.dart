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
      : baseUrl = baseUrl ??
            (Platform.isAndroid
                ? 'http://10.0.2.2:4000'
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
    if (isDemoMode) {
      return _generateDemoPlan(instruction);
    }

    final body = await _post('/api/mobile/plan', {
      'instruction': instruction,
      if (results.isNotEmpty) 'toolResults': results,
    });
    final rawOperations = body['operations'];
    if (rawOperations is! List) {
      throw ApiException('The server returned an invalid AI plan.');
    }

    final ops = rawOperations.whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      return PlannedOperation(
        id: map['id'] as String,
        name: map['name'] as String,
        input: Map<String, dynamic>.from(map['input'] as Map),
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
      steps: steps.isNotEmpty ? steps : _defaultStepsForInstruction(instruction),
      affectedCount: ops.isNotEmpty ? ops.length : 14,
      sourcePath: '/Downloads',
      destinationPath: '/Documents',
      estimatedSeconds: 6,
      previewFiles: const ['Invoice-Mar.pdf', 'Contract.pdf'],
    );
  }

  AiPlan _generateDemoPlan(String instruction) {
    final lower = instruction.toLowerCase();
    if (lower.contains('pdf') || lower.contains('download') || lower.contains('move')) {
      return const AiPlan(
        reply: "Found 14 PDFs in Downloads. Here's my plan:",
        operations: [
          PlannedOperation(
            id: 'demo-op-1',
            name: 'move_file',
            input: {
              'sourcePath': '/Downloads/CS-Lecture-Notes.pdf',
              'destinationPath': '/Documents/CS-Lecture-Notes.pdf',
            },
            requiresApproval: true,
          ),
          PlannedOperation(
            id: 'demo-op-2',
            name: 'rename_file',
            input: {
              'path': '/Documents/CS-Lecture-Notes.pdf',
              'newName': '2026-09-16_CS-Lecture-Notes.pdf',
            },
            requiresApproval: true,
          ),
          PlannedOperation(
            id: 'demo-op-3',
            name: 'delete_item',
            input: {'path': '/Downloads/EmptyFolder'},
            requiresApproval: true,
          ),
        ],
        steps: [
          AiPlanStep(
            stepNumber: 1,
            title: 'Move 14 files → Documents',
            description: 'Source: /Downloads, Destination: /Documents',
            badgeText: 'Step 1',
          ),
          AiPlanStep(
            stepNumber: 2,
            title: 'Rename → prefix "2026-09-08_*"',
            description: 'Apply current date prefix to organized PDFs',
            badgeText: 'Step 2',
          ),
          AiPlanStep(
            stepNumber: 3,
            title: 'Archive original folder to Trash',
            description: 'Cleanup residual empty download artifacts',
            badgeText: 'Step 3',
            isDestructive: true,
          ),
        ],
        affectedCount: 14,
        sourcePath: '/Downloads',
        destinationPath: '/Documents',
        estimatedSeconds: 6,
        previewFiles: ['Invoice-Mar.pdf', 'Contract.pdf'],
      );
    }

    return AiPlan(
      reply: 'I analyzed your request. Here is what I can do:',
      operations: [
        PlannedOperation(
          id: 'demo-op-1',
          name: 'organize_files',
          input: {
            'sourceDirectory': '/Documents',
            'strategy': 'by_type',
          },
          requiresApproval: true,
        ),
      ],
      steps: const [
        AiPlanStep(
          stepNumber: 1,
          title: 'Scan and categorize documents',
          description: 'Categorize files by extension and date',
          badgeText: 'Step 1',
        ),
      ],
      affectedCount: 8,
      sourcePath: '/Documents',
      destinationPath: '/Documents/Organized',
      estimatedSeconds: 4,
      previewFiles: const ['CS-Lecture-Notes-W3.pdf', 'Budget-Tracker-Q4.xlsx'],
    );
  }

  List<AiPlanStep> _defaultStepsForInstruction(String instruction) {
    return const [
      AiPlanStep(
        stepNumber: 1,
        title: 'Move 14 files → Documents',
        description: 'Source: /Downloads, Destination: /Documents',
        badgeText: 'Step 1',
      ),
      AiPlanStep(
        stepNumber: 2,
        title: 'Rename → prefix "2026-09-08_*"',
        description: 'Apply date prefix to files',
        badgeText: 'Step 2',
      ),
      AiPlanStep(
        stepNumber: 3,
        title: 'Archive original folder to Trash',
        description: 'Cleanup original folder',
        badgeText: 'Step 3',
        isDestructive: true,
      ),
    ];
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

  Future<Map<String, dynamic>> _get(String path) async {
    if (token == null) {
      throw ApiException('Sign in before loading your account.');
    }
    try {
      final response = await http
          .get(_uri(path), headers: _headers)
          .timeout(const Duration(seconds: 15));
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
    if (authenticated && token == null) {
      throw ApiException('Sign in before using the AI assistant.');
    }
    try {
      final response = await http
          .post(_uri(path), headers: _headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 30));
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
