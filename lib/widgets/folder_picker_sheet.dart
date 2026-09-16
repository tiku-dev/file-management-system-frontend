import 'package:flutter/material.dart';
import '../services/local_file_service.dart';

Future<void> showDeviceFolderPicker(BuildContext context, LocalFileService fileService) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final availableFolders = fileService.getAvailableDeviceFolders();
  final currentPath = fileService.authorizedPath;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Device Folder',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  if (fileService.isAuthorized)
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await fileService.clearAuthorizedFolder();
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Authorize a folder on your phone for FileMind AI to manage real files and storage metrics.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 16),

              // Device folders list
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...availableFolders.map((f) {
                      final isSelected = currentPath != null &&
                          (currentPath == f['path'] || currentPath.toLowerCase() == f['path']!.toLowerCase());
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6046E8).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.folder_outlined,
                            color: Color(0xFF6046E8),
                            size: 22,
                          ),
                        ),
                        title: Text(
                          f['name']!,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? const Color(0xFF6046E8) : null,
                          ),
                        ),
                        subtitle: Text(
                          f['path']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Color(0xFF10B981))
                            : const Icon(Icons.chevron_right, size: 18),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await fileService.setAuthorizedPath(f['path']!);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Connected to ${f['name']} (${fileService.totalFilesCount} files)',
                                ),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                        },
                      );
                    }),

                    const Divider(height: 24),

                    // System File Picker option
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.folder_open_rounded,
                          color: Color(0xFF3B82F6),
                          size: 22,
                        ),
                      ),
                      title: const Text('Browse with System Picker...'),
                      subtitle: const Text('Pick any folder using the Android document picker', style: TextStyle(fontSize: 11)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final selected = await fileService.pickAndAuthorizeFolder();
                        if (selected != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Connected to ${fileService.authorizedFolderName} (${fileService.totalFilesCount} files)',
                              ),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        }
                      },
                    ),

                    // Custom path input option
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.edit_road_rounded,
                          color: Color(0xFFF97316),
                          size: 22,
                        ),
                      ),
                      title: const Text('Enter Custom Folder Path...'),
                      subtitle: const Text('Type or paste an absolute directory path', style: TextStyle(fontSize: 11)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showCustomPathDialog(context, fileService);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showCustomPathDialog(BuildContext context, LocalFileService fileService) {
  final controller = TextEditingController(text: fileService.authorizedPath ?? '/storage/emulated/0/');
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Enter Directory Path'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '/storage/emulated/0/...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final path = controller.text.trim();
            if (path.isNotEmpty) {
              Navigator.pop(ctx);
              await fileService.setAuthorizedPath(path);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Connected to ${fileService.authorizedFolderName} (${fileService.totalFilesCount} files)',
                    ),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            }
          },
          child: const Text('Set Path'),
        ),
      ],
    ),
  );
}
