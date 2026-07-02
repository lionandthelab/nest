import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../models/nest_models.dart';
import '../../../services/download_helper.dart';
import '../../../services/self_study_planner.dart';
import '../../../state/nest_controller.dart';
import '../../nest_theme.dart';
import '../timetable/room_normalizer.dart';

/// 공과 자습 출석부 미리보기/내보내기 화면.
///
/// 선택된 자습 계획의 슬롯을 (요일, 방)으로 묶어 출석부 한 장씩 렌더링한다.
/// 각 장은 [기간] 안에서 그 요일에 해당하는 날짜들을 열로, 자습 명단 아동을
/// 행으로 표시하고, 각 시간 밴드에서 수업이 있는 칸은 'X'(자습 불가)로 음영
/// 처리한다. 장별로 PNG 로 저장할 수 있다.
class SelfStudySheetPage extends StatefulWidget {
  const SelfStudySheetPage({super.key, required this.controller});

  final NestController controller;

  @override
  State<SelfStudySheetPage> createState() => _SelfStudySheetPageState();
}

class _SelfStudySheetPageState extends State<SelfStudySheetPage> {
  final DownloadHelper _download = createDownloadHelper();
  final Map<String, GlobalKey> _boundaryKeys = {};

  GlobalKey _keyFor(String id) =>
      _boundaryKeys.putIfAbsent(id, () => GlobalKey());

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final groups = _buildGroups(widget.controller);
        return Scaffold(
          backgroundColor: NestColors.creamyWhite,
          appBar: AppBar(
            title: const Text('공과 자습 출석부'),
            backgroundColor: NestColors.creamyWhite,
          ),
          body: groups.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('내보낼 자습 슬롯이 없습니다. 먼저 자동 배치를 실행하세요.'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _SheetCard(
                      controller: widget.controller,
                      group: group,
                      boundaryKey: _keyFor(group.id),
                      onDownload: () => _downloadSheet(group),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _downloadSheet(_SheetGroup group) async {
    final boundary = _keyFor(group.id)
        .currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    final bytes = byteData.buffer.asUint8List();
    final safeName = group.fileLabel.replaceAll(RegExp(r'[^\w가-힣]+'), '_');
    _download.downloadBytes(
      bytes: bytes,
      filename: '자습출석부_$safeName.png',
      mimeType: 'image/png',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${group.title} 출석부를 저장했습니다.')),
      );
    }
  }

  // ── (요일, 방)별 출석부 그룹 구성 ──
  List<_SheetGroup> _buildGroups(NestController controller) {
    final plan = controller.selectedSelfStudyPlan;
    if (plan == null) return const [];
    final slots = controller.selectedPlanSelfStudySlots;
    if (slots.isEmpty) return const [];

    final period = _resolvePeriod(controller, plan);

    // (day, canonical room) → 슬롯들.
    final buckets = <String, List<SelfStudySlot>>{};
    for (final slot in slots) {
      final roomKey = RoomNormalizer.canonical(
        slot.room.trim().isEmpty ? '미정' : slot.room,
      );
      buckets.putIfAbsent('${slot.dayOfWeek}|$roomKey', () => []).add(slot);
    }

    final groups = <_SheetGroup>[];
    buckets.forEach((key, bucketSlots) {
      final day = bucketSlots.first.dayOfWeek;
      final roomDisplay = RoomNormalizer.normalize(
        bucketSlots.first.room.trim().isEmpty ? '미정' : bucketSlots.first.room,
      );
      final startMin = bucketSlots
          .map((s) => minutesFromTime(s.startTime))
          .reduce((a, b) => a < b ? a : b);
      final endMin = bucketSlots
          .map((s) => minutesFromTime(s.endTime))
          .reduce((a, b) => a > b ? a : b);

      // 명단(반원) 구성: 슬롯의 반에서 제외를 뺀 아동 + 학년 소속 반 이름.
      final rosterRows = <_RosterRow>[];
      final seen = <String>{};
      for (final slot in bucketSlots) {
        final groupName = controller.findClassGroupName(slot.classGroupId);
        for (final child in controller.rosterForSelfStudySlot(slot)) {
          if (!seen.add(child.id)) continue;
          rosterRows.add(_RosterRow(child: child, groupName: groupName));
        }
      }
      rosterRows.sort((a, b) {
        final ga = _gradeOrder(a.groupName);
        final gb = _gradeOrder(b.groupName);
        if (ga != gb) return ga.compareTo(gb);
        return a.child.name.compareTo(b.child.name);
      });

      // 감독 이름(중복 제거).
      final supervisors = <String>[];
      for (final slot in bucketSlots) {
        final id = slot.supervisorTeacherId;
        if (id == null) continue;
        final name = controller.teacherProfiles
            .where((t) => t.id == id)
            .map((t) => t.displayName)
            .firstOrNull;
        if (name != null && name.isNotEmpty && !supervisors.contains(name)) {
          supervisors.add(name);
        }
      }

      final dates = datesForWeekday(period.$1, period.$2, day);

      groups.add(_SheetGroup(
        id: key,
        day: day,
        roomDisplay: roomDisplay,
        startMin: startMin,
        endMin: endMin,
        rosterRows: rosterRows,
        supervisors: supervisors,
        dates: dates,
      ));
    });

    groups.sort((a, b) {
      final da = a.day == 0 ? 7 : a.day;
      final db = b.day == 0 ? 7 : b.day;
      if (da != db) return da.compareTo(db);
      return a.startMin.compareTo(b.startMin);
    });
    return groups;
  }

  (DateTime, DateTime) _resolvePeriod(
    NestController controller,
    SelfStudyPlan plan,
  ) {
    if (plan.periodStart != null && plan.periodEnd != null) {
      return (plan.periodStart!, plan.periodEnd!);
    }
    final term = controller.selectedTerm;
    if (term?.startDate != null && term?.endDate != null) {
      return (term!.startDate!, term.endDate!);
    }
    // 마지막 폴백: 이번 달.
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final last = DateTime(now.year, now.month + 1, 0);
    return (first, last);
  }

  int _gradeOrder(String groupName) {
    final m = RegExp(r'^(초|중|고)\s*([1-6])').firstMatch(groupName.trim());
    if (m == null) return 999;
    const band = {'초': 0, '중': 10, '고': 20};
    return (band[m.group(1)] ?? 900) + int.parse(m.group(2)!);
  }
}

class _RosterRow {
  const _RosterRow({required this.child, required this.groupName});
  final ChildProfile child;
  final String groupName;
}

class _SheetGroup {
  const _SheetGroup({
    required this.id,
    required this.day,
    required this.roomDisplay,
    required this.startMin,
    required this.endMin,
    required this.rosterRows,
    required this.supervisors,
    required this.dates,
  });

  final String id;
  final int day;
  final String roomDisplay;
  final int startMin;
  final int endMin;
  final List<_RosterRow> rosterRows;
  final List<String> supervisors;
  final List<DateTime> dates;

  String get title =>
      '${weekdayLabel(day)}요일 ${rangeLabel(startMin, endMin)} $roomDisplay';
  String get fileLabel => '${weekdayLabel(day)}_$roomDisplay';
}

class _SheetCard extends StatelessWidget {
  const _SheetCard({
    required this.controller,
    required this.group,
    required this.boundaryKey,
    required this.onDownload,
  });

  final NestController controller;
  final _SheetGroup group;
  final GlobalKey boundaryKey;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                group.title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('PNG 저장'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: RepaintBoundary(
            key: boundaryKey,
            child: _SheetTable(controller: controller, group: group),
          ),
        ),
      ],
    );
  }
}

