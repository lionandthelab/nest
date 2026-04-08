# Nest - Agent 역할별 가이드

> 이 파일은 팀원별 Claude Code 에이전트가 자신의 역할에 맞는 작업을 수행할 때 참조하는 가이드입니다.
> **반드시 `CLAUDE.md`를 먼저 읽은 후 이 파일을 참조하세요.**

---

## 공통 워크플로우

모든 에이전트는 작업 시 다음 순서를 따릅니다:

### 작업 전

1. `CLAUDE.md` 읽기 (프로젝트 규칙 확인)
2. `docs/architecture.md` 관련 섹션 읽기
3. 변경 대상 파일의 기존 코드 읽기 (패턴 파악)
4. 관련 마이그레이션/RLS 정책 확인 (DB 변경 시)

### 작업 중

5. 기존 패턴과 일관되게 코드 작성
6. `CLAUDE.md`의 가드레일 준수
7. 한국어 UI 문자열, 영어 코드/변수명

### 작업 후

8. `flutter analyze` 실행 → 경고/오류 수정
9. `flutter test` 실행 → 기존 테스트 깨지지 않음 확인
10. 새 기능은 테스트 추가
11. `docs/architecture.md` 업데이트 (아키텍처 변경 시)

---

## Agent 1: Frontend (Flutter UI/UX)

### 담당 영역

- `frontend/lib/src/ui/` 전체 (tabs, widgets, theme, pages)
- `frontend/lib/src/state/nest_controller.dart` (UI 상태 추가/수정)
- `frontend/assets/`

### 핵심 참조 파일

| 파일 | 이유 |
|---|---|
| `ui/nest_theme.dart` | 디자인 토큰 확인 |
| `ui/home_page.dart` | 탭 구성 및 네비게이션 패턴 |
| `ui/widgets/hub_scaffold.dart` | 허브형 레이아웃 패턴 |
| `ui/widgets/search_select_field.dart` | 선택 UI 패턴 |
| `ui/widgets/entity_visuals.dart` | 아바타/엔티티 시각화 |
| `state/nest_controller.dart` | 사용 가능한 상태 및 메서드 |

### 작업 규칙

#### 새 탭 추가

```dart
// 1. tabs/ 디렉토리에 파일 생성
class NewFeatureTab extends StatefulWidget {
  const NewFeatureTab({super.key, required this.controller});
  final NestController controller;
  // ...
}

// 2. home_page.dart의 _buildTabs()에 역할 조건부 등록
if (hasRole('PARENT')) tabs.add(('새기능', Icons.star, NewFeatureTab(controller: c)));
```

#### 카드형 CRUD UI

```dart
// 패턴: 카드 목록 + 카드 클릭 → showDialog()
// 참고: family_admin_tab.dart의 가정/아이/반 관리 패턴
Card(
  child: ListTile(
    leading: EntityAvatar(label: item.name),
    title: Text(item.name),
    subtitle: Text(item.description),
    onTap: () => _showEditDialog(item),
  ),
)
```

#### 검색 선택 UI

```dart
// 항상 SearchSelectField / showSelectSheet 사용
// 드롭다운 직접 구현 금지
final selected = await showSelectSheet<Course>(
  context: context,
  title: '수업 선택',
  options: courses.map((c) => SelectSheetOption(
    value: c,
    title: c.name,
    subtitle: c.description,
    keywords: c.name,
  )).toList(),
);
```

#### 빈 상태 / 로딩

```dart
// 데이터 없을 때
if (items.isEmpty) return const NestEmptyState(
  icon: Icons.folder_open,
  title: '데이터가 없습니다',
  subtitle: '새 항목을 추가해 주세요',
);

// 로딩 중
if (controller.isBusy) return const NestSkeletonList();
```

#### 색상 사용

```dart
// O - 올바른 사용
color: NestColors.dustyRose
color: Theme.of(context).colorScheme.primary

// X - 금지
color: Color(0xFFDCAE96)  // 하드코딩 금지
color: Colors.blue         // Material 기본 색상 직접 사용 금지
```

#### 반응형 레이아웃

```dart
// 화면 폭 기반 분기
final isWide = MediaQuery.of(context).size.width > 800;
// 넓은 화면: Row 레이아웃, 좁은 화면: Column/스크롤
```

