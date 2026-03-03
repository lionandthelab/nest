# Nest Execution Tracker

Last updated: 2026-03-03

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
- [x] 커뮤니티 피드(글/댓글/좋아요/신고)
- [x] SNS Admin 모더레이션(신고 처리/숨김/고정/삭제)
- [x] Google Drive OAuth 연동 + 업로드 + 갤러리
- [x] 관리자 멤버 권한 관리(UUID 기준 부여/회수)
- [x] 이메일 초대 기반 멤버 온보딩(생성/취소/수락)
- [x] 가족/아이/반 배정 관리 UI 고도화
- [x] 반(Class) CRUD(생성/수정/삭제) + 반별 시간표 연계 운영
- [x] 수업별 주강사/보조강사 배정 UI + 충돌 시각화 고도화
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

## Next Batch

1. 다국어(i18n) 범위 정의 및 적용(현재 제외)
2. 결제/정산 도메인 설계 및 구현(현재 제외)
