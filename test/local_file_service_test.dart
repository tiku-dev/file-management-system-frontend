import 'package:flutter_test/flutter_test.dart';
import 'package:smart_file/models.dart';
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

  group('FileEntry Popular File Classification', () {
    test('identifies document extensions', () {
      final pdf = FileEntry(
        path: '/storage/doc.pdf',
        name: 'doc.pdf',
        kind: FileEntryKind.file,
        modified: DateTime.now(),
      );
      expect(pdf.isPdf, isTrue);
      expect(pdf.isDocument, isTrue);
      expect(pdf.badgeText, equals('PDF'));

      final word = FileEntry(
        path: '/storage/resume.docx',
        name: 'resume.docx',
        kind: FileEntryKind.file,
        modified: DateTime.now(),
      );
      expect(word.isDocument, isTrue);
      expect(word.isPdf, isFalse);
    });

    test('identifies Excel spreadsheets and CSV', () {
      final xlsx = FileEntry(
        path: '/storage/finances.xlsx',
        name: 'finances.xlsx',
        kind: FileEntryKind.file,
        modified: DateTime.now(),
      );
      expect(xlsx.isExcel, isTrue);
      expect(xlsx.isDocument, isFalse);

      final csv = FileEntry(
        path: '/storage/data.csv',
        name: 'data.csv',
        kind: FileEntryKind.file,
        modified: DateTime.now(),
      );
      expect(csv.isExcel, isTrue);
    });

    test('identifies PowerPoint presentations', () {
      final ppt = FileEntry(
        path: '/storage/deck.pptx',
        name: 'deck.pptx',
        kind: FileEntryKind.file,
        modified: DateTime.now(),
      );
      expect(ppt.isPpt, isTrue);
      expect(ppt.isExcel, isFalse);
    });

    test('identifies APK packages', () {
      final apk = FileEntry(
        path: '/storage/app.apk',
        name: 'app.apk',
        kind: FileEntryKind.file,
        modified: DateTime.now(),
      );
      expect(apk.isApk, isTrue);
      expect(apk.category, equals(FileCategory.apks));
    });

    test('identifies image, audio, video and readable text files', () {
      final img = FileEntry(
        path: '/storage/photo.jpg',
        name: 'photo.jpg',
        kind: FileEntryKind.file,
        modified: DateTime.now(),
      );
      expect(img.isImage, isTrue);

      final audio = FileEntry(
        path: '/storage/song.mp3',
        name: 'song.mp3',
        kind: FileEntryKind.file,
        modified: DateTime.now(),
      );
      expect(audio.isAudio, isTrue);

      final video = FileEntry(
        path: '/storage/movie.mp4',
        name: 'movie.mp4',
        kind: FileEntryKind.file,
        modified: DateTime.now(),
      );
      expect(video.isVideo, isTrue);

      final txt = FileEntry(
        path: '/storage/notes.txt',
        name: 'notes.txt',
        kind: FileEntryKind.file,
        modified: DateTime.now(),
      );
      expect(txt.isTextReadable, isTrue);
    });
  });
}
