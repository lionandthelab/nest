import 'package:flutter/material.dart';

import '../../nest_theme.dart';

/// 내보내기(PNG/엑셀) 전용 표 데이터 모델과 렌더러.
///
/// 편집용 보드(`_buildEditableGrid`)는 드래그 타깃·메뉴·충돌 배지 때문에
/// 셀이 크고 글씨가 작아 내보낸 이미지의 가독성이 떨어진다. 여기서는
/// 같은 데이터를 "읽기 위한 표"로 다시 그려, 글자를 키우고 빈 공간을 줄인다.
/// 엑셀 시트도 아래 모델을 그대로 사용하므로 PNG와 내용이 항상 일치한다.

/// 표 한 칸에 들어가는 수업 하나.
class TimetableExportEntry {
  const TimetableExportEntry({
    required this.title,
    this.subtitle = '',
    this.location = '',
    this.teachers = const <String>[],
  });

  /// 대표 이름(시간표는 과목명, 교실 상황표는 반 이름).
  final String title;

  /// 보조 이름(교실 상황표의 과목명 등). 비어 있으면 표시하지 않는다.
  final String subtitle;

  /// 교실명. 열 자체가 교실인 표에서는 비워 둔다.
  final String location;

  /// '주 홍길동' 형태로 이미 가공된 교사 라벨 목록.
  final List<String> teachers;

  String get teacherLabel => teachers.join(', ');

  /// 엑셀 셀 한 칸에 넣을 여러 줄 텍스트.
  String toCellText() {
    final lines = <String>[title.trim()];
    if (subtitle.trim().isNotEmpty) {
      lines.add(subtitle.trim());
    }
    if (location.trim().isNotEmpty) {
      lines.add(location.trim());
    }
    if (teachers.isNotEmpty) {
      lines.add(teacherLabel);
    }
    return lines.where((line) => line.isNotEmpty).join('\n');
  }
}

/// 한 시간대(행). [entriesByColumn]의 길이는 표의 열 개수와 같다.
class TimetableExportPeriod {
  const TimetableExportPeriod({
    required this.start,
    required this.end,
    required this.entriesByColumn,
  });

  /// 'HH:mm' 형식 시작 시각.
  final String start;

  /// 'HH:mm' 형식 종료 시각.
  final String end;

  final List<List<TimetableExportEntry>> entriesByColumn;

  bool get isEmpty => entriesByColumn.every((entries) => entries.isEmpty);

  String get label => '$start-$end';
}

/// 표를 나누는 구역. 교실 상황표는 요일마다 한 구역, 반 시간표는 구역 없이 하나.
class TimetableExportSection {
  const TimetableExportSection({this.title = '', required this.periods});

  final String title;
  final List<TimetableExportPeriod> periods;
}

/// 내보낼 표 전체.
class TimetableExportTable {
  const TimetableExportTable({
    required this.title,
    required this.columnLabels,
    required this.sections,
    this.subtitle = '',
    this.columnHeaderLabel = '구분',
    this.entryTitleLabel = '과목',
    this.entrySubtitleLabel = '',
    this.sectionHeaderLabel = '구분',
  });

  /// 문서 제목. 예: '2학기 시간표 · 3학년'.
  final String title;

  /// 제목 아래 보조 설명(학기 기간, 내보낸 시각 등).
  final String subtitle;

  /// 열 머리글의 종류. 목록 시트 헤더에 그대로 쓰인다. 예: '요일', '교실'.
  final String columnHeaderLabel;

  /// 각 열의 이름. 예: ['월요일', '화요일', ...] 또는 ['3.믿음', '304호', ...].
  final List<String> columnLabels;

  /// 구역(요일 등) 열의 이름. 구역이 없으면 목록 시트에서 생략된다.
  final String sectionHeaderLabel;

  /// 목록 시트에서 [TimetableExportEntry.title]에 붙일 헤더 이름.
  final String entryTitleLabel;

  /// 목록 시트에서 [TimetableExportEntry.subtitle]에 붙일 헤더 이름.
  /// 비어 있으면 해당 열을 만들지 않는다.
  final String entrySubtitleLabel;

  final List<TimetableExportSection> sections;

  int get columnCount => columnLabels.length;

  bool get hasSectionTitles =>
      sections.any((section) => section.title.trim().isNotEmpty);

  /// 표에 실제로 들어간 수업이 하나라도 있는지.
  bool get hasEntries => sections.any(
    (section) => section.periods.any((period) => !period.isEmpty),
  );

