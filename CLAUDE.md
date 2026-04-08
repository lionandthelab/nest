# Nest - Claude Code 협업 가이드

> 이 파일은 Claude Code 에이전트가 Nest 프로젝트에서 코드를 생성, 수정, 리뷰할 때 참조하는 핵심 규칙입니다.
> **모든 팀원의 에이전트는 코드 작성 전 반드시 이 파일을 읽어야 합니다.**

---

## 프로젝트 개요

**Nest**는 홈스쿨링 운영 통합 플랫폼입니다.
- 행정(학기/반/시간표/교사 배정) + 관계(커뮤니티) + 성장기록(미디어/활동)을 하나의 앱으로 통합
- Flutter 단일 코드베이스 (Web / Android / iOS)
- Supabase BaaS (PostgreSQL + RLS + Edge Functions + Storage)
- 한국어 우선 UI, 영어 폴백

### 핵심 문서 (반드시 참조)

| 문서 | 경로 | 설명 |
|---|---|---|
| 아키텍처 | `docs/architecture.md` | 프론트엔드 구조, 기능별 상세 설계 |
| 프로젝트 인수인계 | `docs/01 GUIDE/01 PROJECT.md` | 전체 프로젝트 개요 |
| 데이터 모델 | `docs/04_data_model_and_erd.md` | ERD 및 테이블 관계 |
| 권한 체계 | `docs/03_information_architecture_and_permissions.md` | 역할별 접근 권한 |
| OpenAPI | `openapi/nest-api-v1.yaml` | API 명세 |

---

## 1. 아키텍처 규칙

### 레이어 구조 (절대 위반 금지)

```
UI (tabs/, widgets/)
  ↓ 호출만 가능
State (nest_controller.dart)
  ↓ 호출만 가능
Service (nest_repository.dart, nest_cache.dart, local_planner.dart)
  ↓ 호출만 가능
Model (nest_models.dart)
```

- **UI → State → Service → Model** 방향으로만 의존
- UI 레이어에서 Supabase 클라이언트를 직접 호출하지 않는다
- Model은 다른 레이어를 import하지 않는다
- Service는 UI를 import하지 않는다

### 상태관리

- **ChangeNotifier 기반 단일 컨트롤러** (`NestController`) 패턴 유지
- Riverpod, GetX, Bloc 등 다른 상태관리 라이브러리 도입 금지
- 새 기능의 상태는 `NestController`에 추가 (추후 분리 계획 시 별도 논의)
- `AnimatedBuilder(animation: controller, builder: ...)` 패턴으로 UI 바인딩

### 의존성 주입

- 프레임워크 없이 생성자 주입으로 처리
- `NestRepository(Supabase.instance.client)` → `NestController(repository: repository)`

---

## 2. 코드 컨벤션

### 파일 명명

| 대상 | 규칙 | 예시 |
|---|---|---|
| Dart 파일 | snake_case | `nest_controller.dart`, `home_page.dart` |
| 탭 화면 | `*_tab.dart` | `dashboard_tab.dart`, `gallery_tab.dart` |
| 위젯 | 기능 설명 snake_case | `hub_scaffold.dart`, `nest_skeleton.dart` |
| 플랫폼별 | `*_stub.dart`, `*_web.dart` | `download_helper_web.dart` |
| SQL 마이그레이션 | `YYYYMMDDHHMMSS_설명.sql` | `20260324100000_academic_events.sql` |
| Edge Function | kebab-case 디렉토리 | `google-drive-upload/index.ts` |

### 클래스/변수 명명

| 대상 | 규칙 | 예시 |
|---|---|---|
| 클래스 | PascalCase | `NestController`, `HomePage`, `ChildProfile` |
| 변수/메서드 | camelCase | `selectedHomeschoolId`, `fetchMemberships()` |
| 상수 | camelCase | `dustyRose`, `creamyWhite` |
| private | `_` prefix | `_isBusy`, `_runBusy()`, `_buildSection()` |
| Boolean | `is*`, `has*`, `can*` prefix | `isLoggedIn`, `hasAdminRole`, `canAccept` |
| 빌더 메서드 | `_build*` prefix | `_buildTabs()`, `_buildMetrics()` |
| DB 컬럼 | snake_case | `homeschool_id`, `created_at` |

