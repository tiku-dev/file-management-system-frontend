import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'services/api_client.dart';
import 'services/local_file_service.dart';

const _violet = Color(0xff6046e8);
const _purple = Color(0xff7a3de2);
const _ink = Color(0xff17213b);
const _muted = Color(0xff75809a);
const _surface = Color(0xfff9f9fc);

void main() => runApp(const SmartFileApp());

class SmartFileApp extends StatefulWidget {
  const SmartFileApp({super.key});

  @override
  State<SmartFileApp> createState() => _SmartFileAppState();
}

class _SmartFileAppState extends State<SmartFileApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart File',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _violet,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: _surface,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _violet,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff101118),
      ),
      home: SmartFileHome(
        isDark: _themeMode == ThemeMode.dark,
        onDarkModeChanged: (value) => setState(
          () => _themeMode = value ? ThemeMode.dark : ThemeMode.light,
        ),
      ),
    );
  }
}

enum _ItemAction { rename, move, delete }

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.api});

  final SmartFileApi api;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _closed = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await widget.api.register(
          email: _emailController.text.trim(),
          displayName: _nameController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await widget.api.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      if (!mounted) return;
      _closed = true;
      Navigator.of(context).pop(true);
    } on ApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } catch (exception) {
      if (mounted) setState(() => _error = 'Account request failed: $exception');
    } finally {
      if (mounted && !_closed) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_register ? 'Create account' : 'Sign in'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_register)
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _register = !_register;
                  _error = null;
                }),
          child: Text(_register ? 'I have an account' : 'Register'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_register ? 'Create account' : 'Sign in'),
        ),
      ],
    );
  }
}

class SmartFileHome extends StatefulWidget {
  const SmartFileHome({
    super.key,
    required this.isDark,
    required this.onDarkModeChanged,
  });

  final bool isDark;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<SmartFileHome> createState() => _SmartFileHomeState();
}

