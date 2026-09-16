import 'package:flutter/material.dart';

import '../models.dart';
import '../services/local_file_service.dart';
import '../widgets/folder_picker_sheet.dart';

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.fileService,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = Theme.of(context).cardColor;
        final outlineColor = Theme.of(context).colorScheme.outline;
        final isAuthorized = widget.fileService.isAuthorized;

        // Dynamic category statistics derived directly from device filesystem
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

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // Top Bar
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

                // Category Filter Pills
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

                // Real Subfolders Section
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

                // Subfolders List
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
                                onTap: () => widget.onOpenSearch(folder.name),
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
                        childCount: subfolders.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