### 금지 사항

- DropdownButton 직접 사용 (→ `showSelectSheet` 사용)
- Navigator.push로 화면 전환 (→ 탭 기반 네비게이션 유지)
- 새 패키지 의존성 추가 (논의 필요)
- 색상 하드코딩

---

## Agent 2: Backend (Supabase)

### 담당 영역

- `supabase/migrations/` (DB 스키마, RLS, RPC)
- `supabase/functions/` (Edge Functions)
- `supabase/config.toml`
- `frontend/lib/src/services/nest_repository.dart` (Supabase 쿼리 추가)
- `frontend/lib/src/models/nest_models.dart` (새 모델 추가)

### 핵심 참조 파일

| 파일 | 이유 |
|---|---|
| `supabase/migrations/20260302160000_init_nest.sql` | 기본 스키마/enum/RLS 함수 |
| `supabase/functions/_shared/supabase.ts` | Edge Function 공용 유틸리티 |
| `services/nest_repository.dart` | 기존 쿼리 패턴 |
| `models/nest_models.dart` | 기존 모델 패턴 |
| `docs/04_data_model_and_erd.md` | 데이터 관계 |

### 작업 규칙

#### 새 테이블 마이그레이션

```sql
-- 파일명: YYYYMMDDHHMMSS_기능설명.sql

-- 테이블 생성
CREATE TABLE IF NOT EXISTS new_table (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  homeschool_id UUID NOT NULL REFERENCES homeschools(id) ON DELETE CASCADE,
  name       TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS 활성화 (필수)
ALTER TABLE new_table ENABLE ROW LEVEL SECURITY;

-- updated_at 트리거 (필수)
CREATE TRIGGER set_new_table_updated_at
  BEFORE UPDATE ON new_table
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- RLS 정책
CREATE POLICY "new_table_select_member"
  ON new_table FOR SELECT
  USING (is_homeschool_member(homeschool_id));

CREATE POLICY "new_table_insert_admin_staff"
  ON new_table FOR INSERT
  WITH CHECK (has_homeschool_role(homeschool_id, ARRAY['HOMESCHOOL_ADMIN','STAFF']));

CREATE POLICY "new_table_update_admin_staff"
  ON new_table FOR UPDATE
  USING (has_homeschool_role(homeschool_id, ARRAY['HOMESCHOOL_ADMIN','STAFF']));

CREATE POLICY "new_table_delete_admin_staff"
  ON new_table FOR DELETE
  USING (has_homeschool_role(homeschool_id, ARRAY['HOMESCHOOL_ADMIN','STAFF']));

-- 인덱스
CREATE INDEX idx_new_table_homeschool ON new_table(homeschool_id);
```

#### 새 모델 추가

```dart
// models/nest_models.dart에 추가
class NewModel {
  const NewModel({
    required this.id,
    required this.homeschoolId,
    this.name = '',
    this.createdAt,
  });

  factory NewModel.fromMap(Map<String, dynamic> map) {
    return NewModel(
      id: (map['id'] as String?) ?? '',
      homeschoolId: (map['homeschool_id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      createdAt: parseDateTime(map['created_at']),
    );
  }

  final String id;
  final String homeschoolId;
  final String name;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
    'homeschool_id': homeschoolId,
    'name': name,
  };
}
```

#### Repository 메서드 추가

```dart
// services/nest_repository.dart에 추가
Future<List<NewModel>> fetchNewModels(String homeschoolId) async {
  final data = await client
      .from('new_table')
      .select()
      .eq('homeschool_id', homeschoolId)
      .order('created_at', ascending: false);
  return (data as List).map((e) => NewModel.fromMap(e)).toList();
}

Future<void> createNewModel({
  required String homeschoolId,
  required String name,
}) async {
  await client.from('new_table').insert({
    'homeschool_id': homeschoolId,
    'name': name,
  });
}
```

#### Edge Function 추가

```typescript
// functions/new-function/index.ts
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { createAdminClient, requireUser, assertRole, json } from '../_shared/supabase.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return handleCors();

  try {
    const user = await requireUser(req);
    const { homeschool_id } = await req.json();

    const admin = createAdminClient();
    await assertRole(admin, user.id, homeschool_id, ['HOMESCHOOL_ADMIN', 'STAFF']);

    // 비즈니스 로직

    return json({ success: true });
  } catch (err) {
    return json({ error: (err as Error).message }, 400);
  }
});
```