  /// 빈 시간대를 숨긴 뒤의 구역 목록. 구역 안이 모두 비면 구역도 제거한다.
  List<TimetableExportSection> visibleSections({
    required bool hideEmptyPeriods,
  }) {
    if (!hideEmptyPeriods) {
      return sections
          .where((section) => section.periods.isNotEmpty)
          .toList(growable: false);
    }

    final result = <TimetableExportSection>[];
    for (final section in sections) {
      final periods = section.periods
          .where((period) => !period.isEmpty)
          .toList(growable: false);
      if (periods.isEmpty) {
        continue;
      }
      result.add(
        TimetableExportSection(title: section.title, periods: periods),
      );
    }
    return result;
  }

  /// 모든 수업을 (구역, 시간대, 열) 순서로 펼친 목록. 엑셀 목록 시트용.
  List<TimetableExportFlatRow> flatten({required bool hideEmptyPeriods}) {
    final rows = <TimetableExportFlatRow>[];
    for (final section in visibleSections(hideEmptyPeriods: hideEmptyPeriods)) {
      for (final period in section.periods) {
        for (var index = 0; index < period.entriesByColumn.length; index++) {
          final columnLabel = index < columnLabels.length
              ? columnLabels[index]
              : '';
          for (final entry in period.entriesByColumn[index]) {
            rows.add(
              TimetableExportFlatRow(
                sectionTitle: section.title,
                start: period.start,
                end: period.end,
                columnLabel: columnLabel,
                entry: entry,
              ),
            );
          }
        }
      }
    }
    return rows;
  }
}

/// 엑셀 목록 시트의 한 줄.
class TimetableExportFlatRow {
  const TimetableExportFlatRow({
    required this.sectionTitle,
    required this.start,
    required this.end,
    required this.columnLabel,
    required this.entry,
  });

  final String sectionTitle;
  final String start;
  final String end;
  final String columnLabel;
  final TimetableExportEntry entry;
}

/// 표 격자선 색. 엑셀 서식(styles.xml)의 테두리 색과 맞춘다.
const Color _kGridLine = Color(0xFFE3D2C7);

/// 표 바깥 테두리 두께. 보드 전체 너비 계산에 그대로 반영해야
/// 안쪽 행(Row)이 1~2px 넘쳐 잘리지 않는다.
const double _kTableBorderWidth = 1.2;

/// 내보내기 글자 크기 프리셋.
enum TimetableExportScale {
  normal('보통', 1.0),
  large('크게', 1.25),
  extraLarge('아주 크게', 1.55);

  const TimetableExportScale(this.label, this.factor);

  final String label;
  final double factor;
}

/// [TimetableExportTable]을 "읽기 위한" 표로 그린다. PNG 캡처 대상이자
/// 내보내기 다이얼로그의 미리보기로 그대로 재사용된다.
class TimetableExportBoard extends StatelessWidget {
  const TimetableExportBoard({
    super.key,
    required this.table,
    required this.scale,
    required this.hideEmptyPeriods,
    this.repaintKey,
  });

  final TimetableExportTable table;
  final TimetableExportScale scale;
  final bool hideEmptyPeriods;

  /// PNG 캡처용 경계 키. 미리보기에서도 같은 위젯을 쓰기 때문에
  /// 캡처가 필요한 쪽에서만 전달한다.
  final GlobalKey? repaintKey;

  static const double _baseTimeWidth = 112;
  static const double _baseColumnWidth = 184;
  static const double _minColumnWidth = 112;
  static const double _maxBoardWidth = 1720;

