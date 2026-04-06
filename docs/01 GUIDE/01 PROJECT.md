# Nest 프로젝트 인수인계 문서

> **최종 업데이트**: 2026-04-04
> **현재 버전**: 2.0.5+6
> **브랜드 문장**: "우리 아이가 날아오르기 전, 따뜻한 둥지 Nest"

---

## 1. 프로젝트 개요

Nest(네스트)는 **홈스쿨링 운영 통합 플랫폼**입니다. 단순 LMS가 아니라 **행정(학기/반/시간표/교사 배정) + 관계(공동체/커뮤니티) + 성장기록(미디어/활동)**을 하나의 플랫폼으로 통합합니다.

### 핵심 문제 해결

- 학기/반/수업/교사 배정이 스프레드시트와 메신저에 분산되는 문제
- 시간표 충돌(교사 중복, 반 중복, 시간 겹침) 발생 문제
- 부모/교사가 같은 정보를 실시간으로 확인하기 어려운 문제
- 수업 사진/영상이 개인 폰/클라우드에 분산되어 관리되는 문제

### 대상 사용자 및 역할

| 역할 | 코드 | 설명 |
|---|---|---|
| 홈스쿨 관리자 | `HOMESCHOOL_ADMIN` | 운영 전권 + Drive 연동 관리 |
| 부모 | `PARENT` | 본인 가정/자녀 중심 조회 |
| 교사 | `TEACHER` | 담당 수업/학생 접근 + 미디어 업로드 |
| 초청 교사 | `GUEST_TEACHER` | 초청 범위 교사 권한 |
| 운영 스태프 | `STAFF` | 제한된 운영 지원 권한 |

---

## 2. 기술 스택

### 프론트엔드

| 항목 | 기술 | 버전/상세 |
|---|---|---|
| **프레임워크** | Flutter | SDK ^3.10.7 |
| **언어** | Dart | 3.x |
| **플랫폼** | Web, Android, iOS | 단일 코드베이스 |
| **상태관리** | 자체 구현 (`NestController`) | `ChangeNotifier` 기반 단일 컨트롤러 |
| **BaaS 클라이언트** | `supabase_flutter` | ^2.12.0 |
| **국제화** | `intl` | ^0.20.2 |
| **폰트** | `google_fonts` | ^8.0.2 |
| **파일 선택** | `file_picker` | ^10.3.10 |
| **URL 처리** | `url_launcher` | ^6.3.2 |
| **로컬 저장** | `shared_preferences` | ^2.5.0 |
| **스플래시** | `flutter_native_splash` | ^2.4.7 |
| **앱 아이콘** | `flutter_launcher_icons` | ^0.14.4 |
| **린트** | `flutter_lints` | ^6.0.0 |

### 백엔드

| 항목 | 기술 | 상세 |
|---|---|---|
| **BaaS** | Supabase | 호스팅 서비스 사용 |
| **데이터베이스** | PostgreSQL 17 | Supabase 관리형, RLS 기반 접근제어 |
| **인증** | Supabase Auth | 이메일/비밀번호, PKCE 플로우 |
| **Edge Functions** | Deno 2 (TypeScript) | 4개 함수 배포 |
| **실시간** | Supabase Realtime | 활성화됨 |
| **스토리지** | Supabase Storage | 최대 50MiB 파일 |

### Edge Functions 목록

| 함수 | 용도 |
|---|---|
| `timetable-assistant-generate` | AI 기반 시간표 편성안 생성 |
| `google-drive-connect-start` | Google Drive OAuth 연결 시작 |
| `google-drive-connect-complete` | Google Drive OAuth 연결 완료 |
| `google-drive-upload` | Google Drive 파일 업로드 |

### 인프라 / CI/CD

| 항목 | 기술 |
|---|---|
| **웹 호스팅** | GitHub Pages (`gh-pages` 브랜치) |
| **CI/CD** | GitHub Actions |
| **웹 배포 워크플로우** | `flutter_web_pages.yml` (main 브랜치 push 시 자동) |
| **E2E 테스트 워크플로우** | `remote_e2e.yml` (Supabase 원격 테스트) |
| **배포 URL** | `https://lionandthelab.github.io/nest/` |
| **패키지 ID** | `com.lionandthelab.nest` (Android/iOS 통일) |

---

## 3. 프로젝트 구조

