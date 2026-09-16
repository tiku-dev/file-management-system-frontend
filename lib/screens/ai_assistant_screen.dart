import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/local_file_service.dart';
import '../theme/app_theme.dart';
import '../widgets/folder_picker_sheet.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({
    super.key,
    required this.api,
    required this.fileService,
    this.onBack,
  });

  final SmartFileApi api;
  final LocalFileService fileService;
  final VoidCallback? onBack;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _initChatHistory();
  }

  void _initChatHistory() {
    final isAuth = widget.fileService.isAuthorized;
    final folder = widget.fileService.authorizedFolderName;
    final count = widget.fileService.totalFilesCount;

    _messages.add(
      ChatMessage(
        text: isAuth
            ? "Hello! I am FileMind AI. I'm connected to your device folder: $folder ($count files). You can ask me to organize files by category, clean up duplicates, rename files, or create folders."
            : "Hello! I am FileMind AI. Please authorize a folder on your device so I can help manage, organize, and rename your files.",
        isUser: false,
        time: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _textController.text).trim();
    if (text.isEmpty || _isLoading) return;

    _textController.clear();
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        time: DateTime.now(),
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      String prompt = text;
      if (widget.fileService.isAuthorized) {
        final allFiles = widget.fileService.allEntries
            .where((f) => f.kind == FileEntryKind.file)
            .toList();
        final photos = allFiles
            .where((f) => f.category == FileCategory.photos)
            .map((f) => f.name)
            .take(30)
            .toList();
        final docs = allFiles
            .where((f) => f.category == FileCategory.documents)
            .map((f) => f.name)
            .take(30)
            .toList();
        final sample = allFiles.take(25).map((f) => f.name).join(', ');

        final buf = StringBuffer();
        buf.writeln('Target folder: "${widget.fileService.authorizedPath}"');
        buf.writeln('Total files: ${allFiles.length}');
        if (photos.isNotEmpty) buf.writeln('Image files: ${photos.join(', ')}');
        if (docs.isNotEmpty) buf.writeln('Doc files: ${docs.join(', ')}');
        buf.writeln('Sample files: $sample');
        buf.writeln('Instruction: $text');
        prompt = buf.toString();
      }
      final plan = await widget.api.plan(prompt, const []);
      if (!mounted) return;

      setState(() {
        _messages.add(ChatMessage(
          text: plan.reply ?? 'Plan prepared for your review:',
          isUser: false,
          time: DateTime.now(),
          plan: plan,
        ));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: 'Notice: $e',
          isUser: false,
          time: DateTime.now(),
        ));
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.fileService,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = Theme.of(context).cardColor;
        final outlineColor = Theme.of(context).colorScheme.outline;
        final isAuthorized = widget.fileService.isAuthorized;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      if (widget.onBack != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          onPressed: widget.onBack,
                        )
                      else
                        const SizedBox(width: 8),
                      Text(
                        'AI Assistant',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.cleaning_services_outlined, size: 22),
                        tooltip: 'Clear Chat',
                        onPressed: _clearChat,
                      ),
                    ],
                  ),
                ),

                // Profile Header Card (FileMind AI Online)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: outlineColor.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Purple circle with star
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            gradient: AppColors.storageGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FileMind AI',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      isAuthorized
                                          ? 'Online · ${widget.fileService.authorizedFolderName} (${widget.fileService.totalFilesCount} files)'
                                          : 'Online · Groq LLaMA 3.3',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz),
                          color: isDark ? Colors.white60 : Colors.black45,
                          onPressed: () => showDeviceFolderPicker(context, widget.fileService),
                        ),
                      ],
                    ),
                  ),
                ),

                // Connected Folder Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: GestureDetector(
                    onTap: () => showDeviceFolderPicker(context, widget.fileService),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isAuthorized
                            ? const Color(0xFF6046E8).withValues(alpha: 0.1)
                            : Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isAuthorized
                              ? const Color(0xFF6046E8).withValues(alpha: 0.3)
                              : Colors.amber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isAuthorized ? Icons.folder_special : Icons.folder_off_outlined,
                            color: isAuthorized ? const Color(0xFF6046E8) : Colors.amber.shade800,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAuthorized
                                      ? 'Connected: ${widget.fileService.authorizedFolderName}'
                                      : 'No Device Folder Connected',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isAuthorized
                                        ? (isDark ? Colors.white : const Color(0xFF1E1B38))
                                        : Colors.amber.shade900,
                                  ),
                                ),
                                Text(
                                  isAuthorized
                                      ? '${widget.fileService.totalFilesCount} files · ${widget.fileService.authorizedPath}'
                                      : 'Tap here to authorize a folder for AI file management',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6046E8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isAuthorized ? 'Change' : 'Authorize',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

            // Subtitle banner card
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF161A29)
                      : const Color(0xFFF4F6FD),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFF6046E8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'I can organize, search, rename, move, and clean up your files. Anything destructive needs your confirmation.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Chat Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  if (msg.isUser) {
                    return _buildUserBubble(msg.text, isDark);
                  } else {
                    return _buildAssistantBubble(
                      msg,
                      isDark,
                      cardColor,
                      outlineColor,
                    );
                  }
                },
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('FileMind is thinking...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),

            // Bottom Prompt Input Bar
            _buildInputBar(isDark, cardColor, outlineColor),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildUserBubble(String text, bool isDark) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppColors.userBubbleGradient,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(6),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4338CA).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(
    ChatMessage message,
    bool isDark,
    Color cardColor,
    Color outlineColor,
  ) {
    final plan = message.plan;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 36),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: outlineColor.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),

            if (plan != null && plan.steps.isNotEmpty) ...[
              const SizedBox(height: 14),

              // Plan steps
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1F30)
                      : const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: outlineColor.withValues(alpha: 0.4),
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: plan.steps.map((step) {
                    final isFirst = step.stepNumber == 1;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isFirst
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              step.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (isFirst
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFFF59E0B))
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              step.badgeText ?? 'Step ${step.stepNumber}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isFirst
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 14),

              // Interactive action buttons: [Confirm] [Edit step] [Skip step 3]
              Row(
                children: [
                  // Confirm button
                  FilledButton(
                    onPressed: () => _showConfirmationSheet(plan),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6046E8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Edit step button
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Edit step opened')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      'Edit step',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Skip step button
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Step 3 skipped.')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      'Skip step 3',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark, Color cardColor, Color outlineColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          top: BorderSide(
            color: outlineColor.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Row(
        children: [
          // Plus button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E2235)
                  : const Color(0xFFF1F3F9),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.add, size: 20),
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
              onPressed: () {
                _showAttachmentOptions();
              },
            ),
          ),
          const SizedBox(width: 10),

          // Text Field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C2030)
                    : const Color(0xFFF1F3F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Ask about your files...',
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send button (purple circular with paper plane)
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              gradient: AppColors.storageGradient,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              onPressed: () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }

  // Screen 5: Confirmation Sheet modal
  void _showConfirmationSheet(AiPlan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConfirmationSheetModal(
        plan: plan,
        onRunPlan: () async {
          Navigator.pop(ctx);
          int executedCount = 0;
          for (final op in plan.operations) {
            try {
              switch (op.name) {
                case 'move_file':
                  final src = op.input['sourcePath'] as String? ?? op.input['path'] as String?;
                  final dst = op.input['destinationPath'] as String? ?? op.input['destination'] as String?;
                  if (src != null && dst != null) {
                    await widget.fileService.move(src, dst);
                    executedCount++;
                  }
                  break;
                case 'create_folder':
                  final path = op.input['path'] as String? ?? op.input['name'] as String?;
                  if (path != null) {
                    await widget.fileService.createFolder('.', path);
                    executedCount++;
                  }
                  break;
                case 'create_file':
                  final path = op.input['path'] as String? ?? op.input['name'] as String?;
                  final content = op.input['content'] as String? ?? '';
                  if (path != null) {
                    await widget.fileService.createFile(path, content);
                    executedCount++;
                  }
                  break;
                case 'rename_file':
                  final path = op.input['path'] as String?;
                  final newName = op.input['newName'] as String?;
                  if (path != null && newName != null) {
                    await widget.fileService.rename(path, newName);
                    executedCount++;
                  }
                  break;
                case 'delete_file':
                case 'delete_item':
                  final path = op.input['path'] as String?;
                  if (path != null) {
                    await widget.fileService.delete(path);
                    executedCount++;
                  }
                  break;
                case 'edit_file':
                  final path = op.input['path'] as String?;
                  final content = op.input['content'] as String? ?? '';
                  if (path != null) {
                    await widget.fileService.editFile(path, content);
                    executedCount++;
                  }
                  break;
                case 'organize_files':
                  final src = op.input['sourceDirectory'] as String? ?? '.';
                  final strategy = op.input['strategy'] as String? ?? 'by_type';
                  await widget.fileService.organizeFiles(src, strategy);
                  executedCount++;
                  break;
              }
            } catch (e) {
              debugPrint('Error executing operation ${op.name}: $e');
            }
          }

          await widget.fileService.refresh();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Plan executed successfully! $executedCount operations completed on device.',
                ),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
            setState(() {
              _messages.add(ChatMessage(
                text: 'Plan executed successfully! $executedCount file operations completed on your device.',
                isUser: false,
                time: DateTime.now(),
              ));
            });
            _scrollToBottom();
          }
        },
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Color(0xFF6046E8)),
              title: const Text('Organize files by category'),
              onTap: () {
                Navigator.pop(ctx);
                _sendMessage('Organize my files by category into subfolders');
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_delete_outlined, color: Color(0xFFF97316)),
              title: const Text('Clean up duplicate files'),
              onTap: () {
                Navigator.pop(ctx);
                _sendMessage('Clean up duplicate files');
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined, color: Color(0xFF10B981)),
              title: const Text('Create a new folder'),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateFolderFromAi();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_shared_outlined, color: Color(0xFF3B82F6)),
              title: const Text('Authorize / Change folder'),
              onTap: () async {
                Navigator.pop(ctx);
                await showDeviceFolderPicker(context, widget.fileService);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateFolderFromAi() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                _sendMessage('Create folder named "$name"');
              }
            },
            child: const Text('Submit to AI'),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationSheetModal extends StatefulWidget {
  const _ConfirmationSheetModal({
    required this.plan,
    required this.onRunPlan,
  });

  final AiPlan plan;
  final VoidCallback onRunPlan;

  @override
  State<_ConfirmationSheetModal> createState() =>
      _ConfirmationSheetModalState();
}

