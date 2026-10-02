import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/widgets/announcement_attachments.dart';

void main() {
  group('announcementPreviewKind', () {
    test('treats images, pdfs, and text as previewable', () {
      expect(
        announcementPreviewKind(mimeType: 'image/png', fileName: 'a.png'),
        AnnouncementPreviewKind.image,
      );
      expect(
        announcementPreviewKind(mimeType: '', fileName: '현장.jpg'),
        AnnouncementPreviewKind.image,
      );
      expect(
        announcementPreviewKind(
          mimeType: 'application/octet-stream',
          fileName: '안내.pdf',
        ),
        AnnouncementPreviewKind.pdf,
      );
      expect(
        announcementPreviewKind(mimeType: 'text/plain', fileName: 'memo.txt'),
        AnnouncementPreviewKind.text,
      );
      expect(
        announcementPreviewKind(
          mimeType: 'application/x-hwp',
          fileName: '가정통신문.hwp',
        ),
        AnnouncementPreviewKind.other,
      );
    });
  });

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

  testWidgets('shows an image preview and opens it larger', (tester) async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    await tester.pumpWidget(
      _host(
        PendingAnnouncementAttachments(
          files: [
            PendingMediaFile(
              name: '현장사진.png',
              mimeType: 'image/png',
              bytes: png,
            ),
          ],
          onRemove: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('현장사진.png'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pending-attachment-0')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('pdf attachment offers an in-app preview at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        AnnouncementAttachmentList(
          attachments: [
            AnnouncementAttachment(
              id: 'att-1',
              announcementId: 'a-1',
              storagePath: 'announcements/hs/a/notice.pdf',
              fileName: '2026가을학기_준비물_안내문_가정통신문_최종본.pdf',
              mimeType: 'application/pdf',
              sizeBytes: 2400,
              createdAt: null,
            ),
          ],
          resolveUrl: (_) => 'https://example.com/notice.pdf',
          downloadBytes: (_) async => Uint8List(0),
        ),
      ),
    );

    expect(find.text('눌러서 미리보기 · 3KB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: NestTheme.light(),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(12), child: child),
    ),
  );
}
