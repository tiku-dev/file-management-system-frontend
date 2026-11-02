import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Rect;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

enum DocxParagraphType {
  heading1,
  heading2,
  heading3,
  bullet,
  numbered,
  body,
}

class DocxParagraph {
  const DocxParagraph({
    required this.text,
    this.type = DocxParagraphType.body,
    this.isBold = false,
  });

  final String text;
  final DocxParagraphType type;
  final bool isBold;
}

class DocumentParseResult {
  DocumentParseResult({
    required this.text,
    this.docxParagraphs = const [],
    this.wordCount = 0,
    this.charCount = 0,
    this.lineCount = 0,
    this.estimatedReadMinutes = 1,
    this.isTruncated = false,
    this.error,
  });

  final String text;
  final List<DocxParagraph> docxParagraphs;
  final int wordCount;
  final int charCount;
  final int lineCount;
  final int estimatedReadMinutes;
  final bool isTruncated;
  final String? error;

  factory DocumentParseResult.fromText(String rawText, {bool isTruncated = false}) {
    final trimmed = rawText.trim();
    final words = trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
    final chars = rawText.length;
    final lines = rawText.split('\n').length;
    final minutes = (words / 200).ceil().clamp(1, 9999);

    return DocumentParseResult(
      text: rawText,
      wordCount: words,
      charCount: chars,
      lineCount: lines,
      estimatedReadMinutes: minutes,
      isTruncated: isTruncated,
    );
  }

  factory DocumentParseResult.withError(String message) {
    return DocumentParseResult(
      text: '',
      error: message,
    );
  }
}

class DocumentParserService {
  static const int maxTextFileSizeBytes = 2 * 1024 * 1024; // 2 MB preview limit

  /// Ensures a PDF file exists, or creates a rich interactive demo PDF for showcase entries.
  static Future<File> getOrCreatePdfFile(String filePath, String fileName) async {
    final file = File(filePath);
    if (await file.exists()) {
      return file;
    }

    // Generate demo document for missing or showcase files
    final tempDir = Directory.systemTemp;
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final demoFile = File('${tempDir.path}/smartfile_demo_$safeName');
    if (await demoFile.exists()) {
      return demoFile;
    }

    final document = PdfDocument();
    
    // Page 1
    final page1 = document.pages.add();
    final fontHeader = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
    final fontSub = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
    final fontBody = PdfStandardFont(PdfFontFamily.helvetica, 11);

    page1.graphics.drawString(
      fileName.isNotEmpty ? fileName : 'Project Brief & Specifications',
      fontHeader,
      bounds: const Rect.fromLTWH(0, 20, 500, 30),
    );

    page1.graphics.drawString(
      'Document Type: PDF Specification Report\n'
      'Status: Approved and Synchronized Locally\n'
      'Privacy Security Level: Local Encryption Only\n\n'
      '1. Overview & Document Reading Capabilities\n'
      'Welcome to the SmartFile In-App Document Reader! This reader allows you to seamlessly review, navigate, and search PDF and office documents directly inside SmartFile.\n\n'
      'Key Interactive Features Supported:\n'
      '• Multi-page smooth scrolling and navigation\n'
      '• Direct page jumping via the page counter pill\n'
      '• Zoom in (+), Zoom out (-), and 100% Fit Width controls\n'
      '• Real-time in-document text search with match counts and next/previous navigation\n'
      '• Night Mode / Inverted Reading for comfortable viewing in low light\n'
      '• Full privacy: All document rendering runs completely on your local device.\n\n'
      'Try searching for "privacy", "security", or "smartfile" using the Search button in the toolbar above.',
      fontBody,
      bounds: const Rect.fromLTWH(0, 60, 500, 450),
    );

    // Page 2
    final page2 = document.pages.add();
    page2.graphics.drawString(
      'Section 2: Privacy Architecture & Supported Formats',
      fontSub,
      bounds: const Rect.fromLTWH(0, 20, 500, 30),
    );

    page2.graphics.drawString(
      'Document Privacy Assurance:\n'
      'SmartFile is built around a zero-knowledge, local-first architecture. When you inspect or read documents:\n'
      '• Files are parsed on-device.\n'
      '• No text or confidential file data is transmitted to external servers.\n'
      '• High rendering performance ensures instant loading even for multi-megabyte files.\n\n'
      'Supported Document Types in SmartFile:\n'
      '1. PDF Documents (.pdf)\n'
      '2. Microsoft Word Documents (.docx)\n'
      '3. Markdown and Plain Text (.md, .txt, .log)\n'
      '4. Code and Structured Data (.json, .csv, .xml, .yaml, .dart, .py, .sql)\n\n'
      'End of Document — Page 2 of 2.',
      fontBody,
      bounds: const Rect.fromLTWH(0, 60, 500, 450),
    );

    final bytes = await document.save();
    document.dispose();
    await demoFile.writeAsBytes(bytes);
    return demoFile;
  }

