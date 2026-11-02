import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../models.dart';
import '../services/document_parser_service.dart';

enum ReaderTheme {
  system,
  light,
  sepia,
  dark,
  amoled,
}

enum ReaderFontFamily {
  sans,
  serif,
  mono,
}

class DocumentReaderView extends StatefulWidget {
  const DocumentReaderView({
    super.key,
    required this.file,
    this.initialText,
    this.onOpenExternal,
    this.onShare,
  });

  final FileEntry file;
  final String? initialText;
  final VoidCallback? onOpenExternal;
  final VoidCallback? onShare;

  @override
  State<DocumentReaderView> createState() => _DocumentReaderViewState();
}

class _DocumentReaderViewState extends State<DocumentReaderView> {
  // Common states
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // PDF specific
  late PdfViewerController _pdfViewerController;
  PdfTextSearchResult? _pdfSearchResult;
  int _pdfPageNumber = 1;
  int _pdfTotalPages = 1;
  double _pdfZoom = 1.0;
  bool _pdfNightMode = false;
  PdfScrollDirection _pdfScrollDirection = PdfScrollDirection.vertical;

  // Text / DOCX specific
  DocumentParseResult? _parsedDoc;
  ReaderTheme _readerTheme = ReaderTheme.system;
  ReaderFontFamily _fontFamily = ReaderFontFamily.sans;
  double _fontSize = 15.0;
  final double _lineHeight = 1.6;
  bool _showLineNumbers = false;
  String _textSearchQuery = '';
  int _textMatchCount = 0;
  int _currentTextMatchIndex = 0;

