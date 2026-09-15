import 'dart:io';

import 'package:path/path.dart' as p;

import '../models.dart';

class FileScopeException implements Exception {
  FileScopeException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Local-only filesystem operations. Every path is checked against the folder
/// the user chose in the native picker before it is read or changed.
class LocalFileService {
  LocalFileService(this.rootPath);

  final String rootPath;

  String _normal(String value) => p.normalize(p.absolute(value));

  bool isInScope(String value) {
    final root = _normal(rootPath);
    final candidate = _normal(value);
    return p.equals(root, candidate) || p.isWithin(root, candidate);
  }

  void assertInScope(String value) {
    if (!isInScope(value)) {
      throw FileScopeException('This operation is outside the folder you allowed.');
    }
  }

  Future<List<FileEntry>> listDirectory(String directoryPath) async {
    assertInScope(directoryPath);
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw const FileSystemException('Folder no longer exists.');
    }

    final entries = <FileEntry>[];
    await for (final entity in directory.list(followLinks: false)) {
      final stat = await entity.stat();
      final isFolder = stat.type == FileSystemEntityType.directory;
      entries.add(FileEntry(
        path: entity.path,
        name: p.basename(entity.path),
        kind: isFolder ? FileEntryKind.folder : FileEntryKind.file,
        modified: stat.modified,
        sizeBytes: isFolder ? 0 : stat.size,
      ));
    }
    entries.sort((a, b) {
      if (a.kind != b.kind) return a.kind == FileEntryKind.folder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  Future<List<FileEntry>> search(String query, {int limit = 100}) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return [];
    final results = <FileEntry>[];
    await for (final entity in Directory(rootPath).list(recursive: true, followLinks: false)) {
      if (results.length >= limit) break;
      final name = p.basename(entity.path);
      if (!name.toLowerCase().contains(normalizedQuery)) continue;
      final stat = await entity.stat();
      results.add(FileEntry(
        path: entity.path,
        name: name,
        kind: stat.type == FileSystemEntityType.directory ? FileEntryKind.folder : FileEntryKind.file,
        modified: stat.modified,
        sizeBytes: stat.type == FileSystemEntityType.directory ? 0 : stat.size,
      ));
    }
    return results;
  }

  Future<FileEntry> metadata(String itemPath) async {
    assertInScope(itemPath);
    final entity = FileSystemEntity.typeSync(itemPath, followLinks: false);
    if (entity == FileSystemEntityType.notFound) {
      throw const FileSystemException('Item no longer exists.');
    }
    final stat = await FileStat.stat(itemPath);
    return FileEntry(
      path: itemPath,
      name: p.basename(itemPath),
      kind: entity == FileSystemEntityType.directory ? FileEntryKind.folder : FileEntryKind.file,
      modified: stat.modified,
      sizeBytes: entity == FileSystemEntityType.directory ? 0 : stat.size,
    );
  }

  Future<void> createFolder(String parentPath, String name) async {
    assertInScope(parentPath);
    _validateName(name);
    final target = p.join(parentPath, name.trim());
    assertInScope(target);
    if (await Directory(target).exists() || await File(target).exists()) {
      throw const FileSystemException('An item with that name already exists.');
    }
    await Directory(target).create();
  }

  Future<void> rename(String itemPath, String newName) async {
    assertInScope(itemPath);
    _validateName(newName);
    final destination = p.join(p.dirname(itemPath), newName.trim());
    await move(itemPath, destination);
  }

  Future<void> move(String sourcePath, String destinationPath) async {
    assertInScope(sourcePath);
    assertInScope(destinationPath);
    if (!await Directory(p.dirname(destinationPath)).exists()) {
      throw const FileSystemException('The destination folder does not exist.');
    }
    if (await File(destinationPath).exists() || await Directory(destinationPath).exists()) {
      throw const FileSystemException('The destination already exists.');
    }
    final type = FileSystemEntity.typeSync(sourcePath, followLinks: false);
    if (type == FileSystemEntityType.file) {
      await File(sourcePath).rename(destinationPath);
    } else if (type == FileSystemEntityType.directory) {
      await Directory(sourcePath).rename(destinationPath);
    } else {
      throw const FileSystemException('The source item no longer exists.');
    }
  }

  Future<void> delete(String itemPath) async {
    assertInScope(itemPath);
    if (p.equals(_normal(itemPath), _normal(rootPath))) {
      throw FileScopeException('The allowed root folder cannot be deleted.');
    }
    final type = FileSystemEntity.typeSync(itemPath, followLinks: false);
    if (type == FileSystemEntityType.file) {
      await File(itemPath).delete();
    } else if (type == FileSystemEntityType.directory) {
      await Directory(itemPath).delete(recursive: true);
    } else {
      throw const FileSystemException('The item no longer exists.');
    }
  }

  void _validateName(String name) {
    final value = name.trim();
    if (value.isEmpty || value == '.' || value == '..' || p.basename(value) != value) {
      throw const FileSystemException('Enter a valid item name.');
    }
  }
}
