/// 최소 스펙의 XLSX(OOXML SpreadsheetML) 라이터.
///
/// 외부 엑셀 패키지는 `archive` 버전 충돌(flutter_native_splash → image)로
/// 붙일 수 없어, 필요한 기능(문자열 셀 / 열 너비 / 행 높이 / 병합 / 서식 /
/// 틀 고정)만 직접 zip + XML로 만든다. 웹/모바일 모두에서 동작하도록
/// `dart:io`에 의존하지 않는 `package:archive/archive.dart`만 사용한다.
///
/// 사용 예:
/// ```dart
/// final workbook = XlsxWorkbook();
/// final sheet = workbook.addSheet('시간표', columnWidths: [14, 24, 24]);
/// sheet.addRow([XlsxCell('시간', style: XlsxStyle.header)]);
/// final bytes = workbook.encode();
/// ```
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';

/// 셀 서식. 순서는 styles.xml의 `cellXfs` 인덱스와 1:1로 대응하므로
/// 항목을 추가할 때는 [_stylesXml]의 `cellXfs`도 같은 위치에 추가해야 한다.
enum XlsxStyle {
  /// 서식 없는 기본 셀.
  body,

  /// 문서 제목(큰 굵은 글씨, 테두리 없음).
  title,

  /// 표 헤더(로즈미스트 배경 + 가운데 정렬).
  header,

  /// 시간/좌측 라벨 열(크리미화이트 배경 + 굵은 글씨).
  timeCell,

  /// 본문 데이터 셀(흰 배경 + 테두리 + 줄바꿈).
  contentCell,

  /// 구역 구분 행(요일 헤더 등).
  sectionCell,

  /// 비어 있는 셀(연한 글씨 + 테두리).
  mutedCell,

  /// 부가 설명(내보낸 시각 등).
  caption,
}

/// 문자열 한 칸. 숫자/날짜 타입은 쓰지 않고 모두 inline string으로 저장해
/// 엑셀이 "09:00" 같은 값을 임의로 변환하지 않게 한다.
class XlsxCell {
  const XlsxCell(this.text, {this.style = XlsxStyle.contentCell});

  /// 서식만 입히고 내용은 비우는 셀.
  const XlsxCell.blank({this.style = XlsxStyle.contentCell}) : text = '';

  final String text;
  final XlsxStyle style;
}

class _XlsxRow {
  const _XlsxRow(this.cells, this.height);

  final List<XlsxCell> cells;
  final double? height;
}

class _XlsxMerge {
  const _XlsxMerge(this.ref);

  final String ref;
}

/// 시트 하나. 행을 순서대로 추가하는 방식만 지원한다.
class XlsxSheet {
  XlsxSheet({
    required String name,
    this.columnWidths = const <double>[],
    this.freezeRows = 0,
    this.freezeColumns = 0,
    this.showGridLines = true,
  }) : name = _sanitizeSheetName(name);

  final String name;

  /// 엑셀 문자 단위 열 너비. 지정하지 않은 열은 기본 너비를 쓴다.
  final List<double> columnWidths;

  /// 스크롤해도 고정할 상단 행 수.
  final int freezeRows;

  /// 스크롤해도 고정할 좌측 열 수.
  final int freezeColumns;

  /// 표 시트는 테두리로 구분되므로 눈금선을 끄는 편이 읽기 좋다.
  final bool showGridLines;

  final List<_XlsxRow> _rows = <_XlsxRow>[];
  final List<_XlsxMerge> _merges = <_XlsxMerge>[];

  /// 지금까지 추가된 행 수(다음에 추가할 행의 0-based 인덱스).
  int get rowCount => _rows.length;

  void addRow(List<XlsxCell> cells, {double? height}) {
    _rows.add(_XlsxRow(List<XlsxCell>.unmodifiable(cells), height));
  }

  void addBlankRow({double height = 8}) {
    addRow(const <XlsxCell>[], height: height);
  }

  /// 0-based 좌표 기준 셀 병합. [rowSpan]은 세로 병합 행 수.
  void merge({
    required int row,
    required int startColumn,
    required int endColumn,
    int rowSpan = 1,
  }) {
    final endRow = row + (rowSpan < 1 ? 1 : rowSpan) - 1;
    if (endRow == row && endColumn == startColumn) {
      return;
    }
    final ref =
        '${_columnLetter(startColumn)}${row + 1}:'
        '${_columnLetter(endColumn)}${endRow + 1}';
    _merges.add(_XlsxMerge(ref));
  }

  /// 마지막으로 추가한 행을 가로로 병합한다.
  void mergeLastRow({required int startColumn, required int endColumn}) {
    if (_rows.isEmpty) {
      return;
    }
    merge(
      row: _rows.length - 1,
      startColumn: startColumn,
      endColumn: endColumn,
    );
  }
}

/// 여러 시트를 담아 .xlsx 바이트로 직렬화한다.
class XlsxWorkbook {
  final List<XlsxSheet> _sheets = <XlsxSheet>[];

