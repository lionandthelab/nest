/// 새 홈스쿨 관리자가 "나도 이 홈스쿨의 가족·선생님"으로 바로 들어가는 설정.
///
/// 홈스쿨 관리자는 대개 그 집 부모이자 선생님이다. 가정 만들기 → 보호자
/// 연결 → 선생님 등록을 멤버 화면에서 하나씩 찾아다니지 않게, 아직 안 된
/// 항목만 버튼으로 권한다.
library;

enum SelfSetupAction { family, parent, teacher, classroom }

List<SelfSetupAction> pendingSelfSetupActions({
  required bool hasOwnFamily,
  required bool isParent,
  required bool hasTeacherProfile,
  required bool hasTerm,
  required int classroomCount,
}) {
  return [
    if (!hasOwnFamily) SelfSetupAction.family,
    if (!isParent) SelfSetupAction.parent,
    if (!hasTeacherProfile) SelfSetupAction.teacher,
    // 교실은 학기에 속한다. 학기가 없으면 만들 곳이 없다.
    if (hasTerm && classroomCount == 0) SelfSetupAction.classroom,
  ];
}
