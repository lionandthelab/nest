# Nest Supabase Edge Functions

## 포함된 함수

- `timetable-assistant-generate`
- `google-drive-upload`
- `google-drive-connect-start`
- `google-drive-connect-complete`
- `nest-notify` — 수업 변경 / 결석 신고 알림 발송 (문자, 추후 알림톡)
- `lion-notify` — lion_auth 모듈 템플릿(벤더링 원본, **수정 금지**)
- `social-broker` — lion_auth 소셜 로그인 브로커

## 필요한 Secrets

```bash
supabase secrets set \
  SUPABASE_URL="https://avursvhmilcsssabqtkx.supabase.co" \
  SUPABASE_SERVICE_ROLE_KEY="<SERVICE_ROLE_KEY>" \
  GOOGLE_CLIENT_ID="<GOOGLE_CLIENT_ID>" \
  GOOGLE_CLIENT_SECRET="<GOOGLE_CLIENT_SECRET>" \
  GOOGLE_REDIRECT_URI="<GOOGLE_REDIRECT_URI>"
```

`nest-notify` 는 추가로 Solapi 시크릿이 필요하다. 이 값들은 lion_auth 메시징 셋업
(`node scripts/lion_auth_setup.mjs`, `.env` 기반)이 이미 등록하므로 별도로 다시
설정할 필요는 없다.

| 시크릿 | 필수 | 설명 |
|---|---|---|
| `SOLAPI_API_KEY` | O | Solapi API 키 |
| `SOLAPI_API_SECRET` | O | Solapi API 시크릿 (HMAC 서명용) |
| `SOLAPI_SENDER` | O | 사전 등록된 발신번호 |
| `SOLAPI_PFID` | 알림톡 사용 시 | 카카오 발신프로필 ID. 미설정이면 `channel='sms'` 만 동작 |

## 배포 예시

```bash
supabase functions deploy timetable-assistant-generate --project-ref avursvhmilcsssabqtkx
supabase functions deploy google-drive-upload --project-ref avursvhmilcsssabqtkx
supabase functions deploy google-drive-connect-start --project-ref avursvhmilcsssabqtkx
supabase functions deploy google-drive-connect-complete --project-ref avursvhmilcsssabqtkx
supabase functions deploy nest-notify --project-ref avursvhmilcsssabqtkx
```

`scripts/deploy_supabase.sh` 가 위 목록을 한 번에 배포한다.

---

## `nest-notify` — 수업 변경 / 결석 신고 알림

함수 slug: **`nest-notify`**
엔드포인트: `POST https://<PROJECT_REF>.functions.supabase.co/nest-notify`
(Flutter 에서는 `supabase.functions.invoke('nest-notify', body: {...})`)

`verify_jwt = true` — 로그인한 사용자만 호출할 수 있다. `Authorization: Bearer <access_token>` 필수.

### 설계 원칙: 클라이언트는 수신자를 지정하지 않는다

클라이언트는 **도메인 이벤트(`event`, `id`)만** 보낸다. 수신자 목록은 서버가
`service_role` 로 해석하고, 인가도 서버가 직접 SQL 로 검증한다
(`service_role` 은 RLS 를 우회하므로 함수 안에서의 인가 검증이 유일한 방어선이다).
이 때문에 "누구에게 보낼지"를 담은 필드는 요청 계약에 존재하지 않는다.

### 요청

```jsonc
POST /nest-notify
{
  "event": "CLASS_CHANGE" | "ABSENCE",   // 필수
  "id": "<uuid>",                        // 필수. class_session_changes.id 또는 absence_reports.id
  "channel": "sms" | "alimtalk" | "auto",// 선택. 기본값 'sms'
  "force": false                         // 선택. true 면 이미 발송된 건도 재발송
}
```

### 응답 (200)

```jsonc
{
  "accepted": true,          // 실제로 발송을 성공적으로 접수했는지
  "sent": 12,                // 문자를 보낸 수신자 수
  "skipped_no_phone": 3,     // 계정은 있으나 유효한 휴대폰 번호가 없어 제외된 수
  "skipped_no_account": 1,   // 연결된 계정 자체가 없어 제외된 수(학생 미가입, 교사 계정 미연결 등)
  "already_notified": true,  // (선택) 이미 발송된 건이라 아무것도 보내지 않음
  "message_id": "G4V..."     // Solapi 그룹 ID. 미발송이면 null
}
```

> **주의**: 보낼 번호가 하나도 없으면 `accepted: false`, `sent: 0` 으로 돌려준다.
> 호출부는 `accepted` 와 `sent` 를 보고 사용자에게 정직한 메시지를 띄워야 한다
> (예: "알림 대상 3명 중 등록된 연락처가 없어 발송하지 못했습니다").

### 오류 응답

| 상태 | 상황 | 본문 |
|---|---|---|
| 400 | 본문/`event`/`id`/`channel` 형식 오류, 알림톡인데 `SOLAPI_PFID` 미설정 | `{ "error": "..." }` |
| 401 | 토큰 없음/만료 | `{ "error": "로그인이 필요합니다." }` |
| 403 | 발송 권한 없음 | `{ "error": "..." }` |
| 404 | 대상 행 또는 수업 정보 없음 | `{ "error": "..." }` |
| 405 | POST 이외 메서드 | `{ "error": "허용되지 않는 메서드입니다." }` |
| 413 | 1회 발송 상한(300명) 초과 | `{ "error": "..." }` |
| 422 | 대상 행에 필수 참조가 비어 있음 | `{ "error": "..." }` |
| 502 | Solapi 발송 실패 | `{ "error": "문자 발송에 실패했습니다: ..." }` |
| 503 | 관련 테이블 마이그레이션 미배포 | `{ "error": "..." }` |
| 500 | 그 외 서버 오류 | `{ "error": "..." }` |

