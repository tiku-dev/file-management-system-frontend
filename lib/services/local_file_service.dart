import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

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
      if (Directory(initialPath).existsSync()) {
        _authorizedPath = initialPath;
        _useShowcase = false;
        scanDirectory();
      } else {
        _authorizedPath = initialPath;
        _useShowcase = true;
      }
    } else {
      _loadPersistedPath();
    }
  }

  String? _authorizedPath;
  bool _isScanning = false;
  bool _useShowcase = true;
  List<DuplicateFilePair>? _showcaseDuplicatesOverride;
  final List<FileEntry> _cachedEntries = [];

  bool get useShowcase => _useShowcase;
  String? get authorizedPath => _useShowcase
      ? '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media'
      : _authorizedPath;
  String? get rootPath => authorizedPath;
  bool get isAuthorized =>
      _useShowcase || (_authorizedPath != null && Directory(_authorizedPath!).existsSync());
  bool get isScanning => _isScanning;
  List<FileEntry> get allEntries =>
      _useShowcase ? _showcaseEntries : List.unmodifiable(_cachedEntries);
  List<FileEntry> get files => allEntries;

  void enableShowcaseMode() {
    _useShowcase = true;
    _showcaseDuplicatesOverride = null;
    _authorizedPath = '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media';
    notifyListeners();
  }


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
    if (!kIsWeb && Platform.isAndroid) {
      await ensureStoragePermission();
    }

    try {
      for (final candidate in _candidatePrefFiles) {
        final file = File(candidate);
        if (await file.exists()) {
          final content = await file.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final saved = json['authorizedPath'] as String?;
          if (saved != null && saved.isNotEmpty) {
            if (saved == 'showcase') {
              enableShowcaseMode();
              return;
            }
            final normalized = normalizePath(saved);
            if (Directory(normalized).existsSync()) {
              _authorizedPath = normalized;
              _useShowcase = false;
              await scanDirectory();
              if (_cachedEntries.isNotEmpty) {
                return;
              }
            }
          }
        }
      }
    } catch (_) {}

    // Auto-discover real Android storage if none previously authorized or previous folder was empty
    if (!kIsWeb && Platform.isAndroid) {
      final defaultCandidates = [
        '/storage/emulated/0',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media',
      ];
      for (final dirPath in defaultCandidates) {
        final normalized = normalizePath(dirPath);
        if (Directory(normalized).existsSync()) {
          _authorizedPath = normalized;
          _useShowcase = false;
          await _persistPath(normalized);
          await scanDirectory();
          if (_cachedEntries.isNotEmpty) {
            return;
          }
        }
      }
    }

    // Default to showcase Media dataset if not on Android or no accessible storage
    _useShowcase = true;
    _authorizedPath = '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media';
    notifyListeners();
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
      if (!kIsWeb && Platform.isAndroid) {
        await ensureStoragePermission();
      }
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
    if (path == 'showcase' ||
        (path.contains('com.whatsapp/WhatsApp/Media') && !Directory(path).existsSync())) {
      await _persistPath('showcase');
      enableShowcaseMode();
      return;
    }
    if (!kIsWeb && Platform.isAndroid) {
      await ensureStoragePermission();
    }
    final normalized = normalizePath(path);
    _authorizedPath = normalized;
    _useShowcase = false;
    _showcaseDuplicatesOverride = null;
    await _persistPath(normalized);
    await scanDirectory();
  }

  Future<void> clearAuthorizedFolder() async {
    _useShowcase = false;
    _showcaseDuplicatesOverride = null;
    _authorizedPath = null;
    _cachedEntries.clear();
    await _persistPath(null);
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!kIsWeb && Platform.isAndroid) {
      final granted = await ensureStoragePermission();
      if (granted && _useShowcase) {
        await _loadPersistedPath();
        return;
      }
    }
    if (_useShowcase) {
      _isScanning = true;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _isScanning = false;
      notifyListeners();
      return;
    }
    await scanDirectory();
  }

  Future<void> syncOnResume() async {
    if (kIsWeb || !Platform.isAndroid || _isScanning) return;
    if (await hasStoragePermission()) {
      if (_useShowcase || _cachedEntries.isEmpty) {
        await _loadPersistedPath();
      } else {
        await scanDirectory();
      }
    }
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
              // Skip restricted Android/data and Android/obb directories (allow Android/media)
              if (lower == 'data' || lower == 'obb' || lower == 'obj') {
                final parentName = p.basename(p.dirname(entityPath)).toLowerCase();
                if (parentName == 'android') continue;
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

  int get totalFilesCount =>
      _useShowcase ? 9358 : _cachedEntries.where((e) => e.kind == FileEntryKind.file).length;

  int get totalFoldersCount =>
      _useShowcase ? 122 : _cachedEntries.where((e) => e.kind == FileEntryKind.folder).length;

  int get totalBytes => _useShowcase
      ? 1884503100
      : _cachedEntries
          .where((e) => e.kind == FileEntryKind.file)
          .fold(0, (sum, file) => sum + file.sizeBytes);

  String get formattedTotalSize {
    if (_useShowcase) return '1.8 GB';
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    if (totalBytes < 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  List<FileEntry> get recentFiles => _useShowcase
      ? _showcaseRecentFiles
      : _cachedEntries.where((e) => e.kind == FileEntryKind.file).take(10).toList();

  List<FileEntry> getCategoryFiles(FileCategory category) {
    if (_useShowcase) {
      return _showcaseEntries.where((file) {
        return file.kind == FileEntryKind.file && file.category == category;
      }).toList();
    }
    return _cachedEntries.where((file) {
      return file.kind == FileEntryKind.file && file.category == category;
    }).toList();
  }

  int getCategoryBytes(FileCategory category) {
    if (_useShowcase) {
      switch (category) {
        case FileCategory.documents:
          return 41104179;
        case FileCategory.photos:
          return 1012612464;
        case FileCategory.videos:
          return 542113792;
        case FileCategory.audio:
          return 0;
        case FileCategory.apks:
          return 0;
        case FileCategory.other:
          return 288672665;
        default:
          return 0;
      }
    }
    return getCategoryFiles(category).fold(0, (sum, file) => sum + file.sizeBytes);
  }

  int getCategoryCount(FileCategory category) {
    if (_useShowcase) {
      switch (category) {
        case FileCategory.documents:
          return 50;
        case FileCategory.photos:
          return 5483;
        case FileCategory.videos:
          return 94;
        case FileCategory.audio:
          return 0;
        case FileCategory.apks:
          return 0;
        case FileCategory.other:
          return 3731;
        default:
          return 0;
      }
    }
    return getCategoryFiles(category).length;
  }

  String formatCategorySize(FileCategory category) {
    if (_useShowcase) {
      switch (category) {
        case FileCategory.documents:
          return '39.2 MB';
        case FileCategory.photos:
          return '965.7 MB';
        case FileCategory.videos:
          return '517.0 MB';
        case FileCategory.audio:
          return '0 B';
        case FileCategory.apks:
          return '0 B';
        case FileCategory.other:
          return '275.3 MB';
        default:
          return '0 B';
      }
    }
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
    if (_useShowcase) {
      return _showcaseSubdirectories;
    }
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
    if (_useShowcase) {
      return _showcaseDuplicatesOverride ?? _showcaseDuplicates;
    }
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
    if (_useShowcase) {
      _showcaseDuplicatesOverride = [];
      notifyListeners();
      return 6;
    }
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
    if (_useShowcase) {
      if (directoryPath == null || directoryPath.isEmpty || directoryPath == 'all' || directoryPath == 'smart') {
        return _showcaseEntries;
      }
      final lower = directoryPath.toLowerCase().trim();
      for (final cat in FileCategory.values) {
        if (cat.label.toLowerCase() == lower) {
          return getCategoryFiles(cat);
        }
      }
      return _showcaseEntries.where((file) {
        return file.folderName.toLowerCase() == lower ||
            file.path.toLowerCase().contains(lower);
      }).toList();
    }

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

  // --- Android Storage Permission & Checks ---

  Future<bool> hasStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await Permission.storage.isGranted) return true;
      if (await Permission.photos.isGranted || await Permission.videos.isGranted) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> requestStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) return true;

      final mediaStatuses = await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
        Permission.storage,
      ].request();
      if (mediaStatuses.values.any((s) => s.isGranted)) return true;
    } catch (_) {}
    return await hasStoragePermission();
  }

  Future<bool> ensureStoragePermission() async {
    if (await hasStoragePermission()) return true;
    return await requestStoragePermission();
  }

  // --- Folder Specific Listing ---

  List<FileEntry> getFilesInFolder(String folderPath, {bool recursive = false}) {
    final normTarget = normalizePath(folderPath).replaceAll(r'\', '/').toLowerCase();
    return _cachedEntries.where((file) {
      if (file.kind != FileEntryKind.file) return false;
      final fileDir = p.dirname(file.path).replaceAll(r'\', '/').toLowerCase();
      if (recursive) {
        return fileDir == normTarget || fileDir.startsWith('$normTarget/');
      } else {
        return fileDir == normTarget || p.basename(fileDir) == p.basename(normTarget);
      }
    }).toList();
  }

  List<FileEntry> getFolderContents(String folderPath) {
    final normTarget = normalizePath(folderPath).replaceAll(r'\', '/');
    final dir = Directory(normTarget);
    if (!dir.existsSync()) return getFilesInFolder(folderPath);

    final results = <FileEntry>[];
    try {
      final children = dir.listSync(followLinks: false);
      for (final entity in children) {
        final path = entity.path.replaceAll(r'\', '/');
        final name = p.basename(path);
        if (name.startsWith('.')) continue;

        if (entity is Directory) {
          results.add(FileEntry(
            path: path,
            name: name,
            kind: FileEntryKind.folder,
            modified: DateTime.now(),
            sizeBytes: 0,
            folderName: p.basename(normTarget),
          ));
        } else if (entity is File) {
          try {
            final stat = entity.statSync();
            results.add(FileEntry(
              path: path,
              name: name,
              kind: FileEntryKind.file,
              modified: stat.modified,
              sizeBytes: stat.size,
              folderName: p.basename(normTarget),
            ));
          } catch (_) {}
        }
      }
    } catch (_) {
      return getFilesInFolder(folderPath);
    }

    results.sort((a, b) {
      if (a.kind != b.kind) return a.kind == FileEntryKind.folder ? -1 : 1;
      return b.modified.compareTo(a.modified);
    });
    return results;
  }

  // --- Popular Files Helpers ---

  List<FileEntry> getPopularFiles({String? popularType}) {
    final allFiles = _cachedEntries.where((e) => e.kind == FileEntryKind.file).toList();
    if (popularType == null || popularType.isEmpty || popularType.toLowerCase() == 'all') {
      return allFiles;
    }
    final lower = popularType.toLowerCase();
    switch (lower) {
      case 'docs':
      case 'documents':
        return allFiles.where((f) => f.isDocument).toList();
      case 'apk':
      case 'apks':
        return allFiles.where((f) => f.isApk).toList();
      case 'ppt':
      case 'pptx':
      case 'presentations':
        return allFiles.where((f) => f.isPpt).toList();
      case 'excel':
      case 'sheets':
      case 'xls':
      case 'xlsx':
      case 'csv':
        return allFiles.where((f) => f.isExcel).toList();
      case 'photos':
      case 'images':
        return allFiles.where((f) => f.isImage).toList();
      case 'videos':
        return allFiles.where((f) => f.isVideo).toList();
      case 'audio':
        return allFiles.where((f) => f.isAudio).toList();
      default:
        return allFiles.where((f) => f.category.label.toLowerCase() == lower).toList();
    }
  }

  int getPopularFilesCount(String type) {
    return getPopularFiles(popularType: type).length;
  }

  Future<List<FileEntry>> search(String query, {int limit = 100, String? filterType}) async {
    final normalized = query.trim().toLowerCase();
    List<FileEntry> pool;

    if (filterType != null && filterType.isNotEmpty && filterType != 'All') {
      pool = getPopularFiles(popularType: filterType);
    } else {
      pool = _cachedEntries.where((e) => e.kind == FileEntryKind.file).toList();
    }

    if (normalized.isEmpty) {
      return pool.take(limit).toList();
    }

    final results = pool.where((file) {
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

  Future<void> rename(String itemPath, String newName, {bool rescan = true}) async {
    final target = _resolvePath(itemPath);
    final dir = p.dirname(target);
    final destination = p.join(dir, newName.trim());
    await move(target, destination, rescan: rescan);
  }

  String _resolvePath(String itemPath) {
    if (p.isAbsolute(itemPath) && (File(itemPath).existsSync() || Directory(itemPath).existsSync())) {
      return itemPath;
    }
    final direct = p.isAbsolute(itemPath) ? itemPath : p.join(_authorizedPath ?? '.', itemPath);
    if (File(direct).existsSync() || Directory(direct).existsSync()) {
      return direct;
    }
    // Search cached entries by filename
    final base = p.basename(itemPath).toLowerCase();
    for (final entry in _cachedEntries) {
      if (entry.name.toLowerCase() == base || entry.path.toLowerCase().endsWith(base)) {
        if (File(entry.path).existsSync() || Directory(entry.path).existsSync()) {
          return entry.path;
        }
      }
    }
    return direct;
  }

  Future<void> move(String sourcePath, String destinationPath, {bool rescan = true}) async {
    final src = _resolvePath(sourcePath);
    var dst = p.isAbsolute(destinationPath) ? destinationPath : p.join(_authorizedPath ?? '.', destinationPath);

    if (await Directory(dst).exists()) {
      dst = p.join(dst, p.basename(src));
    }

    final entity = File(src);
    if (await entity.exists()) {
      final dstParent = Directory(p.dirname(dst));
      if (!await dstParent.exists()) {
        await dstParent.create(recursive: true);
      }
      try {
        await entity.rename(dst);
      } catch (_) {
        // Fallback for Android cross-device or permission quirks
        await entity.copy(dst);
        await entity.delete();
      }
      if (rescan) await scanDirectory();
    } else if (await Directory(src).exists()) {
      try {
        await Directory(src).rename(dst);
      } catch (_) {}
      if (rescan) await scanDirectory();
    }
  }

  Future<int> executePlan(AiPlan plan) async {
    if (!isAuthorized) return 0;
    int successCount = 0;

    for (final op in plan.operations) {
      try {
        switch (op.name) {
          case 'rename_file':
            final path = op.input['path'] as String?;
            final newName = op.input['newName'] as String?;
            if (path != null && newName != null && newName.trim().isNotEmpty) {
              await rename(path, newName.trim(), rescan: false);
              successCount++;
            }
            break;
          case 'move_file':
            final src = op.input['sourcePath'] as String? ?? op.input['path'] as String?;
            final dst = op.input['destinationPath'] as String? ?? op.input['destination'] as String?;
            if (src != null && dst != null) {
              await move(src, dst, rescan: false);
              successCount++;
            }
            break;
          case 'create_folder':
            final path = op.input['path'] as String? ?? op.input['name'] as String?;
            if (path != null) {
              final target = p.isAbsolute(path) ? path : p.join(_authorizedPath ?? '.', path);
              final dir = Directory(target);
              if (!await dir.exists()) {
                await dir.create(recursive: true);
              }
              successCount++;
            }
            break;
          case 'create_file':
            final path = op.input['path'] as String? ?? op.input['name'] as String?;
            final content = op.input['content'] as String? ?? '';
            if (path != null) {
              final target = p.isAbsolute(path) ? path : p.join(_authorizedPath ?? '.', path);
              final file = File(target);
              if (!await file.parent.exists()) {
                await file.parent.create(recursive: true);
              }
              await file.writeAsString(content);
              successCount++;
            }
            break;
          case 'delete_file':
          case 'delete_item':
            final path = op.input['path'] as String?;
            if (path != null) {
              final target = _resolvePath(path);
              if (await File(target).exists()) {
                await File(target).delete();
                successCount++;
              } else if (await Directory(target).exists()) {
                await Directory(target).delete(recursive: true);
                successCount++;
              }
            }
            break;
          case 'edit_file':
            final path = op.input['path'] as String?;
            final content = op.input['content'] as String? ?? '';
            if (path != null) {
              final target = _resolvePath(path);
              final file = File(target);
              if (await file.exists()) {
                await file.writeAsString(content);
                successCount++;
              }
            }
            break;
          case 'organize_files':
            final src = op.input['sourceDirectory'] as String? ?? '.';
            final strategy = op.input['strategy'] as String? ?? 'by_type';
            await organizeFiles(src, strategy);
            successCount++;
            break;
        }
      } catch (e) {
        debugPrint('Error executing operation ${op.name}: $e');
      }
    }

    // Single directory scan after batch execution
    await scanDirectory();
    return successCount;
  }

  Future<int> moveMultiple(List<String> sourcePaths, String destinationDir) async {
    var moved = 0;
    final dstDir = p.isAbsolute(destinationDir) ? destinationDir : p.join(_authorizedPath ?? '.', destinationDir);
    final targetDir = Directory(dstDir);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    for (final srcPath in sourcePaths) {
      final src = p.isAbsolute(srcPath) ? srcPath : p.join(_authorizedPath ?? '.', srcPath);
      final dst = p.join(dstDir, p.basename(src));
      try {
        final f = File(src);
        if (await f.exists()) {
          await f.rename(dst);
          moved++;
        } else {
          final d = Directory(src);
          if (await d.exists()) {
            await d.rename(dst);
            moved++;
          }
        }
      } catch (_) {}
    }
    if (moved > 0) {
      await scanDirectory();
    }
    return moved;
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

  Future<int> deleteMultiple(List<String> paths) async {
    var deleted = 0;
    for (final path in paths) {
      final target = p.isAbsolute(path) ? path : p.join(_authorizedPath ?? '.', path);
      try {
        if (await File(target).exists()) {
          await File(target).delete();
          deleted++;
        } else if (await Directory(target).exists()) {
          await Directory(target).delete(recursive: true);
          deleted++;
        }
      } catch (_) {}
    }
    if (deleted > 0) {
      await scanDirectory();
    }
    return deleted;
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
    if (_useShowcase) return 'Media';
    if (_authorizedPath == null) return 'No folder';
    final name = p.basename(_authorizedPath!);
    if (name == '0' || name.isEmpty || _authorizedPath == '/storage/emulated/0' || _authorizedPath == '/storage/emulated/0/') {
      return 'Internal Storage';
    }
    return name;
  }

  List<Map<String, String>> getAvailableDeviceFolders() {
    final list = <Map<String, String>>[];
    final addedPaths = <String>{};

    void addIfExisting(String name, String rawPath) {
      final norm = normalizePath(rawPath).replaceAll(r'\', '/');
      if (addedPaths.contains(norm.toLowerCase())) return;
      if (Directory(norm).existsSync()) {
        addedPaths.add(norm.toLowerCase());
        list.add({'name': name, 'path': norm});
      }
    }

    if (!kIsWeb && Platform.isAndroid) {
      final presets = [
        {'name': 'Internal Storage (All Phone Files)', 'path': '/storage/emulated/0'},
        {'name': 'Downloads', 'path': '/storage/emulated/0/Download'},
        {'name': 'Camera / DCIM', 'path': '/storage/emulated/0/DCIM'},
        {'name': 'Pictures', 'path': '/storage/emulated/0/Pictures'},
        {'name': 'Documents', 'path': '/storage/emulated/0/Documents'},
        {'name': 'Movies', 'path': '/storage/emulated/0/Movies'},
        {'name': 'Music', 'path': '/storage/emulated/0/Music'},
        {'name': 'WhatsApp Media', 'path': '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media'},
        {'name': 'VidMate Downloads', 'path': '/storage/emulated/0/VidMate/download'},
      ];
      for (final pItem in presets) {
        addIfExisting(pItem['name']!, pItem['path']!);
      }

      // Also include any other top-level folders on the phone's internal storage
      try {
        final rootDir = Directory('/storage/emulated/0');
        if (rootDir.existsSync()) {
          for (final entity in rootDir.listSync(followLinks: false)) {
            if (entity is Directory) {
              final folderName = p.basename(entity.path);
              if (folderName.startsWith('.') || folderName.toLowerCase() == 'android') {
                continue;
              }
              addIfExisting(folderName, entity.path);
            }
          }
        }
      } catch (_) {}
    }

    list.add({
      'name': 'Showcase Demo (1.8 GB)',
      'path': 'showcase',
    });
    return list;
  }

  // --- Showcase Datasets (Matching Home & Browse Screen Exactly) ---

  static List<FileEntry> get _showcaseRecentFiles {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 17, 4);
    return [
      FileEntry(
        path:
            '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/IMG-20260926-WA0131.jpg',
        name: 'IMG-20260926-WA0131.jpg',
        kind: FileEntryKind.file,
        modified: today,
        sizeBytes: 72000,
        folderName: 'WhatsApp Images',
      ),
      FileEntry(
        path:
            '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/IMG-20260926-WA0130.jpg',
        name: 'IMG-20260926-WA0130.jpg',
        kind: FileEntryKind.file,
        modified: today,
        sizeBytes: 109700,
        folderName: 'WhatsApp Images',
      ),
      FileEntry(
        path:
            '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/IMG-20260926-WA0129.jpg',
        name: 'IMG-20260926-WA0129.jpg',
        kind: FileEntryKind.file,
        modified: DateTime(now.year, now.month, now.day, 17, 3),
        sizeBytes: 87450,
        folderName: 'WhatsApp Images',
      ),
      FileEntry(
        path:
            '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/IMG-20260926-WA0128.jpg',
        name: 'IMG-20260926-WA0128.jpg',
        kind: FileEntryKind.file,
        modified: DateTime(now.year, now.month, now.day, 17, 2),
        sizeBytes: 127600,
        folderName: 'WhatsApp Images',
      ),
    ];
  }

  static List<SubfolderInfo> get _showcaseSubdirectories => [
        SubfolderInfo(
          name: 'WhatsApp Images',
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images',
          fileCount: 5120,
          totalBytes: 935759872,
        ),
        SubfolderInfo(
          name: 'WhatsApp Video',
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
          fileCount: 94,
          totalBytes: 542113792,
        ),
        SubfolderInfo(
          name: 'WhatsApp Documents',
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
          fileCount: 50,
          totalBytes: 41104179,
        ),
        SubfolderInfo(
          name: 'WhatsApp Audio',
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio',
          fileCount: 0,
          totalBytes: 0,
        ),
        SubfolderInfo(
          name: 'WhatsApp Animated Gifs',
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Animated Gifs',
          fileCount: 182,
          totalBytes: 47290777,
        ),
        SubfolderInfo(
          name: 'WhatsApp Voice Notes',
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Voice Notes',
          fileCount: 1420,
          totalBytes: 92799385,
        ),
        SubfolderInfo(
          name: 'WhatsApp Profile Photos',
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Profile Photos',
          fileCount: 12,
          totalBytes: 2202009,
        ),
        SubfolderInfo(
          name: 'WhatsApp Stickers',
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Stickers',
          fileCount: 2150,
          totalBytes: 98774220,
        ),
        SubfolderInfo(
          name: 'WhatsApp Wallpaper',
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Wallpaper',
          fileCount: 8,
          totalBytes: 5033164,
        ),
        SubfolderInfo(
          name: 'Sent',
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Sent',
          fileCount: 280,
          totalBytes: 38168166,
        ),
        SubfolderInfo(
          name: 'Private',
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Private',
          fileCount: 45,
          totalBytes: 13421772,
        ),
        SubfolderInfo(
          name: 'Backups',
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/Backups',
          fileCount: 2,
          totalBytes: 44145049,
        ),
        SubfolderInfo(
          name: '.Statuses',
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
          fileCount: 4,
          totalBytes: 1887436,
        ),
        SubfolderInfo(
          name: 'Media Items',
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/Media Items',
          fileCount: 1,
          totalBytes: 15360,
        ),
      ];

  static List<DuplicateFilePair> get _showcaseDuplicates {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 17, 4);
    return [
      DuplicateFilePair(
        original: FileEntry(
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/IMG-20260926-WA0131.jpg',
          name: 'IMG-20260926-WA0131.jpg',
          kind: FileEntryKind.file,
          modified: today,
          sizeBytes: 72000,
          folderName: 'WhatsApp Images',
        ),
        duplicate: FileEntry(
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Sent/IMG-20260926-WA0131.jpg',
          name: 'IMG-20260926-WA0131.jpg',
          kind: FileEntryKind.file,
          modified: today,
          sizeBytes: 72000,
          folderName: 'Sent',
        ),
      ),
      DuplicateFilePair(
        original: FileEntry(
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/IMG-20260926-WA0130.jpg',
          name: 'IMG-20260926-WA0130.jpg',
          kind: FileEntryKind.file,
          modified: today,
          sizeBytes: 109700,
          folderName: 'WhatsApp Images',
        ),
        duplicate: FileEntry(
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Sent/IMG-20260926-WA0130.jpg',
          name: 'IMG-20260926-WA0130.jpg',
          kind: FileEntryKind.file,
          modified: today,
          sizeBytes: 109700,
          folderName: 'Sent',
        ),
      ),
      DuplicateFilePair(
        original: FileEntry(
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents/Project_Brief.pdf',
          name: 'Project_Brief.pdf',
          kind: FileEntryKind.file,
          modified: today.subtract(const Duration(days: 1)),
          sizeBytes: 1250000,
          folderName: 'WhatsApp Documents',
        ),
        duplicate: FileEntry(
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents/Sent/Project_Brief.pdf',
          name: 'Project_Brief.pdf',
          kind: FileEntryKind.file,
          modified: today.subtract(const Duration(days: 1)),
          sizeBytes: 1250000,
          folderName: 'Sent',
        ),
      ),
      DuplicateFilePair(
        original: FileEntry(
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/VID-20260925-WA0002.mp4',
          name: 'VID-20260925-WA0002.mp4',
          kind: FileEntryKind.file,
          modified: today.subtract(const Duration(days: 1)),
          sizeBytes: 8400000,
          folderName: 'WhatsApp Video',
        ),
        duplicate: FileEntry(
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/Sent/VID-20260925-WA0002.mp4',
          name: 'VID-20260925-WA0002.mp4',
          kind: FileEntryKind.file,
          modified: today.subtract(const Duration(days: 1)),
          sizeBytes: 8400000,
          folderName: 'Sent',
        ),
      ),
      DuplicateFilePair(
        original: FileEntry(
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/IMG-20260924-WA0009.jpg',
          name: 'IMG-20260924-WA0009.jpg',
          kind: FileEntryKind.file,
          modified: today.subtract(const Duration(days: 2)),
          sizeBytes: 310000,
          folderName: 'WhatsApp Images',
        ),
        duplicate: FileEntry(
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Private/IMG-20260924-WA0009.jpg',
          name: 'IMG-20260924-WA0009.jpg',
          kind: FileEntryKind.file,
          modified: today.subtract(const Duration(days: 2)),
          sizeBytes: 310000,
          folderName: 'Private',
        ),
      ),
      DuplicateFilePair(
        original: FileEntry(
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents/Invoice_Sep.pdf',
          name: 'Invoice_Sep.pdf',
          kind: FileEntryKind.file,
          modified: today.subtract(const Duration(days: 3)),
          sizeBytes: 450000,
          folderName: 'WhatsApp Documents',
        ),
        duplicate: FileEntry(
          path:
              '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents/Sent/Invoice_Sep.pdf',
          name: 'Invoice_Sep.pdf',
          kind: FileEntryKind.file,
          modified: today.subtract(const Duration(days: 3)),
          sizeBytes: 450000,
          folderName: 'Sent',
        ),
      ),
    ];
  }

  static List<FileEntry> get _showcaseEntries {
    final list = <FileEntry>[..._showcaseRecentFiles];
    for (final pair in _showcaseDuplicates) {
      if (!list.any((f) => f.path == pair.original.path)) {
        list.add(pair.original);
      }
      if (!list.any((f) => f.path == pair.duplicate.path)) {
        list.add(pair.duplicate);
      }
    }
    list.addAll([
      FileEntry(
        path:
            '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents/Report_2026.docx',
        name: 'Report_2026.docx',
        kind: FileEntryKind.file,
        modified: DateTime.now().subtract(const Duration(days: 2)),
        sizeBytes: 1540000,
        folderName: 'WhatsApp Documents',
      ),
      FileEntry(
        path:
            '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents/Budget_Q4.xlsx',
        name: 'Budget_Q4.xlsx',
        kind: FileEntryKind.file,
        modified: DateTime.now().subtract(const Duration(days: 3)),
        sizeBytes: 620000,
        folderName: 'WhatsApp Documents',
      ),
      FileEntry(
        path:
            '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/VID-20260926-WA0004.mp4',
        name: 'VID-20260926-WA0004.mp4',
        kind: FileEntryKind.file,
        modified: DateTime.now().subtract(const Duration(hours: 4)),
        sizeBytes: 14889779,
        folderName: 'WhatsApp Video',
      ),
      FileEntry(
        path:
            '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/VID-20260925-WA0001.mp4',
        name: 'VID-20260925-WA0001.mp4',
        kind: FileEntryKind.file,
        modified: DateTime.now().subtract(const Duration(days: 1)),
        sizeBytes: 29988776,
        folderName: 'WhatsApp Video',
      ),
      FileEntry(
        path:
            '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/.nomedia',
        name: '.nomedia',
        kind: FileEntryKind.file,
        modified: DateTime.now().subtract(const Duration(days: 30)),
        sizeBytes: 0,
        folderName: 'WhatsApp Images',
      ),
      FileEntry(
        path:
            '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/Backups/chat_backup.crypt14',
        name: 'chat_backup.crypt14',
        kind: FileEntryKind.file,
        modified: DateTime.now().subtract(const Duration(days: 5)),
        sizeBytes: 44145049,
        folderName: 'Backups',
      ),
    ]);
    return list;
  }
}