class _SmartFileHomeState extends State<SmartFileHome> {
  final _chatController = TextEditingController();
  final _searchController = TextEditingController();
  final _settingsUrlController = TextEditingController();
  late final SmartFileApi _api;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'I can organize, search, rename, and move files in your selected folder.',
      isUser: false,
      time: DateTime.now(),
    ),
  ];
  final List<LocalActivity> _activity = [];

  LocalFileService? _files;
  String? _currentPath;
  List<FileEntry> _entries = [];
  List<FileEntry> _searchResults = [];
  List<PlannedOperation> _pendingOperations = [];
  Map<String, dynamic>? _bootstrap;
  String? _bootstrapError;
  String? _error;
  String? _activeInstruction;
  bool _loadingFiles = false;
  bool _searching = false;
  bool _planning = false;
  bool _autoOrganize = true;
  bool _deleteDuplicates = false;
  int _section = 0;

  @override
  void initState() {
    super.initState();
    _api = SmartFileApi();
    _settingsUrlController.text = _api.baseUrl;
  }

  @override
  void dispose() {
    _chatController.dispose();
    _searchController.dispose();
    _settingsUrlController.dispose();
    super.dispose();
  }

  Future<void> _chooseFolder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null || path.trim().isEmpty) return;
    _files = LocalFileService(path);
    _currentPath = path;
    await _loadDirectory(path);
  }

  Future<void> _loadDirectory(String path) async {
    final service = _files;
    if (service == null) return;
    setState(() {
      _loadingFiles = true;
      _error = null;
    });
    try {
      final entries = await service.listDirectory(path);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _currentPath = path;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  Future<void> _goUp() async {
    final service = _files;
    final current = _currentPath;
    if (service == null ||
        current == null ||
        p.equals(current, service.rootPath))
      return;
    await _loadDirectory(p.dirname(current));
  }

  Future<void> _createFolder() async {
    final current = _currentPath;
    final service = _files;
    if (current == null || service == null) return;
    final name = await _askForText('New folder', 'Folder name');
    if (name == null) return;
    try {
      await service.createFolder(current, name);
      await _loadDirectory(current);
      _addActivity('Created folder $name');
    } catch (error) {
      _showMessage(_friendlyError(error));
    }
  }

  Future<void> _handleItemAction(FileEntry item, _ItemAction action) async {
    final service = _files;
    if (service == null) return;
    try {
      if (action == _ItemAction.rename) {
        final name = await _askForText(
          'Rename item',
          'New name',
          initial: item.name,
        );
        if (name == null) return;
        await service.rename(item.path, name);
        _addActivity('Renamed ${item.name}');
      } else if (action == _ItemAction.move) {
        final destination = await _askForText(
          'Move item',
          'Destination folder path',
          initial: p.dirname(item.path),
        );
        if (destination == null) return;
        await service.move(item.path, p.join(destination, item.name));
        _addActivity('Moved ${item.name}');
      } else {
        final confirmed = await _confirm(
          'Delete ${item.name}?',
          'This cannot be undone.',
        );
        if (!confirmed) return;
        await service.delete(item.path);
        _addActivity('Deleted ${item.name}');
      }
      final current = _currentPath;
      if (current != null) await _loadDirectory(current);
    } catch (error) {
      _showMessage(_friendlyError(error));
    }
  }

  Future<void> _runSearch(String query) async {
    final service = _files;
    if (service == null || query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await service.search(query);
      if (mounted) setState(() => _searchResults = results);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _loadBootstrap() async {
    if (_api.token == null) return;
    try {
      final bootstrap = await _api.bootstrap();
      if (!mounted) return;
      setState(() {
        _bootstrap = bootstrap;
        _bootstrapError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _bootstrapError = _friendlyError(error));
    }
  }

  Future<void> _sendChat([String? preset]) async {
    final instruction = (preset ?? _chatController.text).trim();
    if (instruction.isEmpty || _planning) return;
    if (_files == null) {
      _showMessage('Choose a folder before asking the assistant.');
      setState(() => _section = 1);
      return;
    }
    if (_api.token == null) {
      await _showAccountDialog();
      if (_api.token == null) return;
    }
    _chatController.clear();
    setState(() {
      _messages.add(
        ChatMessage(text: instruction, isUser: true, time: DateTime.now()),
      );
      _planning = true;
      _activeInstruction = instruction;
    });
    try {
      final plan = await _api.plan(instruction, const []);
      await _applyPlan(plan, const []);
    } catch (error) {
      _addAssistant(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _planning = false);
    }
  }

  Future<void> _applyPlan(
    AiPlan plan,
    List<Map<String, dynamic>> previousResults,
  ) async {
    if (plan.reply != null && plan.reply!.trim().isNotEmpty)
      _addAssistant(plan.reply!);
    final operations = plan.operations;
    if (operations.isEmpty) return;
    final results = <Map<String, dynamic>>[...previousResults];
    for (var index = 0; index < operations.length; index++) {
      final operation = operations[index];
      if (operation.requiresApproval) {
        if (!mounted) return;
        setState(() => _pendingOperations = operations.sublist(index));
        _addAssistant(
          'I prepared a safe step-by-step plan. Review it before I make any changes.',
        );
        return;
      }
      results.add(await _executeOperation(operation));
    }
    if (results.isNotEmpty && _activeInstruction != null) {
      final followUp = await _api.plan(_activeInstruction!, results);
      if (followUp.operations.isNotEmpty || (followUp.reply ?? '').isNotEmpty)
        await _applyPlan(followUp, results);
    }
  }

  Future<void> _approveOperation() async {
    if (_pendingOperations.isEmpty) return;
    final operation = _pendingOperations.first;
    setState(() {
      _pendingOperations = _pendingOperations.sublist(1);
      _planning = true;
    });
    try {
      final result = await _executeOperation(operation);
      if (_pendingOperations.isEmpty && _activeInstruction != null) {
        final followUp = await _api.plan(_activeInstruction!, [result]);
        await _applyPlan(followUp, [result]);
      }
    } catch (error) {
      _addAssistant(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _planning = false);
    }
  }

  void _skipOperation() {
    if (_pendingOperations.isEmpty) return;
    setState(() => _pendingOperations = _pendingOperations.sublist(1));
    _addAssistant('Skipped that step. Nothing was changed.');
  }

  Future<Map<String, dynamic>> _executeOperation(
    PlannedOperation operation,
  ) async {
    final service = _files;
    if (service == null) throw ApiException('Choose a folder first.');
    switch (operation.name) {
      case 'list_directory':
        final path = operation.input['path'] as String? ?? service.rootPath;
        final entries = await service.listDirectory(path);
        return {
          'operationId': operation.id,
          'items': entries.map((entry) => entry.name).toList(),
        };
      case 'search_files':
        final query = operation.input['query'] as String? ?? '';
        final entries = await service.search(query);
        return {
          'operationId': operation.id,
          'items': entries.map((entry) => entry.name).toList(),
        };
      case 'get_file_metadata':
        final path = operation.input['path'] as String? ?? service.rootPath;
        final entry = await service.metadata(path);
        return {
          'operationId': operation.id,
          'name': entry.name,
          'sizeBytes': entry.sizeBytes,
          'modified': entry.modified.toIso8601String(),
        };
      case 'move_file':
        final source = operation.input['sourcePath'] as String?;
        final destination = operation.input['destinationPath'] as String?;
        if (source == null || destination == null)
          throw ApiException(
            'The plan did not include a valid move destination.',
          );
        await service.move(source, destination);
        final current = _currentPath;
        if (current != null) await _loadDirectory(current);
        _addActivity('Moved ${p.basename(source)}');
        return {'operationId': operation.id, 'moved': true};
      default:
        throw ApiException('Unsupported assistant action: ${operation.name}');
    }
  }

  Future<void> _showAccountDialog() async {
    final authenticated =
        await showDialog<bool>(
          context: context,
          builder: (_) => _AccountDialog(api: _api),
        ) ??
        false;
    if (!mounted || !authenticated) return;
    await WidgetsBinding.instance.endOfFrame;
    await _loadBootstrap();
    if (mounted) _showMessage('Connected to Smart File AI.');
  }

  Future<String?> _askForText(
    String title,
    String label, {
      String initial = '',
    }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value?.isEmpty == true ? null : value;
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _addAssistant(String text) {
    if (!mounted) return;
    setState(
      () => _messages.add(
        ChatMessage(text: text, isUser: false, time: DateTime.now()),
      ),
    );
  }

  void _addActivity(String text) {
    if (!mounted) return;
    setState(
      () =>
          _activity.insert(0, LocalActivity(text: text, time: DateTime.now())),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object error) => error is ApiException
      ? error.message
      : error is FileScopeException
      ? error.message
      : error.toString().replaceFirst('FileSystemException: ', '');

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _relativeTime(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  bool get _backendConnected => _bootstrap != null;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 800;
    final content = _section == 0
        ? _buildHome()
        : _section == 1
        ? _buildBrowse()
        : _section == 2
        ? _buildSearch()
        : _section == 3
        ? _buildSettings()
        : _buildAssistant();
    return Scaffold(
      body: SafeArea(
        child: desktop
            ? Row(
                children: [
                  _buildRail(),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: _section > 3 ? 0 : _section,
              onDestinationSelected: (index) =>
                  setState(() => _section = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: 'Browse',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }

  Widget _buildRail() => NavigationRail(
    selectedIndex: _section > 3 ? 0 : _section,
    onDestinationSelected: (index) => setState(() => _section = index),
    labelType: NavigationRailLabelType.all,
    leading: Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          const Text(
            'Smart File',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Icon(Icons.auto_awesome, color: _violet, size: 30),
        ],
      ),
    ),
    destinations: const [
      NavigationRailDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: Text('Home'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: Text('Browse'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.search),
        label: Text('Search'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text('Settings'),
      ),
    ],
  );

  Widget _page({
    required String title,
    required Widget child,
    List<Widget> actions = const [],
  }) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            sliver: SliverToBoxAdapter(child: child),
          ),
        ],
      ),
    ),
  );

  Widget _buildHome() {
    final recent = [..._entries]
      ..sort((a, b) => b.modified.compareTo(a.modified));
    return _page(
      title: 'Files',
      actions: [
        IconButton(
          onPressed: () => setState(() => _section = 2),
          icon: const Icon(Icons.search),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'folder') _chooseFolder();
            if (value == 'account') _showAccountDialog();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'folder', child: Text('Change folder')),
            PopupMenuItem(value: 'account', child: Text('Account')),
          ],
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _storageCard(),
          const SizedBox(height: 14),
          _tipCard(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _quickAction(
                  Icons.cleaning_services_outlined,
                  'Clean up',
                  'Find duplicates',
                  () => _sendChat(
                    'Find duplicate files and show me a safe plan.',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickAction(
                  Icons.cloud_upload_outlined,
                  'Transfer',
                  'To cloud',
                  () => _showMessage(
                    'Cloud transfer is ready for the next API integration.',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _section = 1),
                child: const Text('See all'),
              ),
            ],
          ),
          if (recent.isEmpty)
            _emptyFolder()
          else
            ...recent.take(5).map(_recentTile),
          if (_activity.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ..._activity
                .take(3)
                .map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xffece9ff),
                      child: Icon(Icons.check, color: _violet),
                    ),
                    title: Text(item.text),
                    subtitle: Text(_relativeTime(item.time)),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _storageCard() {
    final used = _entries.fold<int>(
      0,
      (total, entry) => total + entry.sizeBytes,
    );
    final selected = _files != null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_violet, _purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _violet.withOpacity(.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'STORAGE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (selected)
                IconButton(
                  onPressed: () => _loadDirectory(_currentPath!),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
            ],
          ),
          Text(
            selected ? _formatBytes(used) : '0 B',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            selected
                ? 'in the selected folder'
                : 'Choose a folder to calculate storage',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(
              value: .22,
              minHeight: 8,
              backgroundColor: Color(0x55ffffff),
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _chooseFolder,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0x88ffffff)),
            ),
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(selected ? 'Change folder' : 'Choose folder'),
          ),
        ],
      ),
    );
  }

  Widget _tipCard() => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () => setState(() => _section = 4),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff0edff),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffd9d1ff)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: _violet,
            child: Icon(Icons.auto_awesome, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tip: ask the AI assistant to find duplicates or organize your files.',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.chevron_right, color: _violet),
        ],
      ),
    ),
  );

  Widget _quickAction(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _violet),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
        ],
      ),
    ),
  );

  Widget _emptyFolder() => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Icon(Icons.folder_open_outlined, size: 38, color: _muted),
          const SizedBox(height: 8),
          const Text(
            'Choose a folder to begin',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your files stay on this device.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _chooseFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose folder'),
          ),
        ],
      ),
    ),
  );

  Widget _recentTile(FileEntry entry) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: _fileIcon(entry, large: true),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_relativeTime(entry.modified)} · ${entry.kind == FileEntryKind.folder ? 'Folder' : _formatBytes(entry.sizeBytes)}',
      ),
      trailing: PopupMenuButton<_ItemAction>(
        onSelected: (action) => _handleItemAction(entry, action),
        itemBuilder: (context) => _itemMenu(),
      ),
    ),
  );

  List<PopupMenuEntry<_ItemAction>> _itemMenu() => const [
    PopupMenuItem(value: _ItemAction.rename, child: Text('Rename')),
    PopupMenuItem(value: _ItemAction.move, child: Text('Move')),
    PopupMenuItem(value: _ItemAction.delete, child: Text('Delete')),
  ];

  Widget _buildBrowse() {
    final folders = _entries
        .where((entry) => entry.kind == FileEntryKind.folder)
        .length;
    final files = _entries.length - folders;
    return _page(
      title: 'Browse',
      actions: [
        IconButton(
          onPressed: _chooseFolder,
          icon: const Icon(Icons.folder_open_outlined),
        ),
        IconButton(
          onPressed: _createFolder,
          icon: const Icon(Icons.create_new_folder_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pathBar(),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Smart'),
                selected: true,
                onSelected: (_) {},
              ),
              ChoiceChip(
                label: const Text('Recent'),
                selected: false,
                onSelected: (_) {},
              ),
              ChoiceChip(
                label: const Text('Starred'),
                selected: false,
                onSelected: (_) {},
              ),
              ChoiceChip(
                label: const Text('Downloads'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _categoryCard(
                  Icons.folder_copy_outlined,
                  'Folders',
                  '$folders',
                  const Color(0xffe8edff),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _categoryCard(
                  Icons.insert_drive_file_outlined,
                  'Files',
                  '$files',
                  const Color(0xffffeee4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'All items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              if (_loadingFiles)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_files == null)
            _emptyFolder()
          else if (_entries.isEmpty && !_loadingFiles)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: Text(
                  'This folder is empty.',
                  style: TextStyle(color: _muted),
                ),
              ),
            )
          else
            ..._entries.map((entry) => _browseTile(entry)),
        ],
      ),
    );
  }

  Widget _pathBar() => Card(
    elevation: 0,
    child: ListTile(
      leading: const Icon(Icons.folder, color: _violet),
      title: Text(
        _currentPath == null ? 'No folder selected' : p.basename(_currentPath!),
      ),
      subtitle: Text(
        _currentPath ?? 'Select a folder to browse locally',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _currentPath == null
          ? null
          : IconButton(onPressed: _goUp, icon: const Icon(Icons.arrow_upward)),
    ),
  );

  Widget _categoryCard(
    IconData icon,
    String label,
    String count,
    Color color,
  ) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: _violet),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(count, style: const TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      ],
    ),
  );

  Widget _browseTile(FileEntry entry) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(top: 8),
    child: ListTile(
      onTap: entry.kind == FileEntryKind.folder
          ? () => _loadDirectory(entry.path)
          : null,
      leading: _fileIcon(entry),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${entry.kind == FileEntryKind.folder ? 'Folder' : _formatBytes(entry.sizeBytes)} · ${_relativeTime(entry.modified)}',
      ),
      trailing: PopupMenuButton<_ItemAction>(
        onSelected: (action) => _handleItemAction(entry, action),
        itemBuilder: (context) => _itemMenu(),
      ),
    ),
  );

  Widget _buildSearch() {
    final results = _searchController.text.trim().isEmpty
        ? _entries
        : _searchResults;
    return _page(
      title: 'Search',
      actions: [
        IconButton(
          onPressed: () => _runSearch(_searchController.text),
          icon: const Icon(Icons.tune),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onSubmitted: _runSearch,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search your selected folder',
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              InputChip(
                label: const Text('All'),
                selected: true,
                onSelected: (_) {},
              ),
              InputChip(label: const Text('Documents'), onSelected: (_) {}),
              InputChip(label: const Text('Images'), onSelected: (_) {}),
              InputChip(label: const Text('Recent'), onSelected: (_) {}),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _searchController.text.trim().isEmpty ? 'Recent files' : 'Results',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (_files == null)
            _emptyFolder()
          else if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'No matching files.',
                  style: TextStyle(color: _muted),
                ),
              ),
            )
          else
            ...results.map(_browseTile),
        ],
      ),
    );
  }

  Widget _buildAssistant() {
    return _page(
      title: 'AI Assistant',
      actions: [
        IconButton(
          onPressed: _showAccountDialog,
          icon: Icon(
            _backendConnected
                ? Icons.verified_user_outlined
                : Icons.login_outlined,
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_violet, _purple]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.auto_awesome, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FileMind AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _backendConnected
                            ? 'Online · connected to your account'
                            : 'Sign in to connect · files stay on-device',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ..._messages.map(_messageBubble),
          if (_pendingOperations.isNotEmpty) _planCard(),
          if (_planning)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.cleaning_services, size: 16),
                label: const Text('Find duplicates'),
                onPressed: () => _sendChat('Find duplicate files.'),
              ),
              ActionChip(
                avatar: const Icon(Icons.folder_copy, size: 16),
                label: const Text('Organize files'),
                onPressed: () =>
                    _sendChat('Suggest an organization plan for this folder.'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _chatController,
            minLines: 1,
            maxLines: 3,
            onSubmitted: (_) => _sendChat(),
            decoration: InputDecoration(
              hintText: 'Ask about your files...',
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                onPressed: _planning ? null : _sendChat,
                icon: const Icon(Icons.send, color: _violet),
              ),
            ),
          ),
          if (_bootstrapError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _bootstrapError!,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _messageBubble(ChatMessage message) => Align(
    alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 500),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: message.isUser ? _violet : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message.text,
        style: TextStyle(
          color: message.isUser
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ),
  );

  Widget _planCard() => Card(
    elevation: 0,
    color: const Color(0xfff0edff),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan preview',
            style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
          ),
          const SizedBox(height: 8),
          ..._pendingOperations.map(
            (operation) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.radio_button_checked,
                    size: 16,
                    color: _violet,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(operation.summary)),
                ],
              ),
            ),
          ),
          Row(
            children: [
              FilledButton(
                onPressed: _planning ? null : _approveOperation,
                child: const Text('Confirm'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _planning ? null : _skipOperation,
                child: const Text('Skip step'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildSettings() => _page(
    title: 'Settings',
    actions: [
      IconButton(
        onPressed: () => widget.onDarkModeChanged(!widget.isDark),
        icon: Icon(
          widget.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        ),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingsSection('AI & Privacy', [
          _settingsTile(
            Icons.lock_outline,
            'On-device mode',
            _backendConnected
                ? 'AI connected; raw files never upload'
                : 'Files stay local; sign in for planning',
            trailing: Switch(value: true, onChanged: (_) {}),
          ),
          _settingsTile(
            Icons.auto_awesome,
            'AI model',
            _backendConnected ? _aiStatusLabel() : 'Not connected',
            onTap: _showAccountDialog,
          ),
          _settingsTile(
            Icons.folder_open_outlined,
            'Allowed paths',
            _files == null ? 'No folder selected' : _files!.rootPath,
          ),
        ]),
        const SizedBox(height: 20),
        _settingsSection('Automation', [
          _settingsTile(
            Icons.schedule,
            'Auto-organize weekly',
            'Every Sunday at 9 PM',
            trailing: Switch(
              value: _autoOrganize,
              onChanged: (value) => setState(() => _autoOrganize = value),
            ),
          ),
          _settingsTile(
            Icons.delete_sweep_outlined,
            'Auto-delete duplicates',
            'Confirm before deletion',
            trailing: Switch(
              value: _deleteDuplicates,
              onChanged: (value) => setState(() => _deleteDuplicates = value),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        _settingsSection('Connection', [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backend URL',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _settingsUrlController,
                  decoration: const InputDecoration(
                        hintText: 'http://192.168.1.158:4000',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: () {
                      _api.baseUrl = _settingsUrlController.text.trim();
                      _showMessage('Backend address saved.');
                    },
                    child: const Text('Save address'),
                  ),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 20),
        _settingsSection('Appearance', [
          _settingsTile(
            Icons.palette_outlined,
            'Appearance',
            widget.isDark ? 'Dark mode' : 'Light mode',
            trailing: Switch(
              value: widget.isDark,
              onChanged: widget.onDarkModeChanged,
            ),
          ),
        ]),
      ],
    ),
  );

  String _aiStatusLabel() {
    final ai = _bootstrap?['ai'];
    if (ai is Map && ai['providerCount'] is int)
      return '${ai['providerCount']} provider(s) available';
    return 'Connected';
  }

  Widget _settingsSection(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    ],
  );

  Widget _settingsTile(
    IconData icon,
    String title,
    String subtitle, {
    Widget? trailing,
    VoidCallback? onTap,
  }) => ListTile(
    onTap: onTap,
    leading: CircleAvatar(
      backgroundColor: const Color(0xffeeeaff),
      foregroundColor: _violet,
      child: Icon(icon, size: 19),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: trailing ?? const Icon(Icons.chevron_right),
  );

  Widget _fileIcon(FileEntry entry, {bool large = false}) {
    final color = entry.kind == FileEntryKind.folder
        ? _violet
        : _fileColor(entry.name);
    return Container(
      width: large ? 42 : 38,
      height: large ? 42 : 38,
      decoration: BoxDecoration(
        color: color.withOpacity(.13),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        entry.kind == FileEntryKind.folder
            ? Icons.folder
            : _fileIconData(entry.name),
        color: color,
        size: large ? 23 : 21,
      ),
    );
  }

  IconData _fileIconData(String name) {
    final extension = p.extension(name).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.heic', '.webp'].contains(extension))
      return Icons.image_outlined;
    if (['.pdf', '.doc', '.docx', '.txt'].contains(extension))
      return Icons.description_outlined;
    if (['.mp4', '.mov', '.mkv'].contains(extension))
      return Icons.play_circle_outline;
    if (['.mp3', '.wav'].contains(extension)) return Icons.music_note_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Color _fileColor(String name) {
    final extension = p.extension(name).toLowerCase();
    if (extension == '.pdf') return const Color(0xffef4444);
    if (['.jpg', '.jpeg', '.png', '.gif', '.heic'].contains(extension))
      return const Color(0xff16b86a);
    if (['.doc', '.docx'].contains(extension)) return const Color(0xff3b82f6);
    return _violet;
  }
}
