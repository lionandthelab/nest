import 'dart:math' as math;
import 'dart:typed_data';

import '../../../services/xlsx_writer.dart';
import 'timetable_export_board.dart';

/// [TimetableExportTable]을 두 시트짜리 .xlsx 워크북으로 만든다.
///
/// - **표** 시트: PNG와 같은 격자 배치. 인쇄·배포·눈으로 확인하는 용도.
/// - **목록** 시트: 수업 한 줄씩 펼친 표. 정렬·필터·일괄 수정에 적합.
///
/// 두 시트 모두 같은 [TimetableExportTable]에서 나오므로 PNG와 내용이 어긋나지
/// 않는다. [hideEmptyPeriods]는 미리보기/PNG와 동일한 옵션을 그대로 받는다.
Uint8List buildTimetableWorkbook(
  TimetableExportTable table, {
  required bool hideEmptyPeriods,
}) {
  final workbook = XlsxWorkbook();
  _buildGridSheet(workbook, table, hideEmptyPeriods: hideEmptyPeriods);
  _buildListSheet(workbook, table, hideEmptyPeriods: hideEmptyPeriods);
  return workbook.encode();
}

void _buildGridSheet(
  XlsxWorkbook workbook,
  TimetableExportTable table, {
  required bool hideEmptyPeriods,
}) {
  final sections = table.visibleSections(hideEmptyPeriods: hideEmptyPeriods);
  final columnCount = table.columnCount;
  final lastColumn = columnCount; // 0번은 시간 열

  final sheet = workbook.addSheet(
    '표',
    columnWidths: <double>[14, ...List<double>.filled(columnCount, 22)],
    freezeRows: 4,
    freezeColumns: 1,
    showGridLines: false,
  );

  sheet.addRow(<XlsxCell>[
    XlsxCell(table.title, style: XlsxStyle.title),
    ...List<XlsxCell>.filled(
      columnCount,
      const XlsxCell.blank(style: XlsxStyle.title),
    ),
  ], height: 34);
  sheet.mergeLastRow(startColumn: 0, endColumn: lastColumn);

  sheet.addRow(<XlsxCell>[
    XlsxCell(table.subtitle, style: XlsxStyle.caption),
    ...List<XlsxCell>.filled(
      columnCount,
      const XlsxCell.blank(style: XlsxStyle.caption),
    ),
  ], height: 20);
  sheet.mergeLastRow(startColumn: 0, endColumn: lastColumn);

  sheet.addBlankRow();

  sheet.addRow(<XlsxCell>[
    const XlsxCell('시간', style: XlsxStyle.header),
    ...table.columnLabels.map(
      (label) => XlsxCell(label, style: XlsxStyle.header),
    ),
  ], height: 26);

  for (final section in sections) {
    if (section.title.trim().isNotEmpty) {
      sheet.addRow(<XlsxCell>[
        XlsxCell(section.title, style: XlsxStyle.sectionCell),
        ...List<XlsxCell>.filled(
          columnCount,
          const XlsxCell.blank(style: XlsxStyle.sectionCell),
        ),
      ], height: 24);
      sheet.mergeLastRow(startColumn: 0, endColumn: lastColumn);
    }

    for (final period in section.periods) {
      final cells = <XlsxCell>[
        XlsxCell(period.label, style: XlsxStyle.timeCell),
      ];
      var maxLines = 1;
      for (var index = 0; index < columnCount; index++) {
        final entries = index < period.entriesByColumn.length
            ? period.entriesByColumn[index]
            : const <TimetableExportEntry>[];
        if (entries.isEmpty) {
          cells.add(const XlsxCell.blank(style: XlsxStyle.mutedCell));
          continue;
        }
        final text = entries.map((entry) => entry.toCellText()).join('\n\n');
        maxLines = math.max(maxLines, '\n'.allMatches(text).length + 1);
        cells.add(XlsxCell(text, style: XlsxStyle.contentCell));
      }
      sheet.addRow(cells, height: math.max(22, 15.5 * maxLines + 7));
    }
  }
}

void _buildListSheet(
  XlsxWorkbook workbook,
  TimetableExportTable table, {
  required bool hideEmptyPeriods,
}) {
  final rows = table.flatten(hideEmptyPeriods: hideEmptyPeriods);

  final showSection = table.hasSectionTitles;
  final showSubtitle = table.entrySubtitleLabel.trim().isNotEmpty;
  final showLocation = rows.any((row) => row.entry.location.trim().isNotEmpty);
  final showTeachers = rows.any((row) => row.entry.teachers.isNotEmpty);

  final headers = <String>[
    if (showSection) table.sectionHeaderLabel,
    '시작',
    '종료',
    table.columnHeaderLabel,
    table.entryTitleLabel,
    if (showSubtitle) table.entrySubtitleLabel,
    if (showLocation) '교실',
    if (showTeachers) '교사',
  ];

  final widths = <double>[
    if (showSection) 12,
    10,
    10,
    16,
    22,
    if (showSubtitle) 20,
    if (showLocation) 16,
    if (showTeachers) 24,
  ];

  final sheet = workbook.addSheet('목록', columnWidths: widths, freezeRows: 1);

  sheet.addRow(
    headers.map((header) => XlsxCell(header, style: XlsxStyle.header)).toList(),
    height: 24,
  );

  for (final row in rows) {
    sheet.addRow(<XlsxCell>[
      if (showSection) XlsxCell(row.sectionTitle, style: XlsxStyle.timeCell),
      XlsxCell(row.start, style: XlsxStyle.timeCell),
      XlsxCell(row.end, style: XlsxStyle.timeCell),
      XlsxCell(row.columnLabel, style: XlsxStyle.contentCell),
      XlsxCell(row.entry.title, style: XlsxStyle.contentCell),
      if (showSubtitle)
        XlsxCell(row.entry.subtitle, style: XlsxStyle.contentCell),
      if (showLocation)
        XlsxCell(row.entry.location, style: XlsxStyle.contentCell),
      if (showTeachers)
        XlsxCell(row.entry.teacherLabel, style: XlsxStyle.contentCell),
    ], height: 20);
  }

  if (rows.isEmpty) {
    sheet.addRow(<XlsxCell>[
      const XlsxCell('내보낼 수업이 없습니다.', style: XlsxStyle.mutedCell),
    ], height: 20);
  }
}
