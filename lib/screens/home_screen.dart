import 'package:flutter/material.dart';

import '../models.dart';
import '../services/local_file_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.fileService,
    required this.onOpenSearch,
    required this.onOpenAiAssistant,
    required this.onOpenBrowse,
    required this.onFileTap,
  });

  final LocalFileService fileService;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenAiAssistant;
  final VoidCallback onOpenBrowse;
  final ValueChanged<FileEntry> onFileTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final outlineColor = Theme.of(context).colorScheme.outline;
    final recentFiles = fileService.recentFiles;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Top App Bar
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      'Files',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.search, size: 24),
                      onPressed: onOpenSearch,
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 24),
                      onPressed: () {
                        _showHomeMenu(context);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. Storage Overview Gradient Card
                  _buildStorageCard(context),
                  const SizedBox(height: 16),

                  // 2. Tip Card (AI Recommendation)
                  _buildTipCard(context, isDark, cardColor, outlineColor),
                  const SizedBox(height: 16),

                  // 3. Quick Actions (Clean up & Transfer)
                  _buildQuickActions(context, isDark, cardColor, outlineColor),
                  const SizedBox(height: 24),

                  // 4. Recent Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      GestureDetector(
                        onTap: onOpenBrowse,
                        child: const Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6046E8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Recent items list
                  ...recentFiles.take(4).map((file) => _buildRecentItem(
                        context,
                        file,
                        isDark,
                        cardColor,
                        outlineColor,
                      )),
                  const SizedBox(height: 80), // Space for floating button
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  Widget _buildStorageCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.storageGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B3FE8).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STORAGE badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'STORAGE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Used bytes stat
          const Text(
            '118.2 GB used',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'of 128 GB · 9.8 GB free',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // Multi-segment progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: 45,
                    child: Container(color: AppColors.photosColor),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 26,
                    child: Container(color: AppColors.docsColor),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 21,
                    child: Container(color: AppColors.appsColor),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 17,
                    child: Container(color: AppColors.systemColor),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 10,
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend dots & labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendDot(AppColors.photosColor, 'Photos 45 GB'),
              _buildLegendDot(AppColors.docsColor, 'Docs 26 GB'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendDot(AppColors.appsColor, 'Apps 21 GB'),
              _buildLegendDot(AppColors.systemColor, 'System 17 GB'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTipCard(
    BuildContext context,
    bool isDark,
    Color cardColor,
    Color outlineColor,
  ) {
    return GestureDetector(
      onTap: onOpenAiAssistant,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: outlineColor.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF6046E8),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.star_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tip: 23 duplicate photos found. Want me to clean them up?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white54 : Colors.black45,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    bool isDark,
    Color cardColor,
    Color outlineColor,
  ) {
    return Row(
      children: [
        // Clean up card
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final cleaned = await fileService.cleanupDuplicates();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cleaned $cleaned duplicate files! 4.2 GB freed.'),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Clean up',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Free 4.2 GB',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Transfer card
        Expanded(
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cloud sync transfer initiated with encrypted backup.'),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.cloud_download_outlined,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Transfer',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'To cloud',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentItem(
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
          onTap: () => onFileTap(file),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: outlineColor.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Badge
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

                // Name and details
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: AppColors.storageGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6046E8).withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpenAiAssistant,
          child: const Center(
            child: Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  void _showHomeMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Browse Files'),
              onTap: () {
                Navigator.pop(ctx);
                onOpenBrowse();
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Open AI Assistant'),
              onTap: () {
                Navigator.pop(ctx);
                onOpenAiAssistant();
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Search Files'),
              onTap: () {
                Navigator.pop(ctx);
                onOpenSearch();
              },
            ),
          ],
        ),
      ),
    );
  }
}
