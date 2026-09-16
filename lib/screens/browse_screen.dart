import 'package:flutter/material.dart';

import '../models.dart';
import '../services/local_file_service.dart';

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
  final List<String> _tabs = ['Smart', 'Recent', 'Starred', 'Downloads'];

  final List<Map<String, dynamic>> _categories = [
    {
      'category': FileCategory.documents,
      'title': 'Documents',
      'count': '142',
      'size': '26.4 GB',
      'icon': Icons.description_outlined,
      'color': const Color(0xFFEF4444),
    },
    {
      'category': FileCategory.photos,
      'title': 'Photos',
      'count': '3,847',
      'size': '45.2 GB',
      'icon': Icons.image_outlined,
      'color': const Color(0xFF3B82F6),
    },
    {
      'category': FileCategory.videos,
      'title': 'Videos',
      'count': '218',
      'size': '31.6 GB',
      'icon': Icons.play_arrow_outlined,
      'color': const Color(0xFFF97316),
    },
    {
      'category': FileCategory.audio,
      'title': 'Audio',
      'count': '86',
      'size': '4.7 GB',
      'icon': Icons.music_note_outlined,
      'color': const Color(0xFFA855F7),
    },
    {
      'category': FileCategory.apks,
      'title': 'APKs',
      'count': '52',
      'size': '2.1 GB',
      'icon': Icons.android_outlined,
      'color': const Color(0xFF10B981),
    },
    {
      'category': FileCategory.chats,
      'title': 'Chats',
      'count': '14',
      'size': '812 MB',
      'icon': Icons.chat_bubble_outline,
      'color': const Color(0xFF06B6D4),
    },
  ];

  final List<Map<String, String>> _smartFolders = [
    {'name': 'Tax & Financial 2024', 'count': '18 files', 'tag': 'AI Rule'},
    {'name': 'Work & Proposals', 'count': '24 files', 'tag': 'Weekly'},
    {'name': 'University Lecture Slides', 'count': '42 files', 'tag': 'Synced'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final outlineColor = Theme.of(context).colorScheme.outline;

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
                    Text(
                      'Browse',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.sort_rounded, size: 24),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Filter & sorting applied')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Smart Search Input
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              sliver: SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () => widget.onOpenSearch('tax docs from 2024'),
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
                        Text(
                          "Smart search: 'tax docs from 2024'",
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Tab chips row
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tabs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isSelected = _selectedTab == index;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedTab = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6046E8).withValues(alpha: 0.12)
                                : cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF6046E8)
                                  : outlineColor.withValues(alpha: 0.6),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _tabs[index],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF6046E8)
                                    : (isDark
                                        ? Colors.white70
                                        : const Color(0xFF4B5563)),
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
                    final item = _categories[index];
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
                                color: Colors.black
                                    .withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Top Row: Icon + Count
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                      color: isDark
                                          ? Colors.white60
                                          : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),

                              // Bottom Column: Title & Size
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] as String,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['size'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white60
                                          : const Color(0xFF6B7280),
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
                  childCount: _categories.length,
                ),
              ),
            ),

            // Smart Folders Section
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Smart Folders',
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
                      onPressed: () {
                        _showAddFolderDialog(context);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Smart Folders List
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final folder = _smartFolders[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: cardColor,
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
                                color: const Color(0xFF6046E8)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.folder_special_outlined,
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
                                    folder['name']!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    folder['count']!,
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6046E8)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                folder['tag']!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6046E8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: _smartFolders.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFolderDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Smart Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'e.g. Project Assets',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _smartFolders.add({
                    'name': controller.text.trim(),
                    'count': '0 files',
                    'tag': 'Custom',
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
