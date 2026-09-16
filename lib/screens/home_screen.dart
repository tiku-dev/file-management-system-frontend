import 'package:flutter/material.dart';

import '../models.dart';
import '../services/local_file_service.dart';
import '../theme/app_theme.dart';
import '../widgets/folder_picker_sheet.dart';

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
    return ListenableBuilder(
      listenable: fileService,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = Theme.of(context).cardColor;
        final outlineColor = Theme.of(context).colorScheme.outline;
        final recentFiles = fileService.recentFiles;
        final isAuthorized = fileService.isAuthorized;

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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                            if (isAuthorized) ...[
                              const SizedBox(height: 2),
                              GestureDetector(
                                onTap: () => showDeviceFolderPicker(context, fileService),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.folder_outlined,
                                      size: 14,
                                      color: Color(0xFF6046E8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      fileService.authorizedFolderName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6046E8),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.swap_horiz,
                                      size: 14,
                                      color: Color(0xFF6046E8),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.search, size: 24),
                          onPressed: onOpenSearch,
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert, size: 24),
                          onPressed: () => _showHomeMenu(context),
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
                      // 0. If not authorized, prominent Authorize Folder Banner
                      if (!isAuthorized) ...[
                        _buildAuthorizeCard(context, isDark, cardColor, outlineColor),
                        const SizedBox(height: 16),
                      ],

                      // 1. Storage Overview Gradient Card
                      _buildStorageCard(context),
                      const SizedBox(height: 16),

                      // 2. Tip Card (AI Recommendation based on real files)
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
                      if (recentFiles.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: outlineColor.withValues(alpha: 0.5)),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.folder_open_outlined,
                                  size: 44,
                                  color: isDark ? Colors.white38 : Colors.black26,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  isAuthorized
                                      ? 'No files in this folder yet'
                                      : 'No folder authorized yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isAuthorized
                                      ? 'Add files or use AI to organize'
                                      : 'Authorize a folder above to see your real files',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
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
      },
    );
  }

  Widget _buildAuthorizeCard(
    BuildContext context,
    bool isDark,
    Color cardColor,
    Color outlineColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B38) : const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF6046E8).withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF6046E8).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.folder_special_rounded,
                  color: Color(0xFF6046E8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Authorize Device Folder',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6046E8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Grant SmartFile permission to manage a folder on your phone (e.g. Download, Documents, or Photos). All storage stats and files will come directly from your device.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showDeviceFolderPicker(context, fileService),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text(
                'Select Folder to Manage',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6046E8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageCard(BuildContext context) {
    final isAuthorized = fileService.isAuthorized;
    final totalBytes = fileService.totalBytes;
    final photosBytes = fileService.getCategoryBytes(FileCategory.photos);
    final docsBytes = fileService.getCategoryBytes(FileCategory.documents);
    final videosBytes = fileService.getCategoryBytes(FileCategory.videos);
    final audioBytes = fileService.getCategoryBytes(FileCategory.audio);
    final apksBytes = fileService.getCategoryBytes(FileCategory.apks);
    final otherBytes = fileService.getCategoryBytes(FileCategory.other);

    // Dynamic flex ratios
    final flexPhotos = totalBytes > 0 ? (photosBytes * 100 ~/ totalBytes).clamp(0, 100) : 0;
    final flexDocs = totalBytes > 0 ? (docsBytes * 100 ~/ totalBytes).clamp(0, 100) : 0;
    final flexVideos = totalBytes > 0 ? (videosBytes * 100 ~/ totalBytes).clamp(0, 100) : 0;
    final flexAudio = totalBytes > 0 ? (audioBytes * 100 ~/ totalBytes).clamp(0, 100) : 0;
    final flexApks = totalBytes > 0 ? (apksBytes * 100 ~/ totalBytes).clamp(0, 100) : 0;
    final flexOther = totalBytes > 0 ? (otherBytes * 100 ~/ totalBytes).clamp(0, 100) : 0;

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
          // STORAGE badge + change action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => showDeviceFolderPicker(context, fileService),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        isAuthorized ? fileService.authorizedFolderName.toUpperCase() : 'DEVICE STORAGE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => showDeviceFolderPicker(context, fileService),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz, color: Colors.white, size: 14),
                          SizedBox(width: 3),
                          Text(
                            'Switch',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isAuthorized)
                    GestureDetector(
                      onTap: () async {
                        await fileService.refresh();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Files rescanned from device!')),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh, color: Colors.white, size: 14),
                            SizedBox(width: 3),
                            Text(
                              'Sync',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Real used bytes stat
          Text(
            isAuthorized ? '${fileService.formattedTotalSize} used' : 'No folder authorized',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isAuthorized
                ? '${fileService.totalFilesCount} files · ${fileService.totalFoldersCount} subfolders'
                : 'Tap Authorize Folder above to begin',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // Multi-segment progress bar with real dynamic segments
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: totalBytes == 0
                  ? Container(color: Colors.white.withValues(alpha: 0.2))
                  : Row(
                      children: [
                        if (flexPhotos > 0)
                          Expanded(flex: flexPhotos, child: Container(color: AppColors.photosColor)),
                        if (flexDocs > 0)
                          Expanded(flex: flexDocs, child: Container(color: AppColors.docsColor)),
                        if (flexVideos > 0)
                          Expanded(flex: flexVideos, child: Container(color: const Color(0xFFF97316))),
                        if (flexAudio > 0)
                          Expanded(flex: flexAudio, child: Container(color: const Color(0xFFA855F7))),
                        if (flexApks > 0)
                          Expanded(flex: flexApks, child: Container(color: AppColors.appsColor)),
                        if (flexOther > 0)
                          Expanded(
                            flex: flexOther,
                            child: Container(color: Colors.white.withValues(alpha: 0.4)),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend dots & labels reflecting real device sizes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendDot(
                AppColors.photosColor,
                'Photos ${fileService.formatCategorySize(FileCategory.photos)}',
              ),
              _buildLegendDot(
                AppColors.docsColor,
                'Docs ${fileService.formatCategorySize(FileCategory.documents)}',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendDot(
                const Color(0xFFF97316),
                'Videos ${fileService.formatCategorySize(FileCategory.videos)}',
              ),
              _buildLegendDot(
                AppColors.appsColor,
                'APKs ${fileService.formatCategorySize(FileCategory.apks)}',
              ),
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
    final duplicates = fileService.findDuplicates();

    String tipText;
    if (!fileService.isAuthorized) {
      tipText = 'Tip: Authorize a folder so FileMind AI can organize your phone.';
    } else if (duplicates.isNotEmpty) {
      tipText = 'Tip: ${duplicates.length} duplicate files found. Want me to clean them up?';
    } else {
      tipText = 'Tip: All ${fileService.totalFilesCount} files are organized. Ask AI to rename or sort files.';
    }

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
                tipText,
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
    final duplicates = fileService.findDuplicates();

    return Row(
      children: [
        // Clean up card
        Expanded(
          child: GestureDetector(
            onTap: () async {
              if (!fileService.isAuthorized) {
                await fileService.pickAndAuthorizeFolder();
                return;
              }
              if (duplicates.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No duplicate files found in this folder!')),
                  );
                }
                return;
              }

              final cleaned = await fileService.cleanupDuplicates();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cleaned $cleaned duplicate files from device!'),
                    backgroundColor: const Color(0xFF10B981),
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
                    duplicates.isNotEmpty
                        ? '${duplicates.length} duplicates'
                        : (fileService.isAuthorized ? 'Folder clean' : 'Select folder'),
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

        // AI Organize Card
        Expanded(
          child: GestureDetector(
            onTap: onOpenAiAssistant,
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
                      color: const Color(0xFF6046E8).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF6046E8),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AI Organize',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Auto-sort files',
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
          onTap: () => _showFabActionMenu(context),
          child: const Center(
            child: Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  void _showFabActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Actions for ${fileService.authorizedFolderName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined, color: Color(0xFF6046E8)),
              title: const Text('Create New Folder'),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateFolderDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined, color: Color(0xFF10B981)),
              title: const Text('Create New Text File'),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateFileDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_shared_outlined, color: Color(0xFFF59E0B)),
              title: const Text('Change Authorized Folder'),
              onTap: () async {
                Navigator.pop(ctx);
                await fileService.pickAndAuthorizeFolder();
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Color(0xFF3B82F6)),
              title: const Text('Ask AI Assistant to Organize'),
              onTap: () {
                Navigator.pop(ctx);
                onOpenAiAssistant();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Folder'),
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
                await fileService.createFolder('.', name);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Folder "$name" created on device!')),
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

  void _showCreateFileDialog(BuildContext context) {
    final nameController = TextEditingController(text: 'notes.txt');
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'File Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Content (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                await fileService.createFile(name, contentController.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('File "$name" created on device!')),
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


  void _showHomeMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.folder_shared_outlined),
              title: const Text('Authorize Folder'),
              onTap: () async {
                Navigator.pop(ctx);
                await fileService.pickAndAuthorizeFolder();
              },
            ),
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