class _SheetTable extends StatelessWidget {
  const _SheetTable({required this.controller, required this.group});

  final NestController controller;
  final _SheetGroup group;

  static const double _idxW = 34;
  static const double _nameW = 78;
  static const double _gradeW = 52;
  static const double _bandW = 60;
  static const double _rowH = 34;

  @override
  Widget build(BuildContext context) {
    final bands = hourBands(group.startMin, group.endMin);
    final dates = group.dates;
    final border = Border.all(color: NestColors.deepWood.withValues(alpha: 0.4));

    // 아동 × 요일 밴드 점유(X) 사전 계산(요일 단위이므로 날짜별로 동일).
    final occByChild = <String, List<bool>>{};
    for (final row in group.rosterRows) {
      final occupied = _childOccupiedIntervals(row.child, group.day);
      occByChild[row.child.id] = [
        for (final band in bands)
          occupied.any((iv) => iv.$1 < band[1] && iv.$2 > band[0]),
      ];
    }

    Widget cell(
      String text, {
      required double width,
      Color? bg,
      bool bold = false,
      double fontSize = 12,
    }) {
      return Container(
        width: width,
        height: _rowH,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, border: border),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: NestColors.deepWood,
          ),
        ),
      );
    }

    // (날짜·밴드)별 감독 이름 셀. 오버라이드→매주기본→슬롯감독→미지정 순으로 해석.
    Widget supCell(DateTime d, List<int> band) {
      final id = controller.resolveSelfStudySupervisor(
        dayOfWeek: group.day,
        room: group.roomDisplay,
        bandStartMin: band[0],
        bandEndMin: band[1],
        date: d,
      );
      final name = (id == null || id.isEmpty)
          ? '미지정'
          : controller.findTeacherName(id);
      return cell(
        name,
        width: _bandW,
        fontSize: 10,
        bg: id == null
            ? NestColors.roseMist.withValues(alpha: 0.28)
            : NestColors.creamyWhite,
      );
    }

    final headerBg = NestColors.roseMist.withValues(alpha: 0.5);

    // 헤더 1행: (연번/이름/학년 병합) + 날짜별(밴드 병합).
    final header1 = Row(
      children: [
        cell(group.title,
            width: _idxW + _nameW + _gradeW, bg: headerBg, bold: true),
        for (final d in dates)
          cell('${d.month}. ${d.day}',
              width: _bandW * bands.length, bg: headerBg, bold: true),
      ],
    );

    // 헤더 2행: 연번/이름/학년 + (날짜×밴드) 시간 라벨.
    final header2 = Row(
      children: [
        cell('연번', width: _idxW, bg: headerBg, bold: true),
        cell('이름', width: _nameW, bg: headerBg, bold: true),
        cell('학년', width: _gradeW, bg: headerBg, bold: true),
        for (var i = 0; i < dates.length; i++)
          for (final band in bands)
            cell(rangeLabel(band[0], band[1]),
                width: _bandW, bg: headerBg, fontSize: 10),
      ],
    );

    final bodyRows = <Widget>[];
    for (var r = 0; r < group.rosterRows.length; r++) {
      final row = group.rosterRows[r];
      final occ = occByChild[row.child.id] ?? const [];
      bodyRows.add(Row(
        children: [
          cell('${r + 1}', width: _idxW),
          cell(row.child.name, width: _nameW),
          cell(gradeLabelForGroupName(row.groupName), width: _gradeW),
          for (var i = 0; i < dates.length; i++)
            for (var b = 0; b < bands.length; b++)
              cell(
                (b < occ.length && occ[b]) ? 'X' : '',
                width: _bandW,
                bold: true,
                bg: (b < occ.length && occ[b])
                    ? NestColors.deepWood.withValues(alpha: 0.14)
                    : null,
              ),
        ],
      ));
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header1,
          header2,
          ...bodyRows,
          // 감독 행: (날짜·밴드)별로 그 시간의 감독을 표기(회전 감독 반영).
          Row(
            children: [
              cell('감독',
                  width: _idxW + _nameW + _gradeW, bg: headerBg, bold: true),
              for (final d in dates)
                for (final band in bands) supCell(d, band),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'X = 수업 중(자습 불가) · 빈칸 = 자습',
              style: TextStyle(
                fontSize: 11,
                color: NestColors.deepWood.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 아동이 특정 요일에 수업으로 점유한 (start,end) 분 구간들.
  List<(int, int)> _childOccupiedIntervals(ChildProfile child, int day) {
    final groupIds =
        controller.classGroupsForChild(child.id).map((g) => g.id).toSet();
    if (groupIds.isEmpty) return const [];
    final slotById = {for (final s in controller.timeSlots) s.id: s};
    final intervals = <(int, int)>[];
    for (final session in controller.allTermSessions) {
      if (!groupIds.contains(session.classGroupId)) continue;
      final ts = slotById[session.timeSlotId];
      if (ts == null || ts.dayOfWeek != day) continue;
      intervals.add((minutesFromTime(ts.startTime), minutesFromTime(ts.endTime)));
    }
    return intervals;
  }
}
