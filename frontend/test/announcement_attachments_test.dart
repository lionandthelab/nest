import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/ui/widgets/announcement_attachments.dart';

void main() {
  group('formatAttachmentSize', () {
    test('rounds sub-KB and KB sizes up to the nearest KB', () {
      expect(formatAttachmentSize(0), '0KB');
      expect(formatAttachmentSize(-10), '0KB');
      expect(formatAttachmentSize(500), '1KB');
      expect(formatAttachmentSize(1024), '1KB');
      expect(formatAttachmentSize(1536), '2KB');
    });

    test('formats sizes at or above 1MB with one decimal place', () {
      expect(formatAttachmentSize(1024 * 1024), '1.0MB');
      expect(formatAttachmentSize((1.5 * 1024 * 1024).round()), '1.5MB');
    });
  });
}