```
nest/
├── .github/workflows/          # CI/CD 워크플로우
│   ├── flutter_web_pages.yml   # Flutter 웹 빌드 → GitHub Pages 배포
│   └── remote_e2e.yml          # Supabase 원격 E2E 테스트
├── docs/                       # 프로젝트 문서
│   ├── 01~10_*.md              # 기획/설계 문서 시리즈
│   ├── architecture.md         # Flutter 아키텍처 상세 문서 (핵심)
│   ├── execution_tracker.md    # 실행 체크리스트/개발 로그
│   └── ...                     # 스토어 제출, 개인정보처리방침 등
├── frontend/                   # Flutter 앱
│   ├── lib/
│   │   ├── main.dart           # 앱 엔트리포인트
│   │   └── src/
│   │       ├── config/         # 앱 설정
│   │       │   └── app_config.dart
│   │       ├── models/         # 데이터 모델
│   │       │   └── nest_models.dart          (1,408줄)
│   │       ├── services/       # 데이터 계층
│   │       │   ├── nest_repository.dart      (2,139줄) Supabase API 래퍼
│   │       │   ├── nest_cache.dart           로컬 캐시
│   │       │   ├── local_planner.dart        (565줄) 로컬 시간표 편성 로직
│   │       │   ├── web_oauth_bridge*.dart    웹 OAuth 브릿지 (조건부 import)
│   │       │   ├── download_helper*.dart     파일 다운로드 헬퍼
│   │       │   └── pwa_install_helper*.dart  PWA 설치 헬퍼
│   │       ├── state/          # 상태관리
│   │       │   └── nest_controller.dart      (5,325줄) 전체 앱 상태 컨트롤러
│   │       └── ui/             # UI 계층
│   │           ├── nest_app.dart             앱 루트 위젯
│   │           ├── nest_theme.dart           테마/디자인 토큰
│   │           ├── login_page.dart           로그인/회원가입
│   │           ├── home_page.dart            (2,748줄) 메인 홈 화면
│   │           ├── widgets/                  공용 위젯
│   │           │   ├── child_selector_header.dart
│   │           │   ├── hub_scaffold.dart
│   │           │   ├── entity_visuals.dart
│   │           │   ├── homeschool_create_dialog.dart
│   │           │   ├── nest_empty_state.dart
│   │           │   ├── nest_motion.dart
│   │           │   ├── nest_refresh.dart
│   │           │   ├── nest_skeleton.dart
│   │           │   └── search_select_field.dart
│   │           ├── tabs/                     탭 화면
│   │           │   ├── dashboard_tab.dart         (1,875줄) 대시보드
│   │           │   ├── family_admin_tab.dart       (3,263줄) 학기 설정 (가정/교사/반/수업/교실)
│   │           │   ├── timetable_tab.dart          (3,480줄) 시간표 스튜디오
│   │           │   ├── teacher_hub_tab.dart        (1,433줄) 교사 허브
│   │           │   ├── community_tab.dart          (828줄) 커뮤니티 관리
│   │           │   ├── community_feed_tab.dart     (745줄) 커뮤니티 피드
│   │           │   ├── members_tab.dart            (764줄) 멤버 관리
│   │           │   ├── profile_settings_tab.dart   (736줄) 프로필 설정
│   │           │   ├── gallery_tab.dart            (562줄) 갤러리
│   │           │   ├── parent_timetable_tab.dart   (611줄) 학부모 시간표
│   │           │   ├── parent_home_tab.dart        (369줄) 학부모 홈
│   │           │   ├── parent_progress_tab.dart    (294줄) 학부모 학습현황
│   │           │   ├── parent_news_tab.dart        (278줄) 학부모 소식
│   │           │   ├── ops_tab.dart                (155줄) 운영/감사로그
│   │           │   ├── drive_tab.dart              Google Drive 설정
│   │           │   └── system_admin_tab.dart       (74줄) 시스템 관리 통합 탭
│   │           └── models/                   UI 전용 모델
│   ├── web/
│   │   ├── index.html
│   │   └── oauth/google/callback.html        OAuth 콜백 페이지
│   ├── test/                   테스트
│   │   ├── widget_test.dart
│   │   └── models_test.dart
│   └── assets/
│       ├── logo.png
│       └── logo_square.png
├── supabase/                   # Supabase 백엔드
│   ├── config.toml             로컬 개발 설정
│   ├── migrations/             DB 마이그레이션 (20개)
│   │   ├── 20260302160000_init_nest.sql              핵심 테이블 + RLS
│   │   ├── 20260302173000_constraints_and_drive_tokens.sql
│   │   ├── 20260303060000_community_sns.sql          커뮤니티(SNS) 테이블
│   │   ├── 20260303130000_homeschool_invites.sql     초대 시스템
│   │   ├── 20260303143000_children_policy_fix.sql
│   │   ├── 20260303145000_child_admin_rpc.sql
│   │   ├── 20260303150000_invite_rpc_fix.sql
│   │   ├── 20260303162000_class_groups_delete_and_member_search.sql
│   │   ├── 20260303190000_member_unavailability_blocks.sql
│   │   ├── 20260306100000_session_location.sql       수업 위치 컬럼
│   │   ├── 20260308201000_family_child_delete_policies.sql
│   │   ├── 20260308223000_courses_delete_policy.sql
│   │   ├── 20260308233000_classrooms.sql             교실 관리
│   │   ├── 20260308235500_family_guardians_delete_policy.sql
│   │   ├── 20260309003000_homeschool_join_requests_and_directory.sql
│   │   ├── 20260309011500_homeschool_invites_name_snapshot.sql
│   │   ├── 20260309020000_teacher_profiles_delete_policy.sql
│   │   ├── 20260323100000_child_registration_requests.sql
│   │   ├── 20260324100000_academic_events.sql        학사일정
│   │   └── 20260324120000_supabase_storage_media.sql 미디어 스토리지
│   └── functions/              Edge Functions
│       ├── _shared/            공용 유틸리티
│       ├── timetable-assistant-generate/
│       ├── google-drive-connect-start/
│       ├── google-drive-connect-complete/
│       └── google-drive-upload/
├── openapi/
│   └── nest-api-v1.yaml        OpenAPI 3.1 명세서
├── scripts/                    운영 스크립트 (Node.js)
│   ├── e2e_remote.mjs          원격 E2E 테스트
│   ├── setup_joy_school.mjs    샘플 홈스쿨 데이터 생성
│   ├── update_joy_school.mjs   샘플 데이터 업데이트
│   ├── create_default_admin.mjs 기본 관리자 생성
│   ├── delete_user.mjs         사용자 삭제
│   ├── export_school_data.mjs  학교 데이터 내보내기
│   ├── check_orphans.mjs       고아 데이터 점검
│   ├── test_queries.mjs        쿼리 테스트
│   └── deploy_supabase.sh      Supabase 배포 스크립트
├── screenshots/                스토어 스크린샷
└── CHANGELOG.md                변경 이력
```

