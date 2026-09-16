import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/local_file_service.dart';
import '../theme/app_theme.dart';

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
    // Initial conversation matching Screen 4
    final now = DateTime.now();
    _messages.addAll([
      ChatMessage(
        text:
            'Move all PDFs from Downloads to Documents and rename them with today\'s date.',
        isUser: true,
        time: now.subtract(const Duration(minutes: 2)),
      ),
      ChatMessage(
        text: "Found 14 PDFs in Downloads. Here's my plan:",
        isUser: false,
        time: now.subtract(const Duration(minutes: 1)),
        plan: const AiPlan(
          reply: "Found 14 PDFs in Downloads. Here's my plan:",
          operations: [
            PlannedOperation(
              id: 'op-1',
              name: 'move_file',
              input: {
                'sourcePath': '/Downloads',
                'destinationPath': '/Documents',
              },
              requiresApproval: true,
            ),
            PlannedOperation(
              id: 'op-2',
              name: 'rename_file',
              input: {
                'path': '/Documents/*.pdf',
                'newName': '2026-09-08_*',
              },
              requiresApproval: true,
            ),
            PlannedOperation(
              id: 'op-3',
              name: 'delete_item',
              input: {'path': '/Downloads/Archives'},
              requiresApproval: true,
            ),
          ],
          steps: [
            AiPlanStep(
              stepNumber: 1,
              title: 'Move 14 files → Documents',
              description: 'Downloads to Documents',
              badgeText: 'Step 1',
            ),
            AiPlanStep(
              stepNumber: 2,
              title: 'Rename → prefix "2026-09-08_*"',
              description: 'Date prefix formatting',
              badgeText: 'Step 2',
            ),
            AiPlanStep(
              stepNumber: 3,
              title: 'Archive original folder to Trash',
              description: 'Cleanup residual folder',
              badgeText: 'Step 3',
              isDestructive: true,
            ),
          ],
          affectedCount: 14,
          sourcePath: '/Downloads',
          destinationPath: '/Documents',
          estimatedSeconds: 6,
          previewFiles: ['Invoice-Mar.pdf', 'Contract.pdf'],
        ),
      ),
    ]);
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
      final plan = await widget.api.plan(text, const []);
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
          text: 'I ran into an issue connecting to Groq AI: $e',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final outlineColor = Theme.of(context).colorScheme.outline;

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
                              const Text(
                                'Online · Groq LLaMA 3.3',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.more_horiz,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                  ],
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
          // Execute the operations via local file service
          for (final op in plan.operations) {
            if (op.name == 'move_file') {
              final src = op.input['sourcePath'] as String? ?? '/Downloads';
              final dst = op.input['destinationPath'] as String? ?? '/Documents';
              await widget.fileService.move(src, dst);
            }
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Plan executed successfully! ${plan.affectedCount} files organized.',
                ),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
            setState(() {
              _messages.add(ChatMessage(
                text: 'Plan executed successfully! ${plan.affectedCount} files moved and organized.',
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
              leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444)),
              title: const Text('Move and rename recent PDFs'),
              onTap: () {
                Navigator.pop(ctx);
                _sendMessage(
                  'Move all PDFs from Downloads to Documents and rename them with today\'s date.',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_delete, color: Color(0xFFF97316)),
              title: const Text('Clean up duplicates in Photos'),
              onTap: () {
                Navigator.pop(ctx);
                _sendMessage('Find and clean up duplicate photos.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.sort, color: Color(0xFF10B981)),
              title: const Text('Organize Downloads folder by file type'),
              onTap: () {
                Navigator.pop(ctx);
                _sendMessage('Organize my Downloads folder into Documents, Photos, and Videos.');
              },
            ),
          ],
        ),
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