  File? _pdfFile;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _loadDocumentContent();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _pdfSearchResult?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDocumentContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.file.isPdf) {
        final pdfFile = await DocumentParserService.getOrCreatePdfFile(
          widget.file.path,
          widget.file.name,
        );
        if (mounted) {
          setState(() {
            _pdfFile = pdfFile;
            _isLoading = false;
          });
        }
        return;
      }

      DocumentParseResult result;
      if (widget.file.isDocx) {
        result = await DocumentParserService.parseDocxFile(
          widget.file.path,
          fileName: widget.file.name,
        );
      } else {
        if (widget.initialText != null && widget.initialText!.isNotEmpty) {
          result = DocumentParseResult.fromText(widget.initialText!);
        } else {
          result = await DocumentParserService.parseTextFile(
            widget.file.path,
            fileName: widget.file.name,
          );
        }
      }

      if (mounted) {
        setState(() {
          _parsedDoc = result;
          _errorMessage = result.error;
          _isLoading = false;
          // Default to monospace for code/logs
          if (const ['log', 'json', 'yaml', 'yml', 'dart', 'py', 'js', 'ts', 'sh', 'bat', 'sql', 'xml'].contains(widget.file.extension)) {
            _fontFamily = ReaderFontFamily.mono;
            _showLineNumbers = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load document: $e';
          _isLoading = false;
        });
      }
    }
  }

  // PDF Search logic
  void _handlePdfSearch(String query) {
    if (query.trim().isEmpty) {
      _pdfSearchResult?.clear();
      setState(() {
        _pdfSearchResult = null;
      });
      return;
    }

    _pdfSearchResult?.removeListener(_onPdfSearchUpdated);
    _pdfSearchResult = _pdfViewerController.searchText(query.trim());
    _pdfSearchResult!.addListener(_onPdfSearchUpdated);
    setState(() {});
  }

  void _onPdfSearchUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  void _closeSearch() {
    setState(() {
      _isSearchOpen = false;
      _searchController.clear();
      _textSearchQuery = '';
      _textMatchCount = 0;
      _currentTextMatchIndex = 0;
    });
    _pdfSearchResult?.clear();
    _searchFocusNode.unfocus();
  }

  // Text / DOCX Search logic
  void _handleTextSearch(String query) {
    final clean = query.trim().toLowerCase();
    setState(() {
      _textSearchQuery = clean;
      if (clean.isEmpty || _parsedDoc == null) {
        _textMatchCount = 0;
        _currentTextMatchIndex = 0;
      } else {
        final matches = RegExp(RegExp.escape(clean), caseSensitive: false)
            .allMatches(_parsedDoc!.text);
        _textMatchCount = matches.length;
        _currentTextMatchIndex = _textMatchCount > 0 ? 1 : 0;
      }
    });
  }

  void _nextTextMatch() {
    if (_textMatchCount == 0) return;
    setState(() {
      _currentTextMatchIndex = (_currentTextMatchIndex % _textMatchCount) + 1;
    });
  }

  void _prevTextMatch() {
    if (_textMatchCount == 0) return;
    setState(() {
      _currentTextMatchIndex = _currentTextMatchIndex <= 1
          ? _textMatchCount
          : _currentTextMatchIndex - 1;
    });
  }

  // Color schemes for reading
  Color _getReaderBg(bool isDark) {
    switch (_readerTheme) {
      case ReaderTheme.light:
        return const Color(0xFFFAFAFA);
      case ReaderTheme.sepia:
        return const Color(0xFFFAF2E6);
      case ReaderTheme.dark:
        return const Color(0xFF161A29);
      case ReaderTheme.amoled:
        return Colors.black;
      case ReaderTheme.system:
        return isDark ? const Color(0xFF0F111A) : const Color(0xFFF8FAFC);
    }
  }

  Color _getReaderTextColor(bool isDark) {
    switch (_readerTheme) {
      case ReaderTheme.light:
        return const Color(0xFF1F2937);
      case ReaderTheme.sepia:
        return const Color(0xFF4A3E31);
      case ReaderTheme.dark:
        return const Color(0xFFE2E8F0);
      case ReaderTheme.amoled:
        return const Color(0xFFEDEDED);
      case ReaderTheme.system:
        return isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1F2937);
    }
  }

  TextStyle _getTextStyle(bool isDark) {
    final color = _getReaderTextColor(isDark);
    switch (_fontFamily) {
      case ReaderFontFamily.serif:
        return TextStyle(
          fontFamily: 'serif',
          fontSize: _fontSize,
          height: _lineHeight,
          color: color,
        );
      case ReaderFontFamily.mono:
        return TextStyle(
          fontFamily: 'monospace',
          fontSize: _fontSize,
          height: _lineHeight,
          color: color,
        );
      case ReaderFontFamily.sans:
        return TextStyle(
          fontSize: _fontSize,
          height: _lineHeight,
          color: color,
          letterSpacing: 0.15,
        );
    }
  }

  void _showJumpToPageDialog() {
    final controller = TextEditingController(text: '$_pdfPageNumber');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go to Page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter page number (1 - $_pdfTotalPages):',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixText: '/ $_pdfTotalPages',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final page = int.tryParse(controller.text.trim());
              if (page != null && page >= 1 && page <= _pdfTotalPages) {
                _pdfViewerController.jumpToPage(page);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  void _showReaderPreferencesSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161A29) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Reader Preferences',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Reading themes
                  const Text('Reading Tone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildThemeOption(
                        label: 'Auto',
                        theme: ReaderTheme.system,
                        previewBg: isDark ? const Color(0xFF0F111A) : const Color(0xFFF8FAFC),
                        previewBorder: Colors.grey,
                        setSheetState: setSheetState,
                      ),
                      const SizedBox(width: 8),
                      _buildThemeOption(
                        label: 'Light',
                        theme: ReaderTheme.light,
                        previewBg: Colors.white,
                        previewBorder: Colors.black26,
                        setSheetState: setSheetState,
                      ),
                      const SizedBox(width: 8),
                      _buildThemeOption(
                        label: 'Sepia',
                        theme: ReaderTheme.sepia,
                        previewBg: const Color(0xFFFAF2E6),
                        previewBorder: const Color(0xFFD3B895),
                        setSheetState: setSheetState,
                      ),
                      const SizedBox(width: 8),
                      _buildThemeOption(
                        label: 'Dark',
                        theme: ReaderTheme.dark,
                        previewBg: const Color(0xFF161A29),
                        previewBorder: const Color(0xFF6046E8),
                        setSheetState: setSheetState,
                      ),
                      const SizedBox(width: 8),
                      _buildThemeOption(
                        label: 'OLED',
                        theme: ReaderTheme.amoled,
                        previewBg: Colors.black,
                        previewBorder: Colors.white24,
                        setSheetState: setSheetState,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Font Size
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Text Size', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${_fontSize.toInt()} pt', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('A', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 12.0,
                          max: 26.0,
                          divisions: 14,
                          activeColor: const Color(0xFF6046E8),
                          onChanged: (val) {
                            setState(() => _fontSize = val);
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const Text('A', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Typography Type
                  const Text('Typeface', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SegmentedButton<ReaderFontFamily>(
                    segments: const [
                      ButtonSegment(value: ReaderFontFamily.sans, label: Text('Modern Sans')),
                      ButtonSegment(value: ReaderFontFamily.serif, label: Text('Classic Serif')),
                      ButtonSegment(value: ReaderFontFamily.mono, label: Text('Monospace')),
                    ],
                    selected: {_fontFamily},
                    onSelectionChanged: (val) {
                      setState(() => _fontFamily = val.first);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 16),

                  // Line Numbers toggle
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Line Numbers', style: TextStyle(fontSize: 14)),
                    value: _showLineNumbers,
                    activeTrackColor: const Color(0xFF6046E8),
                    onChanged: (val) {
                      setState(() => _showLineNumbers = val);
                      setSheetState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption({
    required String label,
    required ReaderTheme theme,
    required Color previewBg,
    required Color previewBorder,
    required StateSetter setSheetState,
  }) {
    final isSelected = _readerTheme == theme;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _readerTheme = theme);
          setSheetState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: previewBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF6046E8) : previewBorder,
              width: isSelected ? 2.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Aa',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme == ReaderTheme.light || theme == ReaderTheme.sepia
                      ? Colors.black87
                      : Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: theme == ReaderTheme.light || theme == ReaderTheme.sepia
                      ? Colors.black87
                      : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final outlineColor = Theme.of(context).colorScheme.outline;

    return Column(
      children: [
        // Reader Utility Bar (Search, Zoom, Settings, Page Navigation)
        _buildTopReaderBar(isDark, cardColor, outlineColor),

        // Search Bar (expandable)
        if (_isSearchOpen) _buildSearchBar(isDark, cardColor, outlineColor),

        // Document Reader Canvas
        Expanded(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Preparing document reader...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                )
              : _errorMessage != null
                  ? _buildErrorView(isDark)
                  : widget.file.isPdf
                      ? _buildPdfViewer(isDark)
                      : _buildTextDocViewer(isDark),
        ),
      ],
    );
  }

  Widget _buildTopReaderBar(bool isDark, Color cardColor, Color outlineColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A29) : const Color(0xFFF1F4F9),
        border: Border(
          bottom: BorderSide(color: outlineColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          // File format badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: widget.file.badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.file.extension.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: widget.file.badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Reading statistics or Page indicator
          if (widget.file.isPdf) ...[
            InkWell(
              onTap: _showJumpToPageDialog,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Page $_pdfPageNumber / $_pdfTotalPages',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
            ),
          ] else if (_parsedDoc != null) ...[
            Text(
              '${_parsedDoc!.estimatedReadMinutes} min read · ${_parsedDoc!.wordCount} words',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF4B5563),
              ),
            ),
          ],

          const Spacer(),

          // Search Button
          IconButton(
            icon: Icon(
              _isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded,
              size: 20,
              color: _isSearchOpen ? const Color(0xFF6046E8) : null,
            ),
            tooltip: 'Search Document',
            onPressed: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (_isSearchOpen) {
                  _searchFocusNode.requestFocus();
                } else {
                  _closeSearch();
                }
              });
            },
          ),

          // PDF Specific Controls
          if (widget.file.isPdf) ...[
            // Zoom Out
            IconButton(
              icon: const Icon(Icons.zoom_out_rounded, size: 20),
              tooltip: 'Zoom Out',
              onPressed: () {
                setState(() {
                  _pdfZoom = (_pdfZoom - 0.25).clamp(0.75, 3.0);
                  _pdfViewerController.zoomLevel = _pdfZoom;
                });
              },
            ),
            // Zoom In
            IconButton(
              icon: const Icon(Icons.zoom_in_rounded, size: 20),
              tooltip: 'Zoom In',
              onPressed: () {
                setState(() {
                  _pdfZoom = (_pdfZoom + 0.25).clamp(0.75, 3.0);
                  _pdfViewerController.zoomLevel = _pdfZoom;
                });
              },
            ),
            // Reset Zoom / Fit
            IconButton(
              icon: const Icon(Icons.fit_screen_rounded, size: 19),
              tooltip: 'Fit Width',
              onPressed: () {
                setState(() {
                  _pdfZoom = 1.0;
                  _pdfViewerController.zoomLevel = 1.0;
                });
              },
            ),
            // Night mode inverter
            IconButton(
              icon: Icon(
                _pdfNightMode ? Icons.dark_mode_rounded : Icons.dark_mode_outlined,
                size: 20,
                color: _pdfNightMode ? const Color(0xFFFBBF24) : null,
              ),
              tooltip: 'Invert / Night Mode',
              onPressed: () {
                setState(() {
                  _pdfNightMode = !_pdfNightMode;
                });
              },
            ),
            // Scroll direction toggle
            IconButton(
              icon: Icon(
                _pdfScrollDirection == PdfScrollDirection.vertical
                    ? Icons.swap_vert_rounded
                    : Icons.swap_horiz_rounded,
                size: 20,
              ),
              tooltip: _pdfScrollDirection == PdfScrollDirection.vertical
                  ? 'Switch to Horizontal Pages'
                  : 'Switch to Vertical Continuous',
              onPressed: () {
                setState(() {
                  _pdfScrollDirection = _pdfScrollDirection == PdfScrollDirection.vertical
                      ? PdfScrollDirection.horizontal
                      : PdfScrollDirection.vertical;
                });
              },
            ),
          ] else ...[
            // Reader Typography Settings (Font, Size, Sepia Theme)
            IconButton(
              icon: const Icon(Icons.text_fields_rounded, size: 20),
              tooltip: 'Typography & Theme',
              onPressed: () => _showReaderPreferencesSheet(isDark),
            ),
            // Quick copy all text
            IconButton(
              icon: const Icon(Icons.copy_all_rounded, size: 20),
              tooltip: 'Copy Document Text',
              onPressed: () {
                if (_parsedDoc?.text != null) {
                  Clipboard.setData(ClipboardData(text: _parsedDoc!.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Document text copied to clipboard')),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color cardColor, Color outlineColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF1E2235) : const Color(0xFFE5E9F4),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Color(0xFF6046E8)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search in document...',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (val) {
                if (widget.file.isPdf) {
                  _handlePdfSearch(val);
                } else {
                  _handleTextSearch(val);
                }
              },
            ),
          ),

          // Matches Indicator
          if (widget.file.isPdf && _pdfSearchResult != null) ...[
            Text(
              '${_pdfSearchResult!.currentInstanceIndex} / ${_pdfSearchResult!.totalInstanceCount}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              tooltip: 'Previous match',
              onPressed: () => _pdfSearchResult?.previousInstance(),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              tooltip: 'Next match',
              onPressed: () => _pdfSearchResult?.nextInstance(),
            ),
          ] else if (!widget.file.isPdf && _textSearchQuery.isNotEmpty) ...[
            Text(
              '$_currentTextMatchIndex / $_textMatchCount',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              tooltip: 'Previous match',
              onPressed: _prevTextMatch,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              tooltip: 'Next match',
              onPressed: _nextTextMatch,
            ),
          ],

          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Close search',
            onPressed: _closeSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer(bool isDark) {
    Widget pdfWidget = SfPdfViewer.file(
      _pdfFile ?? File(widget.file.path),
      controller: _pdfViewerController,
      scrollDirection: _pdfScrollDirection,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      enableDoubleTapZooming: true,
      pageSpacing: 4.0,
      onDocumentLoaded: (details) {
        setState(() {
          _pdfTotalPages = details.document.pages.count;
          _pdfPageNumber = 1;
        });
      },
      onPageChanged: (details) {
        setState(() {
          _pdfPageNumber = details.newPageNumber;
        });
      },
      onDocumentLoadFailed: (details) {
        setState(() {
          _errorMessage = 'Could not load PDF document: ${details.description}';
        });
      },
    );

    if (_pdfNightMode) {
      // Invert color matrix for dark / night reading
      pdfWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
           0,-1, 0, 0, 255,
           0, 0,-1, 0, 255,
           0, 0, 0, 1,   0,
        ]),
        child: pdfWidget,
      );
    }

    return Stack(
      children: [
        pdfWidget,

        // Quick page navigation floating pill at bottom center
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2235).withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => _pdfViewerController.previousPage(),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showJumpToPageDialog,
                    child: Text(
                      '$_pdfPageNumber / $_pdfTotalPages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => _pdfViewerController.nextPage(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextDocViewer(bool isDark) {
    final bg = _getReaderBg(isDark);
    final textStyle = _getTextStyle(isDark);

    if (_parsedDoc == null || _parsedDoc!.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('This document appears to be empty.'),
            const SizedBox(height: 16),
            if (widget.onOpenExternal != null)
              OutlinedButton.icon(
                onPressed: widget.onOpenExternal,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in External App'),
              ),
          ],
        ),
      );
    }

    // DOCX rendering with structured paragraphs
    if (widget.file.isDocx && _parsedDoc!.docxParagraphs.isNotEmpty) {
      return Container(
        color: bg,
        child: SelectionArea(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            itemCount: _parsedDoc!.docxParagraphs.length,
            itemBuilder: (ctx, index) {
              final p = _parsedDoc!.docxParagraphs[index];
              return _buildDocxParagraph(p, isDark, textStyle);
            },
          ),
        ),
      );
    }

    // Plain text / Code / Markdown
    final lines = _parsedDoc!.text.split('\n');

    return Container(
      color: bg,
      child: SelectionArea(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: lines.length,
          itemBuilder: (ctx, index) {
            final lineText = lines[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showLineNumbers)
                    Container(
                      width: 44,
                      margin: const EdgeInsets.only(right: 12),
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: (_fontSize * 0.85).clamp(10.0, 18.0),
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                      ),
                    ),
                  Expanded(
                    child: _buildHighlightedText(lineText, textStyle),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDocxParagraph(DocxParagraph p, bool isDark, TextStyle baseStyle) {
    TextStyle style = baseStyle;

    switch (p.type) {
      case DocxParagraphType.heading1:
        style = baseStyle.copyWith(
          fontSize: _fontSize * 1.5,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF6046E8),
        );
        break;
      case DocxParagraphType.heading2:
        style = baseStyle.copyWith(
          fontSize: _fontSize * 1.3,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        );
        break;
      case DocxParagraphType.heading3:
        style = baseStyle.copyWith(
          fontSize: _fontSize * 1.15,
          fontWeight: FontWeight.w700,
        );
        break;
      case DocxParagraphType.bullet:
      case DocxParagraphType.numbered:
      case DocxParagraphType.body:
        if (p.isBold) {
          style = baseStyle.copyWith(fontWeight: FontWeight.w700);
        }
        break;
    }

    final bottomSpacing = p.type == DocxParagraphType.heading1
        ? 16.0
        : p.type == DocxParagraphType.heading2
            ? 12.0
            : 8.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.type == DocxParagraphType.bullet) ...[
            Container(
              margin: const EdgeInsets.only(top: 8, right: 10),
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF6046E8),
                shape: BoxShape.circle,
              ),
            ),
          ],
          Expanded(
            child: _buildHighlightedText(p.text, style),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(String text, TextStyle baseStyle) {
    if (_textSearchQuery.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final query = _textSearchQuery;
    final spans = <TextSpan>[];
    int start = 0;

    final lowerText = text.toLowerCase();
    while (true) {
      final index = lowerText.indexOf(query, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
      }

      final matchText = text.substring(index, index + query.length);
      spans.add(
        TextSpan(
          text: matchText,
          style: baseStyle.copyWith(
            backgroundColor: const Color(0xFFFBBF24).withValues(alpha: 0.8),
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return Text.rich(TextSpan(children: spans));
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 54),
            const SizedBox(height: 16),
            Text(
              'Cannot read document',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            if (widget.onOpenExternal != null)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6046E8),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: widget.onOpenExternal,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open with External Application'),
              ),
          ],
        ),
      ),
    );
  }
}