**총 소스 코드**: 약 30,693줄 (Dart 프론트엔드 기준)

---

## 4. 아키텍처

### 4.1 전체 아키텍처

```
┌──────────────────────────────────────────────────┐
│                   클라이언트                        │
│  Flutter (Web / Android / iOS) - 단일 코드베이스     │
│  ┌─────────┐  ┌──────────┐  ┌────────────────┐   │
│  │ UI Layer│→ │Controller│→ │  Repository    │   │
│  │ (Tabs)  │  │ (State)  │  │  (Supabase)    │   │
│  └─────────┘  └──────────┘  └───────┬────────┘   │
└─────────────────────────────────────┼────────────┘
                                      │
                                      ▼
┌──────────────────────────────────────────────────┐
│                   Supabase                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │   Auth   │  │ Postgres │  │Edge Functions│   │
│  │  (PKCE)  │  │  + RLS   │  │  (Deno 2)    │   │
│  └──────────┘  └──────────┘  └──────────────┘   │
│  ┌──────────┐  ┌──────────┐                      │
│  │ Realtime │  │ Storage  │                      │
│  └──────────┘  └──────────┘                      │
└──────────────────────────────────────────────────┘
                      │
                      ▼
          ┌──────────────────┐
          │  Google Drive API │
          │  (OAuth + Upload) │
          └──────────────────┘
```

### 4.2 프론트엔드 아키텍처 (레이어 구조)

| 레이어 | 역할 | 핵심 파일 |
|---|---|---|
| **UI** | 화면 렌더링, 사용자 인터랙션 | `ui/tabs/*.dart`, `ui/widgets/*.dart` |
| **State** | 앱 전체 상태 관리 (단일 컨트롤러) | `state/nest_controller.dart` |
| **Service** | Supabase API 호출, 로컬 캐시 | `services/nest_repository.dart`, `nest_cache.dart` |
| **Model** | 데이터 모델 정의 | `models/nest_models.dart` |
| **Config** | 환경 설정, 상수 | `config/app_config.dart` |

