import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/album_organizer.dart';

GalleryItem _item({
  required String id,
  DateTime? capturedAt,
  String mediaType = 'PHOTO',
  String fileName = '',
  String title = '',
}) {
  return GalleryItem(
    id: id,
    title: title,
    description: '',
    mediaType: mediaType,
    driveWebViewLink: null,
    storagePath: 'school/2026-09/$id.jpg',
    classGroupId: null,
    capturedAt: capturedAt,
    termId: null,
    courseId: null,
    thumbnailPath: null,
    fileName: fileName,
    mimeType: 'image/jpeg',
    sizeBytes: 0,
    uploaderUserId: '',
  );
}

void main() {
  group('AlbumOrganizer.groupByDate', () {
    test('버킷을 날짜별로 묶고 최신 날짜를 앞에 둔다', () {
      final sections = AlbumOrganizer.groupByDate([
        _item(id: 'a', capturedAt: DateTime(2026, 9, 20, 9)),
        _item(id: 'b', capturedAt: DateTime(2026, 9, 22, 8)),
        _item(id: 'c', capturedAt: DateTime(2026, 9, 20, 18)),
      ]);

      expect(sections.map((s) => s.date), [
        DateTime(2026, 9, 22),
        DateTime(2026, 9, 20),
      ]);
      expect(sections.first.items.map((i) => i.id), ['b']);
      // 같은 날 안에서도 최신이 먼저다.
      expect(sections.last.items.map((i) => i.id), ['c', 'a']);
    });

    test('촬영일이 없는 항목은 맨 뒤 한 구간으로 모은다', () {
      final sections = AlbumOrganizer.groupByDate([
        _item(id: 'no-date'),
        _item(id: 'dated', capturedAt: DateTime(2026, 9, 22)),
      ]);

      expect(sections.length, 2);
      expect(sections.first.date, DateTime(2026, 9, 22));
      expect(sections.last.date, isNull);
      expect(sections.last.items.single.id, 'no-date');
    });

    test('빈 목록은 빈 구간 목록이 된다', () {
      expect(AlbumOrganizer.groupByDate(const []), isEmpty);
    });
  });

  group('AlbumOrganizer.driveFolderSegments', () {
    test('학기 · 수업 · 날짜 순으로 경로를 만든다', () {
      expect(
        AlbumOrganizer.driveFolderSegments(
          termName: '2026 1학기',
          courseName: '미술',
          capturedAt: DateTime(2026, 9, 22),
        ),
        ['2026 1학기', '미술', '2026-09-22'],
      );
    });

    test('빈 이름은 건너뛴다', () {
      expect(
        AlbumOrganizer.driveFolderSegments(
          termName: '  ',
          courseName: '미술',
          capturedAt: DateTime(2026, 9, 22),
        ),
        ['미술', '2026-09-22'],
      );
    });

    test('폴더명에 못 쓰는 구분자는 하이픈으로 바꾼다', () {
      expect(
        AlbumOrganizer.driveFolderSegments(
          termName: '2026/2학기',
          courseName: r'과학\실험',
          capturedAt: DateTime(2026, 3, 2),
        ),
        ['2026-2학기', '과학-실험', '2026-03-02'],
      );
    });

    test('날짜가 없으면 날짜 단계를 빼고 학기·수업만 남긴다', () {
      expect(
        AlbumOrganizer.driveFolderSegments(termName: '2026 1학기'),
        ['2026 1학기'],
      );
    });
  });

  group('AlbumOrganizer.downloadFileName', () {
    test('원본 파일명이 있으면 그대로 쓴다', () {
      final used = <String>{};
      expect(
        AlbumOrganizer.downloadFileName(
          _item(id: 'a', fileName: '운동회.jpg'),
          used: used,
        ),
        '운동회.jpg',
      );
    });

    test('같은 이름이 겹치면 번호를 붙인다', () {
      final used = <String>{};
      final first = AlbumOrganizer.downloadFileName(
        _item(id: 'a', fileName: '운동회.jpg'),
        used: used,
      );
      final second = AlbumOrganizer.downloadFileName(
        _item(id: 'b', fileName: '운동회.jpg'),
        used: used,
      );

      expect(first, '운동회.jpg');
      expect(second, '운동회 (2).jpg');
    });

    test('파일명이 없으면 제목을 쓰고, 제목도 없으면 저장 경로에서 뽑는다', () {
      final used = <String>{};
      expect(
        AlbumOrganizer.downloadFileName(
          _item(id: 'a', title: '가을 소풍'),
          used: used,
        ),
        '가을 소풍.jpg',
      );
      expect(
        AlbumOrganizer.downloadFileName(_item(id: 'b'), used: used),
        'b.jpg',
      );
    });
  });

  group('AlbumOrganizer.keysetFilter', () {
    test('커서가 없으면 필터도 없다', () {
      expect(AlbumOrganizer.keysetFilter(null), isNull);
    });

    test('촬영일이 같은 행을 건너뛰지 않도록 id까지 비교한다', () {
      final filter = AlbumOrganizer.keysetFilter(
        AlbumCursor(capturedAt: DateTime.utc(2026, 9, 22, 1, 2, 3), id: 'row-9'),
      );

      expect(filter, contains('captured_at.lt.2026-09-22T01:02:03.000Z'));
      expect(
        filter,
        contains('and(captured_at.eq.2026-09-22T01:02:03.000Z,id.lt.row-9)'),
      );
    });
  });

  group('AlbumOrganizer.gridColumnsFor', () {
    test('격자는 480/720/1080/1440에서 열이 늘어난다', () {
      expect(AlbumOrganizer.gridColumnsFor(360, AlbumViewMode.grid), 3);
      expect(AlbumOrganizer.gridColumnsFor(700, AlbumViewMode.grid), 4);
      expect(AlbumOrganizer.gridColumnsFor(1000, AlbumViewMode.grid), 6);
      expect(AlbumOrganizer.gridColumnsFor(1400, AlbumViewMode.grid), 8);
      expect(AlbumOrganizer.gridColumnsFor(1600, AlbumViewMode.grid), 10);
    });

    test('타임라인은 타일이 커서 넓은 화면에서 격자보다 성기다', () {
      expect(AlbumOrganizer.gridColumnsFor(360, AlbumViewMode.timeline), 3);
      expect(AlbumOrganizer.gridColumnsFor(1000, AlbumViewMode.timeline), 5);
      expect(AlbumOrganizer.gridColumnsFor(1400, AlbumViewMode.timeline), 6);
    });

    test('폴더 카드는 세로로 길어 열이 가장 적다', () {
      expect(AlbumOrganizer.gridColumnsFor(360, AlbumViewMode.folder), 2);
      expect(AlbumOrganizer.gridColumnsFor(700, AlbumViewMode.folder), 3);
      expect(AlbumOrganizer.gridColumnsFor(1400, AlbumViewMode.folder), 5);
    });

    test('크게 보기는 900 미만에서 한 열, 그 이상에서 두 열이다', () {
      expect(AlbumOrganizer.gridColumnsFor(700, AlbumViewMode.large), 1);
      expect(AlbumOrganizer.gridColumnsFor(1200, AlbumViewMode.large), 2);
    });
  });
}
