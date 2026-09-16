import 'package:flutter/material.dart';

import '../models.dart';
import '../services/local_file_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.fileService,
    this.initialQuery = '',
    this.onBack,
  });

  final LocalFileService fileService;
  final String initialQuery;
  final VoidCallback? onBack;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  int _selectedFilterIndex = 0;

  List<FileEntry> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _performSearch(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() => _searching = true);
    final results = await widget.fileService.search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  List<Map<String, dynamic>> _buildFilterChips() {
    return [
      {'label': 'All', 'count': widget.fileService.totalFilesCount, 'category': null},
      {
        'label': 'Docs',
        'count': widget.fileService.getCategoryCount(FileCategory.documents),
        'category': FileCategory.documents,
      },
      {
        'label': 'Photos',
        'count': widget.fileService.getCategoryCount(FileCategory.photos),
        'category': FileCategory.photos,
      },
      {
        'label': 'Videos',
        'count': widget.fileService.getCategoryCount(FileCategory.videos),
        'category': FileCategory.videos,
      },
      {
        'label': 'Audio',
        'count': widget.fileService.getCategoryCount(FileCategory.audio),
        'category': FileCategory.audio,
      },
      {
        'label': 'APKs',
        'count': widget.fileService.getCategoryCount(FileCategory.apks),
        'category': FileCategory.apks,
      },
    ];
  }

  List<FileEntry> get _filteredResults {
    final chips = _buildFilterChips();
    if (_selectedFilterIndex >= chips.length) return _results;
    final cat = chips[_selectedFilterIndex]['category'] as FileCategory?;
    if (cat == null) return _results;
    return _results.where((f) => f.category == cat).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.fileService,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = Theme.of(context).cardColor;
        final outlineColor = Theme.of(context).colorScheme.outline;
        final filterChips = _buildFilterChips();
        final displayResults = _filteredResults;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                  child: Row(
                    children: [
                      if (widget.onBack != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          onPressed: widget.onBack,
                        )
                      else
                        const SizedBox(width: 8),
                      Text(
                        'Search',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const Spacer(),
                      if (widget.fileService.isAuthorized)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6046E8).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.fileService.authorizedFolderName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6046E8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Search text box
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: outlineColor.withValues(alpha: 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: isDark ? Colors.white60 : const Color(0xFF9CA3AF),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            onChanged: _performSearch,
                            onSubmitted: _performSearch,
                            decoration: InputDecoration(
                              hintText: widget.fileService.isAuthorized
                                  ? 'Search files in ${widget.fileService.authorizedFolderName}...'
                                  : 'Search files...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        if (_controller.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _controller.clear();
                              _performSearch('');
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // Dynamic Status line
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _controller.text.isEmpty
                          ? 'Showing all files in ${widget.fileService.authorizedFolderName}'
                          : 'Matches for "${_controller.text}" (${displayResults.length} items)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),

                // Filter chips row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: filterChips.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final isSelected = _selectedFilterIndex == index;
                        final item = filterChips[index];

                        return GestureDetector(
                          onTap: () => setState(() => _selectedFilterIndex = index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF6046E8).withValues(alpha: 0.12)
                                  : cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF6046E8)
                                    : outlineColor.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  item['label'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? const Color(0xFF6046E8)
                                        : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF6046E8)
                                        : (isDark ? const Color(0xFF282F46) : const Color(0xFFE5E7EB)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${item['count']}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Search Results
                Expanded(
                  child: _searching
                      ? const Center(child: CircularProgressIndicator())
                      : displayResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 56,
                                    color: isDark ? Colors.white24 : Colors.black26,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'No files found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white70 : const Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Try adjusting your search or category filter',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              itemCount: displayResults.length,
                              itemBuilder: (context, index) {
                                final file = displayResults[index];
                                return _buildResultItem(context, file, isDark, cardColor, outlineColor);
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultItem(
    BuildContext context,
    FileEntry file,
    bool isDark,
    Color cardColor,
    Color outlineColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showFileDetails(context, file),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: outlineColor.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${file.formattedDate} · ${file.formattedSize}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFileDetails(BuildContext context, FileEntry file) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text('Path: ${file.path}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Size: ${file.formattedSize}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Modified: ${file.formattedDate}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.drive_file_rename_outline),
                      label: const Text('Rename'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showRenameDialog(file);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await widget.fileService.delete(file.path);
                        _performSearch(_controller.text);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(FileEntry file) {
    final controller = TextEditingController(text: file.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != file.name) {
                Navigator.pop(ctx);
                await widget.fileService.rename(file.path, newName);
                _performSearch(_controller.text);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}
