import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/local_file_service.dart';
import '../widgets/destination_folder_picker.dart';
import '../widgets/permission_dialogs.dart';
import 'file_preview_screen.dart';

class FileListScreen extends StatefulWidget {
  const FileListScreen({
    super.key,
    required this.fileService,
    this.category,
    this.folderPath,
    this.folderTitle,
    required this.onBack,
  }) : assert(category != null || folderPath != null, 'Either category or folderPath must be provided');

  final LocalFileService fileService;
  final FileCategory? category;
  final String? folderPath;
  final String? folderTitle;
  final VoidCallback onBack;

  @override
  State<FileListScreen> createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen> {
  final Set<String> _selectedPaths = {};
  List<FileEntry> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  String get _title {
    if (widget.folderTitle != null) return widget.folderTitle!;
    if (widget.folderPath != null) {
      final name = p.basename(widget.folderPath!);
      return name == '0' || name.isEmpty ? 'Root Storage' : name;
    }
    return widget.category?.label ?? 'Files';
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    List<FileEntry> results;

    if (widget.folderPath != null) {
      results = widget.fileService.getFolderContents(widget.folderPath!);
    } else if (widget.category != null) {
      results = await widget.fileService.listDirectory(widget.category!.label);
    } else {
      results = widget.fileService.allEntries.where((e) => e.kind == FileEntryKind.file).toList();
    }

    if (!mounted) return;
    setState(() {
      _files = results;
      _loading = false;
      _selectedPaths.clear();
    });
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedPaths.clear());
  }