### 4.3 상태관리 패턴

- **단일 컨트롤러**: `NestController`가 `ChangeNotifier`를 상속하여 앱 전체 상태를 관리
- 관리 대상: 인증 세션, 홈스쿨/학기/반 컨텍스트, 뷰 역할, 시간표, 갤러리, 커뮤니티, 멤버십 등
- **뷰 역할 전환**: 한 사용자가 복수 역할(관리자+부모+교사)을 가질 수 있으며, UI에서 실시간 전환 가능

### 4.4 데이터베이스 보안 모델

- **RLS (Row Level Security)**: 모든 테이블에 적용되어 역할별 데이터 접근 제어
- **Security-definer RPC**: 복잡한 트랜잭션은 RPC 함수로 처리
  - `accept_homeschool_invite`, `create_child_admin`, `search_homeschool_members`, `search_homeschool_directory`
- **멀티 테넌시**: 모든 데이터는 `homeschool_id` 기준으로 논리적 격리

---

## 5. 핵심 데이터 모델

### 계정/조직

- `users` - 사용자 계정
- `homeschools` - 홈스쿨 기관
- `homeschool_memberships` - 소속/역할 매핑
- `families` - 가정
- `family_guardians` - 보호자-가정 연결
- `children` - 아이

### 운영

- `terms` - 학기 (DRAFT/ACTIVE/ARCHIVED)
- `class_groups` - 반
- `class_enrollments` - 아이-반 배정
- `courses` - 수업 과목
- `classrooms` - 교실
- `teacher_profiles` - 교사 프로필
- `member_unavailability_blocks` - 불가 시간
- `time_slots` - 시간 슬롯
- `class_sessions` - 수업 세션
- `session_teacher_assignments` - 교사 배정
- `timetable_proposals` - AI 편성안

### 학습/기록

- `teaching_plans` - 수업 계획
- `student_activity_logs` - 활동 기록
- `announcements` - 공지
- `academic_events` - 학사일정
- `audit_logs` - 감사 로그

### 커뮤니티

- `community_posts` - 게시글
- `community_post_comments` - 댓글
- `community_post_reactions` - 반응
- `community_reports` - 신고

### 미디어/Drive

- `drive_integrations` - Drive 연동 설정
- `media_assets` - 미디어 자산

### 가입/초대

- `homeschool_invites` - 초대
- `homeschool_join_requests` - 가입 요청
- `child_registration_requests` - 자녀 등록 요청

---

## 6. 주요 기능

### 6.1 인증 및 온보딩

- 이메일/비밀번호 로그인 (Supabase Auth, PKCE 플로우)
- 비밀번호 재설정 이메일 요청
- 온보딩 3가지 경로:
  - 초대 수락 (이메일 기반)
  - 홈스쿨 검색 → 가입 요청
  - 새 홈스쿨 직접 개설

### 6.2 역할 기반 동적 UI

- **관리자/스태프 레이아웃**: 대시보드 → 학기 설정 → 시간표 → 시스템
- **학부모/교사 레이아웃**: 대시보드 → 허브 → 시간표 → 갤러리 → 커뮤니티
- 역할별 탭 동적 구성 (`HomePage._buildTabs`)
- 상단 컨텍스트 카드로 홈스쿨/학기/반/뷰 역할 빠른 전환

### 6.3 학기 설정 (Term Setup)

- **가정 관리**: 가정 생성/수정/삭제, 보호자 계정 연결
- **아이 관리**: 아이 등록/수정/삭제, 가정 재배정
- **교사 관리**: 교사 프로필, 계정 연결, 불가 시간 설정
- **반 관리**: 반 생성/수정/삭제, 아이 배정 (멀티셀렉트)
- **수업 관리**: 수업 과목 CRUD
- **교실 관리**: 교실 CRUD, 시간표와 연동
- KPI 지표 카드 (가정수, 아이수, 보호자수, 교사수, 반수, 수업수, 교실수)

### 6.4 시간표 스튜디오 (핵심 기능)