  /// Parses text from a file (.txt, .md, .log, .json, .csv, code, etc.)
  static Future<DocumentParseResult> parseTextFile(String filePath, {String fileName = ''}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        // Fallback for demo files
        return _generateSampleTextDoc(fileName.isNotEmpty ? fileName : 'Document');
      }

      final fileLength = await file.length();
      if (fileLength == 0) {
        return DocumentParseResult.fromText('');
      }

      bool isTruncated = false;
      List<int> bytes;
      if (fileLength > maxTextFileSizeBytes) {
        // Read only first chunk
        final stream = file.openRead(0, maxTextFileSizeBytes);
        bytes = await stream.expand((chunk) => chunk).toList();
        isTruncated = true;
      } else {
        bytes = await file.readAsBytes();
      }

      String content;
      try {
        content = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        content = latin1.decode(bytes);
      }

      if (isTruncated) {
        content = '$content\n\n--- [Document preview truncated: file exceeds 2 MB] ---';
      }

      return DocumentParseResult.fromText(content, isTruncated: isTruncated);
    } catch (e) {
      return DocumentParseResult.withError('Failed to read file: $e');
    }
  }

  /// Parses text and structure from a Word .docx file
  static Future<DocumentParseResult> parseDocxFile(String filePath, {String fileName = ''}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        // Fallback for demo showcase files
        final paragraphs = _getSampleDocxParagraphs(fileName.isNotEmpty ? fileName : 'Word Document');
        final fullText = paragraphs.map((p) => p.text).join('\n\n');
        return DocumentParseResult(
          text: fullText,
          docxParagraphs: paragraphs,
          wordCount: fullText.split(RegExp(r'\s+')).length,
          charCount: fullText.length,
          lineCount: paragraphs.length,
          estimatedReadMinutes: 2,
        );
      }

      final bytes = await file.readAsBytes();
      return await compute(_extractDocxContent, bytes);
    } catch (e) {
      return DocumentParseResult.withError('Unable to parse DOCX document: $e');
    }
  }

  static DocumentParseResult _extractDocxContent(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentFile = archive.findFile('word/document.xml');

      if (documentFile == null) {
        return DocumentParseResult.withError('Invalid DOCX format: word/document.xml missing');
      }

      final contentBytes = documentFile.content as List<int>;
      final xmlString = utf8.decode(contentBytes, allowMalformed: true);
      final document = XmlDocument.parse(xmlString);

      final paragraphs = <DocxParagraph>[];
      final fullTextBuffer = StringBuffer();

      // Find all paragraph nodes <w:p>
      final pNodes = document.findAllElements('w:p');
      for (final pNode in pNodes) {
        // Extract paragraph style
        DocxParagraphType pType = DocxParagraphType.body;
        final pStyle = pNode.findElements('w:pPr').expand((pr) => pr.findElements('w:pStyle')).firstOrNull;
        if (pStyle != null) {
          final val = pStyle.getAttribute('w:val')?.toLowerCase() ?? '';
          if (val.contains('heading1') || val == '1' || val == 'title') {
            pType = DocxParagraphType.heading1;
          } else if (val.contains('heading2') || val == '2' || val == 'subtitle') {
            pType = DocxParagraphType.heading2;
          } else if (val.contains('heading3') || val == '3') {
            pType = DocxParagraphType.heading3;
          }
        }

        // Check if list/bullet item
        final numPr = pNode.findElements('w:pPr').expand((pr) => pr.findElements('w:numPr')).firstOrNull;
        if (numPr != null && pType == DocxParagraphType.body) {
          pType = DocxParagraphType.bullet;
        }

        // Collect all text inside <w:r> -> <w:t>
        final pTextBuffer = StringBuffer();
        bool hasBold = false;

        for (final rNode in pNode.findElements('w:r')) {
          final isBoldRun = rNode.findElements('w:rPr').any((rPr) => rPr.findElements('w:b').isNotEmpty);
          if (isBoldRun) hasBold = true;

          for (final tNode in rNode.findElements('w:t')) {
            pTextBuffer.write(tNode.innerText);
          }
        }

        final pText = pTextBuffer.toString().trim();
        if (pText.isNotEmpty) {
          paragraphs.add(DocxParagraph(
            text: pText,
            type: pType,
            isBold: hasBold,
          ));
          fullTextBuffer.writeln(pText);
        }
      }

      final fullText = fullTextBuffer.toString();
      final words = fullText.isEmpty ? 0 : fullText.split(RegExp(r'\s+')).length;
      final chars = fullText.length;
      final lines = fullText.split('\n').length;
      final minutes = (words / 200).ceil().clamp(1, 9999);

      return DocumentParseResult(
        text: fullText,
        docxParagraphs: paragraphs,
        wordCount: words,
        charCount: chars,
        lineCount: lines,
        estimatedReadMinutes: minutes,
      );
    } catch (e) {
      return DocumentParseResult.withError('Failed to extract document contents: $e');
    }
  }

  static DocumentParseResult _generateSampleTextDoc(String title) {
    final sample = '# $title\n\n'
        'SmartFile In-App Document Reader\n'
        '===============================\n\n'
        'This file preview is rendered directly inside SmartFile.\n\n'
        'Features available in this reader:\n'
        '- In-document text search with live highlight navigation\n'
        '- Adjustable font size (A- / A+)\n'
        '- Customizable reading tone: Auto, Clean Light, Warm Sepia, Dark Slate, or OLED Black\n'
        '- Font style switcher: Modern Sans, Classic Serif, or Monospace code mode\n'
        '- Line numbers toggle\n'
        '- One-tap Copy All text\n\n'
        'Security & Privacy:\n'
        'All reading and text parsing operations are performed locally on your device without transmitting data.';
    return DocumentParseResult.fromText(sample);
  }

  static List<DocxParagraph> _getSampleDocxParagraphs(String title) {
    return [
      DocxParagraph(text: title, type: DocxParagraphType.heading1),
      const DocxParagraph(
        text: 'Executive Summary & Project Report',
        type: DocxParagraphType.heading2,
      ),
      const DocxParagraph(
        text:
            'This Microsoft Word (.docx) document has been parsed and rendered in the SmartFile in-app reader.',
        type: DocxParagraphType.body,
      ),
      const DocxParagraph(
        text: 'Key Reader Features for Office Documents:',
        type: DocxParagraphType.heading3,
      ),
      const DocxParagraph(
        text: 'Custom Typography: Switch between Modern Sans, Classic Serif, or Monospace fonts.',
        type: DocxParagraphType.bullet,
      ),
      const DocxParagraph(
        text: 'Reading Tones: Choose Light, Warm Sepia, Dark Slate, or OLED Black.',
        type: DocxParagraphType.bullet,
      ),
      const DocxParagraph(
        text: 'Font Resizing: Adjust text size dynamically for maximum reading comfort.',
        type: DocxParagraphType.bullet,
      ),
      const DocxParagraph(
        text: 'In-Document Search: Live search query highlighting with jump navigation.',
        type: DocxParagraphType.bullet,
      ),
      const DocxParagraph(
        text: 'Line Numbers & Statistics: View estimated read times, word count, and line numbering.',
        type: DocxParagraphType.bullet,
      ),
      const DocxParagraph(
        text: 'Security & Integrity Notice',
        type: DocxParagraphType.heading2,
      ),
      const DocxParagraph(
        text:
            'All text extraction and XML processing executes strictly locally within your application session. Enjoy distraction-free document reading.',
        type: DocxParagraphType.body,
      ),
    ];
  }
}
