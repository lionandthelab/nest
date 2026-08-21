/// 신학기 준비 체크리스트.
///
/// 관리자 홈 상단에서 "이번 학기를 열려면 무엇이 남았는지"를 한눈에 보여주고,
/// 각 단계를 탭하면 해당 화면(탭 + 섹션)으로 바로 이동하기 위한 순수 모델이다.
/// 컨트롤러를 직접 참조하지 않고 개수/플래그만 받으므로 단위 테스트가 쉽다.
library;

/// 체크리스트 단계가 이동할 탭 라벨. `HomePage._buildTabs`의 라벨과 일치해야 한다.
class NewTermTabs {
  const NewTermTabs._();

  static const home = '홈';
  static const termSetup = '학기 설정';
  static const timetable = '시간표';
  static const news = '소식';
  static const system = '시스템';
}

/// 탭 내부에서 열 섹션 키.
///
/// `FamilyAdminTab`의 설정 단위 키, `TimetableWorkspaceTab`/`AdminNewsTab`의
/// 세그먼트 키와 같은 값을 쓴다.
class NewTermSections {
  const NewTermSections._();

  static const family = 'FAMILY';
  static const teacher = 'TEACHER';
  static const classGroup = 'CLASS';
  static const course = 'COURSE';
  static const classroom = 'CLASSROOM';
  static const timetable = 'TIMETABLE';
  static const selfStudy = 'SELF_STUDY';
  static const notices = 'NOTICES';
  static const events = 'EVENTS';
}

enum NewTermStepState {
  /// 이미 끝난 단계.
  done,

  /// 지금 바로 진행할 수 있는 단계.
  ready,

  /// 선행 단계가 끝나야 진행할 수 있는 단계.
  blocked,
}

class NewTermStep {
  const NewTermStep({
    required this.id,
    required this.title,
    required this.description,
    required this.targetTab,
    required this.targetSection,
    required this.completed,
    required this.enabled,
    this.optional = false,
  });

  /// 단계 식별자. UI가 특수 동작(예: `term`은 학기 생성 다이얼로그)을 고를 때 쓴다.
  final String id;
  final String title;
  final String description;

  /// 이동할 탭 라벨. `term` 단계처럼 탭 이동이 없는 단계는 null.
  final String? targetTab;

  /// 탭 안에서 열 섹션 키. 없으면 탭 기본 섹션.
  final String? targetSection;

  final bool completed;
  final bool enabled;

  /// 진행률 계산에서 제외되는 선택 단계.
  final bool optional;

  NewTermStepState get state {
    if (completed) return NewTermStepState.done;
    return enabled ? NewTermStepState.ready : NewTermStepState.blocked;
  }
}

class NewTermChecklist {
  const NewTermChecklist(this.steps);

  final List<NewTermStep> steps;

  /// 진행률에 포함되는 필수 단계.
  List<NewTermStep> get requiredSteps =>
      steps.where((step) => !step.optional).toList(growable: false);

  int get completedCount =>
      requiredSteps.where((step) => step.completed).length;

  int get totalCount => requiredSteps.length;

  /// 0.0 ~ 1.0. 필수 단계가 없으면 1.0으로 본다.
  double get progress =>
      totalCount == 0 ? 1 : completedCount / totalCount;

  bool get isComplete => completedCount == totalCount;

  /// 사용자가 지금 눌러야 할 단계. 없으면 null(= 모두 완료했거나 전부 막힘).
  NewTermStep? get nextStep {
    for (final step in steps) {
      if (!step.completed && step.enabled && !step.optional) {
        return step;
      }
    }
    for (final step in steps) {
      if (!step.completed && step.enabled) {
        return step;
      }
    }
    return null;
  }

  /// 완료되지 않은 단계(선택 포함).
  List<NewTermStep> get remainingSteps =>
      steps.where((step) => !step.completed).toList(growable: false);
}

/// 컨트롤러가 들고 있는 개수만으로 체크리스트를 만든다.
///
/// 반/시간표/학사일정은 학기에 종속되므로 [hasTerm]이 false면 잠긴다.
/// 가정·선생님·과목·교실은 홈스쿨 단위라 학기가 없어도 미리 준비할 수 있다.
NewTermChecklist buildNewTermChecklist({
  required bool hasTerm,
  required int familyCount,
  required int childCount,
  required int teacherCount,
  required int classGroupCount,
  required int enrollmentCount,
  required int courseCount,
  required int classroomCount,
  required int timeSlotCount,
  required int sessionCount,
  required int academicEventCount,
  required int announcementCount,
}) {
  final hasClass = classGroupCount > 0;
  final hasCourse = courseCount > 0;
  final hasSlot = timeSlotCount > 0;

  return NewTermChecklist([
    NewTermStep(
      id: 'term',
      title: '학기 만들기',
      description: '이번 학기의 이름과 기간을 정합니다.',
      targetTab: null,
      targetSection: null,
      completed: hasTerm,
      enabled: true,
    ),
    NewTermStep(
      id: 'family',
      title: '가정·아이 등록',
      description: '참여하는 가정과 아이를 등록합니다.',
      targetTab: NewTermTabs.termSetup,
      targetSection: NewTermSections.family,
      completed: familyCount > 0 && childCount > 0,
      enabled: true,
    ),
    NewTermStep(
      id: 'teacher',
      title: '선생님 등록',
      description: '이번 학기에 수업할 선생님을 등록합니다.',
      targetTab: NewTermTabs.termSetup,
      targetSection: NewTermSections.teacher,
      completed: teacherCount > 0,
      enabled: true,
    ),
    NewTermStep(
      id: 'class',
      title: '반 편성',
      description: '반을 만들고 아이를 반에 배정합니다.',
      targetTab: NewTermTabs.termSetup,
      targetSection: NewTermSections.classGroup,
      completed: hasClass && enrollmentCount > 0,
      enabled: hasTerm,
    ),
    NewTermStep(
      id: 'course',
      title: '과목 준비',
      description: '이번 학기에 열 과목을 준비합니다.',
      targetTab: NewTermTabs.termSetup,
      targetSection: NewTermSections.course,
      completed: hasCourse,
      enabled: true,
    ),
    NewTermStep(
      id: 'classroom',
      title: '교실 등록',
      description: '수업이 열리는 교실을 등록합니다. (선택)',
      targetTab: NewTermTabs.termSetup,
      targetSection: NewTermSections.classroom,
      completed: classroomCount > 0,
      enabled: true,
      optional: true,
    ),
    NewTermStep(
      id: 'timetable',
      title: '시간표 배치',
      description: '반별 수업을 시간표에 배치하고 확정합니다.',
      targetTab: NewTermTabs.timetable,
      targetSection: NewTermSections.timetable,
      completed: sessionCount > 0,
      enabled: hasTerm && hasClass && hasCourse && hasSlot,
    ),
    NewTermStep(
      id: 'event',
      title: '학사일정 등록',
      description: '개학일·행사 등 이번 학기 일정을 올립니다.',
      targetTab: NewTermTabs.news,
      targetSection: NewTermSections.events,
      completed: academicEventCount > 0,
      enabled: hasTerm,
    ),
    NewTermStep(
      id: 'announcement',
      title: '개학 공지',
      description: '학부모·선생님에게 새 학기 안내를 보냅니다.',
      targetTab: NewTermTabs.news,
      targetSection: NewTermSections.notices,
      completed: announcementCount > 0,
      enabled: true,
    ),
  ]);
}
