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

  final List<ChatConversation> _conversations = [];
  ChatConversation? _activeConversation;

  List<ChatMessage> get _messages => _activeConversation?.messages ?? [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _loadConversations() {
    final local = widget.api.loadLocalConversations();
    if (local.isNotEmpty) {
      setState(() {
        _conversations.clear();
        _conversations.addAll(local);
        _activeConversation = _conversations.first;
      });
    } else {
      _startNewChat(save: false);
    }

    _syncRemoteConversations();
  }

  Future<void> _syncRemoteConversations() async {
    try {
      final remote = await widget.api.fetchRemoteConversations();
      if (remote.isNotEmpty && mounted) {
        setState(() {
          final existingIds = _conversations.map((c) => c.id).toSet();
          for (final r in remote) {
            if (!existingIds.contains(r.id)) {
              _conversations.add(r);
            }
          }
        });
        widget.api.saveLocalConversations(_conversations);
      }
    } catch (_) {}
  }

  void _startNewChat({bool save = true}) {
    final isAuth = widget.fileService.isAuthorized;
    final folder = widget.fileService.authorizedFolderName;
    final count = widget.fileService.totalFilesCount;

    final welcomeMsg = ChatMessage(
      text: isAuth
          ? "Hello! I am FileMind AI. I'm connected to your device folder: $folder ($count files). You can ask me to organize files by category, clean up duplicates, rename files, or create folders."
          : "Hello! I am FileMind AI. Please authorize a folder on your device so I can help manage, organize, and rename your files.",
      isUser: false,
      time: DateTime.now(),
    );

    final newConv = ChatConversation(
      id: 'conv-${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Conversation',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: [welcomeMsg],
    );

    setState(() {
      _conversations.insert(0, newConv);
      _activeConversation = newConv;
    });

    if (save) {
      widget.api.saveLocalConversations(_conversations);
    }
    _scrollToBottom();
  }

  Future<void> _selectConversation(ChatConversation conv) async {
    setState(() {
      _activeConversation = conv;
    });

    if (conv.messages.isEmpty) {
      final detailed = await widget.api.fetchRemoteConversationDetail(conv.id);
      if (detailed != null && mounted) {
        setState(() {
          conv.messages.clear();
          conv.messages.addAll(detailed.messages);
        });
        widget.api.saveLocalConversations(_conversations);
      }
    }

    _scrollToBottom();
  }

  void _deleteConversation(ChatConversation conv) {
    setState(() {
      _conversations.removeWhere((c) => c.id == conv.id);
      if (_activeConversation?.id == conv.id) {
        if (_conversations.isNotEmpty) {
          _activeConversation = _conversations.first;
        } else {
          _startNewChat(save: false);
        }
      }
    });
    widget.api.deleteRemoteConversation(conv.id);
    widget.api.saveLocalConversations(_conversations);
  }

  void _clearAllConversations() {
    for (final c in _conversations) {
      widget.api.deleteRemoteConversation(c.id);
    }
    setState(() {
      _conversations.clear();
    });
    widget.api.saveLocalConversations(_conversations);
    _startNewChat();
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

    if (_activeConversation == null) {
      _startNewChat(save: false);
    }

    final conv = _activeConversation!;
    _textController.clear();

    final userMsg = ChatMessage(
      text: text,
      isUser: true,
      time: DateTime.now(),
    );

    setState(() {
      conv.messages.add(userMsg);
      conv.updatedAt = DateTime.now();
      if (conv.title == 'New Conversation' || conv.title.isEmpty) {
        conv.title = text.length > 40 ? '${text.substring(0, 37)}...' : text;
      }
      _isLoading = true;
    });

    widget.api.saveLocalConversations(_conversations);
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

      final plan = await widget.api.plan(
        prompt,
        const [],
        conversationId: conv.id.startsWith('conv-') ? null : conv.id,
      );

      if (!mounted) return;

      final asstMsg = ChatMessage(
        text: plan.reply ?? 'Plan prepared for your review:',
        isUser: false,
        time: DateTime.now(),
        plan: plan,
      );

      setState(() {
        conv.messages.add(asstMsg);
        conv.updatedAt = DateTime.now();
      });

      widget.api.saveLocalConversations(_conversations);
    } catch (e) {
      if (!mounted) return;
      final errorMsg = ChatMessage(
        text: 'Notice: $e',
        isUser: false,
        time: DateTime.now(),
      );
      setState(() {
        conv.messages.add(errorMsg);
        conv.updatedAt = DateTime.now();
      });
      widget.api.saveLocalConversations(_conversations);
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
                        // Chat History Action Button
                        IconButton(
                          icon: Badge(
                            isLabelVisible: _conversations.length > 1,
                            label: Text('${_conversations.length}'),
                            backgroundColor: const Color(0xFF6046E8),
                            child: const Icon(Icons.history_rounded),
                          ),
                          tooltip: 'Chat History',
                          color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                          onPressed: _showChatHistorySheet,
                        ),
                        // New Chat Button
                        IconButton(
                          icon: const Icon(Icons.add_comment_outlined),
                          tooltip: 'New Chat',
                          color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                          onPressed: () => _startNewChat(),
                        ),
                        // Folder Options
                        IconButton(
                          icon: const Icon(Icons.folder_shared_outlined),
                          tooltip: 'Select Folder',
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

                // Active Conversation Bar (tappable to view chat history)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                  child: InkWell(
                    onTap: _showChatHistorySheet,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E2235)
                            : const Color(0xFFF1F3F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: outlineColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6046E8).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.forum_outlined,
                              size: 16,
                              color: Color(0xFF6046E8),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _activeConversation?.title ?? 'Conversation',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF1E1B38),
                                  ),
                                ),
                                Text(
                                  '${_activeConversation?.messages.length ?? 0} messages · ${_activeConversation?.formattedDate ?? "Today"}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6046E8).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'History',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6046E8),
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right,
                                  size: 14,
                                  color: Color(0xFF6046E8),
                                ),
                              ],
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

              // Interactive action buttons: [Confirm & Run] [Review details]
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _showConfirmationSheet(plan),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Confirm & Run'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6046E8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showConfirmationSheet(plan),
                    icon: const Icon(Icons.tune_rounded, size: 15),
                    label: const Text('Review details'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      foregroundColor:
                          isDark ? Colors.white70 : const Color(0xFF4B5563),
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
        fileService: widget.fileService,
        onRunPlan: () async {
          Navigator.pop(ctx);
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Executing ${plan.operations.length} file operations on your device...'),
              duration: const Duration(seconds: 2),
            ),
          );

          final executedCount = await widget.fileService.executePlan(plan);

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
              final confirmationMsg = ChatMessage(
                text: 'Plan executed successfully! $executedCount file operations completed on your device.',
                isUser: false,
                time: DateTime.now(),
              );
              _activeConversation?.messages.add(confirmationMsg);
              _activeConversation?.updatedAt = DateTime.now();
            });
            widget.api.saveLocalConversations(_conversations);
            _scrollToBottom();
          }
        },
      ),
    );
  }

  void _showChatHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChatHistoryModal(
        conversations: _conversations,
        activeConversationId: _activeConversation?.id,
        onSelectConversation: (conv) {
          Navigator.pop(ctx);
          _selectConversation(conv);
        },
        onNewChat: () {
          Navigator.pop(ctx);
          _startNewChat();
        },
        onDeleteConversation: (conv) {
          _deleteConversation(conv);
        },
        onClearAll: () {
          Navigator.pop(ctx);
          _clearAllConversations();
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
    required this.fileService,
    required this.onRunPlan,
  });

  final AiPlan plan;
  final LocalFileService fileService;
  final VoidCallback onRunPlan;

  @override
  State<_ConfirmationSheetModal> createState() =>
      _ConfirmationSheetModalState();
}

