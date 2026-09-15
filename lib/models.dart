enum FileEntryKind { file, folder }

class FileEntry {
  const FileEntry({
    required this.path,
    required this.name,
    required this.kind,
    required this.modified,
    this.sizeBytes = 0,
  });

  final String path;
  final String name;
  final FileEntryKind kind;
  final DateTime modified;
  final int sizeBytes;
}

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });

  final String text;
  final bool isUser;
  final DateTime time;
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
        return 'Move ${input['sourcePath'] ?? 'file'} to ${input['destinationPath'] ?? 'destination'}';
      case 'list_directory':
        return 'List ${input['path'] ?? 'folder'}';
      case 'search_files':
        return 'Search for “${input['query'] ?? ''}”';
      case 'get_file_metadata':
        return 'Inspect ${input['path'] ?? 'item'}';
      default:
        return name;
    }
  }
}

class AiPlan {
  const AiPlan({required this.reply, required this.operations});

  final String? reply;
  final List<PlannedOperation> operations;
}

class LocalActivity {
  const LocalActivity({required this.text, required this.time});

  final String text;
  final DateTime time;
}
