/// 탭 안의 특정 섹션을 열어달라는 요청.
///
/// 관리자 홈의 체크리스트/빠른 작업에서 "가정 관리"나 "학사일정"처럼 탭 내부
/// 세그먼트까지 지정해 이동할 때 쓴다. 탭 위젯은 `_buildTabs`가 매 빌드마다 새
/// 인스턴스를 만들지만 State는 유지되므로, 같은 섹션을 연달아 요청해도 반응할 수
/// 있도록 [nonce]로 요청을 구분한다.
class TabSectionRequest {
  const TabSectionRequest({required this.section, required this.nonce});

  final String section;
  final int nonce;

  /// 이전 요청과 다른(= 새로 처리해야 할) 요청인지.
  bool isNewerThan(TabSectionRequest? previous) =>
      previous == null || previous.nonce != nonce;
}
