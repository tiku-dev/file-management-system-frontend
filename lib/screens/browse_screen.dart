import 'package:flutter/material.dart';

import '../models.dart';
import '../services/local_file_service.dart';
import '../widgets/destination_folder_picker.dart';
import '../widgets/folder_picker_sheet.dart';
import '../widgets/permission_dialogs.dart';
import 'file_list_screen.dart';
import 'file_preview_screen.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({
    super.key,
    required this.fileService,
    required this.onSelectCategory,
    required this.onOpenSearch,
  });

  final LocalFileService fileService;
  final ValueChanged<FileCategory> onSelectCategory;
  final ValueChanged<String> onOpenSearch;

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = ['All', 'Recent', 'Duplicates', 'Folders'];

  void _openFilePreview(FileEntry file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilePreviewScreen(
          file: file,
          fileService: widget.fileService,
          onFileDeleted: () => setState(() {}),
          onFileRenamed: (_) => setState(() {}),
        ),
      ),
    );
  }

  void _openFolderView(String folderPath, String folderName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FileListScreen(
          fileService: widget.fileService,
          folderPath: folderPath,
          folderTitle: folderName,
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.fileService,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = Theme.of(context).cardColor;
        final outlineColor = Theme.of(context).colorScheme.outline;
        final isAuthorized = widget.fileService.isAuthorized;

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // Top App Bar
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 10),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Browse',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            if (isAuthorized)
                              GestureDetector(
                                onTap: () => showDeviceFolderPicker(context, widget.fileService),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.folder_outlined, size: 13, color: Color(0xFF6046E8)),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.fileService.authorizedFolderName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6046E8),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.swap_horiz, size: 14, color: Color(0xFF6046E8)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.sync_rounded, size: 24),
                          tooltip: 'Rescan Folder',
                          onPressed: () async {
                            await widget.fileService.refresh();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Scanned live files from device.')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // If not authorized, show quick picker banner
                if (!isAuthorized)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1B38) : const Color(0xFFF3F0FF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF6046E8).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder_open, color: Color(0xFF6046E8), size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'No Folder Authorized',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  Text(
                                    'Select a directory to browse real files',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: () => showDeviceFolderPicker(context, widget.fileService),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF6046E8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              child: const Text('Authorize'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Smart Search Input
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  sliver: SliverToBoxAdapter(
                    child: GestureDetector(
                      onTap: () => widget.onOpenSearch(''),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: isDark ? Colors.white60 : const Color(0xFF9CA3AF),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Search files in ${widget.fileService.authorizedFolderName}...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Category Filter Pills (All, Recent, Duplicates, Folders)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _tabs.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final isSelected = _selectedTab == index;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedTab = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF6046E8).withValues(alpha: 0.15)
                                    : cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF6046E8)
                                      : outlineColor.withValues(alpha: 0.6),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _tabs[index],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? const Color(0xFF6046E8)
                                        : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Content View based on active _selectedTab
                ..._buildTabSlivers(context, isDark, cardColor, outlineColor, isAuthorized),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildTabSlivers(
    BuildContext context,
    bool isDark,
    Color cardColor,
    Color outlineColor,
    bool isAuthorized,
  ) {
    switch (_selectedTab) {
      case 1:
        return _buildRecentTabSlivers(context, isDark, cardColor, outlineColor);
      case 2:
        return _buildDuplicatesTabSlivers(context, isDark, cardColor, outlineColor);
      case 3:
        return _buildFoldersTabSlivers(context, isDark, cardColor, outlineColor, isAuthorized);
      case 0:
      default:
        return _buildAllTabSlivers(context, isDark, cardColor, outlineColor, isAuthorized);
    }
  }

  // --- TAB 0: ALL ---
  List<Widget> _buildAllTabSlivers(
    BuildContext context,
    bool isDark,
    Color cardColor,
    Color outlineColor,
    bool isAuthorized,
  ) {
    final categories = [
      {
        'category': FileCategory.documents,
        'title': 'Documents',
        'count': '${widget.fileService.getCategoryCount(FileCategory.documents)}',
        'size': widget.fileService.formatCategorySize(FileCategory.documents),
        'icon': Icons.description_outlined,
        'color': const Color(0xFFEF4444),
      },
      {
        'category': FileCategory.photos,
        'title': 'Photos',
        'count': '${widget.fileService.getCategoryCount(FileCategory.photos)}',
        'size': widget.fileService.formatCategorySize(FileCategory.photos),
        'icon': Icons.image_outlined,
        'color': const Color(0xFF3B82F6),
      },
      {
        'category': FileCategory.videos,
        'title': 'Videos',
        'count': '${widget.fileService.getCategoryCount(FileCategory.videos)}',
        'size': widget.fileService.formatCategorySize(FileCategory.videos),
        'icon': Icons.play_arrow_outlined,
        'color': const Color(0xFFF97316),
      },
      {
        'category': FileCategory.audio,
        'title': 'Audio',
        'count': '${widget.fileService.getCategoryCount(FileCategory.audio)}',
        'size': widget.fileService.formatCategorySize(FileCategory.audio),
        'icon': Icons.music_note_outlined,
        'color': const Color(0xFFA855F7),
      },
      {
        'category': FileCategory.apks,
        'title': 'APKs',
        'count': '${widget.fileService.getCategoryCount(FileCategory.apks)}',
        'size': widget.fileService.formatCategorySize(FileCategory.apks),
        'icon': Icons.android_outlined,
        'color': const Color(0xFF10B981),
      },
      {
        'category': FileCategory.other,
        'title': 'Other',
        'count': '${widget.fileService.getCategoryCount(FileCategory.other)}',
        'size': widget.fileService.formatCategorySize(FileCategory.other),
        'icon': Icons.insert_drive_file_outlined,
        'color': const Color(0xFF6B7280),
      },
    ];

    final subfolders = widget.fileService.subdirectories;

    return [
      // 2x3 Categories Grid
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.12,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = categories[index];
              final category = item['category'] as FileCategory;
              final color = item['color'] as Color;

              return Material(
                color: cardColor,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => widget.onSelectCategory(category),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: outlineColor.withValues(alpha: 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: color,
                                  size: 24,
                                ),
                              ),
                            ),
                            Text(
                              item['count'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['size'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            childCount: categories.length,
          ),
        ),
      ),

      // Real Subfolders Section Header
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        sliver: SliverToBoxAdapter(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Folders (${subfolders.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              IconButton(
                icon: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6046E8).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Color(0xFF6046E8),
                    size: 18,
                  ),
                ),
                onPressed: () => _showAddFolderDialog(context),
              ),
            ],
          ),
        ),
      ),

      // Subfolders List (first 5 in 'All' tab, or empty state)
      if (subfolders.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: outlineColor.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Text(
                  isAuthorized
                      ? 'No subdirectories found in ${widget.fileService.authorizedFolderName}. Tap + to create one.'
                      : 'Authorize a folder to view its subdirectories.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final folder = subfolders[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openFolderView(folder.path, folder.name),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: outlineColor.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6046E8).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.folder_outlined,
                                  color: Color(0xFF6046E8),
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    folder.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${folder.fileCount} files · ${folder.formattedSize}',
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
              },
              childCount: subfolders.length > 5 ? 5 : subfolders.length,
            ),
          ),
        ),
    ];
  }

  // --- TAB 1: RECENT ---
  List<Widget> _buildRecentTabSlivers(
    BuildContext context,
    bool isDark,
    Color cardColor,
    Color outlineColor,
  ) {
    final recentFiles = widget.fileService.allEntries
        .where((e) => e.kind == FileEntryKind.file)
        .toList();

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Recent Files (${recentFiles.length} items)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ),
      ),
      if (recentFiles.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.history_rounded, size: 56, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 12),
                  const Text('No recent files found'),
                ],
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final file = recentFiles[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openFilePreview(file),
                      onLongPress: () => _showItemActions(context, file),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: outlineColor.withValues(alpha: 0.5)),
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
                                  const SizedBox(height: 3),
                                  Text(
                                    '${file.folderName} · ${file.formattedSize} · ${file.formattedDate}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.more_vert, size: 20, color: isDark ? Colors.white38 : Colors.black38),
                              onPressed: () => _showItemActions(context, file),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: recentFiles.length,
            ),
          ),
        ),
    ];
  }

  // --- TAB 2: DUPLICATES ---
  List<Widget> _buildDuplicatesTabSlivers(
    BuildContext context,
    bool isDark,
    Color cardColor,
    Color outlineColor,
  ) {
    final duplicates = widget.fileService.findDuplicates();
    final totalReclaimableBytes = duplicates.fold(0, (sum, p) => sum + p.duplicate.sizeBytes);

    String formatBytes(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        sliver: SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.15),
                  const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.copy_rounded, color: Color(0xFFF59E0B), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${duplicates.length} Duplicate Files Detected',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          Text(
                            'Can free up ${formatBytes(totalReclaimableBytes)} of storage',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (duplicates.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.auto_delete_outlined, color: Colors.black, size: 20),
                      label: const Text(
                        'Clean All Duplicates',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
                      ),
                      onPressed: () async {
                        final confirmed = await showCleanupDuplicatesDialog(
                          context,
                          count: duplicates.length,
                          totalReclaimable: formatBytes(totalReclaimableBytes),
                        );
                        if (confirmed && context.mounted) {
                          final cleaned = await widget.fileService.cleanupDuplicates();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Cleaned $cleaned duplicate files.')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      if (duplicates.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.all(40),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 56, color: Color(0xFF10B981)),
                  const SizedBox(height: 14),
                  Text(
                    'No duplicate files found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your storage space is well organized and duplicate-free.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                  ),
                ],
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final pair = duplicates[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: outlineColor.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: pair.duplicate.badgeColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  pair.duplicate.badgeText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pair.duplicate.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  Text(
                                    pair.duplicate.formattedSize,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                              tooltip: 'Delete this duplicate',
                              onPressed: () async {
                                final confirmed = await showDeletePermissionDialog(
                                  context,
                                  count: 1,
                                  fileNames: [pair.duplicate.name],
                                );
                                if (confirmed) {
                                  await widget.fileService.delete(pair.duplicate.path);
                                  setState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161A29) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Original: ${pair.original.path}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Duplicate: ${pair.duplicate.path}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: const Color(0xFFEF4444).withValues(alpha: 0.8)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: duplicates.length,
            ),
          ),
        ),
    ];
  }

  // --- TAB 3: FOLDERS ---
  List<Widget> _buildFoldersTabSlivers(
    BuildContext context,
    bool isDark,
    Color cardColor,
    Color outlineColor,
    bool isAuthorized,
  ) {
    final subfolders = widget.fileService.subdirectories;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        sliver: SliverToBoxAdapter(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Folders (${subfolders.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6046E8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showAddFolderDialog(context),
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('New Folder'),
              ),
            ],
          ),
        ),
      ),
      if (subfolders.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.all(40),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.folder_open_rounded, size: 56, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 12),
                  const Text('No subfolders found'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => _showAddFolderDialog(context),
                    child: const Text('Create New Folder'),
                  ),
                ],
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final folder = subfolders[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openFolderView(folder.path, folder.name),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: outlineColor.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6046E8).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.folder,
                                  color: Color(0xFF6046E8),
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    folder.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${folder.fileCount} files · ${folder.formattedSize}',
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
                              size: 20,
                              color: isDark ? Colors.white38 : Colors.black26,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: subfolders.length,
            ),
          ),
        ),
    ];
  }

  void _showItemActions(BuildContext context, FileEntry file) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF6046E8)),
                title: const Text('Preview File'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openFilePreview(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined, color: Color(0xFF6046E8)),
                title: const Text('Move File'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final dest = await showDestinationFolderPicker(context, widget.fileService);
                  if (dest != null && context.mounted) {
                    final confirmed = await showMovePermissionDialog(
                      context,
                      count: 1,
                      destinationName: dest['name']!,
                      destinationPath: dest['path']!,
                    );
                    if (confirmed) {
                      await widget.fileService.move(file.path, dest['path']!);
                      setState(() {});
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('Rename'),
                onTap: () async {
                  Navigator.pop(ctx);
                  _showRenameDialog(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                title: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirmed = await showDeletePermissionDialog(
                    context,
                    count: 1,
                    fileNames: [file.name],
                  );
                  if (confirmed) {
                    await widget.fileService.delete(file.path);
                    setState(() {});
                  }
                },
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
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != file.name) {
                Navigator.pop(ctx);
                await widget.fileService.rename(file.path, newName);
                setState(() {});
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showAddFolderDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Folder name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                await widget.fileService.createFolder('.', name);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Folder "$name" created.')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
