# Nest API 설계 v1

## 1) 공통 규약

- Base URL: `/api/v1`
- 인증: `Authorization: Bearer <access_token>`
- 홈스쿨 컨텍스트: `X-Homeschool-Id: <homeschool_id>`
- 시간대: 홈스쿨 기본 타임존 사용
- 응답 형식: JSON

## 2) 응답 포맷

### 성공
```json
{
  "data": {},
  "meta": {}
}
```

### 실패
```json
{
  "error": {
    "code": "TIMETABLE_CONFLICT",
    "message": "Teacher already assigned at the same time",
    "details": []
  }
}
```

## 3) 인증/기본

- `POST /auth/login`
- `POST /auth/refresh`
- `GET /me`

## 4) 홈스쿨 운영

- `GET /homeschools`
- `POST /homeschools`
- `POST /homeschools/{homeschoolId}/invite-links`
- `GET /families`
- `POST /families`
- `GET /children`
- `POST /children`
- `GET /teacher-profiles`
- `POST /teacher-profiles`
- `GET /terms`
- `POST /terms`
- `POST /class-groups`
- `POST /courses`

## 5) 시간표 스튜디오 API

### 채팅 편성
- `POST /terms/{termId}/timetable/assistant/generate`
- 입력
```json
{
  "prompt": "화/목 오전은 국어/수학 중심으로 배치",
  "constraints": {
    "lock_existing_sessions": true,
    "prefer_teacher_ids": ["t_1", "t_2"]
  }
}
```
- 출력
```json
{
  "proposal_id": "tp_123",
  "is_valid": false,
  "sessions": [],
  "hard_conflicts": [],
  "soft_warnings": []
}
```

### 생성안 조회/적용
- `GET /terms/{termId}/timetable/proposals/{proposalId}`
- `POST /terms/{termId}/timetable/proposals/{proposalId}/apply`

### 수동 편집
- `PATCH /class-sessions/{sessionId}`
- `DELETE /class-sessions/{sessionId}`

### 검증/확정
- `POST /terms/{termId}/timetable/validate`
- `POST /terms/{termId}/timetable/commit`
- `GET /class-groups/{classGroupId}/timetable`

## 6) Google Drive 연동 API

- `POST /integrations/google-drive/connect/start`
- `POST /integrations/google-drive/connect/complete`
- `GET /integrations/google-drive/status`
- `PATCH /integrations/google-drive/settings`
- `POST /integrations/google-drive/disconnect`

## 7) 미디어 업로드/갤러리 API

### 업로드 세션
- `POST /media/upload-sessions`
- `PUT /media/upload-sessions/{uploadSessionId}/binary`
- `POST /media/upload-sessions/{uploadSessionId}/complete`

### 갤러리
- `GET /gallery/items`
- Query
- `term_id`, `class_group_id`, `child_id`, `from`, `to`, `media_type`, `cursor`
- `GET /gallery/items/{itemId}`

## 8) 활동/계획 API

- `POST /class-sessions/{sessionId}/plans`
- `GET /class-sessions/{sessionId}/plans`
- `POST /children/{childId}/activity-logs`
- `GET /children/{childId}/activity-logs`

## 9) 오류 코드

- `UNAUTHORIZED`
- `FORBIDDEN`
- `VALIDATION_ERROR`
- `TIMETABLE_CONFLICT`
- `TERM_VERSION_CONFLICT`
- `DRIVE_NOT_CONNECTED`
- `UPLOAD_FAILED`
- `RESOURCE_NOT_FOUND`

## 10) 권한 요약

- Admin
- 전체 운영 API 접근
- 채팅/수동 시간표 편성, Drive 연결/설정

- Teacher/Guest Teacher
- 담당 수업 계획/활동 기록
- 미디어 업로드, 담당 범위 갤러리 조회

- Parent
- 내 아이 시간표/활동/갤러리 조회
- 업로드/API 수정 권한 없음(MVP)