모든 오류 메시지는 한국어다.

### 인가 규칙 (함수 내부에서 직접 검증)

| 이벤트 | 발송 가능한 호출자 |
|---|---|
| `CLASS_CHANGE` | 해당 수업의 담당 교사(`session_teacher_assignments` MAIN/ASSISTANT), 반 담임(`class_groups.main_teacher_id`), 또는 해당 홈스쿨의 `HOMESCHOOL_ADMIN` / `STAFF` |
| `ABSENCE` | 그 자녀의 보호자(`family_guardians`), 학생 본인(`children.user_id`), 또는 `HOMESCHOOL_ADMIN` / `STAFF` |

교사 판정은 `teacher_profiles.user_id` ↔ 호출자 uuid 매칭으로 한다.
멤버십은 `status = 'ACTIVE'` 인 행만 인정한다.

### 수신자 해석

| 이벤트 | 수신자 |
|---|---|
| `CLASS_CHANGE` | 해당 반 수강생(학생 계정) + 그 학생들의 가정 보호자 |
| `ABSENCE` | 해당 수업 담당 교사(배정이 없으면 담임) |

수신자 해석은 아래 RPC 를 먼저 호출하고, RPC 가 아직 배포되지 않았으면
(`PGRST202` / `does not exist`) 동등한 인라인 조인 쿼리로 자동 폴백한다.

```sql
recipients_for_class_session(
  p_class_session_id uuid,
  p_include_guardians boolean default true,
  p_include_students  boolean default true,
  p_include_teachers  boolean default false
) returns table (user_id uuid, recipient_kind text)

recipients_for_absence_report(p_report_id uuid)
  returns table (user_id uuid, recipient_kind text)
```

- `recipient_kind`: `STUDENT` | `GUARDIAN` | `TEACHER`
- RPC 는 **계정이 연결된 대상만** 돌려준다. 응답의 `skipped_no_account`(계정 미연결
  학생이면서 보호자도 없는 경우, `teacher_profiles.user_id` 가 null 인 교사)는
  함수가 반 명부 / 교사 배정을 직접 세어서 채운다.
- `RETURNS TABLE` plpgsql 함수이므로 본문 첫 줄에 `#variable_conflict use_column`
  을 넣어야 42702(모호한 컬럼 참조)를 피할 수 있다.

### 전화번호 조회 순서

1. `profiles.phone` (마이그레이션 `20260814089000_profiles_phone_sync.sql` 이 가입 트리거·
   메타데이터 동기화·백필로 채운다)
2. 없으면 `auth.users` 메타데이터 `raw_user_meta_data->>'phone_number'`
   (→ `phone`, 그다음 `auth.users.phone`) — 백필 전이거나 동기화가 어긋난 계정용 안전망

번호는 `_shared/solapi.ts` 의 `normalizePhone()` 으로 정규화한다
(숫자만 남기고 `+82`/`82` 접두를 `0` 으로, `^01[016789]\d{7,8}$` 이 아니면 제외).

### 중복 발송 방지

대상 행의 `notified_at` 이 이미 채워져 있으면 발송하지 않고
`{ accepted: false, already_notified: true, sent: 0 }` 을 돌려준다.
재발송이 필요하면 `force: true` 를 보낸다.
발송에 성공한 경우에만 `notified_at` 을 `now()` 로 갱신한다(실패 시 갱신하지 않으므로 재시도 가능).

### 대상 테이블에 필요한 컬럼

| 테이블 | 이 함수가 읽는 컬럼 |
|---|---|
| `class_session_changes` | `id`, `class_session_id`, `change_type`(`CANCELED`/`TIME_MOVED`/`ROOM_MOVED`/`TEACHER_SUBSTITUTE`/`NOTE`), `effective_from`, `effective_to`(null = 학기 끝까지), `reason`, `notified_at`, `new_time_slot_id`, `new_location`, `substitute_teacher_id` |
| `absence_reports` | `id`, `class_session_id`, `child_id`, `occurrence_date`, `reason`, `status`, `notified_at` |

`status = 'CANCELED'`(철회) 인 결석 신고는 422 로 거절한다.

### 발송 채널과 알림톡 전환

- 기본 채널은 `sms` (`nest-notify/index.ts` 의 `DEFAULT_CHANNEL`).
- 카카오 알림톡 템플릿이 승인되고 `SOLAPI_PFID` 가 설정되면
  `DEFAULT_CHANNEL` 을 `'auto'` 로 바꾸고 `ALIMTALK_TEMPLATE_IDS` 에 템플릿 코드만
  채우면 된다. 본문 조립 함수가 이미 `{ text, templateId, variables }` 를 함께 만든다.
- `auto` 는 알림톡 실패 시 문자/LMS 로 자동 대체, `alimtalk` 은 대체 없음.

### 감사 로그

발송 수신자 1명당 `notification_log` 1행을 기록한다
(`requested_by`, `to_user_id`, `channel`, `template_id`, `status`, `provider_message_id`, `error`).

---

## 주의

- `google-drive-upload`는 `drive_integrations.google_access_token`이 저장되어 있어야 동작합니다.
- Access token 만료 시 refresh token + Google client secret으로 자동 갱신을 시도합니다.
- `supabase/functions/lion-notify/` 와 `packages/lion_auth/` 는 벤더링된 모듈 원본이므로
  Nest 쪽에서 수정하지 않습니다. Nest 전용 발송 로직은 `nest-notify` 에만 추가합니다.
  (그래서 `_shared/solapi.ts` 는 lion-notify 의 Solapi 코드와 의도적으로 중복됩니다.)