  @override
  Widget build(BuildContext context) {
    final factor = scale.factor;
    final sections = table.visibleSections(hideEmptyPeriods: hideEmptyPeriods);
    final columnCount = table.columnCount;

    final timeWidth = _baseTimeWidth * factor;
    var columnWidth = _baseColumnWidth * factor;
    if (columnCount > 0) {
      final needed = timeWidth + columnCount * columnWidth;
      final maxWidth = _maxBoardWidth * factor;
      if (needed > maxWidth) {
        columnWidth = ((maxWidth - timeWidth) / columnCount).clamp(
          _minColumnWidth * factor,
          _baseColumnWidth * factor,
        );
      }
    }
    // 표 바깥 테두리까지 더해야 안쪽 행이 넘치지 않는다.
    final boardWidth =
        timeWidth + columnCount * columnWidth + _kTableBorderWidth * 2;
    final padding = 22.0 * factor;

    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        width: boardWidth + padding * 2,
        padding: EdgeInsets.all(padding),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              table.title,
              style: TextStyle(
                fontSize: 26 * factor,
                fontWeight: FontWeight.w800,
                color: NestColors.deepWood,
                height: 1.2,
              ),
            ),
            if (table.subtitle.trim().isNotEmpty) ...[
              SizedBox(height: 4 * factor),
              Text(
                table.subtitle,
                style: TextStyle(
                  fontSize: 14 * factor,
                  color: NestColors.deepWood.withValues(alpha: 0.6),
                  height: 1.3,
                ),
              ),
            ],
            SizedBox(height: 14 * factor),
            if (sections.isEmpty)
              _EmptyNotice(factor: factor)
            else
              _BoardTable(
                table: table,
                sections: sections,
                factor: factor,
                timeWidth: timeWidth,
                columnWidth: columnWidth,
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice({required this.factor});

  final double factor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18 * factor),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * factor),
        color: NestColors.creamyWhite,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Text(
        '내보낼 수업이 없습니다.',
        style: TextStyle(
          fontSize: 16 * factor,
          color: NestColors.deepWood.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _BoardTable extends StatelessWidget {
  const _BoardTable({
    required this.table,
    required this.sections,
    required this.factor,
    required this.timeWidth,
    required this.columnWidth,
  });

  final TimetableExportTable table;
  final List<TimetableExportSection> sections;
  final double factor;
  final double timeWidth;
  final double columnWidth;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[_buildHeaderRow()];

    for (final section in sections) {
      if (section.title.trim().isNotEmpty) {
        rows.add(_buildSectionRow(section.title));
      }
      for (final period in section.periods) {
        rows.add(_buildPeriodRow(period));
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _kGridLine, width: _kTableBorderWidth),
        borderRadius: BorderRadius.circular(10 * factor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }

  Widget _buildHeaderRow() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cell(
            width: timeWidth,
            background: NestColors.roseMist,
            showTopBorder: false,
            showLeftBorder: false,
            child: Text('시간', textAlign: TextAlign.center, style: _headerStyle),
          ),
          ...table.columnLabels.map(
            (label) => _cell(
              width: columnWidth,
              background: NestColors.roseMist,
              showTopBorder: false,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: _headerStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionRow(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 12 * factor,
        vertical: 7 * factor,
      ),
      decoration: BoxDecoration(
        color: NestColors.roseMist.withValues(alpha: 0.55),
        border: const Border(top: BorderSide(color: _kGridLine)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18 * factor,
          fontWeight: FontWeight.w800,
          color: NestColors.deepWood,
        ),
      ),
    );
  }

  Widget _buildPeriodRow(TimetableExportPeriod period) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cell(
            width: timeWidth,
            background: NestColors.creamyWhite,
            showLeftBorder: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  period.start,
                  textAlign: TextAlign.center,
                  style: _timeStyle,
                ),
                Text(
                  period.end,
                  textAlign: TextAlign.center,
                  style: _timeStyle.copyWith(
                    fontWeight: FontWeight.w500,
                    color: NestColors.deepWood.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          ...List<Widget>.generate(table.columnCount, (index) {
            final entries = index < period.entriesByColumn.length
                ? period.entriesByColumn[index]
                : const <TimetableExportEntry>[];
            return _cell(
              width: columnWidth,
              background: Colors.white,
              child: entries.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (var i = 0; i < entries.length; i++) ...[
                          if (i > 0) SizedBox(height: 8 * factor),
                          _buildEntry(entries[i]),
                        ],
                      ],
                    ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEntry(TimetableExportEntry entry) {
    final metaLines = <String>[
      if (entry.subtitle.trim().isNotEmpty) entry.subtitle.trim(),
      if (entry.location.trim().isNotEmpty) entry.location.trim(),
      if (entry.teachers.isNotEmpty) entry.teacherLabel,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          entry.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20 * factor,
            fontWeight: FontWeight.w800,
            color: NestColors.deepWood,
            height: 1.2,
          ),
        ),
        for (final line in metaLines) ...[
          SizedBox(height: 3 * factor),
          Text(
            line,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15 * factor,
              fontWeight: FontWeight.w500,
              color: NestColors.deepWood.withValues(alpha: 0.72),
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }

  Widget _cell({
    required double width,
    required Color background,
    required Widget child,
    bool showTopBorder = true,
    bool showLeftBorder = true,
  }) {
    const line = BorderSide(color: _kGridLine);
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(
        horizontal: 8 * factor,
        vertical: 10 * factor,
      ),
      constraints: BoxConstraints(minHeight: 46 * factor),
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: showTopBorder ? line : BorderSide.none,
          left: showLeftBorder ? line : BorderSide.none,
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  TextStyle get _headerStyle => TextStyle(
    fontSize: 18 * factor,
    fontWeight: FontWeight.w800,
    color: NestColors.deepWood,
  );

  TextStyle get _timeStyle => TextStyle(
    fontSize: 16 * factor,
    fontWeight: FontWeight.w700,
    color: NestColors.deepWood,
    height: 1.25,
  );
}
