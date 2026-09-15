 import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'services/api_client.dart';
import 'services/local_file_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartFileApp());
}

class SmartFileApp extends StatelessWidget {
  const SmartFileApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Smart File',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2457d6)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff7f8fc),
    ),
    home: const SmartFileHome(),
  );
}

enum _ItemAction { rename, move, delete }

class SmartFileHome extends StatefulWidget {
  const SmartFileHome({super.key});

  @override
  State<SmartFileHome> createState() => _SmartFileHomeState();
}

class _SmartFileHomeState extends State<SmartFileHome> {
  final _chatController = TextEditingController();
  final _searchController = TextEditingController();
  late final SmartFileApi _api;
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Choose a folder, then ask me to find or organize files. I will always ask before changing anything.',
      isUser: false,
      time: DateTime.now(),
    ),
  ];
  final List<LocalActivity> _activity = [];
  final List<PlannedOperation> _pendingOperations = [];

  LocalFileService? _files;
  String? _currentPath;
  List<FileEntry> _entries = [];
  bool _loadingFiles = false;
  bool _planning = false;
  String? _error;
  String? _activeInstruction;
  int _section = 0;

  @override
  void initState() {
    super.initState();
    _api = SmartFileApi();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _chooseFolder() async {
    final selected = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose a folder Smart File may manage',
    );
    if (selected != null) await _setRoot(selected);
  }

  Future<void> _setRoot(String root) async {
    if (!await Directory(root).exists()) return;
    setState(() {
      _files = LocalFileService(root);
      _currentPath = root;
      _entries = [];
      _error = null;
      _pendingOperations.clear();
    });
    await _loadDirectory(root);
    _addActivity('Allowed folder: $root');
  }

  Future<void> _loadDirectory([String? path]) async {
    final files = _files;
    final target = path ?? _currentPath;
    if (files == null || target == null) return;
    setState(() {
      _loadingFiles = true;
      _error = null;
    });
    try {
      final entries = await files.listDirectory(target);
      if (!mounted) return;
      setState(() {
        _currentPath = target;
        _entries = entries;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  Future<void> _goUp() async {
    final files = _files;
    final path = _currentPath;
    if (files == null ||
        path == null ||
        p.equals(p.normalize(path), p.normalize(files.rootPath))) {
      return;
    }
    await _loadDirectory(p.dirname(path));
  }

  List<FileEntry> get _visibleEntries {
    final query = _searchController.text.trim().toLowerCase();
    return query.isEmpty
        ? _entries
        : _entries
              .where((entry) => entry.name.toLowerCase().contains(query))
              .toList();
  }

  Future<void> _createFolder() async {
    final path = _currentPath;
    if (_files == null || path == null) return;
    final name = await _askForText(
      title: 'New folder',
      label: 'Folder name',
      action: 'Create',
    );
    if (name == null) return;
    try {
      await _files!.createFolder(path, name);
      _addActivity('Created folder “$name”');
      await _loadDirectory();
    } catch (error) {
      _showMessage(_friendlyError(error));
    }
  }

  Future<void> _handleItemAction(_ItemAction action, FileEntry entry) async {
    if (_files == null) return;
    switch (action) {
      case _ItemAction.rename:
        final name = await _askForText(
          title: 'Rename',
          label: 'New name',
          initialValue: entry.name,
          action: 'Rename',
        );
        if (name == null || name == entry.name) return;
        try {
          await _files!.rename(entry.path, name);
          _addActivity('Renamed “${entry.name}” to “$name”');
          await _loadDirectory();
        } catch (error) {
          _showMessage(_friendlyError(error));
        }
        return;
      case _ItemAction.move:
        final folder = await FilePicker.getDirectoryPath(
          dialogTitle: 'Choose destination within your allowed folder',
        );
        if (folder == null) return;
        try {
          await _files!.move(entry.path, p.join(folder, entry.name));
          _addActivity('Moved “${entry.name}”');
          await _loadDirectory();
        } catch (error) {
          _showMessage(_friendlyError(error));
        }
        return;
      case _ItemAction.delete:
        final approved = await _confirm(
          'Delete ${entry.name}?',
          entry.kind == FileEntryKind.folder
              ? 'This permanently deletes the folder and its contents.'
              : 'This permanently deletes the file.',
          confirmText: 'Delete',
          destructive: true,
        );
        if (!approved) return;
        try {
          await _files!.delete(entry.path);
          _addActivity('Deleted “${entry.name}”');
          await _loadDirectory();
        } catch (error) {
          _showMessage(_friendlyError(error));
        }
        return;
    }
  }

  Future<void> _sendChat() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _planning) return;
    if (_files == null) {
      _showMessage('Choose an allowed folder before using the assistant.');
      return;
    }
    if (_api.token == null) {
      await _showAccountDialog();
      if (_api.token == null) return;
    }
    _chatController.clear();
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, time: DateTime.now()),
      );
      _planning = true;
      _activeInstruction =
          '$text\n\nYou are planning actions for a local file manager. Only use the allowed folder "${_files!.rootPath}" and its children. Never use read_file. Prefer metadata-only inspection. move_file changes a file and must be proposed for explicit approval.';
    });
    await _continuePlan(const []);
  }

  Future<void> _continuePlan(
    List<Map<String, dynamic>> results, {
    int round = 0,
  }) async {
    final instruction = _activeInstruction;
    if (instruction == null) return;
    if (round >= 3) {
      _addAssistant(
        'I stopped after three planning rounds. Ask a more specific follow-up if you need more help.',
      );
      if (mounted) setState(() => _planning = false);
      return;
    }
    try {
      final plan = await _api.plan(instruction, results);
      if (plan.reply != null && plan.reply!.trim().isNotEmpty) {
        _addAssistant(plan.reply!);
      }
      final approvals = plan.operations
          .where((operation) => operation.requiresApproval)
          .toList();
      final reads = plan.operations
          .where((operation) => !operation.requiresApproval)
          .toList();
      if (approvals.isNotEmpty && mounted) {
        setState(() {
          _pendingOperations.addAll(approvals);
          _planning = false;
        });
      }
      if (reads.isEmpty) {
        if (approvals.isEmpty && mounted) setState(() => _planning = false);
        return;
      }
      final nextResults = <Map<String, dynamic>>[];
      for (final operation in reads) {
        nextResults.add(await _executeOperation(operation));
      }
      await _continuePlan(nextResults, round: round + 1);
    } on ApiException catch (error) {
      _addAssistant(error.message);
      if (mounted) setState(() => _planning = false);
    } catch (error) {
      _addAssistant(_friendlyError(error));
      if (mounted) setState(() => _planning = false);
    }
  }

  Future<Map<String, dynamic>> _executeOperation(
    PlannedOperation operation,
  ) async {
    try {
      final files = _files!;
      switch (operation.name) {
        case 'list_directory':
          final path = operation.input['path'] as String;
          final entries = await files.listDirectory(path);
          return _success(operation.id, {
            'path': path,
            'items': entries.take(50).map(_entryJson).toList(),
          });
        case 'search_files':
          final matches = await files.search(
            operation.input['query'] as String,
          );
          return _success(operation.id, {
            'items': matches.map(_entryJson).toList(),
          });
        case 'get_file_metadata':
          return _success(
            operation.id,
            _entryJson(await files.metadata(operation.input['path'] as String)),
          );
        case 'move_file':
          await files.move(
            operation.input['sourcePath'] as String,
            operation.input['destinationPath'] as String,
          );
          _addActivity(
            'AI moved “${p.basename(operation.input['sourcePath'] as String)}”',
          );
          await _loadDirectory();
          return _success(operation.id, {'completed': true});
        default:
          return _failure(
            operation.id,
            'This operation is not available in the app.',
          );
      }
    } catch (error) {
      return _failure(operation.id, _friendlyError(error));
    }
  }

  Map<String, dynamic> _entryJson(FileEntry entry) => {
    'name': entry.name,
    'path': entry.path,
    'kind': entry.kind.name,
    'sizeBytes': entry.sizeBytes,
    'modified': entry.modified.toIso8601String(),
  };
  Map<String, dynamic> _success(String id, Object data) => {
    'callId': id,
    'ok': true,
    'data': data,
  };
  Map<String, dynamic> _failure(String id, String message) => {
    'callId': id,
    'ok': false,
    'data': {'message': message},
  };

  Future<void> _approveOperation(PlannedOperation operation) async {
    final approved = await _confirm(
      'Approve file change?',
      operation.summary,
      confirmText: 'Approve',
    );
    if (!approved) {
      setState(() => _pendingOperations.remove(operation));
      _addActivity('Rejected AI proposal: ${operation.summary}');
      return;
    }
    setState(() {
      _pendingOperations.remove(operation);
      _planning = true;
    });
    await _continuePlan([await _executeOperation(operation)]);
  }

  void _addAssistant(String text) {
    if (mounted) {
      setState(
        () => _messages.add(
          ChatMessage(text: text, isUser: false, time: DateTime.now()),
        ),
      );
    }
  }

  void _addActivity(String text) {
    if (mounted) {
      setState(
        () => _activity.insert(
          0,
          LocalActivity(text: text, time: DateTime.now()),
        ),
      );
    }
  }

  Future<String?> _askForText({
    required String title,
    required String label,
    required String action,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(action),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirm(
    String title,
    String content, {
    required String confirmText,
    bool destructive = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmText),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _showAccountDialog() async {
    final email = TextEditingController();
    final name = TextEditingController();
    final password = TextEditingController();
    var isRegistering = false;
    var loading = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isRegistering ? 'Create account' : 'Sign in'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRegistering)
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                  ),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading
                  ? null
                  : () => setDialogState(() => isRegistering = !isRegistering),
              child: Text(
                isRegistering ? 'I already have an account' : 'Create account',
              ),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      setDialogState(() {
                        loading = true;
                        error = null;
                      });
                      try {
                        if (isRegistering) {
                          await _api.register(
                            email: email.text.trim(),
                            displayName: name.text.trim(),
                            password: password.text,
                          );
                        } else {
                          await _api.login(
                            email: email.text.trim(),
                            password: password.text,
                          );
                        }
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          _showMessage('Signed in. Your AI session is ready.');
                        }
                      } on ApiException catch (exception) {
                        setDialogState(() => error = exception.message);
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => loading = false);
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isRegistering ? 'Create account' : 'Sign in'),
            ),
          ],
        ),
      ),
    );
    email.dispose();
    name.dispose();
    password.dispose();
  }

  Future<void> _showSettings() async {
    final controller = TextEditingController(text: _api.baseUrl);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection settings'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Backend URL',
                  hintText: 'http://192.168.x.x:4000',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'For a physical Android phone, use your computer’s LAN address and start the backend with HOST=0.0.0.0. Do not put an AI key in this app.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _api.baseUrl = controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  String _friendlyError(Object error) {
    if (error is ApiException || error is FileScopeException) {
      return error.toString();
    }
    if (error is FileSystemException) return error.message;
    return 'That operation could not be completed.';
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 760;
    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: 'Files',
      ),
      NavigationDestination(
        icon: Icon(Icons.auto_awesome_outlined),
        selectedIcon: Icon(Icons.auto_awesome),
        label: 'Assistant',
      ),
      NavigationDestination(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history),
        label: 'Activity',
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, size: 21),
            SizedBox(width: 8),
            Text('Smart File'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showAccountDialog,
            tooltip: _api.token == null ? 'Sign in' : 'Account',
            icon: Icon(
              _api.token == null
                  ? Icons.account_circle_outlined
                  : Icons.verified_user_outlined,
            ),
          ),
          IconButton(
            onPressed: _showSettings,
            tooltip: 'Connection settings',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Row(
        children: [
          if (desktop)
            NavigationRail(
              selectedIndex: _section,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (index) =>
                  setState(() => _section = index),
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: IconButton.filledTonal(
                  onPressed: _chooseFolder,
                  tooltip: 'Choose folder',
                  icon: const Icon(Icons.drive_folder_upload_outlined),
                ),
              ),
              destinations: destinations
                  .map(
                    (item) => NavigationRailDestination(
                      icon: item.icon,
                      selectedIcon: item.selectedIcon,
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSection(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: _section,
              onDestinationSelected: (index) =>
                  setState(() => _section = index),
              destinations: destinations,
            ),
      floatingActionButton: desktop || _section != 0
          ? null
          : FloatingActionButton(
              onPressed: _chooseFolder,
              tooltip: 'Choose folder',
              child: const Icon(Icons.folder_open),
            ),
    );
  }

  Widget _buildSection() => _section == 0
      ? _buildFiles()
      : _section == 1
      ? _buildAssistant()
      : _buildActivity();

  Widget _buildFiles() {
    if (_files == null || _currentPath == null) {
      return _emptyState(
        Icons.folder_open_outlined,
        'Choose a folder to begin',
        'Smart File only sees the folder you select and its children.',
        'Choose folder',
        _chooseFolder,
      );
    }
    final entries = _visibleEntries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Files',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _chooseFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('Change folder'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _loadingFiles ? null : _loadDirectory,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  onPressed: _goUp,
                  tooltip: 'Up',
                  icon: const Icon(Icons.arrow_upward),
                ),
                Expanded(
                  child: Text(
                    _currentPath!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _createFolder,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('New folder'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Filter this folder',
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        if (_error != null) _errorBanner(_error!),
        Expanded(
          child: _loadingFiles
              ? const Center(child: CircularProgressIndicator())
              : entries.isEmpty
              ? const Center(child: Text('This folder is empty.'))
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return ListTile(
                      onTap: entry.kind == FileEntryKind.folder
                          ? () => _loadDirectory(entry.path)
                          : null,
                      leading: Icon(
                        entry.kind == FileEntryKind.folder
                            ? Icons.folder_rounded
                            : Icons.insert_drive_file_outlined,
                        color: entry.kind == FileEntryKind.folder
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(entry.name),
                      subtitle: Text(
                        '${entry.kind == FileEntryKind.folder ? 'Folder' : _formatBytes(entry.sizeBytes)} · ${_formatDate(entry.modified)}',
                      ),
                      trailing: PopupMenuButton<_ItemAction>(
                        onSelected: (action) =>
                            _handleItemAction(action, entry),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _ItemAction.rename,
                            child: Text('Rename'),
                          ),
                          PopupMenuItem(
                            value: _ItemAction.move,
                            child: Text('Move'),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem(
                            value: _ItemAction.delete,
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAssistant() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI assistant',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  _api.token == null
                      ? 'Sign in to use your configured backend.'
                      : 'The assistant can only plan actions inside your allowed folder.',
                ),
              ],
            ),
          ),
          if (_api.token == null)
            FilledButton(
              onPressed: _showAccountDialog,
              child: const Text('Sign in'),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (_pendingOperations.isNotEmpty) _approvalPanel(),
      Expanded(
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_planning ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final message = _messages[index];
              return Align(
                alignment: message.isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxWidth: 620),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(message.text),
                ),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              enabled: !_planning,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => _sendChat(),
              decoration: const InputDecoration(
                hintText: 'Example: Organize my reports into Documents',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _planning ? null : _sendChat,
            tooltip: 'Send',
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    ],
  );

  Widget _approvalPanel() => Card(
    color: Theme.of(context).colorScheme.tertiaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Approval required',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'The AI cannot make these changes unless you approve each one.',
          ),
          const SizedBox(height: 8),
          ..._pendingOperations.map(
            (operation) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber_rounded),
              title: Text(operation.summary),
              trailing: FilledButton(
                onPressed: () => _approveOperation(operation),
                child: const Text('Review'),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildActivity() => _activity.isEmpty
      ? _emptyState(
          Icons.history,
          'No activity yet',
          'Manual and approved AI file operations will appear here.',
          'Browse files',
          () => setState(() => _section = 0),
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _activity.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final item = _activity[index];
                  return ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(item.text),
                    subtitle: Text(_formatDate(item.time)),
                  );
                },
              ),
            ),
          ],
        );

  Widget _emptyState(
    IconData icon,
    String title,
    String description,
    String action,
    VoidCallback onPressed,
  ) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton(onPressed: onPressed, child: Text(action)),
        ],
      ),
    ),
  );
  Widget _errorBanner(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: MaterialBanner(
      content: Text(text),
      actions: [
        TextButton(onPressed: _loadDirectory, child: const Text('Retry')),
      ],
    ),
  );
  String _formatBytes(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : bytes < 1024 * 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
