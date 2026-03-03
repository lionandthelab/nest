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
- [x] 커뮤니티 피드(글/댓글/좋아요/신고)
- [x] SNS Admin 모더레이션(신고 처리/숨김/고정/삭제)
- [x] Google Drive OAuth 연동 + 업로드 + 갤러리
- [x] 관리자 멤버 권한 관리(UUID 기준 부여/회수)
- [x] 이메일 초대 기반 멤버 온보딩(생성/취소/수락)
- [x] 가족/아이/반 배정 관리 UI 고도화
- [x] 수업별 주강사/보조강사 배정 UI + 충돌 시각화 고도화
- [x] 교사 학기 계획표/아동 활동기록 작성 UI
- [x] 운영 감사로그/알림(권한 변경, 신고 처리, 시간표 확정 이벤트)
- [x] 원격 E2E 자동화(핵심 시나리오 CI 내 상시 검증)

## Iteration Log

| Date | Scope | Result | Verification |
|---|---|---|---|
| 2026-03-02 | Flutter 전환, OAuth/Drive/GH Pages 파이프라인 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/`, `flutter build apk --debug`, `flutter build ios --simulator --no-codesign`, `node scripts/e2e_remote.mjs` |
| 2026-03-03 | 역할 기반 사용자/관리자 뷰 + SNS 관리 탭 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release` |
| 2026-03-03 | 이메일 초대 플로우(관리자 생성·취소, 사용자 수락) | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/`, `supabase db push` |
| 2026-03-03 | 가족/아이/반 배정, 교사배정 UI, 계획/활동기록, 공지/감사로그, 원격E2E 자동화 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/`, `supabase db push`, `node scripts/e2e_remote.mjs` |

## Next Batch

1. 다국어(i18n) 범위 정의 및 적용(현재 제외)
2. 결제/정산 도메인 설계 및 구현(현재 제외)