  List<XlsxSheet> get sheets => List<XlsxSheet>.unmodifiable(_sheets);

  XlsxSheet addSheet(
    String name, {
    List<double> columnWidths = const <double>[],
    int freezeRows = 0,
    int freezeColumns = 0,
    bool showGridLines = true,
  }) {
    final sheet = XlsxSheet(
      name: name,
      columnWidths: columnWidths,
      freezeRows: freezeRows,
      freezeColumns: freezeColumns,
      showGridLines: showGridLines,
    );
    _sheets.add(sheet);
    return sheet;
  }

  Uint8List encode() {
    if (_sheets.isEmpty) {
      addSheet('Sheet1');
    }

    final archive = Archive();
    archive.add(ArchiveFile.string('[Content_Types].xml', _contentTypesXml()));
    archive.add(ArchiveFile.string('_rels/.rels', _rootRelsXml));
    archive.add(ArchiveFile.string('xl/workbook.xml', _workbookXml()));
    archive.add(
      ArchiveFile.string('xl/_rels/workbook.xml.rels', _workbookRelsXml()),
    );
    archive.add(ArchiveFile.string('xl/styles.xml', _stylesXml));
    for (var index = 0; index < _sheets.length; index++) {
      archive.add(
        ArchiveFile.string(
          'xl/worksheets/sheet${index + 1}.xml',
          _sheetXml(_sheets[index]),
        ),
      );
    }

    return ZipEncoder().encodeBytes(archive);
  }

  String _contentTypesXml() {
    final buffer = StringBuffer()
      ..write(_xmlDeclaration)
      ..write(
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
      )
      ..write(
        '<Default Extension="rels" '
        'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
      )
      ..write('<Default Extension="xml" ContentType="application/xml"/>')
      ..write(
        '<Override PartName="/xl/workbook.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
      )
      ..write(
        '<Override PartName="/xl/styles.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>',
      );
    for (var index = 0; index < _sheets.length; index++) {
      buffer.write(
        '<Override PartName="/xl/worksheets/sheet${index + 1}.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
      );
    }
    buffer.write('</Types>');
    return buffer.toString();
  }

  String _workbookXml() {
    final buffer = StringBuffer()
      ..write(_xmlDeclaration)
      ..write(
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
      )
      ..write('<sheets>');
    for (var index = 0; index < _sheets.length; index++) {
      buffer.write(
        '<sheet name="${_escapeXml(_sheets[index].name)}" '
        'sheetId="${index + 1}" r:id="rId${index + 1}"/>',
      );
    }
    buffer.write('</sheets></workbook>');
    return buffer.toString();
  }

  String _workbookRelsXml() {
    final buffer = StringBuffer()
      ..write(_xmlDeclaration)
      ..write(
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
      );
    for (var index = 0; index < _sheets.length; index++) {
      buffer.write(
        '<Relationship Id="rId${index + 1}" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
        'Target="worksheets/sheet${index + 1}.xml"/>',
      );
    }
    buffer.write(
      '<Relationship Id="rId${_sheets.length + 1}" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
      'Target="styles.xml"/>',
    );
    buffer.write('</Relationships>');
    return buffer.toString();
  }

  String _sheetXml(XlsxSheet sheet) {
    final buffer = StringBuffer()
      ..write(_xmlDeclaration)
      ..write(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
      )
      ..write('<sheetViews><sheetView workbookViewId="0"');
    if (!sheet.showGridLines) {
      buffer.write(' showGridLines="0"');
    }
    buffer.write('>');
    if (sheet.freezeRows > 0 || sheet.freezeColumns > 0) {
      final topLeft =
          '${_columnLetter(sheet.freezeColumns)}${sheet.freezeRows + 1}';
      buffer.write(
        '<pane xSplit="${sheet.freezeColumns}" ySplit="${sheet.freezeRows}" '
        'topLeftCell="$topLeft" activePane="bottomRight" state="frozen"/>',
      );
    }
    buffer
      ..write('</sheetView></sheetViews>')
      ..write('<sheetFormatPr defaultRowHeight="18"/>');

    if (sheet.columnWidths.isNotEmpty) {
      buffer.write('<cols>');
      for (var index = 0; index < sheet.columnWidths.length; index++) {
        final width = sheet.columnWidths[index];
        buffer.write(
          '<col min="${index + 1}" max="${index + 1}" '
          'width="${width.toStringAsFixed(2)}" customWidth="1"/>',
        );
      }
      buffer.write('</cols>');
    }

    buffer.write('<sheetData>');
    for (var rowIndex = 0; rowIndex < sheet._rows.length; rowIndex++) {
      final row = sheet._rows[rowIndex];
      buffer.write('<row r="${rowIndex + 1}"');
      final height = row.height;
      if (height != null) {
        buffer.write(' ht="${height.toStringAsFixed(1)}" customHeight="1"');
      }
      buffer.write('>');
      for (var colIndex = 0; colIndex < row.cells.length; colIndex++) {
        final cell = row.cells[colIndex];
        final ref = '${_columnLetter(colIndex)}${rowIndex + 1}';
        final styleIndex = cell.style.index;
        if (cell.text.isEmpty) {
          buffer.write('<c r="$ref" s="$styleIndex"/>');
        } else {
          buffer.write(
            '<c r="$ref" s="$styleIndex" t="inlineStr"><is>'
            '<t xml:space="preserve">${_escapeXml(cell.text)}</t>'
            '</is></c>',
          );
        }
      }
      buffer.write('</row>');
    }
    buffer.write('</sheetData>');

    if (sheet._merges.isNotEmpty) {
      buffer.write('<mergeCells count="${sheet._merges.length}">');
      for (final merge in sheet._merges) {
        buffer.write('<mergeCell ref="${merge.ref}"/>');
      }
      buffer.write('</mergeCells>');
    }

    buffer.write('</worksheet>');
    return buffer.toString();
  }
}