#### Controller 상태 추가

```dart
// state/nest_controller.dart에 추가

// 1. 상태 프로퍼티
List<NewModel> newModels = [];

// 2. fetch 메서드
Future<void> fetchNewModels() async {
  if (selectedHomeschoolId == null) return;
  newModels = await _repo.fetchNewModels(selectedHomeschoolId!);
  _notifyIfIdle();
}

// 3. create/update/delete 메서드 (_runBusy 래핑)
Future<void> createNewModel({required String name}) async {
  await _runBusy(() async {
    await _repo.createNewModel(
      homeschoolId: selectedHomeschoolId!,
      name: name,
    );
    await fetchNewModels();
  });
}

// 4. bootstrap에 fetchNewModels() 호출 추가 (필요 시)
```

### 금지 사항

- 기존 마이그레이션 파일 수정 (항상 새 파일)
- RLS 없이 테이블 생성
- `service_role_key`를 프론트엔드에 노출
- `supabaseAdmin` 클라이언트를 프론트엔드에서 사용
- `ON DELETE CASCADE` 없이 FK 생성 (명시적 정책 없는 한)
- 아카이브된 학기의 데이터 변경 허용

---

## Agent 3: QA / Testing

### 담당 영역

- `frontend/test/` (모델/위젯/통합 테스트)
- `scripts/e2e_remote.mjs` (원격 E2E)
- CI/CD 파이프라인 검증

### 핵심 참조 파일

| 파일 | 이유 |
|---|---|
| `test/models_test.dart` | 기존 모델 테스트 패턴 |
| `test/widget_test.dart` | 기존 위젯 테스트 패턴 |
| `scripts/e2e_remote.mjs` | E2E 테스트 패턴 |
| `.github/workflows/` | CI 워크플로우 |

### 테스트 작성 패턴

#### 모델 테스트

```dart
// test/models_test.dart
test('NewModel.fromMap parses correctly', () {
  final map = {
    'id': 'test-id',
    'homeschool_id': 'hs-1',
    'name': 'Test',
    'created_at': '2026-01-01T00:00:00Z',
  };
  final model = NewModel.fromMap(map);
  expect(model.id, 'test-id');
  expect(model.homeschoolId, 'hs-1');
  expect(model.name, 'Test');
  expect(model.createdAt, isNotNull);
});

test('NewModel.fromMap handles missing fields', () {
  final model = NewModel.fromMap({});
  expect(model.id, '');
  expect(model.name, '');
  expect(model.createdAt, isNull);
});
```

#### 로직 테스트

```dart
// local_planner 테스트 패턴 참고
test('algorithm handles edge case', () {
  final result = someAlgorithm(input);
  expect(result, expectedOutput);
});
```

### 검증 순서

```bash
# 1. 정적 분석
cd frontend && flutter analyze --no-fatal-infos --no-fatal-warnings

# 2. 단위/위젯 테스트
flutter test

# 3. 웹 빌드 검증
flutter build web --release --base-href /nest/

# 4. E2E (시크릿 필요)
SUPABASE_URL=... SUPABASE_ANON_KEY=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/e2e_remote.mjs
```

---

## Agent 4: DevOps / Infrastructure

### 담당 영역

- `.github/workflows/` (CI/CD)
- `scripts/deploy_supabase.sh`
- `scripts/` (운영 스크립트)
- `supabase/config.toml`
- `frontend/pubspec.yaml` (버전 관리)

### 핵심 참조 파일

| 파일 | 이유 |
|---|---|
| `.github/workflows/flutter_web_pages.yml` | 웹 배포 워크플로우 |
| `.github/workflows/remote_e2e.yml` | E2E 테스트 워크플로우 |
| `scripts/deploy_supabase.sh` | Supabase 배포 |
| `frontend/pubspec.yaml` | 버전 정보 |

### 배포 체크리스트

#### 웹 배포 (자동)

1. `main` 브랜치에 `frontend/**` 변경 push
2. GitHub Actions가 자동으로:
   - `flutter analyze`
   - `flutter test`
   - `flutter build web --release --base-href /nest/`
   - `gh-pages` 브랜치에 배포