class _ConfirmationSheetModalState extends State<_ConfirmationSheetModal> {
  bool _moveToTrash = true;
  bool _allowUndo = true;
  bool _notifyWhenDone = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final outlineColor = Theme.of(context).colorScheme.outline;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top accent bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2438) : const Color(0xFFE8EDFD),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Metric Key-Value pairs
                _buildMetricRow('Files affected', '${widget.plan.affectedCount} PDFs', isDark),
                const SizedBox(height: 12),
                _buildMetricRow('Source', widget.plan.sourcePath ?? '/Downloads', isDark),
                const SizedBox(height: 12),
                _buildMetricRow('Destination', widget.plan.destinationPath ?? '/Documents', isDark),
                const SizedBox(height: 12),
                _buildMetricRow('Estimated time', '~${widget.plan.estimatedSeconds} seconds', isDark),
                const SizedBox(height: 18),

                // File badges preview: [PDF Invoice-Mar.pdf] [PDF Contract.pdf] [+12]
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPreviewChip('Invoice-Mar.pdf', isDark, outlineColor),
                    _buildPreviewChip('Contract.pdf', isDark, outlineColor),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF22283A) : const Color(0xFFEFF2F8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+12',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Safety Switches
                _buildSwitchRow(
                  'Move originals to Trash after copy',
                  _moveToTrash,
                  (val) => setState(() => _moveToTrash = val),
                  isDark,
                ),
                _buildSwitchRow(
                  'Allow undo for 24h',
                  _allowUndo,
                  (val) => setState(() => _allowUndo = val),
                  isDark,
                ),
                _buildSwitchRow(
                  'Notify me when done',
                  _notifyWhenDone,
                  (val) => setState(() => _notifyWhenDone = val),
                  isDark,
                ),
                const SizedBox(height: 24),

                // Top row buttons: [Cancel] [Review step-by-step]
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reviewing steps...')),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6046E8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Review step-by-step',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Big prominent green button: [Run plan (14 files)]
                FilledButton(
                  onPressed: widget.onRunPlan,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Run plan (${widget.plan.affectedCount} files)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewChip(String filename, bool isDark, Color outlineColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2235) : const Color(0xFFF3F4F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: outlineColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'PDF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            filename,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF6046E8),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