### Import 순서

```dart
// 1. Dart SDK
import 'dart:async';
import 'dart:convert';

// 2. Flutter/패키지
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 3. 프로젝트 내부 (상대 경로)
import '../config/app_config.dart';
import '../models/nest_models.dart';
import '../state/nest_controller.dart';

// 4. 조건부 import (플랫폼별)
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';
```

- Barrel file(재수출 파일)은 사용하지 않는다
- 상대 경로 import 사용 (`package:` 대신 `../`)

### 모델 작성 규칙

```dart
class ExampleModel {
  const ExampleModel({
    required this.id,
    this.name = '',
    this.createdAt,
  });

  // factory 생성자로 Supabase JSON 역직렬화
  factory ExampleModel.fromMap(Map<String, dynamic> map) {
    return ExampleModel(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      createdAt: parseDateTime(map['created_at']),
    );
  }

  final String id;
  final String name;
  final DateTime? createdAt;

  // 직렬화
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
  };

  // 계산 프로퍼티
  bool get hasName => name.isNotEmpty;
}
```

- `const` 생성자 사용
- `factory fromMap()` + `toMap()` 패턴 (코드 생성 없음)
- Null-safe 파싱: `(map['field'] as Type?) ?? defaultValue`
- `parseDateTime()`, `parseBool()` 헬퍼 함수 활용
- DB snake_case → Dart camelCase 변환은 `fromMap()` 내에서 처리

---

## 3. UI 컨벤션

### 디자인 토큰 (NestTheme)

```dart
// 색상 - NestColors 클래스 사용
NestColors.dustyRose     // #DCAE96 - 주요 CTA, 브랜드
NestColors.creamyWhite   // #F9F7F2 - 배경
NestColors.deepWood      // #5A4637 - 텍스트/강조
NestColors.mutedSage     // #8A9A84 - 보조/성공
NestColors.clay          // #B48268 - 3차 색상
NestColors.roseMist      // #F4E4DB - 액센트 배경

// 폰트
fontFamily: 'Pretendard Variable'
```

- 하드코딩 색상 금지, 반드시 `NestColors.*` 또는 `Theme.of(context)` 사용
- `NestTheme.themeData` 기반 Material 3 테마 적용

### UI 패턴

| 패턴 | 사용처 | 설명 |
|---|---|---|
| **HubScaffold** | 부모/교사 허브 | 지표 카드 + 섹션 칩 네비게이션 |
| **카드 클릭 → 모달** | 학기 설정 전체 | CRUD는 카드 탭 → 통합 다이얼로그 |
| **SearchSelectField** | 교사/아이/반 선택 | 검색 가능한 바텀시트 선택기 |
| **NestEmptyState** | 데이터 없을 때 | 아이콘 + 제목 + CTA 빈 상태 |
| **NestSkeleton** | 로딩 중 | 시머 애니메이션 플레이스홀더 |
| **NestBusyOverlay** | 뮤테이션 중 | 반투명 로딩 오버레이 |
| **EntityAvatar** | 엔티티 시각화 | 시드 그라디언트 + 이니셜 아바타 |

### 탭 추가 규칙

1. `frontend/lib/src/ui/tabs/` 디렉토리에 `*_tab.dart` 파일 생성
2. `NestController` 인스턴스를 파라미터로 받음
3. `HomePage._buildTabs()`에서 역할 조건부 등록
4. `docs/architecture.md` 섹션 6에 기능 설명 추가

### 한국어 우선

- 모든 사용자 대면 문자열은 한국어로 작성
- 코드 내 주석과 변수명은 영어
- IA 라벨: `대시보드`, `학기 설정`, `시간표`, `시스템`, `갤러리`, `커뮤니티`

---

## 4. 백엔드(Supabase) 규칙

### 마이그레이션 규칙

