# Nest 관리자(웹) 시간표 빌더 + 오브젝트 관리 — 재설계 스펙

> 승인된 설계 방향 (오너 결정: 전체 Phase 1~4 구현 · 하드 `deleteSession` 추가 · `TimetableTab` 인플레이스 업그레이드).
> UI/UX 설계팀(디자이너 4안 → 심사 3인 → 리드 종합) 산출물. 심사 만장일치 백본 = "충돌 없는 드래그 빌더(D)" + A·C·B 접목.

## 1. 한 줄 요약
기존 `timetable_tab.dart`의 검증된 `_draftSessions`/`_draftAssignments`/`_commitDraftChanges` 2단계 버퍼 위에 얹어:
- `LongPressDraggable` → 즉시 `Draggable` 전면 교체, 셀 `onWillAcceptWithDetails`를 실시간 충돌 상태 enum으로 승격.
- **A 접목**: 반|장소|선생 3축 피벗을 **읽기 전용 전교 오버레이**로 추가(쓰기는 선택 반 드래프트로만).
- **C 접목**: 오브젝트-우선 인스펙터를 우측 레일에 흡수(반/선생/가정 클릭 → FK 관계 펼침).
- **B 접목**: 벌크 파워무브(요일/주 전체 적용·복제)를 스프레드시트가 아닌 컨텍스트 메뉴로.
- 새 상태 라이브러리 0개, 백엔드 신규는 `deleteSession`(필수) + 배치 커밋 RPC(Phase 4).

## 2. 정보 구조 (IA)
데스크톱-웹 워크스페이스(≥1280px 1차, `isMobileLike`<1080 → 기존 단일 컬럼 폴백). 4영역 단일 화면:
- A 상단 컨텍스트 바: 학기 선택 · 오브젝트 관리 바로가기 · 실행취소/다시실행 · 반 전환 칩 + [전교 보기 ◇] 토글
- B 좌 팔레트: 수업 카드 조립기 + 과목·선생·장소 칩(개별 드래그)
- C 메인 그리드: 시간표 보드 / 전교 피벗 보드(반|장소|선생 축) + 드래그-투-트래시
- D 우 인스펙터 레일: 오브젝트 한눈에 관리(클릭 → 관계 펼침)

내비게이션 = 탭이 아니라 "모드 + 축":
| 모드 | 진입 | 그리드 | 쓰기 |
|---|---|---|---|
| 반 빌드(기본) | 반 칩 클릭 | 요일×교시 (선택 반) | ✅ 드래프트 |
| 전교-반 축 | [전교 보기] | 요일×교시 × 반 컬럼 | ❌ 읽기 전용 |
| 전교-장소 축 | 축 토글 | 장소 컬럼 | ❌ |
| 전교-선생 축 | 축 토글 | 선생 컬럼 + 불가시간 음영 | ❌ |

**안전장치**: 전교 보기는 읽기 전용. 충돌을 "발견"하면 반 칩 클릭 → 빌드 모드로 내려와 수정. (`createSessionByCourse`/`moveSession`이 `selectedClassGroupId` 고정.)

## 3. "수업 카드 조립" 플로우 (2단계 모달 제거)
1. 팔레트 조립기에 과목(필수)+주강사(선택)+장소(선택) 인라인 입력.
2. [카드 만들기] → `ComposedSessionPayload{courseId, teacherProfileId?, location?}` 칩 생성.
3. 빈 셀에 **한 번의 드래그**로 완성 세션 배치.
4. 개별 과목/선생/장소 칩도 별도 드래그 소스로 유지 → 기존 세션 타일에 떨어뜨려 속성 1개만 교체.

## 4. 드래그앤드롭 인터랙션 모델
모든 드래그는 `Draggable`(delay 0). ARCHIVED 학기면 드래그 불가 + frosted overlay + 배너 + 커밋 비활성.

| # | 소스 | 페이로드 | 드롭 타깃 | 결과(드래프트) |
|---|---|---|---|---|
| 1 | 조립 수업 카드 | ComposedSessionPayload | 빈 셀 | `_EditableSession(isNew)` + MAIN 배정 + location |
| 2 | 과목 칩 | DragPayload(course) | 빈 셀 | `_EditableSession(isNew, course만)` |
| 3 | 선생 칩 | DragPayload(teacher) | 타일 "교사 교체" 서브존 | `_setMainTeacher` / ASSISTANT 추가 |
| 4 | 장소 칩 | DragPayload(room) | 타일 📍 배지 | `_setSessionLocation` |
| 5 | 세션 타일 | DragPayload(session) | 다른 빈 셀 | `timeSlotId` 변경(move) |
| 6 | 세션 타일 | DragPayload(session) | 🗑 트래시 존 | `_deletedDraftIds` → 커밋 시 `deleteSession` |
| 7 | 학생 카드 | DragPayload(child) | 반 드롭존 | `syncClassEnrollments(diff)` |