#### Supabase 배포

```bash
# Edge Functions + Secrets 배포
SUPABASE_ACCESS_TOKEN=... \
SUPABASE_SERVICE_ROLE_KEY=... \
GOOGLE_CLIENT_ID=... \
GOOGLE_CLIENT_SECRET=... \
GOOGLE_REDIRECT_URI=... \
bash scripts/deploy_supabase.sh

# DB 마이그레이션 (별도)
supabase db push --project-ref avursvhmilcsssabqtkx
```

#### 모바일 릴리스

```bash
# 버전 업데이트 (pubspec.yaml)
version: X.Y.Z+N  # N은 항상 증가

# Android
flutter build appbundle --release
# → Google Play Console 업로드

# iOS
flutter build ios --release --no-codesign
# → Xcode에서 Archive → App Store Connect
```

### 운영 스크립트 사용

```bash
# 환경변수 설정 필요
export SUPABASE_URL=https://avursvhmilcsssabqtkx.supabase.co
export SUPABASE_ANON_KEY=<anon-key>
export SUPABASE_SERVICE_ROLE_KEY=<service-role-key>

# 샘플 데이터 생성
node scripts/setup_joy_school.mjs

# 고아 데이터 점검
node scripts/check_orphans.mjs

# 사용자 삭제
node scripts/delete_user.mjs
```

### GitHub Actions 규칙

- `secrets.*`를 `if` 조건에 직접 사용 금지 → `env.*`로 변환 후 사용
- 경로 필터로 불필요한 빌드 방지 (`paths:`)
- Flutter 캐싱 활성화 유지

---

## Agent 5: Documentation

### 담당 영역

- `docs/architecture.md` (아키텍처 문서 - 핵심)
- `docs/execution_tracker.md` (실행 추적)
- `docs/01 GUIDE/` (인수인계/가이드)
- `CHANGELOG.md`
- `CLAUDE.md`, `agents.md` (이 파일들)

### 문서 업데이트 트리거

| 변경 종류 | 업데이트 대상 |
|---|---|
| 새 탭/기능 추가 | `architecture.md` 섹션 6에 기능 설명 추가 |
| DB 마이그레이션 추가 | `architecture.md` 섹션 7에 마이그레이션 설명 추가 |
| UI 패턴 변경 | `architecture.md` 관련 섹션 업데이트 |
| 새 기능 완료 | `execution_tracker.md`에 이터레이션 로그 추가 |
| 릴리스 | `CHANGELOG.md` 버전 엔트리 추가 |
| 새 컨벤션 확립 | `CLAUDE.md` 업데이트 |

### execution_tracker.md 기록 형식

```markdown
| 날짜 | 범위 | 결과 | 검증 |
|---|---|---|---|
| 2026-XX-XX | 기능 설명 | 완료 | `flutter analyze`, `flutter test`, `flutter build web --release --base-href /nest/` |
```

### architecture.md 업데이트 규칙

- 기능별 설명은 섹션 6에 추가 (6.N 번호 할당)
- DB 변경은 섹션 7에 마이그레이션 설명 추가
- 프로젝트 구조 변경 시 섹션 3 업데이트
- 환경 변수 추가 시 섹션 8 업데이트

---

## 협업 프로토콜

### 에이전트 간 충돌 방지

1. **파일 소유권**: 각 에이전트는 담당 영역의 파일만 수정
2. **공유 파일**: `nest_controller.dart`, `nest_models.dart`, `nest_repository.dart`는 변경 전 현재 상태 확인 필수
3. **마이그레이션**: 타임스탬프 기반이므로 충돌 위험 낮음, 단 같은 테이블 수정 시 주의

### PR 제목 컨벤션

```
feat: 새 기능 추가 (한국어 설명)
fix: 버그 수정 (한국어 설명)
style: UI/UX 개선 (한국어 설명)
refactor: 코드 구조 개선
test: 테스트 추가/수정
docs: 문서 업데이트
chore: 빌드/CI 설정 변경
```

### 커밋 메시지

```
feat: 학사일정 관리 기능 추가

- academic_events 테이블 마이그레이션 추가
- AcademicEvent 모델 및 Repository 메서드 구현
- 학사일정 탭 UI 추가

```
