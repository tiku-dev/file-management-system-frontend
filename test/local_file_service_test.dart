import 'package:flutter_test/flutter_test.dart';
import 'package:smart_file/services/local_file_service.dart';

void main() {
  group('LocalFileService.normalizePath', () {
    test('normalizes raw SAF tree encoded path', () {
      final normalized = LocalFileService.normalizePath('primary%3AVidMate%2FDownload');
      expect(normalized.contains('VidMate'), isTrue);
      expect(normalized.startsWith('/storage/emulated/0'), isTrue);
    });

    test('normalizes primary colon notation', () {
      final normalized = LocalFileService.normalizePath('primary:Download');
      expect(normalized, equals('/storage/emulated/0/Download'));
    });

    test('normalizes SAF URI format', () {
      final normalized = LocalFileService.normalizePath(
        'content://com.android.externalstorage.documents/tree/primary%3APictures',
      );
      expect(normalized, equals('/storage/emulated/0/Pictures'));
    });

    test('preserves absolute Linux/Android path', () {
      final normalized = LocalFileService.normalizePath('/storage/emulated/0/Documents');
      expect(normalized, equals('/storage/emulated/0/Documents'));
    });
  });
}
