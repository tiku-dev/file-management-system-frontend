import 'package:flutter/material.dart';

enum FileEntryKind { file, folder }

enum FileCategory {
  documents,
  photos,
  videos,
  audio,
  apks,
  chats,
  other;

  String get label {
    switch (this) {
      case FileCategory.documents:
        return 'Documents';
      case FileCategory.photos:
        return 'Photos';
      case FileCategory.videos:
        return 'Videos';
      case FileCategory.audio:
        return 'Audio';
      case FileCategory.apks:
        return 'APKs';
      case FileCategory.chats:
        return 'Chats';
      case FileCategory.other:
        return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case FileCategory.documents:
        return const Color(0xFFEF4444);
      case FileCategory.photos:
        return const Color(0xFF3B82F6);
      case FileCategory.videos:
        return const Color(0xFFF97316);
      case FileCategory.audio:
        return const Color(0xFFA855F7);
      case FileCategory.apks:
        return const Color(0xFF10B981);
      case FileCategory.chats:
        return const Color(0xFF06B6D4);
      case FileCategory.other:
        return const Color(0xFF6B7280);
    }
  }

  IconData get icon {
    switch (this) {
      case FileCategory.documents:
        return Icons.description_outlined;
      case FileCategory.photos:
        return Icons.image_outlined;
      case FileCategory.videos:
        return Icons.play_arrow_outlined;
      case FileCategory.audio:
        return Icons.music_note_outlined;
      case FileCategory.apks:
        return Icons.android_outlined;
      case FileCategory.chats:
        return Icons.chat_bubble_outline;
      case FileCategory.other:
        return Icons.insert_drive_file_outlined;
    }
  }
}

class FileEntry {
  const FileEntry({
    required this.path,
    required this.name,
    required this.kind,
    required this.modified,
    this.sizeBytes = 0,
    this.folderName = 'Documents',
    this.isStarred = false,
    this.snippet,
  });

  final String path;
  final String name;
  final FileEntryKind kind;
  final DateTime modified;
  final int sizeBytes;
  final String folderName;
  final bool isStarred;
  final String? snippet;

  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  String get badgeText {
    final ext = extension.toUpperCase();
    if (ext.isNotEmpty && ext.length <= 4) {
      if (ext == 'HEIC' || ext == 'JPG' || ext == 'PNG') return 'IMG';
      return ext;
    }
    return kind == FileEntryKind.folder ? 'DIR' : 'FILE';
  }

  Color get badgeColor {
    switch (extension) {
      case 'pdf':
        return const Color(0xFFEF4444);
      case 'doc':
      case 'docx':
        return const Color(0xFF2563EB);
      case 'xls':
      case 'xlsx':
      case 'csv':
        return const Color(0xFF10B981);
      case 'ppt':
      case 'pptx':
        return const Color(0xFF8B5CF6);
      case 'heic':
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
        return const Color(0xFF10B981);
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
      case 'flac':
        return const Color(0xFFA855F7);
      case 'mp4':
      case 'mov':
      case 'mkv':
      case 'avi':
        return const Color(0xFFF97316);
      case 'apk':
        return const Color(0xFF059669);
      case 'txt':
      case 'md':
      case 'log':
      case 'json':
        return const Color(0xFF06B6D4);
      default:
        return const Color(0xFF6B7280);
    }
  }

