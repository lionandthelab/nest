import 'package:flutter/material.dart';

import '../../state/nest_controller.dart';
import '../models/new_term_checklist.dart';
import '../models/tab_section_request.dart';
import 'self_study/self_study_tab.dart';
import 'timetable_tab.dart';

/// 관리자 시간표 작업 공간 — 수업 시간표와 공과 자습을 한 탭에 묶는다.
///
/// 하단 네비게이션은 5칸이 한계인데 신학기 운영에는 '소식'(공지·학사일정) 탭이
/// 필요했다. 시간표와 자습은 같은 학기 시간표 데이터를 다루는 이웃 작업이라
/// 세그먼트로 합치는 편이 오히려 자연스럽다.
///
/// 두 화면 모두 편집 중 상태(시간표 드래프트, 자습 계획 선택)를 들고 있으므로
/// 세그먼트를 오갈 때 State가 살아 있도록 [IndexedStack]으로 유지한다. 다만
/// 아직 열어보지 않은 쪽은 만들지 않아 첫 진입 비용을 늘리지 않는다.
class TimetableWorkspaceTab extends StatefulWidget {
  const TimetableWorkspaceTab({
    super.key,
    required this.controller,
    required this.onDirtyChanged,
    this.sectionRequest,
  });

  final NestController controller;
  final ValueChanged<bool> onDirtyChanged;
  final TabSectionRequest? sectionRequest;

  @override
  State<TimetableWorkspaceTab> createState() => _TimetableWorkspaceTabState();
}

class _TimetableWorkspaceTabState extends State<TimetableWorkspaceTab> {
  static const _sections = [
    NewTermSections.timetable,
    NewTermSections.selfStudy,
  ];

  int _index = 0;
  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();
    _applySectionRequest(widget.sectionRequest);
  }

  @override
  void didUpdateWidget(covariant TimetableWorkspaceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final request = widget.sectionRequest;
    if (request != null && request.isNewerThan(oldWidget.sectionRequest)) {
      setState(() => _applySectionRequest(request));
    }
  }

  void _applySectionRequest(TabSectionRequest? request) {
    if (request == null) return;
    final index = _sections.indexOf(request.section);
    if (index < 0) return;
    _index = index;
    _visited.add(index);
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(
                value: 0,
                icon: Icon(Icons.calendar_view_week_outlined, size: 18),
                label: Text('시간표', maxLines: 1),
              ),
              ButtonSegment<int>(
                value: 1,
                icon: Icon(Icons.menu_book_outlined, size: 18),
                label: Text('자습', maxLines: 1),
              ),
            ],
            selected: {_index},
            showSelectedIcon: false,
            onSelectionChanged: (values) => _select(values.first),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: [
              _visited.contains(0)
                  ? TimetableTab(
                      controller: widget.controller,
                      onDirtyChanged: widget.onDirtyChanged,
                    )
                  : const SizedBox.shrink(),
              _visited.contains(1)
                  ? SelfStudyTab(controller: widget.controller)
                  : const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}
