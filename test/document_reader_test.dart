import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_file/models.dart';
import 'package:smart_file/services/document_parser_service.dart';

void main() {
  group('Document Classification & Model Getters', () {
    test('identifies readable documents correctly', () {
      final pdf = FileEntry(
        path: '/storage/sample.pdf',
        name: 'sample.pdf',
        kind: FileEntryKind.file,
        modified: DateTime.now(),
      );
      expect(pdf.isPdf, isTrue);
      expect(pdf.isDocumentReadable, isTrue);

      final docx = FileEntry(
        path: '/storage/report.docx',
        name: 'report.docx',
        kind: FileEntryKind.file,
        modified: DateTime.now(),
      );
      expect(docx.isDocx, isTrue);
      expect(docx.isDocumentReadable, isTrue);

      final txt = FileEntry(
        path: '/storage/notes.txt',
        name: 'notes.txt',
        kind: FileEntryKind.file,
        modified: DateTime.now(),
      );
      expect(txt.isTextReadable, isTrue);
      expect(txt.isDocumentReadable, isTrue);

      final markdown = FileEntry(
        path: '/storage/README.md',
        name: 'README.md',
        kind: FileEntryKind.file,
        modified: DateTime.now(),
      );
      expect(markdown.isTextReadable, isTrue);
      expect(markdown.isDocumentReadable, isTrue);

      final img = FileEntry(
        path: '/storage/photo.jpg',
        name: 'photo.jpg',
        kind: FileEntryKind.file,
        modified: DateTime.now(),
      );
      expect(img.isDocumentReadable, isFalse);
    });
  });

  group('DocumentParserService Text & PDF Processing', () {
    test('calculates document reading statistics correctly', () {
      const sampleText =
          'SmartFile is a privacy-first AI file manager designed for Windows and Android.\n'
          'It provides deep local file inspection, intuitive categorization, and in-app document reading.\n'
          'Users can read PDF documents, Word documents, and text files without third-party apps.';

      final result = DocumentParseResult.fromText(sampleText);
      expect(result.wordCount, greaterThan(20));
      expect(result.charCount, equals(sampleText.length));
      expect(result.lineCount, equals(3));
      expect(result.estimatedReadMinutes, equals(1));
    });

    test('creates and verifies valid PDF document via getOrCreatePdfFile', () async {
      final tempFile = await DocumentParserService.getOrCreatePdfFile(
        'non_existent_mock_file.pdf',
        'Test_Doc.pdf',
      );

      expect(await tempFile.exists(), isTrue);
      expect(await tempFile.length(), greaterThan(100));

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (_) {}
    });

    test('parses text files with UTF-8 encoding safely', () async {
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/test_reading_note.txt');
      await file.writeAsString('Line 1: Hello World\nLine 2: SmartFile In-App Document Reader');

      final result = await DocumentParserService.parseTextFile(file.path);
      expect(result.error, isNull);
      expect(result.text.contains('SmartFile In-App Document Reader'), isTrue);
      expect(result.lineCount, equals(2));

      await file.delete();
    });
  });
}
