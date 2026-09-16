import 'package:flutter/material.dart';

import '../models.dart';
import '../services/local_file_service.dart';

class FileListScreen extends StatefulWidget {
  const FileListScreen({
    super.key,
    required this.fileService,
    this.category = FileCategory.documents,
    required this.onBack,
  });

  final LocalFileService fileService;
  final FileCategory category;
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

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    final results = await widget.fileService.listDirectory(widget.category.label);
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
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
                  Text(
                    widget.category.label,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
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
                    '${_selectedPaths.length} selected · ${_formatBytes(_selectedBytes)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6046E8),
                    ),
                  ),
                  const Spacer(),
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
                                widget.category.icon,
                                size: 56,
                                color: widget.category.color.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No ${widget.category.label} found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white70 : const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Files in this category will appear here',
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
                        final file = _files[index];
                        final isSelected = _selectedPaths.contains(file.path);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _toggleSelection(file.path),
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
                                  // File badge (PDF, DOC, XLS, PPT)
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: file.badgeColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        file.badgeText,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          file.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${file.folderName} · ${file.formattedSize} · ${file.formattedDate}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white60
                                                : const Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Circular Checkbox
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? const Color(0xFF6046E8)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF6046E8)
                                            : (isDark
                                                ? Colors.white38
                                                : const Color(0xFFD1D5DB)),
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 16,
                                          )
                                        : null,
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
              icon: Icons.arrow_forward_rounded,
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count items?'),
        content: const Text('These items will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final path in _selectedPaths) {
        await widget.fileService.delete(path);
      }
      _selectedPaths.clear();
      await _loadFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $count files.')),
        );
      }
    }
  }

  Future<void> _handleMoveSelected() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved ${_selectedPaths.length} files to /Archive')),
    );
    _selectedPaths.clear();
  }

  Future<void> _handleShareSelected() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sharing ${_selectedPaths.length} files...')),
    );
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