class _ConfirmationSheetModalState extends State<_ConfirmationSheetModal> {
  bool _moveToTrash = true;
  bool _allowUndo = true;
  bool _notifyWhenDone = false;

  String _computeAffectedLabel() {
    final count = widget.plan.affectedCount > 0
        ? widget.plan.affectedCount
        : (widget.plan.operations.isNotEmpty
            ? widget.plan.operations.length
            : widget.fileService.files.length);

    final names = <String>[];
    for (final op in widget.plan.operations) {
      final n = op.input['newName']?.toString() ??
          op.input['path']?.toString() ??
          op.input['sourcePath']?.toString() ??
          '';
      if (n.isNotEmpty) names.add(n.split('/').last);
    }
    if (names.isEmpty && widget.fileService.files.isNotEmpty) {
      names.addAll(widget.fileService.files.map((f) => f.name));
    }

    final extensions = names
        .map((name) {
          final dot = name.lastIndexOf('.');
          return dot != -1 ? name.substring(dot + 1).toLowerCase() : '';
        })
        .where((e) => e.isNotEmpty)
        .toSet();

    const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'};
    const docExts = {'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx'};

    if (extensions.isNotEmpty && extensions.every((e) => imageExts.contains(e))) {
      return '$count Images';
    } else if (extensions.length == 1 && extensions.first == 'pdf') {
      return '$count PDFs';
    } else if (extensions.isNotEmpty &&
        extensions.every((e) => docExts.contains(e) || e == 'pdf')) {
      return '$count Documents';
    }
    return '$count Files';
  }