- **드래그앤드롭 편성**: 반별 주간 시간표 보드
  - 수업 팔레트에서 드래그 → 세션 생성
  - 세션 카드 드래그 → 이동
  - 교사/교실 팔레트에서 드래그 → 배정
- **세션별 설정**: 메인/보조 교사, 교실 배정
- **충돌 검증**: 동일 시간 교사/반 중복 차단
- **수정 확정**: 드래프트 라이프사이클 관리
- **내보내기**: 시간표 PNG 출력, 교실 상황표 출력
- **팔레트 퀵 관리**: 시간표 화면에서 바로 수업/교사/교실 추가/삭제

### 6.5 학부모 뷰

- 자녀 선택 헤더 (전역 상단바)
- 주간 시간표 보드 (요일 x 교시)
- 학습 현황 조회
- 최신 공지 미리보기
- 불가 시간 등록/삭제 (본인 계정)

### 6.6 교사 허브

- 반 운영보드 / 수업 운영 / 아이 상태 섹션
- 수업 계획 작성 (세션별)
- 학생 활동 기록 작성
- 공지 작성
- 불가 시간 등록/삭제

### 6.7 커뮤니티 (SNS)

- **사용자**: 게시글 작성, 좋아요, 댓글, 신고
- **관리자**: 신고 대기열, 게시글 숨김/고정/삭제, 운영 지표

### 6.8 Google Drive 연동

- OAuth 연결 (Edge Function 기반)
- 루트 폴더 설정 + 폴더 정책
- 교사용 미디어 업로드 → Drive 자동 저장
- 권한 기반 갤러리 조회

### 6.9 멤버 관리

- 역할 부여/해제
- 이메일 기반 초대 발송/취소
- 가입 요청 승인/거절
- 자기 계정 역할 전환 (관리자용)
- 마지막 관리자 삭제 방지 가드레일

---

## 7. 환경 변수 및 설정

### 빌드 시 필수 (dart-define)

| 변수 | 설명 | 기본값 |
|---|---|---|
| `SUPABASE_URL` | Supabase 프로젝트 URL | `app_config.dart`에 하드코딩 |
| `SUPABASE_ANON_KEY` | Supabase 익명 키 | `app_config.dart`에 하드코딩 |

### 선택 (dart-define)

| 변수 | 설명 | 기본값 |
|---|---|---|
| `AUTH_EMAIL_REDIRECT_URL` | 웹 인증 리다이렉트 | `https://lionandthelab.github.io/nest/` |
| `AUTH_EMAIL_REDIRECT_URL_MOBILE` | 모바일 딥링크 | `com.lionandthelab.nest://login-callback/` |

### CI/CD Secrets (GitHub Actions)

| Secret | 용도 |
|---|---|
| `SUPABASE_URL` | 원격 E2E 테스트용 |
| `SUPABASE_ANON_KEY` | 원격 E2E 테스트용 |
| `SUPABASE_SERVICE_ROLE_KEY` | 원격 E2E 테스트용 (관리 작업) |

---

## 8. 빌드 및 배포

### 로컬 개발

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
flutter run -d chrome  # 웹 실행
```

### 빌드 명령어

```bash
# 웹 빌드
flutter build web --release --base-href /nest/

# Android 앱 번들
flutter build appbundle --release

