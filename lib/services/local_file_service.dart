import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models.dart';

class FileScopeException implements Exception {
  FileScopeException(this.message);
  final String message;

  @override
  String toString() => message;
}

class DuplicateFilePair {
  DuplicateFilePair({required this.original, required this.duplicate});
  final FileEntry original;
  final FileEntry duplicate;
}

class SubfolderInfo {
  SubfolderInfo({
    required this.name,
    required this.path,
    required this.fileCount,
    required this.totalBytes,
  });

  final String name;
  final String path;
  final int fileCount;
  final int totalBytes;

  String get formattedSize {
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    if (totalBytes < 1024 * 1024 * 1024) return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class LocalFileService extends ChangeNotifier {
  LocalFileService([String? initialPath]) {
    if (initialPath != null) {
      _authorizedPath = initialPath;
      scanDirectory();
    } else {
      _loadPersistedPath();
    }
  }

  String? _authorizedPath;
  bool _isScanning = false;
  final List<FileEntry> _cachedEntries = [];

  String? get authorizedPath => _authorizedPath;
  String? get rootPath => _authorizedPath;
  bool get isAuthorized => _authorizedPath != null && Directory(_authorizedPath!).existsSync();
  bool get isScanning => _isScanning;
  List<FileEntry> get allEntries => List.unmodifiable(_cachedEntries);


  static List<String> get _candidatePrefFiles {
    return [
      '/data/user/0/com.smartfile.app/files/smartfile_authorized_path.json',
      '/data/user/0/com.smartfile.app/app_flutter/smartfile_authorized_path.json',
      p.join(Directory.systemTemp.path, 'smartfile_authorized_path.json'),
    ];
  }

  static String normalizePath(String raw) {
    var path = raw.trim();
    if (path.isEmpty) return path;

    // 1. Decode URL percent encoding, e.g. primary%3AVidMate%2FDownload -> primary:VidMate/Download
    try {
      path = Uri.decodeComponent(path);
    } catch (_) {}

    // 2. Remove SAF prefixes
    if (path.contains('tree/')) {
      path = path.substring(path.indexOf('tree/') + 5);
    } else if (path.contains('document/')) {
      path = path.substring(path.indexOf('document/') + 9);
    }

    // 3. Map "primary:subpath" -> "/storage/emulated/0/subpath"
    if (path.startsWith('primary:') || path.startsWith('/primary:')) {
      final sub = path.replaceFirst(RegExp(r'^/?primary:'), '').replaceAll(r'\', '/');
      path = p.posix.join('/storage/emulated/0', sub);
    } else if (path.contains(':')) {
      final parts = path.split(':');
      if (parts.length == 2 && !parts[0].startsWith('http')) {
        final volume = parts[0].replaceAll(RegExp(r'^/'), '');
        final sub = parts[1].replaceAll(r'\', '/');
        if (volume == 'primary') {
          path = p.posix.join('/storage/emulated/0', sub);
        } else {
          path = p.posix.join('/storage', volume, sub);
        }
      }
    }

    // 4. If path doesn't start with / on Android, prepend /storage/emulated/0/
    if (Platform.isAndroid && !path.startsWith('/') && !path.startsWith(r'\\')) {
      path = p.posix.join('/storage/emulated/0', path.replaceAll(r'\', '/'));
    }

    if (path.startsWith('/storage')) {
      path = path.replaceAll(r'\', '/');
    }

    // 5. Case-insensitive path resolution for Android filesystems
    if (!Directory(path).existsSync() && Platform.isAndroid) {
      final resolved = _resolveCaseInsensitive(path);
      if (resolved != null) {
        path = resolved;
      }
    }

    return path;
  }

  static String? _resolveCaseInsensitive(String originalPath) {
    try {
      final segments = originalPath
          .replaceAll(r'\', '/')
          .split('/')
          .where((s) => s.isNotEmpty)
          .toList();
      var current = '/';
      if (originalPath.startsWith('/storage/emulated/0') && segments.length >= 3) {
        current = '/storage/emulated/0';
        segments.removeRange(0, 3);
      }

      for (final segment in segments) {
        final direct = p.posix.join(current, segment);
        if (Directory(direct).existsSync()) {
          current = direct;
          continue;
        }

        final dir = Directory(current);
        if (!dir.existsSync()) return null;

        var matched = false;
        for (final entity in dir.listSync()) {
          if (entity is Directory && p.basename(entity.path).toLowerCase() == segment.toLowerCase()) {
            current = entity.path;
            matched = true;
            break;
          }
        }
        if (!matched) return null;
      }

      if (Directory(current).existsSync()) {
        return current;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadPersistedPath() async {
    try {
      for (final candidate in _candidatePrefFiles) {
        final file = File(candidate);
        if (await file.exists()) {
          final content = await file.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final saved = json['authorizedPath'] as String?;
          if (saved != null && saved.isNotEmpty) {
            final normalized = normalizePath(saved);
            if (Directory(normalized).existsSync()) {
              _authorizedPath = normalized;
              await scanDirectory();
              return;
            }
          }
        }
      }
    } catch (_) {}

    // Auto-discover common Android folders if none previously authorized
    if (Platform.isAndroid) {
      final defaultCandidates = [
        '/storage/emulated/0/VidMate/download',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0',
      ];
      for (final dirPath in defaultCandidates) {
        final normalized = normalizePath(dirPath);
        if (Directory(normalized).existsSync()) {
          _authorizedPath = normalized;
          await _persistPath(normalized);
          await scanDirectory();
          return;
        }
      }
    }
  }

  Future<void> _persistPath(String? path) async {
    for (final candidate in _candidatePrefFiles) {
      try {
        final file = File(candidate);
        if (path == null) {
          if (await file.exists()) await file.delete();
        } else {
          final parent = file.parent;
          if (!await parent.exists()) {
            await parent.create(recursive: true);
          }
          await file.writeAsString(jsonEncode({'authorizedPath': path}));
        }
      } catch (_) {}
    }
  }

  Future<String?> pickAndAuthorizeFolder() async {
    try {
      final selectedDirectory = await FilePickerPlatform.instance.getDirectoryPath(
        dialogTitle: 'Select Folder for SmartFile AI',
      );

      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        final normalized = normalizePath(selectedDirectory);
        await setAuthorizedPath(normalized);
        return normalized;
      }
    } catch (e) {
      debugPrint('Error picking folder: $e');
    }
    return null;
  }

  Future<void> setAuthorizedPath(String path) async {
    final normalized = normalizePath(path);
    _authorizedPath = normalized;
    await _persistPath(normalized);
    await scanDirectory();
  }

  Future<void> clearAuthorizedFolder() async {
    _authorizedPath = null;
    _cachedEntries.clear();
    await _persistPath(null);
    notifyListeners();
  }

  Future<void> refresh() async {
    await scanDirectory();
  }

  Future<void> scanDirectory() async {
    if (_authorizedPath == null) {
      _cachedEntries.clear();
      notifyListeners();
      return;
    }

    // Try normalizing path if not existing as-is
    if (!Directory(_authorizedPath!).existsSync()) {
      final normalized = normalizePath(_authorizedPath!);
      if (Directory(normalized).existsSync()) {
        _authorizedPath = normalized;
      } else {
        _cachedEntries.clear();
        notifyListeners();
        return;
      }
    }

    _isScanning = true;
    notifyListeners();

    final entries = <FileEntry>[];
    final rootDir = Directory(_authorizedPath!);

    try {
      final queue = <Directory>[rootDir];
      final visited = <String>{};

      while (queue.isNotEmpty && entries.length < 10000) {
        final currentDir = queue.removeAt(0);
        final canonical = currentDir.path.replaceAll(r'\', '/');
        if (visited.contains(canonical)) continue;
        visited.add(canonical);

        try {
          final children = currentDir.listSync(followLinks: false);
          for (final entity in children) {
            final entityPath = entity.path.replaceAll(r'\', '/');
            final fileName = p.basename(entityPath);

            // Skip hidden system/cache files like .thumbnails, .nomedia
            if (fileName.startsWith('.')) continue;

            if (entity is Directory) {
              final lower = fileName.toLowerCase();
              // Skip restricted Android/data and Android/obb directories
              if (lower == 'data' || lower == 'obb') {
                final parentName = p.basename(p.dirname(entityPath)).toLowerCase();
                if (parentName == 'android') continue;
              }
              if (lower == 'android' &&
                  (entityPath == '/storage/emulated/0/Android' ||
                      entityPath == '/storage/emulated/0/Android/')) {
                continue;
              }

              queue.add(entity);
              final parentDir = p.basename(currentDir.path);
              entries.add(FileEntry(
                path: entityPath,
                name: fileName,
                kind: FileEntryKind.folder,
                modified: DateTime.now(),
                sizeBytes: 0,
                folderName: parentDir.isNotEmpty && parentDir != '0' ? parentDir : 'Root',
              ));
            } else if (entity is File) {
              try {
                final stat = entity.statSync();
                final parentDir = p.basename(currentDir.path);
                entries.add(FileEntry(
                  path: entityPath,
                  name: fileName,
                  kind: FileEntryKind.file,
                  modified: stat.modified,
                  sizeBytes: stat.size,
                  folderName: parentDir.isNotEmpty && parentDir != '0' ? parentDir : 'Root',
                ));
              } catch (_) {}
            }
          }
        } catch (dirError) {
          debugPrint('Skipping restricted directory ${currentDir.path}: $dirError');
        }
      }
    } catch (e) {
      debugPrint('Error scanning directory $_authorizedPath: $e');
    }

    // Sort folders first, then files by modified descending
    entries.sort((a, b) {
      if (a.kind != b.kind) return a.kind == FileEntryKind.folder ? -1 : 1;
      return b.modified.compareTo(a.modified);
    });

    _cachedEntries.clear();
    _cachedEntries.addAll(entries);
    _isScanning = false;
    notifyListeners();
  }

  // --- Dynamic Live Computed Metrics ---

  int get totalFilesCount => _cachedEntries.where((e) => e.kind == FileEntryKind.file).length;

  int get totalFoldersCount => _cachedEntries.where((e) => e.kind == FileEntryKind.folder).length;

  int get totalBytes => _cachedEntries
      .where((e) => e.kind == FileEntryKind.file)
      .fold(0, (sum, file) => sum + file.sizeBytes);

  String get formattedTotalSize {
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    if (totalBytes < 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  List<FileEntry> get recentFiles => _cachedEntries
      .where((e) => e.kind == FileEntryKind.file)
      .take(10)
      .toList();

  List<FileEntry> getCategoryFiles(FileCategory category) {
    return _cachedEntries.where((file) {
      return file.kind == FileEntryKind.file && file.category == category;
    }).toList();
  }

  int getCategoryBytes(FileCategory category) {
    return getCategoryFiles(category).fold(0, (sum, file) => sum + file.sizeBytes);
  }

  int getCategoryCount(FileCategory category) {
    return getCategoryFiles(category).length;
  }

  String formatCategorySize(FileCategory category) {
    final bytes = getCategoryBytes(category);
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  double getCategoryPercentage(FileCategory category) {
    if (totalBytes == 0) return 0.0;
    final bytes = getCategoryBytes(category);
    return (bytes / totalBytes) * 100.0;
  }

  List<SubfolderInfo> get subdirectories {
    if (_authorizedPath == null) return [];
    final root = Directory(_authorizedPath!);
    if (!root.existsSync()) return [];

    final list = <SubfolderInfo>[];
    try {
      final children = root.listSync(followLinks: false);
      for (final child in children) {
        if (child is Directory) {
          final dirName = p.basename(child.path);
          if (dirName.startsWith('.')) continue;
          final filesInSubfolder = _cachedEntries.where((e) {
            return e.kind == FileEntryKind.file && p.isWithin(child.path, e.path);
          }).toList();
          final bytes = filesInSubfolder.fold(0, (sum, f) => sum + f.sizeBytes);
          list.add(SubfolderInfo(
            name: dirName,
            path: child.path,
            fileCount: filesInSubfolder.length,
            totalBytes: bytes,
          ));
        }
      }
    } catch (_) {}

    list.sort((a, b) => b.fileCount.compareTo(a.fileCount));
    return list;
  }

  List<DuplicateFilePair> findDuplicates() {
    final duplicates = <DuplicateFilePair>[];
    final files = _cachedEntries.where((e) => e.kind == FileEntryKind.file && e.sizeBytes > 0).toList();
    final sizeMap = <int, List<FileEntry>>{};

    for (final f in files) {
      sizeMap.putIfAbsent(f.sizeBytes, () => []).add(f);
    }

    for (final group in sizeMap.values) {
      if (group.length > 1) {
        final original = group.first;
        for (var i = 1; i < group.length; i++) {
          duplicates.add(DuplicateFilePair(original: original, duplicate: group[i]));
        }
      }
    }

    return duplicates;
  }

  Future<int> cleanupDuplicates() async {
    final duplicates = findDuplicates();
    var deletedCount = 0;
    for (final pair in duplicates) {
      try {
        final file = File(pair.duplicate.path);
        if (await file.exists()) {
          await file.delete();
          deletedCount++;
        }
      } catch (_) {}
    }
    if (deletedCount > 0) {
      await scanDirectory();
    }
    return deletedCount;
  }

  // --- Real File Operations ---

  Future<List<FileEntry>> listDirectory([String? directoryPath]) async {
    if (_cachedEntries.isEmpty && _authorizedPath != null) {
      await scanDirectory();
    }

    if (directoryPath == null || directoryPath.isEmpty || directoryPath == 'all' || directoryPath == 'smart') {
      return _cachedEntries.where((e) => e.kind == FileEntryKind.file).toList();
    }

    final lower = directoryPath.toLowerCase().trim();

    // Check if it's a category name
    for (final cat in FileCategory.values) {
      if (cat.label.toLowerCase() == lower) {
        return getCategoryFiles(cat);
      }
    }

    // Otherwise filter by folderName or path match
    return _cachedEntries.where((file) {
      return file.folderName.toLowerCase() == lower ||
          file.path.toLowerCase().contains(lower);
    }).toList();
  }

  Future<List<FileEntry>> search(String query, {int limit = 100}) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return recentFiles;

    final results = _cachedEntries.where((file) {
      final inName = file.name.toLowerCase().contains(normalized);
      final inFolder = file.folderName.toLowerCase().contains(normalized);
      final inCategory = file.category.label.toLowerCase().contains(normalized);
      final inExt = file.extension.toLowerCase().contains(normalized);
      return inName || inFolder || inCategory || inExt;
    }).toList();

    return results.take(limit).toList();
  }

  Future<void> createFolder(String parentPath, String name) async {
    final targetParent = (parentPath == '.' || parentPath.isEmpty) ? (_authorizedPath ?? '.') : parentPath;
    final target = p.isAbsolute(targetParent) ? p.join(targetParent, name.trim()) : p.join(_authorizedPath ?? '.', name.trim());
    final dir = Directory(target);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await scanDirectory();
  }

  Future<void> createFile(String itemPath, [String content = '']) async {
    final target = p.isAbsolute(itemPath) ? itemPath : p.join(_authorizedPath ?? '.', itemPath);
    final file = File(target);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsString(content);
    await scanDirectory();
  }

  Future<void> editFile(String itemPath, String newContent) async {
    final target = p.isAbsolute(itemPath) ? itemPath : p.join(_authorizedPath ?? '.', itemPath);
    final file = File(target);
    if (await file.exists()) {
      await file.writeAsString(newContent);
      await scanDirectory();
    }
  }

  Future<void> rename(String itemPath, String newName) async {
    final target = p.isAbsolute(itemPath) ? itemPath : p.join(_authorizedPath ?? '.', itemPath);
    final dir = p.dirname(target);
    final destination = p.join(dir, newName.trim());
    await move(target, destination);
  }

  Future<void> move(String sourcePath, String destinationPath) async {
    final src = p.isAbsolute(sourcePath) ? sourcePath : p.join(_authorizedPath ?? '.', sourcePath);
    var dst = p.isAbsolute(destinationPath) ? destinationPath : p.join(_authorizedPath ?? '.', destinationPath);

    // If destination is an existing directory, move file inside it
    if (await Directory(dst).exists()) {
      dst = p.join(dst, p.basename(src));
    }

    final entity = File(src);
    if (await entity.exists()) {
      final dstParent = Directory(p.dirname(dst));
      if (!await dstParent.exists()) {
        await dstParent.create(recursive: true);
      }
      await entity.rename(dst);
      await scanDirectory();
    } else if (await Directory(src).exists()) {
      await Directory(src).rename(dst);
      await scanDirectory();
    }
  }

  Future<void> delete(String itemPath) async {
    final target = p.isAbsolute(itemPath) ? itemPath : p.join(_authorizedPath ?? '.', itemPath);
    if (await File(target).exists()) {
      await File(target).delete();
    } else if (await Directory(target).exists()) {
      await Directory(target).delete(recursive: true);
    }
    await scanDirectory();
  }

  Future<void> organizeFiles(String sourceDirectory, [String strategy = 'by_type']) async {
    if (_authorizedPath == null) return;
    final root = (sourceDirectory == '.' || sourceDirectory.isEmpty)
        ? _authorizedPath!
        : (p.isAbsolute(sourceDirectory) ? sourceDirectory : p.join(_authorizedPath!, sourceDirectory));

    if (!Directory(root).existsSync()) return;

    if (strategy == 'clean_duplicates') {
      await cleanupDuplicates();
      return;
    }

    // Organize by file category into subdirectories (Documents, Photos, Videos, Audio, APKs, Other)
    final files = _cachedEntries
        .where((e) => e.kind == FileEntryKind.file && p.equals(p.dirname(e.path), root))
        .toList();

    for (final file in files) {
      final categoryDirName = file.category.label;
      final targetDir = p.join(root, categoryDirName);
      final destPath = p.join(targetDir, file.name);

      final dir = Directory(targetDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final f = File(file.path);
      if (await f.exists()) {
        await f.rename(destPath);
      }
    }

    await scanDirectory();
  }

  String get authorizedFolderName {
    if (_authorizedPath == null) return 'No folder';
    final name = p.basename(_authorizedPath!);
    if (name == '0' || name.isEmpty || _authorizedPath == '/storage/emulated/0' || _authorizedPath == '/storage/emulated/0/') {
      return 'Internal Storage';
    }
    return name;
  }

  List<Map<String, String>> getAvailableDeviceFolders() {
    final list = <Map<String, String>>[];
    if (Platform.isAndroid) {
      final presets = [
        {'name': 'VidMate Downloads', 'path': '/storage/emulated/0/VidMate/download'},
        {'name': 'Downloads', 'path': '/storage/emulated/0/Download'},
        {'name': 'Documents', 'path': '/storage/emulated/0/Documents'},
        {'name': 'Camera / DCIM', 'path': '/storage/emulated/0/DCIM'},
        {'name': 'Pictures', 'path': '/storage/emulated/0/Pictures'},
        {'name': 'Music', 'path': '/storage/emulated/0/Music'},
        {'name': 'Movies', 'path': '/storage/emulated/0/Movies'},
        {'name': 'WhatsApp Media', 'path': '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media'},
        {'name': 'Internal Storage', 'path': '/storage/emulated/0'},
      ];
      for (final pItem in presets) {
        final norm = normalizePath(pItem['path']!);
        if (Directory(norm).existsSync()) {
          list.add({'name': pItem['name']!, 'path': norm});
        }
      }
    }
    return list;
  }
}
