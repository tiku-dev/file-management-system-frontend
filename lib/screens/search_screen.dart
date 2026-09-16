import 'package:flutter/material.dart';

import '../models.dart';
import '../services/local_file_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.fileService,
    this.initialQuery = 'tax 2024',
    this.onBack,
  });

  final LocalFileService fileService;
  final String initialQuery;
  final VoidCallback? onBack;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  int _selectedFilterIndex = 0;

  final List<Map<String, dynamic>> _filterChips = [
    {'label': 'PDF', 'count': 12},
    {'label': '2024', 'count': 8},
    {'label': 'Documents', 'count': 12},
    {'label': 'Images', 'count': 4},
  ];

  List<FileEntry> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _performSearch(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() => _searching = true);
    final results = await widget.fileService.search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
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
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
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
                    'Search',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),

            // Search text box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: outlineColor.withValues(alpha: 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: isDark ? Colors.white60 : const Color(0xFF9CA3AF),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: _performSearch,
                        decoration: const InputDecoration(
                          hintText: 'Search files or ask a question...',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          _performSearch('');
                        },
                      ),
                  ],
                ),
              ),
            ),

            // "AI understood" badge
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    text: 'AI understood: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                    ),
                    children: const [
                      TextSpan(
                        text: 'tax-related PDFs from 2024',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6046E8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Filter chips row: [PDF 12] [2024 8] [Documents 12] [Images 4]
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filterChips.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final isSelected = _selectedFilterIndex == index;
                    final item = _filterChips[index];

                    return GestureDetector(
                      onTap: () => setState(() => _selectedFilterIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6046E8).withValues(alpha: 0.12)
                              : cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF6046E8)
                                : outlineColor.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              item['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF6046E8)
                                    : (isDark
                                        ? Colors.white70
                                        : const Color(0xFF4B5563)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF6046E8)
                                    : (isDark
                                        ? const Color(0xFF282F46)
                                        : const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item['count']}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white70
                                          : const Color(0xFF4B5563)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Search Results
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            'No matching files found.',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final file = _results[index];
                            return _buildResultCard(
                              file,
                              isDark,
                              cardColor,
                              outlineColor,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(
    FileEntry file,
    bool isDark,
    Color cardColor,
    Color outlineColor,
  ) {
    final hasSnippet = file.snippet != null && file.snippet!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: outlineColor.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Badge + Title + Star
            Row(
              children: [
                // Badge (PDF, DOC)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: file.badgeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      file.badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & folder details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${file.folderName} · ${file.formattedSize} · ${file.formattedDate}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),

                // Star icon
                IconButton(
                  icon: Icon(
                    file.isStarred
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: file.isStarred
                        ? const Color(0xFFFBBF24)
                        : (isDark ? Colors.white38 : Colors.black26),
                    size: 22,
                  ),
                  onPressed: () {
                    // Toggle star
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          file.isStarred ? 'Unstarred ${file.name}' : 'Starred ${file.name}',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Quoted text snippet box (if available)
            if (hasSnippet) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1C2235)
                      : const Color(0xFFF6F8FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '“${file.snippet!}”',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