# iOS 빌드
flutter build ios --release --no-codesign
```

### 배포 파이프라인

1. **웹**: `main` 브랜치에 `frontend/**` 변경 push → GitHub Actions → `gh-pages` 자동 배포
2. **E2E**: `main` 브랜치에 `supabase/**` 또는 `scripts/e2e_remote.mjs` 변경 push → 원격 Supabase E2E 자동 실행
3. **Android/iOS**: 수동 빌드 후 스토어 제출

### Android 서명

- `android/key.properties` 존재 시 릴리스 서명 사용
- 미존재 시 디버그 서명으로 폴백

---

## 9. 브랜치 전략

| 브랜치 | 용도 |
|---|---|
| `main` | 프로덕션 배포 브랜치 |
| `develop` | 개발 통합 브랜치 (현재 작업 브랜치) |
| `gh-pages` | GitHub Pages 배포 (자동 생성) |
| `feature/*` | 기능 개발 브랜치 |

---

## 10. 운영 스크립트

`scripts/` 디렉토리의 Node.js 스크립트로 운영 작업 수행:

| 스크립트 | 용도 |
|---|---|
| `setup_joy_school.mjs` | 샘플 홈스쿨("기쁨의 샘") 데이터 자동 생성 |
| `update_joy_school.mjs` | 샘플 데이터 업데이트 |
| `create_default_admin.mjs` | 기본 관리자 계정 생성 |
| `delete_user.mjs` | 사용자 계정 삭제 |
| `export_school_data.mjs` | 홈스쿨 데이터 내보내기 |
| `check_orphans.mjs` | 고아 데이터(참조 끊긴 레코드) 점검 |
| `test_queries.mjs` | DB 쿼리 테스트 |
| `e2e_remote.mjs` | 원격 Supabase 대상 E2E 통합 테스트 |
| `deploy_supabase.sh` | Supabase 배포 자동화 |

---

## 11. 디자인 시스템

### 컬러 팔레트 (Warm Nest)

| 이름 | 코드 | 용도 |
|---|---|---|
| Dusty Rose (Main) | `#DCAE96` | 주요 CTA, 브랜드 바 |
| Creamy White (Base) | `#F9F7F2` | 페이지/카드 배경 |
| Deep Wood (Point) | `#5E4636` | 보조 버튼, 상태 뱃지 |
| Muted Sage (Point) | `#7D9272` | 그래프 포인트, 성공 상태 |
| Text Main | `#2E2A27` | 본문 텍스트 |
| Text Sub | `#6C625C` | 보조 텍스트 |

### UI/UX 원칙

- **카드 퍼스트 레이아웃**: 인지 부하 최소화
- **섹션 칩 네비게이션**: `ChoiceChip`으로 섹션 전환
- **모달 기반 CRUD**: 카드 클릭 → 통합 생성/수정 다이얼로그
- **반응형 디자인**: 데스크톱/모바일 동적 레이아웃 조정
- **한국어 우선 IA**: 대시보드, 학기 설정, 시간표, 시스템 등

---

## 12. 관련 문서 가이드

| 문서 | 설명 | 중요도 |
|---|---|---|
| `docs/architecture.md` | Flutter 아키텍처 상세 (가장 중요) | ★★★ |
| `docs/02_prd_mvp.md` | 제품 요구사항 정의서 | ★★★ |
| `docs/04_data_model_and_erd.md` | 데이터 모델/ERD | ★★★ |
| `docs/03_information_architecture_and_permissions.md` | 권한 체계 | ★★☆ |
| `docs/07_system_architecture_and_integration.md` | 시스템 아키텍처 초안 | ★★☆ |
| `docs/01_product_vision_and_brand.md` | 브랜드/비전 | ★☆☆ |
| `docs/05_timetable_assignment_engine.md` | 시간표 엔진 상세 | ★★☆ |
| `openapi/nest-api-v1.yaml` | OpenAPI 명세 | ★★☆ |
| `docs/execution_tracker.md` | 실행 체크리스트/로그 | ★☆☆ |

### 권장 읽기 순서

1. **이 문서** (전체 개요 파악)
2. `architecture.md` (프론트엔드 구조 상세)
3. `02_prd_mvp.md` (요구사항 이해)
4. `04_data_model_and_erd.md` (데이터 구조)
5. `03_information_architecture_and_permissions.md` (권한 체계)

---

## 13. 알려진 제약사항 및 기술 부채

### 현재 제약사항

- MVP에서 **결제/정산, 화상수업, 고급 AI 추천, 다국어** 제외
- 부모는 미디어 **조회만** 가능 (업로드 권한 미결)
- Drive 저장 폴더 구조 정책 ("학기/반/날짜" vs "반/아이/날짜") 미확정

### 기술 부채

- `NestController`가 5,325줄로 단일 파일에 전체 상태 집중 → 분리 필요 가능성
- `family_admin_tab.dart`(3,263줄), `timetable_tab.dart`(3,480줄), `home_page.dart`(2,748줄) 등 대형 파일 존재
- `class_sessions.location` 컬럼 호환성 폴백 로직 유지 중
- Supabase `anon_key`가 `app_config.dart`에 하드코딩 (dart-define으로 오버라이드 가능하나 기본값 노출)

---

## 14. 연락처 및 조직 정보

- **조직**: Lion and the Lab (`lionandthelab`)
- **GitHub**: `lionandthelab/nest`
- **배포 URL**: `https://lionandthelab.github.io/nest/`
- **Supabase 프로젝트**: `avursvhmilcsssabqtkx`