  int get _selectedBytes {
    return _files
        .where((file) => _selectedPaths.contains(file.path))
        .fold(0, (sum, file) => sum + file.sizeBytes);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _openFilePreview(FileEntry file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilePreviewScreen(
          file: file,
          fileService: widget.fileService,
          onFileDeleted: _loadFiles,
          onFileRenamed: (_) => _loadFiles(),
        ),
      ),
    );
  }

  void _openFolder(FileEntry folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FileListScreen(
          fileService: widget.fileService,
          folderPath: folder.path,
          folderTitle: folder.name,
          onBack: () => Navigator.pop(context),
        ),
      ),
    ).then((_) => _loadFiles());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final outlineColor = Theme.of(context).colorScheme.outline;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: widget.onBack,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        if (widget.folderPath != null)
                          Text(
                            widget.folderPath!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 24),
                    onPressed: _selectedPaths.isEmpty ? null : _handleDeleteSelected,
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 24),
                    onPressed: () => _showMenu(context),
                  ),
                ],
              ),
            ),

            // Selection Banner: "4 selected · 12.8 MB" & "Clear"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: isDark ? const Color(0xFF161A29) : const Color(0xFFEFF2FE),
              child: Row(
                children: [
                  Text(
                    _selectedPaths.isEmpty
                        ? '${_files.length} items total'
                        : '${_selectedPaths.length} selected · ${_formatBytes(_selectedBytes)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6046E8),
                    ),
                  ),
                  const Spacer(),
                  if (_selectedPaths.isNotEmpty)
                    GestureDetector(
                      onTap: _clearSelection,
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // File items list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _files.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.category?.icon ?? Icons.folder_open_outlined,
                                size: 56,
                                color: (widget.category?.color ?? const Color(0xFF6046E8)).withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No items found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white70 : const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'This folder has no files matching the view.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 90),
                          itemCount: _files.length,
                          itemBuilder: (context, index) {
                            final item = _files[index];
                            final isSelected = _selectedPaths.contains(item.path);
                            final isFolder = item.kind == FileEntryKind.folder;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  if (_selectedPaths.isNotEmpty) {
                                    _toggleSelection(item.path);
                                  } else if (isFolder) {
                                    _openFolder(item);
                                  } else {
                                    _openFilePreview(item);
                                  }
                                },
                                onLongPress: () => _toggleSelection(item.path),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF6046E8)
                                          : outlineColor.withValues(alpha: 0.5),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Folder or File badge
                                      if (isFolder)
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6046E8).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.folder,
                                              color: Color(0xFF6046E8),
                                              size: 24,
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: item.badgeColor,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              item.badgeText,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: 14),

                                      // Name and metadata
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : const Color(0xFF111827),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              isFolder
                                                  ? 'Folder · ${item.formattedDate}'
                                                  : '${item.folderName} · ${item.formattedSize} · ${item.formattedDate}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Circular Checkbox
                                      GestureDetector(
                                        onTap: () => _toggleSelection(item.path),
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected ? const Color(0xFF6046E8) : Colors.transparent,
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFF6046E8)
                                                  : (isDark ? Colors.white38 : const Color(0xFFD1D5DB)),
                                              width: 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),

      // Bottom Docked Action Toolbar: Move, Share, Delete, Rename
      bottomNavigationBar: Container(
        height: 72,
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(
            top: BorderSide(
              color: outlineColor.withValues(alpha: 0.6),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildToolbarAction(
              icon: Icons.drive_file_move_outlined,
              label: 'Move',
              onTap: _handleMoveSelected,
            ),
            _buildToolbarAction(
              icon: Icons.share_outlined,
              label: 'Share',
              onTap: _handleShareSelected,
            ),
            _buildToolbarAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              onTap: _handleDeleteSelected,
            ),
            _buildToolbarAction(
              icon: Icons.drive_file_rename_outline_rounded,
              label: 'Rename',
              onTap: _handleRenameSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final enabled = _selectedPaths.isNotEmpty;
    final color = enabled
        ? const Color(0xFF6046E8)
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.white24
            : Colors.black26);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteSelected() async {
    final count = _selectedPaths.length;
    final selectedFiles = _files.where((f) => _selectedPaths.contains(f.path)).map((f) => f.name).toList();

    final confirmed = await showDeletePermissionDialog(
      context,
      count: count,
      fileNames: selectedFiles,
    );

    if (confirmed && mounted) {
      final deleted = await widget.fileService.deleteMultiple(_selectedPaths.toList());
      _selectedPaths.clear();
      await _loadFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permanently deleted $deleted items.')),
        );
      }
    }
  }

  Future<void> _handleMoveSelected() async {
    if (_selectedPaths.isEmpty) return;

    final dest = await showDestinationFolderPicker(context, widget.fileService);
    if (dest == null || !mounted) return;

    final confirmed = await showMovePermissionDialog(
      context,
      count: _selectedPaths.length,
      destinationName: dest['name']!,
      destinationPath: dest['path']!,
    );

    if (confirmed && mounted) {
      final moved = await widget.fileService.moveMultiple(_selectedPaths.toList(), dest['path']!);
      _selectedPaths.clear();
      await _loadFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved $moved items to ${dest['name']}')),
        );
      }
    }
  }

  Future<void> _handleShareSelected() async {
    if (_selectedPaths.isEmpty) return;
    try {
      final xFiles = _selectedPaths.map((path) => XFile(path)).toList();
      // ignore: deprecated_member_use
      await Share.shareXFiles(xFiles);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing files: $e')),
        );
      }
    }
  }

  Future<void> _handleRenameSelected() async {
    if (_selectedPaths.isEmpty) return;
    final path = _selectedPaths.first;
    final file = _files.firstWhere((f) => f.path == path);
    final controller = TextEditingController(text: file.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != file.name) {
      await widget.fileService.rename(file.path, newName);
      await _loadFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renamed to $newName')),
        );
      }
    }
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.select_all),
              title: const Text('Select All'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _selectedPaths.addAll(_files.map((f) => f.path));
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Refresh'),
              onTap: () {
                Navigator.pop(ctx);
                _loadFiles();
              },
            ),
          ],
        ),
      ),
    );
  }
}
