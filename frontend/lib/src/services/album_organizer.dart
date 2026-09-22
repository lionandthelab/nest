import '../models/nest_models.dart';

/// 앨범 화면의 보기 방식.
///
/// 같은 목록을 네 가지로 보여 준다. 사진첩은 "찾으러 오는" 화면과 "훑어보러
/// 오는" 화면이 섞여 있어서, 한 가지 레이아웃으로는 둘 다 나빠진다.
enum AlbumViewMode {
  /// 촘촘한 정사각 격자. 많은 양을 빠르게 훑는다.
  grid,

  /// 날짜 머리글 + 성긴 격자. "언제 찍었나"로 찾을 때.
  timeline,

  /// 학기·수업 카드. "어느 수업 사진인가"로 찾을 때.
  folder,

  /// 한 장씩 크게, 설명까지. 함께 둘러볼 때.
  large,
}

/// 타임라인 뷰의 날짜 구간 하나.
class AlbumDateSection {
  const AlbumDateSection({required this.date, required this.items});

  /// 자정 기준 날짜. 촬영일을 모르는 항목만 모은 구간이면 null이다.
  final DateTime? date;
  final List<GalleryItem> items;
}

/// 내려받기 결과. 플랫폼마다 할 수 있는 일이 달라, 호출부가 이 값을 보고
/// 안내 문구를 고른다.
enum AlbumDownloadOutcome {
  /// 파일 한 장을 저장했다.
  savedSingle,

  /// 여러 장을 zip으로 묶어 저장했다.
  savedZip,

  /// 저장 대신 새 창으로 열었다(모바일·데스크톱 단일 건).
  openedExternally,

  /// 이 플랫폼에서는 여러 장 저장을 지원하지 않는다.
  bulkUnsupported,

  /// 한 번에 내려받을 수 있는 용량을 넘었다.
  tooLarge,

  /// 고른 것이 없다.
  empty,

  failed,
}

/// 한 번에 내려받을 수 있는 총 용량. 브라우저가 zip을 통째로 메모리에 들고
/// 있어야 해서, 넘기면 탭이 죽는다.
const int kAlbumDownloadMaxBytes = 300 * 1024 * 1024;

/// 업로드 한 건이 쓰는 저장 경로 묶음.
class AlbumStoragePaths {
  const AlbumStoragePaths({
    required this.originalPath,
    required this.thumbnailPath,
  });

  /// 원본이 Supabase로 떨어질 때(관리자 Drive 미연결·업로드 실패·용량 초과)
  /// 쓰는 경로. Drive에 올라가면 이 경로는 비워 둔다.
  final String originalPath;

  /// 축소본 경로. 원본이 어디에 있든 썸네일은 항상 Supabase에 둔다 — 그리드가
  /// CDN에서 바로 받아야 하기 때문이다.
  final String thumbnailPath;
}

/// 목록 페이지네이션 커서. 마지막으로 받은 행을 가리킨다.
class AlbumCursor {
  const AlbumCursor({required this.capturedAt, required this.id});

  final DateTime? capturedAt;
  final String id;
}

/// 앨범 목록을 다루는 순수 함수 모음. 컨트롤러·리포지토리·UI가 같은 규칙을
/// 쓰도록 한곳에 모았다.
class AlbumOrganizer {
  const AlbumOrganizer._();

  /// 촬영일 기준 내림차순으로 날짜 구간을 만든다. 구간 안에서도 최신이 먼저다.
  /// 촬영일을 모르는 항목은 맨 뒤 한 구간(`date == null`)으로 모은다.
  static List<AlbumDateSection> groupByDate(List<GalleryItem> items) {
    if (items.isEmpty) {
      return const [];
    }

    final dated = <DateTime, List<GalleryItem>>{};
    final undated = <GalleryItem>[];

    for (final item in items) {
      final captured = item.capturedAt;
      if (captured == null) {
        undated.add(item);
        continue;
      }
      final day = DateTime(captured.year, captured.month, captured.day);
      dated.putIfAbsent(day, () => <GalleryItem>[]).add(item);
    }

    final days = dated.keys.toList()..sort((a, b) => b.compareTo(a));

    final sections = <AlbumDateSection>[
      for (final day in days)
        AlbumDateSection(
          date: day,
          items: dated[day]!
            ..sort((a, b) => b.capturedAt!.compareTo(a.capturedAt!)),
        ),
    ];

    if (undated.isNotEmpty) {
      sections.add(AlbumDateSection(date: null, items: undated));
    }

    return sections;
  }

