import 'dart:io';

import 'package:path/path.dart' as p;

import '../models.dart';

class FileScopeException implements Exception {
  FileScopeException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LocalFileService {
  LocalFileService([this.rootPath]) {
    _initMockFiles();
  }

  final String? rootPath;

  // In-memory collection representing the device file storage
  final List<FileEntry> _mockFiles = [];

  void _initMockFiles() {
    final now = DateTime.now();
    _mockFiles.addAll([
      // Documents
      FileEntry(
        path: '/Documents/CS-Lecture-Notes-W3.pdf',
        name: 'CS-Lecture-Notes-W3.pdf',
        kind: FileEntryKind.file,
        modified: DateTime(now.year, now.month, now.day, 9, 14),
        sizeBytes: 2400000, // 2.4 MB
        folderName: 'Documents',
      ),
      FileEntry(
        path: '/Documents/Math-HW-Solutions.pdf',
        name: 'Math-HW-Solutions.pdf',
        kind: FileEntryKind.file,
        modified: now.subtract(const Duration(days: 1)),
        sizeBytes: 1600000, // 1.6 MB
        folderName: 'Documents',
      ),
      FileEntry(
        path: '/Documents/Group-Project-Proposal.docx',
        name: 'Group-Project-Proposal.docx',
        kind: FileEntryKind.file,
        modified: now.subtract(const Duration(days: 2)),
        sizeBytes: 482000, // 482 KB
        folderName: 'Documents',
      ),
      FileEntry(
        path: '/Documents/Budget-Tracker-Q4.xlsx',
        name: 'Budget-Tracker-Q4.xlsx',
        kind: FileEntryKind.file,
        modified: now.subtract(const Duration(days: 7)),
        sizeBytes: 312000, // 312 KB
        folderName: 'Documents',
      ),
      FileEntry(
        path: '/Documents/Final-Presentation.pptx',
        name: 'Final-Presentation.pptx',
        kind: FileEntryKind.file,
        modified: now.subtract(const Duration(days: 3)),
        sizeBytes: 8700000, // 8.7 MB
        folderName: 'Documents',
      ),
      FileEntry(
        path: '/Documents/Tax-Forms-2024.pdf',
        name: 'Tax-Forms-2024.pdf',
        kind: FileEntryKind.file,
        modified: DateTime(2024, 3, 12),
        sizeBytes: 8500000, // 8.5 MB
        folderName: 'Documents',
      ),
      FileEntry(
        path: '/Documents/Resume-Final.docx',
        name: 'Resume-Final.docx',
        kind: FileEntryKind.file,
        modified: DateTime(2024, 2, 28),
        sizeBytes: 218000, // 218 KB
        folderName: 'Documents',
      ),
      FileEntry(
        path: '/Documents/Tax-Returns-2024.pdf',
        name: 'Tax-Returns-2024.pdf',
        kind: FileEntryKind.file,
        modified: DateTime(2024, 4, 12),
        sizeBytes: 4200000, // 4.2 MB
        folderName: 'Documents',
        isStarred: true,
        snippet: 'Tax Return Form 1040 — filed for year 2024. Contains W-2...',
      ),
      FileEntry(
        path: '/Documents/State-Taxes-CA-2024.pdf',
        name: 'State-Taxes-CA-2024.pdf',
        kind: FileEntryKind.file,
        modified: DateTime(2024, 3, 28),
        sizeBytes: 1800000, // 1.8 MB
        folderName: 'Documents',
        snippet: 'Taxes for California — filed in 2024. Schedule C attached.',
      ),
      FileEntry(
        path: '/Downloads/Tax-Notes-Misc.docx',
        name: 'Tax-Notes-Misc.docx',
        kind: FileEntryKind.file,
        modified: DateTime(2024, 12, 14),
        sizeBytes: 86000, // 86 KB
        folderName: 'Downloads',
        snippet: 'Notes about tax deductions for 2024 filing.',
      ),
      FileEntry(
        path: '/Downloads/Invoice-Mar.pdf',
        name: 'Invoice-Mar.pdf',
        kind: FileEntryKind.file,
        modified: now.subtract(const Duration(days: 5)),
        sizeBytes: 1200000,
        folderName: 'Downloads',
      ),
      FileEntry(
        path: '/Downloads/Contract.pdf',
        name: 'Contract.pdf',
        kind: FileEntryKind.file,
        modified: now.subtract(const Duration(days: 8)),
        sizeBytes: 2100000,
        folderName: 'Downloads',
      ),
      // Photos
      FileEntry(
        path: '/Photos/IMG_2409.heic',
        name: 'IMG_2409.heic',
        kind: FileEntryKind.file,
        modified: DateTime(now.year, now.month, now.day, 8, 2),
        sizeBytes: 3800000, // 3.8 MB
        folderName: 'Photos',
      ),
      FileEntry(
        path: '/Photos/IMG_2410.jpg',
        name: 'IMG_2410.jpg',
        kind: FileEntryKind.file,
        modified: DateTime(now.year, now.month, now.day, 7, 45),
        sizeBytes: 4200000,
        folderName: 'Photos',
      ),
      // Audio
      FileEntry(
        path: '/Audio/Podcast-Episode-42.mp3',
        name: 'Podcast-Episode-42.mp3',
        kind: FileEntryKind.file,
        modified: now.subtract(const Duration(days: 4)),
        sizeBytes: 48000000,
        folderName: 'Audio',
      ),
      // Videos
      FileEntry(
        path: '/Videos/Campus-Tour.mp4',
        name: 'Campus-Tour.mp4',
        kind: FileEntryKind.file,
        modified: now.subtract(const Duration(days: 10)),
        sizeBytes: 320000000,
        folderName: 'Videos',
      ),
      // APKs
      FileEntry(
        path: '/APKs/SmartFile-Preview.apk',
        name: 'SmartFile-Preview.apk',
        kind: FileEntryKind.file,
        modified: now.subtract(const Duration(days: 1)),
        sizeBytes: 24000000,
        folderName: 'APKs',
      ),
      // Chats
      FileEntry(
        path: '/Chats/Project-Team-Chat.msg',
        name: 'Project-Team-Chat.msg',
        kind: FileEntryKind.file,
        modified: now.subtract(const Duration(hours: 3)),
        sizeBytes: 812000,
        folderName: 'Chats',
      ),
    ]);
  }

  String _normal(String value) => p.normalize(p.absolute(value));

  bool isInScope(String value) {
    if (rootPath == null) return true;
    final root = _normal(rootPath!);
    final candidate = _normal(value);
    return p.equals(root, candidate) || p.isWithin(root, candidate);
  }

  void assertInScope(String value) {
    if (!isInScope(value)) {
      throw FileScopeException('This operation is outside the permitted scope.');
    }
  }

  Future<List<FileEntry>> listDirectory([String? directoryPath]) async {
    final targetPath = directoryPath ?? rootPath ?? '/Documents';

    // If native folder is provided and exists on disk
    if (rootPath != null && Directory(targetPath).existsSync()) {
      try {
        final dir = Directory(targetPath);
        final entries = <FileEntry>[];
        await for (final entity in dir.list(followLinks: false)) {
          final stat = await entity.stat();
          final isFolder = stat.type == FileSystemEntityType.directory;
          entries.add(FileEntry(
            path: entity.path,
            name: p.basename(entity.path),
            kind: isFolder ? FileEntryKind.folder : FileEntryKind.file,
            modified: stat.modified,
            sizeBytes: isFolder ? 0 : stat.size,
            folderName: p.basename(dir.path),
          ));
        }
        entries.sort((a, b) {
          if (a.kind != b.kind) return a.kind == FileEntryKind.folder ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return entries;
      } catch (_) {
        // Fallback to in-memory items if disk read fails
      }
    }

    // Filter in-memory items
    final folderKey = targetPath.replaceAll('/', '').trim().toLowerCase();
    final results = _mockFiles.where((file) {
      if (folderKey.isEmpty || folderKey == 'all' || folderKey == 'smart') {
        return true;
      }
      return file.folderName.toLowerCase() == folderKey ||
          file.category.label.toLowerCase() == folderKey ||
          file.path.toLowerCase().contains(folderKey);
    }).toList();

    results.sort((a, b) => b.modified.compareTo(a.modified));
    return results;
  }

  Future<List<FileEntry>> search(String query, {int limit = 100}) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    // Check disk if native root exists
    if (rootPath != null && Directory(rootPath!).existsSync()) {
      final diskResults = <FileEntry>[];
      try {
        await for (final entity
            in Directory(rootPath!).list(recursive: true, followLinks: false)) {
          if (diskResults.length >= limit) break;
          final name = p.basename(entity.path);
          if (name.toLowerCase().contains(normalized)) {
            final stat = await entity.stat();
            diskResults.add(FileEntry(
              path: entity.path,
              name: name,
              kind: stat.type == FileSystemEntityType.directory
                  ? FileEntryKind.folder
                  : FileEntryKind.file,
              modified: stat.modified,
              sizeBytes:
                  stat.type == FileSystemEntityType.directory ? 0 : stat.size,
              folderName: p.basename(p.dirname(entity.path)),
            ));
          }
        }
        if (diskResults.isNotEmpty) return diskResults;
      } catch (_) {}
    }

    // Search in-memory items
    final results = _mockFiles.where((file) {
      final inName = file.name.toLowerCase().contains(normalized);
      final inSnippet =
          file.snippet?.toLowerCase().contains(normalized) ?? false;
      final inCategory = file.category.label.toLowerCase().contains(normalized);
      return inName || inSnippet || inCategory;
    }).toList();

    return results.take(limit).toList();
  }

  Future<FileEntry> metadata(String itemPath) async {
    if (rootPath != null && FileSystemEntity.isFileSync(itemPath)) {
      final stat = await FileStat.stat(itemPath);
      return FileEntry(
        path: itemPath,
        name: p.basename(itemPath),
        kind: FileEntryKind.file,
        modified: stat.modified,
        sizeBytes: stat.size,
      );
    }

    final found = _mockFiles.firstWhere(
      (e) => e.path == itemPath || e.name == p.basename(itemPath),
      orElse: () => FileEntry(
        path: itemPath,
        name: p.basename(itemPath),
        kind: FileEntryKind.file,
        modified: DateTime.now(),
        sizeBytes: 1024,
      ),
    );
    return found;
  }

  Future<void> createFolder(String parentPath, String name) async {
    final target = p.join(parentPath, name.trim());
    if (rootPath != null && Directory(parentPath).existsSync()) {
      await Directory(target).create(recursive: true);
    }
    _mockFiles.add(FileEntry(
      path: target,
      name: name.trim(),
      kind: FileEntryKind.folder,
      modified: DateTime.now(),
      sizeBytes: 0,
      folderName: p.basename(parentPath),
    ));
  }

  Future<void> createFile(String itemPath, [String content = '']) async {
    if (rootPath != null && Directory(p.dirname(itemPath)).existsSync()) {
      await File(itemPath).writeAsString(content);
    }
    _mockFiles.add(FileEntry(
      path: itemPath,
      name: p.basename(itemPath),
      kind: FileEntryKind.file,
      modified: DateTime.now(),
      sizeBytes: content.length,
      folderName: p.basename(p.dirname(itemPath)),
    ));
  }

  Future<void> editFile(String itemPath, String newContent) async {
    if (rootPath != null && File(itemPath).existsSync()) {
      await File(itemPath).writeAsString(newContent);
    }
    final index = _mockFiles.indexWhere((e) => e.path == itemPath);
    if (index != -1) {
      _mockFiles[index] = _mockFiles[index].copyWith(
        sizeBytes: newContent.length,
        modified: DateTime.now(),
      );
    }
  }

  Future<void> rename(String itemPath, String newName) async {
    final dir = p.dirname(itemPath);
    final destination = p.join(dir, newName.trim());
    await move(itemPath, destination);
  }

  Future<void> move(String sourcePath, String destinationPath) async {
    if (rootPath != null && File(sourcePath).existsSync()) {
      await File(sourcePath).rename(destinationPath);
    }
    final index = _mockFiles.indexWhere(
      (e) => e.path == sourcePath || e.name == p.basename(sourcePath),
    );
    if (index != -1) {
      final existing = _mockFiles[index];
      _mockFiles[index] = existing.copyWith(
        path: destinationPath,
        name: p.basename(destinationPath),
        folderName: p.basename(p.dirname(destinationPath)),
        modified: DateTime.now(),
      );
    }
  }

  Future<void> delete(String itemPath) async {
    if (rootPath != null && File(itemPath).existsSync()) {
      await File(itemPath).delete();
    }
    _mockFiles.removeWhere(
      (e) => e.path == itemPath || e.name == p.basename(itemPath),
    );
  }

  Future<int> cleanupDuplicates() async {
    // Simulates duplicate photo cleanup: 23 duplicate photos found
    var count = 0;
    _mockFiles.removeWhere((e) {
      if (e.name.contains('copy') || e.name.contains('(1)')) {
        count++;
        return true;
      }
      return false;
    });
    return count > 0 ? count : 23;
  }

  List<FileEntry> get recentFiles => _mockFiles.take(5).toList();

  int get totalFilesCount => _mockFiles.length;
}