- 파일명: `YYYYMMDDHHMMSS_기능설명.sql` (UTC 타임스탬프)
- 새 테이블은 반드시 RLS 활성화 (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY`)
- `set_updated_at()` 트리거를 `updated_at` 컬럼이 있는 모든 테이블에 추가
- ENUM 타입 사용 시 기존 enum 재활용 우선, 불가능할 때만 새 타입 생성
- 기존 마이그레이션 파일 수정 금지 - 항상 새 파일로 추가

### RLS 정책 명명

```sql
-- 패턴: {테이블명}_{동작}_{대상역할}
CREATE POLICY "children_select_member" ON children FOR SELECT ...;
CREATE POLICY "children_insert_admin_staff" ON children FOR INSERT ...;
CREATE POLICY "children_delete_admin_staff" ON children FOR DELETE ...;
```

### RLS 헬퍼 함수

```sql
-- 항상 이 함수들을 사용하여 역할 검증
is_homeschool_member(homeschool_id)
has_homeschool_role(homeschool_id, roles[])
has_term_role(term_id, roles[])
is_term_member(term_id)
has_family_role(family_id, roles[])
```

### Edge Function 규칙

- `_shared/supabase.ts`의 `requireUser()`, `assertRole()` 사용
- `_shared/cors.ts`의 CORS 헤더 적용
- Bearer 토큰 인증 필수
- 한국어 에러 메시지 반환
- 서비스 키 절대 프론트엔드에 노출 금지

### 데이터 격리

- 모든 데이터는 `homeschool_id` 기준 논리적 격리 (멀티 테넌시)
- RLS 정책에서 반드시 `homeschool_id` 기반 접근 제어 포함
- Security-definer RPC는 복잡한 트랜잭션에만 사용

---

## 5. 보안 가드레일

### 절대 금지 사항

- [ ] `SUPABASE_SERVICE_ROLE_KEY`를 프론트엔드 코드에 포함
- [ ] RLS가 비활성화된 테이블 생성
- [ ] `.env` 파일이나 시크릿을 git에 커밋
- [ ] 프론트엔드에서 `supabaseAdmin` 클라이언트 사용
- [ ] Edge Function에서 인증 없이 데이터 접근
- [ ] `--no-verify` 플래그로 git hook 우회
- [ ] `main` 브랜치에 force push

### 인증/인가 규칙

- Supabase Auth (이메일/비밀번호 PKCE 플로우)만 사용
- JWT 토큰 만료: 3600초 (1시간)
- Refresh 토큰 자동 갱신 활성화
- 모든 API 호출은 `supabase.auth.currentUser` 기반
- Edge Function은 `requireUser(req)` → `assertRole()` 순서로 검증

### 역할 체계

```
HOMESCHOOL_ADMIN - 운영 전권 + Drive 연동 관리
STAFF            - 제한된 운영 지원
TEACHER          - 담당 수업/학생 접근 + 미디어 업로드
GUEST_TEACHER    - 초청 범위 교사 권한
PARENT           - 본인 가정/자녀 중심 조회
```

- 한 사용자가 복수 역할 보유 가능
- 마지막 HOMESCHOOL_ADMIN 삭제 방지 가드레일 필수

---

## 6. 테스트 규칙

### 필수 테스트

| 대상 | 위치 | 실행 |
|---|---|---|
| 모델 단위 테스트 | `frontend/test/models_test.dart` | `flutter test` |
| 위젯 테스트 | `frontend/test/widget_test.dart` | `flutter test` |
| E2E (원격 Supabase) | `scripts/e2e_remote.mjs` | `node scripts/e2e_remote.mjs` |

### 새 기능 추가 시 테스트 체크리스트

1. 새 모델 추가 시 → `models_test.dart`에 `fromMap()` 파싱 테스트 추가
2. 새 로직(알고리즘) 추가 시 → 해당 로직의 단위 테스트 추가
3. DB 마이그레이션 추가 시 → E2E 테스트에서 해당 테이블/RPC 검증

### CI에서 자동 실행되는 검증

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build web --release --base-href /nest/
```

---

## 7. 빌드 및 배포

### 로컬 개발

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
flutter run -d chrome              # 웹
flutter run -d chrome --web-port=8080  # OAuth 테스트 시
```

### 빌드

```bash
flutter build web --release --base-href /nest/
flutter build appbundle --release   # Android
flutter build ios --release --no-codesign  # iOS
```

### 배포 파이프라인

- **웹**: `main` 브랜치 push → `.github/workflows/flutter_web_pages.yml` → GitHub Pages
- **E2E**: `main` 브랜치 push → `.github/workflows/remote_e2e.yml` → Supabase 원격 테스트
- **모바일**: 수동 빌드 후 스토어 제출
- **Supabase**: `scripts/deploy_supabase.sh` (Edge Function + Secrets 배포)

### 브랜치 전략

| 브랜치 | 용도 |
|---|---|
| `main` | 프로덕션 배포 |
| `develop` | 개발 통합 |
| `feature/*` | 기능 개발 |
| `gh-pages` | GitHub Pages 배포 (자동) |

---

## 8. 코드 리뷰 체크리스트

PR 생성 또는 코드 변경 시 에이전트가 확인해야 할 항목:

- [ ] 레이어 의존성 방향 준수 (UI → State → Service → Model)
- [ ] 새 모델에 `const` 생성자, `fromMap()`, `toMap()` 구현
- [ ] RLS 정책이 새 테이블에 적용됨
- [ ] 하드코딩 색상 없이 `NestColors` 사용
- [ ] 한국어 UI 문자열
- [ ] 기존 패턴과 일관된 네이밍
- [ ] `docs/architecture.md` 업데이트 (아키텍처 변경 시)
- [ ] `flutter analyze` 통과
- [ ] `flutter test` 통과
- [ ] 시크릿/키가 코드에 포함되지 않음

---

## 9. 향후 모듈화 가이드

현재 대형 파일들의 분리 계획 방향:

### NestController 분리 방안

현재 `nest_controller.dart` (5,325줄)를 도메인별로 분리할 때:

```
state/
  nest_controller.dart          # 코어: auth, bootstrap, context
  auth_controller.dart          # 인증/세션 관리
  timetable_controller.dart     # 시간표 상태
  community_controller.dart     # 커뮤니티 상태
  membership_controller.dart    # 멤버십/초대/가입
  academic_controller.dart      # 학기/반/수업/교사
```

- 분리 시 각 서브 컨트롤러는 `ChangeNotifier` 상속
- `NestController`가 서브 컨트롤러를 조합하는 Facade 역할

### 대형 탭 파일 분리

```
tabs/
  timetable/
    timetable_tab.dart          # 메인 탭 (라우팅만)
    timetable_board.dart        # 시간표 보드 위젯
    timetable_palette.dart      # 팔레트 (수업/교사/교실)
    session_dialog.dart         # 세션 설정 모달
    timetable_export.dart       # 내보내기 기능
  family_admin/
    family_admin_tab.dart       # 메인 탭
    family_section.dart         # 가정 관리 섹션
    teacher_section.dart        # 교사 관리 섹션
    class_section.dart          # 반 관리 섹션
    course_section.dart         # 수업 관리 섹션
```

### NestRepository 분리

```
services/
  nest_repository.dart          # 코어: auth, homeschool
  timetable_repository.dart     # 시간표/세션/슬롯
  community_repository.dart     # 커뮤니티/게시글/댓글
  membership_repository.dart    # 멤버십/초대
  academic_repository.dart      # 학기/반/수업/교사
  media_repository.dart         # 갤러리/Drive
```

> **중요**: 모듈화는 기능 추가 중이 아닌, 별도 리팩토링 작업으로 진행한다.
> 기능 개발 중에는 기존 구조를 따른다.

---

## 10. 에이전트 전용 참조

### 에이전트 역할별 안내

각 팀원의 에이전트는 `agents.md`에 정의된 역할별 가이드를 참조합니다.

### 코드 생성 시 필수 확인 사항

1. **변경 전**: 반드시 관련 파일을 먼저 읽고 기존 패턴 파악
2. **변경 중**: 이 파일의 컨벤션과 가드레일 준수
3. **변경 후**: `flutter analyze` + `flutter test` 통과 확인
4. **문서화**: 아키텍처에 영향을 주는 변경은 `docs/architecture.md` 업데이트

### 절대 하지 않을 것

- 이 파일(`CLAUDE.md`)의 보안 가드레일 섹션을 무시하거나 완화
- 기존 코드의 동작을 변경하면서 관련 테스트를 제거
- 기존 마이그레이션 파일 수정 (항상 새 마이그레이션으로)
- `pubspec.yaml`에 이 파일에 언급되지 않은 상태관리 패키지 추가