  /// 관리자 Drive 안에서 파일이 들어갈 경로 조각. 학기 → 수업 → 날짜 순이다.
  /// 이름이 비어 있는 단계는 건너뛴다.
  ///
  /// 엣지 함수도 같은 정규화를 한 번 더 하지만, 클라이언트에서 미리 맞춰 두면
  /// 업로드 전에 사용자에게 "어디에 저장됩니다"를 정확히 보여 줄 수 있다.
  /// 앨범 폴더를 골랐으면 `학기/폴더명` 으로 끝낸다. Drive를 열었을 때 사람이
  /// 찾는 단위는 "가을 소풍"이지 수업명이나 날짜가 아니다. 폴더가 없을 때만
  /// 예전처럼 `학기/수업/날짜` 로 쪼갠다.
  static List<String> driveFolderSegments({
    String? termName,
    String? folderName,
    String? courseName,
    DateTime? capturedAt,
  }) {
    final segments = <String>[];

    final term = sanitizeFolderName(termName ?? '');
    if (term.isNotEmpty) {
      segments.add(term);
    }

    final folder = sanitizeFolderName(folderName ?? '');
    if (folder.isNotEmpty) {
      segments.add(folder);
      return segments;
    }

    final course = sanitizeFolderName(courseName ?? '');
    if (course.isNotEmpty) {
      segments.add(course);
    }

    if (capturedAt != null) {
      segments.add(formatDateFolder(capturedAt));
    }

    return segments;
  }

