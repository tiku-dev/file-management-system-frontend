import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/local_file_service.dart';
import '../widgets/destination_folder_picker.dart';
import '../widgets/document_reader_view.dart';
import '../widgets/permission_dialogs.dart';

class FilePreviewScreen extends StatefulWidget {
  const FilePreviewScreen({
    super.key,
    required this.file,
    required this.fileService,
    this.onFileDeleted,
    this.onFileRenamed,
  });

  final FileEntry file;
  final LocalFileService fileService;
  final VoidCallback? onFileDeleted;
  final ValueChanged<String>? onFileRenamed;

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> with SingleTickerProviderStateMixin {
  late FileEntry _currentFile;
  bool _forceDocumentReader = false;

  // Audio simulated playback state
  bool _isPlayingAudio = false;
  double _audioProgress = 0.0;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.file;
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _handleOpenWithExternalApp() async {
    try {
      final result = await OpenFilex.open(_currentFile.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${result.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching file: $e')),
        );
      }
    }
  }

  Future<void> _handleShare() async {
    try {
      final xFile = XFile(_currentFile.path);
      // ignore: deprecated_member_use
      await Share.shareXFiles([xFile], text: _currentFile.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDeletePermissionDialog(
      context,
      count: 1,
      fileNames: [_currentFile.name],
    );

    if (confirmed && mounted) {
      await widget.fileService.delete(_currentFile.path);
      widget.onFileDeleted?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${_currentFile.name}')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _handleMove() async {
    final destination = await showDestinationFolderPicker(context, widget.fileService);
    if (destination == null || !mounted) return;

    final confirmed = await showMovePermissionDialog(
      context,
      count: 1,
      destinationName: destination['name']!,
      destinationPath: destination['path']!,
    );

    if (confirmed && mounted) {
      final targetPath = destination['path']!;
      await widget.fileService.move(_currentFile.path, targetPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved ${_currentFile.name} to ${destination['name']}')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _handleRename() async {
    final controller = TextEditingController(text: _currentFile.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'File Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _currentFile.name) {
      await widget.fileService.rename(_currentFile.path, newName);
      final dir = File(_currentFile.path).parent.path;
      final newPath = Platform.isWindows ? '$dir\\$newName' : '$dir/$newName';
      setState(() {
        _currentFile = _currentFile.copyWith(name: newName, path: newPath);
      });
      widget.onFileRenamed?.call(newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renamed to $newName')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final outlineColor = Theme.of(context).colorScheme.outline;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F111A) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF161A29) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentFile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              '${_currentFile.formattedSize} · ${_currentFile.folderName}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _handleShare,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: 'Open with System App',
            onPressed: _handleOpenWithExternalApp,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preview Body Area
            Expanded(
              child: _buildPreviewBody(context, isDark, cardColor, outlineColor),
            ),

            // Bottom Action Bar
            _buildBottomActionBar(context, isDark, cardColor, outlineColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewBody(BuildContext context, bool isDark, Color cardColor, Color outlineColor) {
    if (_currentFile.isImage) {
      return _buildImagePreview();
    } else if (_currentFile.isAudio) {
      return _buildAudioPreview(isDark, cardColor, outlineColor);
    } else if (_currentFile.isVideo) {
      return _buildVideoPreview(isDark, cardColor, outlineColor);
    } else if (_currentFile.isDocumentReadable || _forceDocumentReader) {
      return DocumentReaderView(
        file: _currentFile,
        onOpenExternal: _handleOpenWithExternalApp,
        onShare: _handleShare,
      );
    } else {
      return _buildDocumentCardPreview(isDark, cardColor, outlineColor);
    }
  }

  Widget _buildImagePreview() {
    final imageFile = File(_currentFile.path);

    return Container(
      color: Colors.black,
      child: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            imageFile,
            fit: BoxFit.contain,
            errorBuilder: (_, error, _) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to render image preview',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _handleOpenWithExternalApp,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open in Photo Viewer'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPreview(bool isDark, Color cardColor, Color outlineColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Vinyl / Disc Graphic
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFA855F7), Color(0xFF6046E8), Color(0xFF1E1B38)],
                    stops: [0.2, 0.7, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA855F7).withValues(alpha: _isPlayingAudio ? 0.4 : 0.15),
                      blurRadius: _isPlayingAudio ? 30 : 15,
                      spreadRadius: _isPlayingAudio ? 5 : 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F111A) : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 32,
                      color: const Color(0xFFA855F7),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // File Title & Details
          Text(
            _currentFile.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFA855F7).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentFile.extension.toUpperCase()} Audio · ${_currentFile.formattedSize}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFA855F7),
              ),
            ),
          ),
          const SizedBox(height: 36),

          // Audio Waveform Visualization Simulation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(24, (index) {
              final heights = [12, 24, 38, 18, 44, 28, 52, 34, 48, 20, 36, 56, 42, 22, 50, 32, 16, 40, 26, 46, 18, 30, 14, 22];
              final h = heights[index % heights.length].toDouble();
              return Container(
                width: 3.5,
                height: _isPlayingAudio ? h : (h * 0.4).clamp(8.0, 50.0),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: (index / 24.0) <= _audioProgress
                      ? const Color(0xFFA855F7)
                      : (isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Progress Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: const Color(0xFFA855F7),
              inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
              thumbColor: const Color(0xFFA855F7),
            ),
            child: Slider(
              value: _audioProgress,
              onChanged: (val) {
                setState(() => _audioProgress = val);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Playback Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10_rounded, size: 28),
                onPressed: () {
                  setState(() => _audioProgress = (_audioProgress - 0.1).clamp(0.0, 1.0));
                },
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isPlayingAudio = !_isPlayingAudio;
                    if (_isPlayingAudio) {
                      _waveController.repeat(reverse: true);
                    } else {
                      _waveController.stop();
                    }
                  });
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFA855F7),
                  ),
                  child: Center(
                    child: Icon(
                      _isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.forward_10_rounded, size: 28),
                onPressed: () {
                  setState(() => _audioProgress = (_audioProgress + 0.1).clamp(0.0, 1.0));
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Open in External Player
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _handleOpenWithExternalApp,
            icon: const Icon(Icons.launch_rounded, size: 18),
            label: const Text('Open with Full Music Player'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview(bool isDark, Color cardColor, Color outlineColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              height: 240,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2235) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _currentFile.extension.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _handleOpenWithExternalApp,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF97316).withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 44,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tap to Play Video',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Plays in your device native media player',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildMetadataTile(
              icon: Icons.movie_outlined,
              label: 'Format',
              value: _currentFile.extension.toUpperCase(),
              isDark: isDark,
            ),
            _buildMetadataTile(
              icon: Icons.data_usage_outlined,
              label: 'Size',
              value: _currentFile.formattedSize,
              isDark: isDark,
            ),
            _buildMetadataTile(
              icon: Icons.folder_outlined,
              label: 'Folder',
              value: _currentFile.folderName,
              isDark: isDark,
            ),
            _buildMetadataTile(
              icon: Icons.calendar_today_outlined,
              label: 'Modified',
              value: _currentFile.formattedDate,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCardPreview(bool isDark, Color cardColor, Color outlineColor) {
    final isApk = _currentFile.isApk;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _currentFile.badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _currentFile.badgeColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  _currentFile.badgeText,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: _currentFile.badgeColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _currentFile.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_currentFile.formattedSize} · ${_currentFile.folderName}',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 28),

            if (!isApk) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6046E8),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  setState(() {
                    _forceDocumentReader = true;
                  });
                },
                icon: const Icon(Icons.menu_book_rounded, size: 20),
                label: const Text(
                  'Read Document in App',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _handleOpenWithExternalApp,
                icon: const Icon(Icons.launch_rounded, size: 18),
                label: const Text('Open in Default App'),
              ),
            ] else ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _handleOpenWithExternalApp,
                icon: const Icon(Icons.android_rounded, size: 20),
                label: const Text(
                  'Install Application',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 28),

            _buildMetadataTile(
              icon: Icons.info_outline_rounded,
              label: 'Type',
              value: '${_currentFile.extension.toUpperCase()} File',
              isDark: isDark,
            ),
            _buildMetadataTile(
              icon: Icons.folder_open_rounded,
              label: 'Location',
              value: _currentFile.path,
              isDark: isDark,
            ),
            _buildMetadataTile(
              icon: Icons.calendar_today_rounded,
              label: 'Last Modified',
              value: _currentFile.formattedDate,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, bool isDark, Color cardColor, Color outlineColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          top: BorderSide(
            color: outlineColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionItem(
            icon: Icons.drive_file_move_outlined,
            label: 'Move',
            onTap: _handleMove,
            color: const Color(0xFF6046E8),
          ),
          _buildActionItem(
            icon: Icons.drive_file_rename_outline_rounded,
            label: 'Rename',
            onTap: _handleRename,
            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
          ),
          _buildActionItem(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: _handleShare,
            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
          ),
          _buildActionItem(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            onTap: _handleDelete,
            color: const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
