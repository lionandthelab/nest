import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/services/xlsx_writer.dart';
import 'package:nest_frontend/src/ui/tabs/timetable/timetable_excel_export.dart';
import 'package:nest_frontend/src/ui/tabs/timetable/timetable_export_board.dart';
import 'package:xml/xml.dart';

/// 월/화 2열 × 3개 시간대. 두 번째 시간대는 완전히 비어 있어
/// "빈 시간대 숨기기" 동작을 확인할 수 있다.
TimetableExportTable _sampleTable() {
  return TimetableExportTable(
    title: '2학기 · 3학년 시간표',
    subtitle: '내보낸 시각 2026-08-03 10:00',
    columnHeaderLabel: '요일',
    columnLabels: const ['월요일', '화요일'],
    entryTitleLabel: '과목',
    sections: [
      TimetableExportSection(
        periods: [
          const TimetableExportPeriod(
            start: '09:00',
            end: '09:30',
            entriesByColumn: [
              [
                TimetableExportEntry(
                  title: '영어 <기초>',
                  location: '3.믿음',
                  teachers: ['주 섬예리'],
                ),
              ],
              [],
            ],
          ),
          const TimetableExportPeriod(
            start: '09:30',
            end: '10:00',
            entriesByColumn: [[], []],
          ),
          const TimetableExportPeriod(
            start: '10:00',
            end: '10:30',
            entriesByColumn: [
              [],
              [
                TimetableExportEntry(
                  title: '국어',
                  location: '3.소망',
                  teachers: ['주 황정애', '보조 김수진'],
                ),
              ],
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  group('TimetableExportTable', () {
    test('빈 시간대 숨기기를 켜면 수업 없는 행이 빠진다', () {
      final table = _sampleTable();

      final all = table.visibleSections(hideEmptyPeriods: false);
      expect(all.single.periods.length, 3);

      final filtered = table.visibleSections(hideEmptyPeriods: true);
      expect(filtered.single.periods.length, 2);
      expect(filtered.single.periods.map((period) => period.start), [
        '09:00',
        '10:00',
      ]);
    });

    test('모든 시간대가 비면 구역 자체가 사라진다', () {
      const table = TimetableExportTable(
        title: '빈 표',
        columnLabels: ['월요일'],
        sections: [
          TimetableExportSection(
            periods: [
              TimetableExportPeriod(
                start: '09:00',
                end: '09:30',
                entriesByColumn: [[]],
              ),
            ],
          ),
        ],
      );

      expect(table.hasEntries, isFalse);
      expect(table.visibleSections(hideEmptyPeriods: true), isEmpty);
    });

    test('flatten은 수업을 한 줄씩 펼친다', () {
      final rows = _sampleTable().flatten(hideEmptyPeriods: true);

      expect(rows.length, 2);
      expect(rows.first.columnLabel, '월요일');
      expect(rows.first.entry.title, '영어 <기초>');
      expect(rows.last.columnLabel, '화요일');
      expect(rows.last.entry.teacherLabel, '주 황정애, 보조 김수진');
    });

    test('셀 텍스트는 과목/교실/교사를 줄바꿈으로 묶는다', () {
      const entry = TimetableExportEntry(
        title: '국어',
        subtitle: '3학년',
        location: '3.소망',
        teachers: ['주 황정애'],
      );

      expect(entry.toCellText(), '국어\n3학년\n3.소망\n주 황정애');
    });
  });

  group('buildTimetableWorkbook', () {
    test('OOXML 패키지 구조를 모두 갖춘 xlsx를 만든다', () {
      final bytes = buildTimetableWorkbook(
        _sampleTable(),
        hideEmptyPeriods: true,
      );

      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.map((file) => file.name).toSet();

      expect(names, contains('[Content_Types].xml'));
      expect(names, contains('_rels/.rels'));
      expect(names, contains('xl/workbook.xml'));
      expect(names, contains('xl/_rels/workbook.xml.rels'));
      expect(names, contains('xl/styles.xml'));
      expect(names, contains('xl/worksheets/sheet1.xml'));
      expect(names, contains('xl/worksheets/sheet2.xml'));
    });

    test('표 시트에 제목·헤더·수업이 담기고 XML 특수문자는 이스케이프된다', () {
      final bytes = buildTimetableWorkbook(
        _sampleTable(),
        hideEmptyPeriods: true,
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final sheet = utf8.decode(
        archive.files
                .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml')
                .content
            as List<int>,
      );

      expect(sheet, contains('2학기 · 3학년 시간표'));
      expect(sheet, contains('월요일'));
      expect(sheet, contains('09:00-09:30'));
      // 숨김이 켜져 있으므로 빈 시간대는 나오지 않는다.
      expect(sheet, isNot(contains('09:30-10:00')));
      // '<'가 그대로 들어가면 XML이 깨진다.
      expect(sheet, contains('영어 &lt;기초&gt;'));
      expect(sheet, isNot(contains('영어 <기초>')));
      // 표 시트는 시간 열 + 요일 열만 고정한다.
      expect(sheet, contains('state="frozen"'));
    });

    test('목록 시트는 헤더와 수업 줄을 갖는다', () {
      final bytes = buildTimetableWorkbook(
        _sampleTable(),
        hideEmptyPeriods: true,
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final sheet = utf8.decode(
        archive.files
                .firstWhere((f) => f.name == 'xl/worksheets/sheet2.xml')
                .content
            as List<int>,
      );

      expect(sheet, contains('시작'));
      expect(sheet, contains('종료'));
      expect(sheet, contains('교실'));
      expect(sheet, contains('교사'));
      expect(sheet, contains('주 황정애, 보조 김수진'));
    });

    test('모든 XML 파트가 정상 파싱된다', () {
      final bytes = buildTimetableWorkbook(
        _sampleTable(),
        hideEmptyPeriods: false,
      );
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive.files) {
        final text = utf8.decode(file.content as List<int>);
        expect(
          text.startsWith('<?xml version="1.0" encoding="UTF-8"'),
          isTrue,
          reason: '${file.name} 이(가) XML 선언으로 시작하지 않음',
        );
        expect(
          () => XmlDocument.parse(text),
          returnsNormally,
          reason: '${file.name} XML 파싱 실패',
        );
      }
    });

    test('시트 관계(rId)와 시트 파일이 서로 맞물린다', () {
      final bytes = buildTimetableWorkbook(
        _sampleTable(),
        hideEmptyPeriods: false,
      );
      final archive = ZipDecoder().decodeBytes(bytes);

      String read(String name) => utf8.decode(
        archive.files.firstWhere((f) => f.name == name).content as List<int>,
      );

      final workbook = XmlDocument.parse(read('xl/workbook.xml'));
      final rels = XmlDocument.parse(read('xl/_rels/workbook.xml.rels'));

      final relTargets = <String, String>{
        for (final rel in rels.findAllElements('Relationship'))
          rel.getAttribute('Id')!: rel.getAttribute('Target')!,
      };

      final sheets = workbook.findAllElements('sheet').toList();
      expect(sheets.length, 2);
      expect(sheets.map((s) => s.getAttribute('name')), ['표', '목록']);

      for (final sheet in sheets) {
        final relId = sheet.getAttribute('r:id')!;
        final target = relTargets[relId];
        expect(target, isNotNull, reason: '$relId 관계가 없음');
        expect(
          archive.files.any((f) => f.name == 'xl/$target'),
          isTrue,
          reason: 'xl/$target 시트 파일이 없음',
        );
      }

      // 서식 관계도 실제 파트를 가리켜야 엑셀이 서식을 읽는다.
      expect(relTargets.values, contains('styles.xml'));
    });

    test('styles.xml의 cellXfs 개수가 XlsxStyle 개수와 같다', () {
      final bytes = buildTimetableWorkbook(
        _sampleTable(),
        hideEmptyPeriods: false,
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final styles = XmlDocument.parse(
        utf8.decode(
          archive.files.firstWhere((f) => f.name == 'xl/styles.xml').content
              as List<int>,
        ),
      );

      final cellXfs = styles.findAllElements('cellXfs').single;
      expect(cellXfs.findElements('xf').length, XlsxStyle.values.length);
      expect(cellXfs.getAttribute('count'), '${XlsxStyle.values.length}');
    });

    test('내용이 없는 표도 시트 두 장을 만든다', () {
      const empty = TimetableExportTable(
        title: '빈 표',
        columnLabels: ['월요일'],
        sections: [],
      );

      final archive = ZipDecoder().decodeBytes(
        buildTimetableWorkbook(empty, hideEmptyPeriods: true),
      );
      final names = archive.map((file) => file.name).toSet();

      expect(names, contains('xl/worksheets/sheet1.xml'));
      expect(names, contains('xl/worksheets/sheet2.xml'));

      final list = utf8.decode(
        archive.files
                .firstWhere((f) => f.name == 'xl/worksheets/sheet2.xml')
                .content
            as List<int>,
      );
      expect(list, contains('내보낼 수업이 없습니다.'));
    });

    test('생성된 파일을 디스크에 남겨 수동 확인할 수 있다', () {
      final bytes = buildTimetableWorkbook(
        _sampleTable(),
        hideEmptyPeriods: false,
      );
      final file = File(
        '${Directory.systemTemp.path}/nest_timetable_sample.xlsx',
      )..writeAsBytesSync(bytes);

      expect(file.lengthSync(), greaterThan(1000));
    });
  });

  group('TimetableExportBoard', () {
    /// 보드는 스스로 폭을 정하므로, 화면 크기와 무관하게 넘침이 없어야 한다.
    Future<void> pumpBoard(
      WidgetTester tester,
      TimetableExportTable table, {
      required bool hideEmptyPeriods,
      required TimetableExportScale scale,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: TimetableExportBoard(
                  table: table,
                  scale: scale,
                  hideEmptyPeriods: hideEmptyPeriods,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('글자 크기를 키워도 행이 넘치지 않는다', (tester) async {
      for (final scale in TimetableExportScale.values) {
        await pumpBoard(
          tester,
          _sampleTable(),
          hideEmptyPeriods: false,
          scale: scale,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '${scale.label}에서 레이아웃 넘침 발생',
        );
      }
    });

    testWidgets('빈 시간대 숨기기가 미리보기에도 적용된다', (tester) async {
      // '09:30'은 09:00 행의 끝이자 09:30 행의 시작이라 두 번 그려진다.
      await pumpBoard(
        tester,
        _sampleTable(),
        hideEmptyPeriods: false,
        scale: TimetableExportScale.large,
      );
      expect(find.text('09:30'), findsNWidgets(2));

      // 09:30 행(수업 없음)이 빠지면 끝 시각 한 번만 남는다.
      await pumpBoard(
        tester,
        _sampleTable(),
        hideEmptyPeriods: true,
        scale: TimetableExportScale.large,
      );
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('영어 <기초>'), findsOneWidget);
      expect(find.text('주 황정애, 보조 김수진'), findsOneWidget);
    });

    testWidgets('구역(요일) 제목이 있는 표도 넘침 없이 그려진다', (tester) async {
      const table = TimetableExportTable(
        title: '2학기 교실 상황표',
        columnHeaderLabel: '교실',
        columnLabels: ['3.믿음', '3.소망', '4층예배실', '304호'],
        sectionHeaderLabel: '요일',
        entryTitleLabel: '반',
        entrySubtitleLabel: '과목',
        sections: [
          TimetableExportSection(
            title: '월요일',
            periods: [
              TimetableExportPeriod(
                start: '10:00',
                end: '10:30',
                entriesByColumn: [
                  [TimetableExportEntry(title: '3학년', subtitle: '영어')],
                  [],
                  [],
                  [],
                ],
              ),
            ],
          ),
          TimetableExportSection(
            title: '화요일',
            periods: [
              TimetableExportPeriod(
                start: '10:00',
                end: '10:30',
                entriesByColumn: [[], [], [], []],
              ),
            ],
          ),
        ],
      );

      await pumpBoard(
        tester,
        table,
        hideEmptyPeriods: true,
        scale: TimetableExportScale.extraLarge,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('월요일'), findsOneWidget);
      // 화요일은 수업이 없으므로 구역째로 빠진다.
      expect(find.text('화요일'), findsNothing);
    });
  });
}
