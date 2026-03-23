# Changelog

## 2.0.5+6 — 2026-03-23

### Changed
- 교실 상황표 리디자인: 요일 기반 → 교실명 컬럼 기반으로 변경 (시간별 교실 사용 현황 한눈에 확인)
- 모바일 시간표 팔레트: Wrap 뱃지 → ExpansionTile 드롭다운으로 변경 (세로 공간 절약)
- 미사용 cellData 변수 제거

### Fixed
- 학부모 시간표 뷰 크래시 방어: board/card 렌더링에 try-catch 래핑으로 오류 시 메시지 표시

## 2.0.4+5 — 2026-03-22

### Fixed
- DropdownButtonFormField<String> → <String?> 타입 수정 (nullable value 크래시 해결)
- AlertDialog.actions 내 Spacer 크래시 수정 (OverflowBar 호환)
- 부모뷰 '반 배정 대기 중' 안내 배너 추가

## 2.0.3+4 — 2026-03-22

### Fixed
- const 리스트 sort 크래시 수정
- 부모뷰 시간표 스크롤 개선

## 2.0.2+3 — 2026-03-21

### Added
- 30분 슬롯 기반 시간표 + Joy School 데이터 셋업 스크립트

### Fixed
- 시간표 그리드 시간 정렬 + 요일 표시 + 선생님 삭제 + 데이터 정리