**LIVE 충돌(드롭 전)**: 셀 진입 시 `_evaluateDropConflict(slotId, payload)` 동기 호출 → `DropConflictState{empty/occupied/teacherConflict/validWithWarning}`. 빨강=거부+흔들림, 노랑=경고+허용, 초록=가능(광채). `_EditableSession → ScheduleOptionSession` 어댑터로 `local_planner.evaluateScheduleOptionIssues`에 **제안 세션 교사를 `sessions` 인자에 주입**(existingSessions만 바꾸면 SLOT_OCCUPIED만 잡힘). `allTermSessions`로 전교 범위.

**삭제**: 드래그 시작 시 트래시 존 등장. 커밋 시 하드 `deleteSession`(현 `cancelSession`은 CANCELED 잔존).
**Undo/Redo**: `_undoStack:List<_DraftSnapshot>`(max 30) + Ctrl+Z/Ctrl+Shift+Z. 클라이언트 전용.
**벌크**: 세션 ⋮ 메뉴 = [이 요일 전체]/[이 교시 모든 요일]/[주 채우기]/[복제]. 빈 셀에만 `createSessionByCourse` 루프, 점유/충돌 셀 스킵.

## 5. 핵심 컴포넌트
| 컴포넌트 | 목적 | 기존/신규 |
|---|---|---|
| `TimetableTab`/`_TimetableTabState` | 4영역 셸 + undo/conflict/deleted 상태 | 기존 확장 |
| `ComposedSessionPayload` | 과목+선생+장소 한 드래그 운반 | 신규(models) |
| `ComposedSessionCard` | 팔레트 조립 폼 + 조립 칩 | 신규 |
| `DropConflictState` enum + `_evaluateDropConflict` | 드래그-타임 프리플라이트 | 신규 |
| `_EditableSession→ScheduleOptionSession` 어댑터 | 충돌엔진 입력 변환 | 신규(필수) |
| `_TrashZone` | 드래그 중 삭제 타깃 | 신규 |
| `_ClassSwitcherStrip` | 반 칩 + [전교 보기] + ARCHIVED 락 | 추출·승격 |
| `WholeSchoolOverlayBoard` + `AxisToggle` | 읽기전용 전교 피벗(반/장소/선생) | 신규 |
| `ObjectInspectorRail` | 반/선생/가정 클릭→관계 펼침 | 신규(C) |
| `FamilyEnrollmentPanel` | 학생 카드→반 드롭(`syncClassEnrollments`) | 신규 |
| `_DraftSnapshot` | undo 스냅샷 | 신규 |
| `RoomNormalizer` | location trim+case-fold | 신규 유틸 |

## 6. API 매핑 & 백엔드
UI는 `NestController`만 호출. 기존 메서드로 충분:
`changeTerm/changeClassGroup`, `createSessionByCourse`, `moveSession`, `updateSessionLocation`, `assignTeacherToSession/removeTeacherFromSession`, `syncClassEnrollments`, `regenerateTimeSlots`, 컬렉션 `sessions/allTermSessions/classEnrollments/...`, `local_planner.evaluateScheduleOptionIssues`.

백엔드 신규:
1. **`deleteSession(sessionId)` 하드 삭제 — REQUIRED (Phase 1)**: repo `DELETE FROM class_sessions WHERE id=`; controller `deleteSession`. admin DELETE RLS 기존 존재 → RLS 변경 불필요.
2. **배치 커밋 RPC `apply_timetable_draft(...)` — Phase 4**: 단일 트랜잭션으로 N개 세션 생성/이동/삭제 + 배정 적용(지터·fuzzy-match 부채 해소).
3. (선택) 충돌 프리플라이트 RPC, MemberUnavailabilityBlock CRUD.
location의 `classroom_id` FK 정규화는 보류(RoomNormalizer로 충분).

## 7. 단계별 구현 계획
- **Phase 1 드래그 빌더 코어**: Draggable 교체·수업카드 조립·실시간 충돌·트래시·Undo·ARCHIVED 락 + `deleteSession`. 파일: `timetable_tab.dart`(주), `nest_controller.dart`, `nest_repository.dart`, `local_planner.dart`(어댑터 호출부).
- **Phase 2 인스펙터 레일 + 전교 읽기 오버레이**: `ObjectInspectorRail`, `_ClassSwitcherStrip`+[전교 보기], `WholeSchoolOverlayBoard`+`AxisToggle`, `RoomNormalizer`.
- **Phase 3 오브젝트 워크스페이스**: `FamilyEnrollmentPanel`(드래그 등록), 인스펙터 인라인 편집, FamilyAdminTab 바로가기.
- **Phase 4 벌크/템플릿 + 배치 RPC**: 세션 컨텍스트 메뉴, `apply_timetable_draft` 마이그레이션 + repo/controller 래퍼.

모바일: 전 Phase `isMobileLike(<1080)` → 기존 단일 컬럼 폴백, 우측 레일 collapse.

## 8. 제약 (불변)
- 레이어링 UI→State→Service→Model 절대. UI는 컨트롤러만.
- 단일 ChangeNotifier `NestController`, 새 상태 라이브러리 금지. 기존 드래프트 버퍼 패턴 계승.
- `NestColors` 토큰만(하드코딩 색상 금지). 한국어 우선.
- 백엔드 불변식: (class_group_id,time_slot_id) 유니크 · 세션당 MAIN 1 · 교사 슬롯 더블부킹 트리거 · ARCHIVED=읽기전용 · location=자유 TEXT.
