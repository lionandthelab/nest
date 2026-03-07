# Nest Execution Tracker

Last updated: 2026-03-07

## Scope

- In scope: Nest 플랫폼 기능 전체(운영/시간표/커뮤니티/갤러리/권한)
- Excluded for now: `다국어(i18n)`, `결제`

## Tracking Rules

- 기능 단위로 구현 후 문서에 즉시 누적 기록
- 모든 배치에서 테스트를 추가/실행하고 결과를 남김
- 아키텍처 변경 시 `docs/architecture.md` 동시 업데이트

## Master Checklist (No i18n/Payment)

- [x] Flutter 단일 코드베이스(웹/모바일) 전환
- [x] Supabase Auth 로그인/회원가입
- [x] 역할 기반 뷰 전환(Parent/Teacher/Admin)
- [x] 역할별 동적 탭 구성
- [x] 시간표 Prompt 생성 + 수동 DnD 편집
- [x] 관리자 질문형 스케줄 생성기(다중 초안/충돌 점검/보정 편집)
- [x] 과목 가중치/교사 선호 기반 스케줄링 엔진
- [x] 커뮤니티 피드(글/댓글/좋아요/신고)
- [x] SNS Admin 모더레이션(신고 처리/숨김/고정/삭제)
- [x] Google Drive OAuth 연동 + 업로드 + 갤러리
- [x] 관리자 멤버 권한 관리(UUID 기준 부여/회수)
- [x] 이메일 초대 기반 멤버 온보딩(생성/취소/수락)
- [x] 가족/아이/반 배정 관리 UI 고도화
- [x] 반(Class) CRUD(생성/수정/삭제) + 반별 시간표 연계 운영
- [x] 수업별 주강사/보조강사 배정 UI + 충돌 시각화 고도화
- [x] 교사/부모 불가 시간 등록 + 스케줄 자동 회피(관리자/본인 self-service)
- [x] 교사 계정 검색 자동완성(이름/이메일/UUID) + 계정 없는 초청교사 등록
- [x] 교사 학기 계획표/아동 활동기록 작성 UI
- [x] 운영 감사로그/알림(권한 변경, 신고 처리, 시간표 확정 이벤트)
- [x] 원격 E2E 자동화(핵심 시나리오 CI 내 상시 검증)
- [x] Drive 설정 간소화 + 개발자 고급 메뉴 분리(기본 숨김)

## Iteration Log

| Date | Scope | Result | Verification |
|---|---|---|---|
| 2026-03-02 | Flutter 전환, OAuth/Drive/GH Pages 파이프라인 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/`, `flutter build apk --debug`, `flutter build ios --simulator --no-codesign`, `node scripts/e2e_remote.mjs` |
| 2026-03-03 | 역할 기반 사용자/관리자 뷰 + SNS 관리 탭 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release` |
| 2026-03-03 | 이메일 초대 플로우(관리자 생성·취소, 사용자 수락) | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/`, `supabase db push` |
| 2026-03-03 | 가족/아이/반 배정, 교사배정 UI, 계획/활동기록, 공지/감사로그, 원격E2E 자동화 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/`, `supabase db push`, `node scripts/e2e_remote.mjs` |
| 2026-03-03 | 원격E2E GitHub Actions 워크플로 파싱 오류 수정(`secrets` 직접 조건식 제거) | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/` |
| 2026-03-03 | 원격E2E 스크립트 CI 경로 하드코딩 제거(콜백 파일 검증 경로 이식성 수정) | 완료 | `node scripts/e2e_remote.mjs`, GitHub Actions `Remote Supabase E2E` run `22607933835` 성공 |
| 2026-03-03 | 어드민 반 CRUD + 교사 계정 검색 연결 UX 개선 | 코드 완료 (DB 마이그레이션 파일 추가, `supabase db push`는 권한/DB 비밀번호 이슈로 미실행) | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/`, `node scripts/e2e_remote.mjs`, GitHub Actions `Remote Supabase E2E` run `22609099078` 성공 |
| 2026-03-03 | 관리자 스케줄 UX 고도화(질문형 초안/다중 대안/실시간 충돌 검증) + 반/교사 질문형 일괄 생성 + Drive 고급 설정 숨김 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/` |
| 2026-03-03 | 스케줄 엔진 고도화(과목 빈도 가중치 + 교사 선호 전략) 및 원격 E2E 재검증 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/`, `SUPABASE_* node scripts/e2e_remote.mjs`, GitHub Actions `Remote Supabase E2E` run `22610640069` 성공, `Deploy Flutter Web to GitHub Pages` run `22610637304` 성공 |
| 2026-03-03 | 교사/부모 불가 시간 등록(관리자+본인) 및 스케줄 자동 회피/충돌 검증 고도화 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/`, `supabase db push`, `SUPABASE_* node scripts/e2e_remote.mjs` |
| 2026-03-03 | `class_sessions_source_type_check` 오류 수정(`ASSISTED` -> `AI_PROMPT`) + 관리자 대시보드 단계형 학기 설정 가이드(순번/완료표시/탭 이동) 추가 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/` |
| 2026-03-03 | 관리자 UI/UX 재구성: 상위 탭 축소(`Term Setup`/`Schedule`/`System`), 학기 설정 단위 분리(가정/선생님/반/과목), 시스템 설정 통합(Drive+SNS+권한+운영) | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/`, `SUPABASE_* node scripts/e2e_remote.mjs` |
| 2026-03-03 | 시간표 편집 UX 재설계: 과목 팔레트 + 그리드 시간표(day x period) 기반 드래그앤드롭 스튜디오 및 시각적 세션 카드 개선 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/` |
| 2026-03-03 | 부모/교사 허브 UX 통일(공통 섹션형 레이아웃) + 전역 로딩/전환 모션 시스템 적용 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/` |
| 2026-03-03 | Parent Hub 아이별 뷰(소속 반/반별 시간표/상태 로그) + Teacher Hub 담당 반별 뷰(시간표/공지/아동 상태 관리) 고도화 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/` |
| 2026-03-03 | 시간표 UX 강화: 단계형 초안 위자드 + 메인보드 프롬프트 액션바 + 반/교사 상황패널(웹 사이드바/모바일 모달) 추가 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/` |
| 2026-03-03 | DnD 세션 생성 `location` 스키마 호환 수정(컬럼 없음/NOT NULL 대응) + `supabase db push`로 세션 위치 마이그레이션 적용 + 상단 컨텍스트 카드형 UX/도움말 개편 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/`, `supabase db push` |
| 2026-03-07 | 관리자/교사/학부모 선택 UX 고도화: 공용 검색 선택 시트 + 카드형 선택 필드 도입, Term Setup/Teacher Hub/Child Selector의 드롭다운 중심 입력 제거 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/` |
| 2026-03-07 | UI 반복개선 100회 루프 수행(분석/개선제안/피드백) + 공통 UI 폴리시 적용(테마 통일, 반응형 헤더, 허브/시스템 탭 반응형 섹션 전환, 본문 폭 최적화) | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/` |

## Next Batch

1. 다국어(i18n) 범위 정의 및 적용(현재 제외)
2. 결제/정산 도메인 설계 및 구현(현재 제외)
