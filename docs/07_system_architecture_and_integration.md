# 시스템 아키텍처 및 연동 설계 (초안)

## 1) 아키텍처 목표

- 멀티 홈스쿨 운영 지원
- 역할 기반 접근 제어
- 시간표 충돌 검증 실시간성 확보
- 웹/앱 동시 제공 및 확장성 확보
- Google Drive 기반 미디어 중앙화

## 2) 논리 아키텍처

- Client Layer
- 관리자 웹 콘솔
- 부모/교사 웹 포털
- 부모/교사 모바일 앱

- API Layer
- 인증/인가 API
- 홈스쿨 운영 API
- 시간표 스튜디오 API
- 학습 활동 API
- 미디어 업로드/갤러리 API
- 공지/알림 API

- Domain Services
- Membership Service
- Scheduling Service
- Scheduling Assistant Service
- Teaching Service
- Media Service
- Community Service

- Integration Services
- Google Drive Connector
- Notification Gateway (Push/Email)

- Data Layer
- PostgreSQL
- Redis (캐시/락/큐)
- Object Storage (임시 업로드 버퍼)

- Observability Layer
- 로그/메트릭/트레이싱
- 감사 로그 리포지토리

## 3) 주요 컴포넌트 분리

### Auth Service
- 로그인, 토큰 발급, 세션 관리
- 홈스쿨 컨텍스트 전환 지원

### Homeschool Core Service
- 가정, 아이, 교사, 학기, 반, 수업 카탈로그 관리

### Timetable Service
- 시간표 생성/검증/확정
- 충돌 규칙 엔진
- 버전 기반 동시성 제어

### Scheduling Assistant Service
- 프롬프트 기반 편성안 생성
- 제약조건 반영 및 설명 생성

### Media Service
- 업로드 세션 발급
- 업로드 상태 관리
- Drive 파일 메타데이터 동기화
- 갤러리 조회 API 제공

### Google Drive Connector
- OAuth 연결/토큰 갱신
- 폴더 생성/권한 부여
- 파일 업로드/링크 생성

## 4) 이벤트 흐름

### A) 시간표 확정
1. 관리자가 시간표 확정
2. `TIMETABLE_CONFIRMED` 이벤트 발행
3. 알림 서비스가 대상자(부모/교사) 계산
4. 푸시/인앱 알림 전송
5. 감사 로그 기록

### B) 미디어 업로드
1. 교사가 업로드 세션 생성
2. 파일 전송 후 완료 호출
3. Media Service가 Drive 업로드 실행
4. `MEDIA_UPLOADED` 이벤트 발행
5. 갤러리 인덱스 반영 + 대상자 알림

## 5) 통합 포인트

- Google Drive API: OAuth, 파일/폴더 관리
- 이메일/SMS 게이트웨이: 초대 링크/중요 알림
- 향후 AI 모듈: Discovery 결과 해석 보조

## 6) 보안 아키텍처

- JWT + Refresh Token
- RBAC + 리소스 레벨 정책
- 개인정보 컬럼 암호화
- Drive 토큰 암호화 저장
- 관리자 중요 액션 2차 인증(후속 단계)

## 7) 배포 전략

- 환경 분리: `dev` / `staging` / `prod`
- 브랜치 전략: trunk 기반 + 짧은 feature branch
- 배포: CI/CD 자동화, 점진적 롤아웃

## 8) 장애 대응 기준

- 장애 등급 분류(P1/P2/P3)
- 시간표 API 장애 시 우선 복구
- Drive 업로드 지연/실패는 비동기 재처리 큐로 복원
- 장기 실패 건은 관리자 대시보드에 경고 표시