  /// Drive 폴더명에 못 쓰는 구분자를 하이픈으로 바꾸고 공백을 정리한다.
  static String sanitizeFolderName(String raw) {
    return raw
        .replaceAll(RegExp(r'[/\\]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 업로드 한 건의 저장 경로를 한 키에서 함께 만든다.
  ///
  /// 하이브리드 저장에서는 원본이 Supabase에 없을 수 있어(관리자 Drive로 감)
  /// 썸네일 경로를 원본 경로에서 유도할 수 없다. 둘 다 같은
  /// `{밀리초}_{seed}` 키에서 뽑아, 나중에 짝을 다시 찾을 수 있게 한다.
  static AlbumStoragePaths storagePathsFor({
    required String homeschoolId,
    required String fileName,
    required DateTime now,
    required int seed,
  }) {
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final dot = fileName.lastIndexOf('.');
    final ext = dot <= 0 ? '' : fileName.substring(dot);
    final key = '${now.millisecondsSinceEpoch}_$seed';

    return AlbumStoragePaths(
      originalPath: '$homeschoolId/$month/$key$ext',
      thumbnailPath: '$homeschoolId/$month/thumb/$key.jpg',
    );
  }

  /// 원본 [storagePath]에 대응하는 썸네일 경로. 같은 폴더의 `thumb/` 아래에
  /// 같은 이름으로 두되 확장자는 항상 jpg다 — 썸네일은 영상이든 png든 jpg로
  /// 다시 인코딩하기 때문이다. 경로가 비어 있으면 null.
  static String? thumbnailPathFor(String? storagePath) {
    final path = (storagePath ?? '').trim();
    if (path.isEmpty) {
      return null;
    }

    final slash = path.lastIndexOf('/');
    final dir = slash < 0 ? '' : path.substring(0, slash);
    final name = slash < 0 ? path : path.substring(slash + 1);

    final ext = _extensionOf(name);
    final stem = ext.isEmpty ? name : name.substring(0, name.length - ext.length);

    return dir.isEmpty ? 'thumb/$stem.jpg' : '$dir/thumb/$stem.jpg';
  }

  static String formatDateFolder(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// 내려받을 때 쓸 파일명. [used]에 이미 있는 이름이면 뒤에 번호를 붙이고,
  /// 정해진 이름을 [used]에 넣어 다음 호출과 겹치지 않게 한다.
  static String downloadFileName(
    GalleryItem item, {
    required Set<String> used,
  }) {
    final raw = _preferredName(item);
    final ext = _extensionOf(raw);
    final stem = ext.isEmpty ? raw : raw.substring(0, raw.length - ext.length);

    var candidate = raw;
    var counter = 2;
    while (used.contains(candidate)) {
      candidate = '$stem ($counter)$ext';
      counter += 1;
    }

    used.add(candidate);
    return candidate;
  }

  /// PostgREST의 `or=` 필터. 촬영일이 같은 행이 있어도 건너뛰지 않도록
  /// (captured_at, id) 복합 키로 비교한다.
  static String? keysetFilter(AlbumCursor? cursor) {
    if (cursor == null) {
      return null;
    }

    final capturedAt = cursor.capturedAt;
    if (capturedAt == null) {
      // 촬영일이 비어 있는 꼬리 구간에서는 id만으로 이어 읽는다.
      return 'captured_at.is.null,and(captured_at.is.null,id.lt.${cursor.id})';
    }

    final iso = capturedAt.toUtc().toIso8601String();
    return 'captured_at.lt.$iso,and(captured_at.eq.$iso,id.lt.${cursor.id})';
  }

  /// 보기 방식과 가로 폭에 맞는 열 수.
  ///
  /// 폭은 반드시 `LayoutBuilder`의 `constraints.maxWidth`를 넣는다. 데스크톱
  /// 셸이 왼쪽 레일로 220pt 가까이 먹기 때문에, 화면 전체 폭(MediaQuery)으로
  /// 계산하면 앨범 창에는 늘 한 단계 빽빽한 격자가 나온다.
  static int gridColumnsFor(double width, AlbumViewMode mode) {
    switch (mode) {
      case AlbumViewMode.grid:
        if (width < 480) return 3;
        if (width < 720) return 4;
        if (width < 1080) return 6;
        if (width < 1440) return 8;
        return 10;
      case AlbumViewMode.timeline:
        if (width < 480) return 3;
        if (width < 720) return 4;
        if (width < 1080) return 5;
        return 6;
      case AlbumViewMode.folder:
        if (width < 600) return 2;
        if (width < 900) return 3;
        if (width < 1280) return 4;
        return 5;
      case AlbumViewMode.large:
        return width < 900 ? 1 : 2;
    }
  }

  static String _preferredName(GalleryItem item) {
    final fileName = item.fileName.trim();
    if (fileName.isNotEmpty) {
      return _sanitizeFileName(fileName);
    }

    final storageName = _basename(item.storagePath ?? '');
    final ext = _extensionOf(storageName);

    final title = item.title.trim();
    if (title.isNotEmpty) {
      return _sanitizeFileName('$title$ext');
    }

    if (storageName.isNotEmpty) {
      return _sanitizeFileName(storageName);
    }

    return '${item.id}$ext';
  }

  static String _sanitizeFileName(String raw) {
    return raw.replaceAll(RegExp(r'[/\\:*?"<>|]'), '-').trim();
  }

  static String _basename(String path) {
    if (path.isEmpty) {
      return '';
    }
    final index = path.lastIndexOf('/');
    return index < 0 ? path : path.substring(index + 1);
  }

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) {
      return '';
    }
    final ext = name.substring(dot);
    // "2026-09-22" 처럼 점이 없는데도 잘못 잡히는 경우를 막는다.
    return ext.length <= 6 ? ext : '';
  }
}