  bool get isDocument => const ['pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'log', 'md'].contains(extension);
  bool get isPdf => extension == 'pdf';
  bool get isExcel => const ['xls', 'xlsx', 'csv'].contains(extension);
  bool get isPpt => const ['ppt', 'pptx'].contains(extension);
  bool get isApk => extension == 'apk';
  bool get isImage => const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'].contains(extension);
  bool get isVideo => const ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(extension);
  bool get isAudio => const ['mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg'].contains(extension);
  bool get isTextReadable => const [
        'txt',
        'json',
        'csv',
        'xml',
        'log',
        'md',
        'yaml',
        'yml',
        'dart',
        'py',
        'js',
        'ts',
        'html',
        'css',
        'ini',
        'conf',
        'sh',
        'bat',
        'sql',
      ].contains(extension);

  FileCategory get category {
    switch (extension) {
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
      case 'ppt':
      case 'pptx':
      case 'xls':
      case 'xlsx':
      case 'csv':
      case 'md':
        return FileCategory.documents;
      case 'heic':
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return FileCategory.photos;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return FileCategory.videos;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'm4a':
      case 'aac':
        return FileCategory.audio;
      case 'apk':
        return FileCategory.apks;
      case 'chat':
      case 'msg':
      case 'log':
        return FileCategory.chats;
      default:
        return FileCategory.other;
    }
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedDate {
    final now = DateTime.now();
    if (modified.year == now.year && modified.month == now.month && modified.day == now.day) {
      final hour = modified.hour.toString().padLeft(2, '0');
      final min = modified.minute.toString().padLeft(2, '0');
      return 'Today · $hour:$min';
    }
    final diff = now.difference(modified);
    if (diff.inDays <= 1) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    }
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[modified.month - 1]} ${modified.day}';
  }

  FileEntry copyWith({
    String? path,
    String? name,
    FileEntryKind? kind,
    DateTime? modified,
    int? sizeBytes,
    String? folderName,
    bool? isStarred,
    String? snippet,
  }) {
    return FileEntry(
      path: path ?? this.path,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      modified: modified ?? this.modified,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      folderName: folderName ?? this.folderName,
      isStarred: isStarred ?? this.isStarred,
      snippet: snippet ?? this.snippet,
    );
  }
}

class PlannedOperation {
  const PlannedOperation({
    required this.id,
    required this.name,
    required this.input,
    required this.requiresApproval,
  });

  final String id;
  final String name;
  final Map<String, dynamic> input;
  final bool requiresApproval;

  String get summary {
    switch (name) {
      case 'move_file':
        final src = input['sourcePath']?.toString().split('/').last ?? 'file';
        final dst =
            input['destinationPath']?.toString().split('/').last ??
            'destination';
        return 'Move $src to $dst';
      case 'create_file':
        final path = input['path']?.toString().split('/').last ?? 'new file';
        return 'Create file "$path"';
      case 'create_folder':
        final path = input['path']?.toString().split('/').last ?? 'new folder';
        return 'Create folder "$path"';
      case 'rename_file':
        final path = input['path']?.toString().split('/').last ?? 'item';
        final newName = input['newName']?.toString() ?? 'new name';
        return 'Rename $path -> $newName';
      case 'delete_file':
      case 'delete_item':
        final path = input['path']?.toString().split('/').last ?? 'item';
        return 'Delete $path';
      case 'edit_file':
        final path = input['path']?.toString().split('/').last ?? 'file';
        return 'Edit content of $path';
      case 'organize_files':
        final src = input['sourceDirectory']?.toString() ?? 'folder';
        final strat = input['strategy']?.toString() ?? 'by type';
        return 'Organize $src ($strat)';
      case 'list_directory':
        return 'List ${input['path'] ?? 'folder'}';
      case 'search_files':
        return 'Search for "${input['query'] ?? ''}"';
      case 'get_file_metadata':
        return 'Inspect ${input['path'] ?? 'item'}';
      default:
        return name.replaceAll('_', ' ');
    }
  }
}

class AiPlanStep {
  const AiPlanStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    this.badgeText,
    this.isDestructive = false,
  });

  final int stepNumber;
  final String title;
  final String description;
  final String? badgeText;
  final bool isDestructive;
}

class AiPlan {
  const AiPlan({
    required this.reply,
    required this.operations,
    this.steps = const [],
    this.affectedCount = 0,
    this.sourcePath,
    this.destinationPath,
    this.estimatedSeconds = 6,
    this.previewFiles = const [],
    this.conversationId,
  });

  final String? reply;
  final List<PlannedOperation> operations;
  final List<AiPlanStep> steps;
  final int affectedCount;
  final String? sourcePath;
  final String? destinationPath;
  final int estimatedSeconds;
  final List<String> previewFiles;
  final String? conversationId;
}

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.plan,
  });

  final String text;
  final bool isUser;
  final DateTime time;
  final AiPlan? plan;
}