  String _computeSource() {
    if (widget.plan.sourcePath != null && widget.plan.sourcePath!.isNotEmpty) {
      return widget.plan.sourcePath!;
    }
    final folder = widget.fileService.authorizedFolderName;
    return folder.isNotEmpty ? folder : 'Device Storage';
  }

  String _computeDestination() {
    if (widget.plan.destinationPath != null &&
        widget.plan.destinationPath!.isNotEmpty) {
      return widget.plan.destinationPath!;
    }
    final isRename =
        widget.plan.operations.any((op) => op.name == 'rename_file');
    if (isRename) {
      if (widget.plan.operations.isNotEmpty) {
        final first = widget.plan.operations.first.input['newName']?.toString();
        final last = widget.plan.operations.last.input['newName']?.toString();
        if (first != null && last != null && first != last) {
          return '$first ... $last';
        } else if (first != null) {
          return first;
        }
      }
      return 'In-place Rename';
    }
    return _computeSource();
  }

  List<Widget> _buildPreviewChips(bool isDark, Color outlineColor) {
    final chips = <Widget>[];
    final previewItems = <({String name, String ext})>[];

    for (final op in widget.plan.operations) {
      final rawName = op.input['newName']?.toString() ??
          op.input['path']?.toString() ??
          op.input['sourcePath']?.toString() ??
          '';
      final name = rawName.split('/').last;
      if (name.isNotEmpty) {
        final dot = name.lastIndexOf('.');
        final ext =
            dot != -1 ? name.substring(dot + 1).toUpperCase() : 'FILE';
        previewItems.add((name: name, ext: ext));
      }
    }

    if (previewItems.isEmpty) {
      for (final f in widget.fileService.files) {
        final dot = f.name.lastIndexOf('.');
        final ext =
            dot != -1 ? f.name.substring(dot + 1).toUpperCase() : 'FILE';
        previewItems.add((name: f.name, ext: ext));
      }
    }

    final displayItems = previewItems.take(2).toList();
    for (final item in displayItems) {
      chips.add(_buildPreviewChip(item.name, item.ext, isDark, outlineColor));
    }

    final remaining = previewItems.length - displayItems.length;
    if (remaining > 0) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF22283A) : const Color(0xFFEFF2F8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '+$remaining',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
            ),
          ),
        ),
      );
    }

    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final outlineColor = Theme.of(context).colorScheme.outline;

    final totalAffected = widget.plan.affectedCount > 0
        ? widget.plan.affectedCount
        : (widget.plan.operations.isNotEmpty
            ? widget.plan.operations.length
            : widget.fileService.files.length);
    final isMoveOrCopy = widget.plan.operations.any(
      (op) => op.name == 'move_file' || op.name == 'copy_file',
    );

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
                _buildMetricRow('Files affected', _computeAffectedLabel(), isDark),
                const SizedBox(height: 12),
                _buildMetricRow('Source', _computeSource(), isDark),
                const SizedBox(height: 12),
                _buildMetricRow('Destination', _computeDestination(), isDark),
                const SizedBox(height: 12),
                _buildMetricRow('Estimated time', '~${widget.plan.estimatedSeconds} seconds', isDark),
                const SizedBox(height: 18),

                // File badges preview
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildPreviewChips(isDark, outlineColor),
                ),
                const SizedBox(height: 20),

                // Safety Switches
                if (isMoveOrCopy)
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

                // Big prominent green button
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
                    'Run plan ($totalAffected files)',
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

  Widget _buildPreviewChip(
    String filename,
    String badgeText,
    bool isDark,
    Color outlineColor,
  ) {
    Color badgeBgColor;
    final extUpper = badgeText.toUpperCase();
    if (extUpper == 'PDF') {
      badgeBgColor = const Color(0xFFEF4444);
    } else if (['JPG', 'JPEG', 'PNG', 'WEBP', 'GIF', 'HEIC']
        .contains(extUpper)) {
      badgeBgColor = const Color(0xFF0EA5E9);
    } else if (['MP4', 'MOV', 'MKV', 'AVI'].contains(extUpper)) {
      badgeBgColor = const Color(0xFF8B5CF6);
    } else if (['MP3', 'WAV', 'AAC', 'FLAC'].contains(extUpper)) {
      badgeBgColor = const Color(0xFFEC4899);
    } else if (['DOC', 'DOCX', 'TXT', 'MD'].contains(extUpper)) {
      badgeBgColor = const Color(0xFF3B82F6);
    } else {
      badgeBgColor = const Color(0xFF6B7280);
    }

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
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: badgeBgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
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

class _ChatHistoryModal extends StatefulWidget {
  const _ChatHistoryModal({
    required this.conversations,
    required this.activeConversationId,
    required this.onSelectConversation,
    required this.onNewChat,
    required this.onDeleteConversation,
    required this.onClearAll,
  });

  final List<ChatConversation> conversations;
  final String? activeConversationId;
  final ValueChanged<ChatConversation> onSelectConversation;
  final VoidCallback onNewChat;
  final ValueChanged<ChatConversation> onDeleteConversation;
  final VoidCallback onClearAll;

  @override
  State<_ChatHistoryModal> createState() => _ChatHistoryModalState();
}

class _ChatHistoryModalState extends State<_ChatHistoryModal> {
  final _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final outlineColor = Theme.of(context).colorScheme.outline;

    final filtered = widget.conversations.where((c) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return c.title.toLowerCase().contains(q) ||
          c.messages.any((m) => m.text.toLowerCase().contains(q));
    }).toList();

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.75,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6046E8).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: Color(0xFF6046E8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chat History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${widget.conversations.length} saved conversation${widget.conversations.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: widget.onNewChat,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Chat'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6046E8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2235) : const Color(0xFFF1F3F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _filter = val.trim()),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, size: 20),
                  hintText: 'Search chat history...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // Conversations List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 48,
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _filter.isNotEmpty
                              ? 'No matching conversations found'
                              : 'No chat history yet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final conv = filtered[index];
                      final isActive = conv.id == widget.activeConversationId;

                      return Container(
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF6046E8).withValues(alpha: isDark ? 0.16 : 0.08)
                              : (isDark ? const Color(0xFF1A1F30) : const Color(0xFFFAFAFD)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFF6046E8)
                                : outlineColor.withValues(alpha: 0.4),
                            width: isActive ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF6046E8)
                                  : (isDark
                                      ? const Color(0xFF262E44)
                                      : const Color(0xFFECEFF8)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                              color: isActive
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : const Color(0xFF6046E8)),
                            ),
                          ),
                          title: Text(
                            conv.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conv.snippet,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      conv.formattedDate,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                    const Text(' · ', style: TextStyle(color: Colors.grey)),
                                    Text(
                                      '${conv.messages.length} msg${conv.messages.length == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isActive)
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Active',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                tooltip: 'Delete conversation',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (dlgCtx) => AlertDialog(
                                      title: const Text('Delete conversation?'),
                                      content: Text('Delete "${conv.title}"? This cannot be undone.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dlgCtx),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFFEF4444),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(dlgCtx);
                                            setState(() {
                                              widget.onDeleteConversation(conv);
                                            });
                                          },
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          onTap: () => widget.onSelectConversation(conv),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom clear all button
          if (widget.conversations.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (dlgCtx) => AlertDialog(
                            title: const Text('Clear all chat history?'),
                            content: const Text(
                                'This will delete all conversations from your device and server.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dlgCtx),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                ),
                                onPressed: () {
                                  Navigator.pop(dlgCtx);
                                  widget.onClearAll();
                                },
                                child: const Text('Clear All'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_sweep_outlined,
                          size: 18, color: Color(0xFFEF4444)),
                      label: const Text(
                        'Clear all history',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
