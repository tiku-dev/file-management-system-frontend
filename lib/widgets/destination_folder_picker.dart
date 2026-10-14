import 'package:flutter/material.dart';
import '../services/local_file_service.dart';

/// Shows a bottom sheet to pick a destination folder for moving files.
Future<Map<String, String>?> showDestinationFolderPicker(
  BuildContext context,
  LocalFileService fileService,
) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final subfolders = fileService.subdirectories;
  final rootPath = fileService.authorizedPath;
  final rootName = fileService.authorizedFolderName;

  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
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
                        'Select Destination Folder',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.create_new_folder_outlined, color: Color(0xFF6046E8)),
                        tooltip: 'New Folder',
                        onPressed: () async {
                          final nameController = TextEditingController();
                          final newName = await showDialog<String>(
                            context: ctx,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('Create Folder'),
                              content: TextField(
                                controller: nameController,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: 'Folder Name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(dCtx, nameController.text.trim()),
                                  child: const Text('Create'),
                                ),
                              ],
                            ),
                          );

                          if (newName != null && newName.isNotEmpty) {
                            await fileService.createFolder('.', newName);
                            setModalState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose where you want to move the selected files:',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        // Root Folder Option
                        if (rootPath != null)
                          ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6046E8).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.home_outlined, color: Color(0xFF6046E8), size: 22),
                            ),
                            title: Text(
                              rootName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: const Text('Root directory', style: TextStyle(fontSize: 11)),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () {
                              Navigator.pop(ctx, {'name': rootName, 'path': rootPath});
                            },
                          ),
                        const Divider(height: 12),

                        // Subfolders
                        ...subfolders.map((f) {
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6046E8).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.folder_outlined, color: Color(0xFF6046E8), size: 22),
                            ),
                            title: Text(
                              f.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${f.fileCount} files · ${f.formattedSize}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () {
                              Navigator.pop(ctx, {'name': f.name, 'path': f.path});
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