class ChatConversation {
  ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<ChatMessage> messages;

  String get snippet {
    if (messages.isEmpty) return 'No messages yet';
    final last = messages.last;
    return last.text.replaceAll('\n', ' ').trim();
  }

  String get formattedDate {
    final now = DateTime.now();
    if (updatedAt.year == now.year &&
        updatedAt.month == now.month &&
        updatedAt.day == now.day) {
      final hour = updatedAt.hour.toString().padLeft(2, '0');
      final min = updatedAt.minute.toString().padLeft(2, '0');
      return 'Today · $hour:$min';
    }
    final diff = now.difference(updatedAt);
    if (diff.inDays <= 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${updatedAt.month}/${updatedAt.day}/${updatedAt.year}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages
            .map((m) => {
                  'text': m.text,
                  'isUser': m.isUser,
                  'time': m.time.toIso8601String(),
                  if (m.plan != null)
                    'plan': {
                      'reply': m.plan!.reply,
                      'affectedCount': m.plan!.affectedCount,
                      'sourcePath': m.plan!.sourcePath,
                      'destinationPath': m.plan!.destinationPath,
                      'estimatedSeconds': m.plan!.estimatedSeconds,
                      'previewFiles': m.plan!.previewFiles,
                      'steps': m.plan!.steps
                          .map((s) => {
                                'stepNumber': s.stepNumber,
                                'title': s.title,
                                'description': s.description,
                                'badgeText': s.badgeText,
                                'isDestructive': s.isDestructive,
                              })
                          .toList(),
                      'operations': m.plan!.operations
                          .map((op) => {
                                'id': op.id,
                                'name': op.name,
                                'input': op.input,
                                'requiresApproval': op.requiresApproval,
                              })
                          .toList(),
                    },
                })
            .toList(),
      };

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final rawMsgs = json['messages'] as List? ?? [];
    final msgs = rawMsgs.whereType<Map>().map((m) {
      AiPlan? plan;
      if (m['plan'] is Map) {
        final p = Map<String, dynamic>.from(m['plan'] as Map);
        final rawOps = p['operations'] as List? ?? [];
        final ops = rawOps.whereType<Map>().map((o) {
          final opMap = Map<String, dynamic>.from(o);
          return PlannedOperation(
            id: opMap['id']?.toString() ?? 'op-1',
            name: opMap['name']?.toString() ?? 'operation',
            input: Map<String, dynamic>.from(opMap['input'] as Map? ?? {}),
            requiresApproval: opMap['requiresApproval'] == true,
          );
        }).toList();

        final rawSteps = p['steps'] as List? ?? [];
        final steps = rawSteps.whereType<Map>().map((s) {
          final sMap = Map<String, dynamic>.from(s);
          return AiPlanStep(
            stepNumber: sMap['stepNumber'] as int? ?? 1,
            title: sMap['title']?.toString() ?? '',
            description: sMap['description']?.toString() ?? '',
            badgeText: sMap['badgeText']?.toString(),
            isDestructive: sMap['isDestructive'] == true,
          );
        }).toList();

        plan = AiPlan(
          reply: p['reply']?.toString(),
          operations: ops,
          steps: steps,
          affectedCount: p['affectedCount'] as int? ?? ops.length,
          sourcePath: p['sourcePath']?.toString(),
          destinationPath: p['destinationPath']?.toString(),
          estimatedSeconds: p['estimatedSeconds'] as int? ?? 6,
          previewFiles: (p['previewFiles'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
        );
      }

      return ChatMessage(
        text: m['text'] as String? ?? '',
        isUser: m['isUser'] == true,
        time: DateTime.tryParse(m['time'] as String? ?? '') ?? DateTime.now(),
        plan: plan,
      );
    }).toList();

    return ChatConversation(
      id: json['id']?.toString() ??
          'conv-${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? 'Conversation',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      messages: msgs,
    );
  }
}

class LocalActivity {
  const LocalActivity({required this.text, required this.time});

  final String text;
  final DateTime time;
}

class UserAccount {
  const UserAccount({
    required this.id,
    required this.email,
    required this.displayName,
  });

  final String id;
  final String email;
  final String displayName;
}