const String _xmlDeclaration =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';

const String _rootRelsXml =
    '$_xmlDeclaration'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
    'Target="xl/workbook.xml"/>'
    '</Relationships>';

/// Nest 디자인 토큰(roseMist / creamyWhite / deepWood)을 그대로 옮긴 서식표.
/// `cellXfs`의 순서가 [XlsxStyle] 순서와 정확히 일치해야 한다.
const String _stylesXml =
    '$_xmlDeclaration'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<fonts count="6">'
    '<font><sz val="12"/><color rgb="FF3B322B"/><name val="맑은 고딕"/><family val="2"/></font>'
    '<font><b/><sz val="12"/><color rgb="FF3B322B"/><name val="맑은 고딕"/><family val="2"/></font>'
    '<font><b/><sz val="20"/><color rgb="FF5A4637"/><name val="맑은 고딕"/><family val="2"/></font>'
    '<font><b/><sz val="13"/><color rgb="FF5A4637"/><name val="맑은 고딕"/><family val="2"/></font>'
    '<font><sz val="11"/><color rgb="FF9C8B7D"/><name val="맑은 고딕"/><family val="2"/></font>'
    '<font><b/><sz val="14"/><color rgb="FF5A4637"/><name val="맑은 고딕"/><family val="2"/></font>'
    '</fonts>'
    '<fills count="5">'
    '<fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFF4E4DB"/><bgColor indexed="64"/></patternFill></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFF9F7F2"/><bgColor indexed="64"/></patternFill></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFFFFFFF"/><bgColor indexed="64"/></patternFill></fill>'
    '</fills>'
    '<borders count="2">'
    '<border><left/><right/><top/><bottom/><diagonal/></border>'
    '<border>'
    '<left style="thin"><color rgb="FFE3D2C7"/></left>'
    '<right style="thin"><color rgb="FFE3D2C7"/></right>'
    '<top style="thin"><color rgb="FFE3D2C7"/></top>'
    '<bottom style="thin"><color rgb="FFE3D2C7"/></bottom>'
    '<diagonal/>'
    '</border>'
    '</borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="8">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1">'
    '<alignment vertical="center" wrapText="1"/></xf>'
    '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1">'
    '<alignment vertical="center"/></xf>'
    '<xf numFmtId="0" fontId="3" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
    '<alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
    '<xf numFmtId="0" fontId="1" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
    '<alignment horizontal="center" vertical="center"/></xf>'
    '<xf numFmtId="0" fontId="0" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
    '<alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
    '<xf numFmtId="0" fontId="5" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
    '<alignment horizontal="left" vertical="center"/></xf>'
    '<xf numFmtId="0" fontId="4" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1">'
    '<alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
    '<xf numFmtId="0" fontId="4" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1">'
    '<alignment vertical="center"/></xf>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '<dxfs count="0"/>'
    '</styleSheet>';

/// 0 → A, 25 → Z, 26 → AA 형태의 엑셀 열 문자.
String _columnLetter(int index) {
  var value = index;
  var letters = '';
  while (value >= 0) {
    letters = String.fromCharCode(65 + (value % 26)) + letters;
    value = (value ~/ 26) - 1;
  }
  return letters;
}

/// 엑셀 시트 이름 제약(31자, `[]:*?/\` 금지)에 맞춘다.
String _sanitizeSheetName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) {
    return 'Sheet';
  }
  return cleaned.length <= 31 ? cleaned : cleaned.substring(0, 31);
}

/// XML 예약문자 이스케이프 + XML 1.0에서 허용되지 않는 제어문자 제거.
String _escapeXml(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final isAllowedControl = rune == 0x09 || rune == 0x0A || rune == 0x0D;
    if (rune < 0x20 && !isAllowedControl) {
      continue;
    }
    switch (rune) {
      case 0x26:
        buffer.write('&amp;');
      case 0x3C:
        buffer.write('&lt;');
      case 0x3E:
        buffer.write('&gt;');
      case 0x22:
        buffer.write('&quot;');
      case 0x27:
        buffer.write('&apos;');
      default:
        buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}
