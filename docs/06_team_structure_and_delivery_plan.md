# 전문 개발팀 구성 및 전달 계획

## 1) 팀 구성 제안 (앱/웹 통합)

- Product Manager (1)
- Product Designer (1)
- Tech Lead / Architect (1)
- Backend Engineers (2)
- Web Frontend Engineer (1)
- Mobile App Engineer (1)
- QA Engineer (1)
- DevOps / SRE (0.5~1)
- Data/Analytics Engineer (0.5)

권장 초기 총 인원: **8~9명**

## 2) 역할별 책임

### PM
- PRD/우선순위/KPI 관리
- 운영 정책 의사결정(권한, 충돌정책, Drive 정책)

### Designer
- Warm Nest 브랜드 반영 UI 시스템 구축
- 시간표 스튜디오(채팅 + 드래그앤드롭) UX 고도화
- 갤러리 탐색/업로드 UX 설계

### Tech Lead
- 도메인 모델/아키텍처 확정
- 코드 품질/리뷰/기술 리스크 관리

### Backend
- 인증, 권한, 도메인 API, 충돌 검증 엔진
- Google Drive 연동, 미디어 업로드 파이프라인
- 감사로그/알림/운영 리포트

### Web Frontend
- 관리자 콘솔
- 부모/교사 웹 포털
- 갤러리 탐색 UI

### Mobile App
- 부모/교사 앱
- 교사용 카메라 기반 업로드 기능
- 푸시 알림 연동

### QA
- 기능/회귀/E2E 테스트 체계
- 시간표 충돌/권한/업로드 복구 시나리오 검증

### DevOps
- CI/CD, 관측성, 장애 대응 체계
- 대용량 미디어 업로드 모니터링

## 3) 개발 단계 로드맵

## Phase 1 (6주): 운영 코어 MVP
- 인증/홈스쿨/가정/아이/교사 관리
- 학기/반/수업 카탈로그
- 시간표 스튜디오 기본형(채팅 생성 + 수동 편집)
- 부모 시간표 조회

주요 산출물
- 운영 가능 MVP 웹앱
- API v1
- 기본 감사 로그

## Phase 2 (5주): 교사 운영 및 미디어
- 교사 계획표/활동기록
- Google Drive 연동
- 교사 사진/영상 업로드
- 부모/교사 갤러리 조회

주요 산출물
- 미디어 파이프라인 안정화
- 갤러리 기능 오픈

## Phase 3 (4주): 브랜드 모듈 확장
- Discovery 기초 진단 기능
- Nest Community 기본형
- Ttobak 학습지 생성 v1 (템플릿 기반)

주요 산출물
- 성장 지원 3모듈 MVP 버전

총 권장 일정: **15주 (약 3.8개월)**

## 4) 스프린트 운영

- 2주 스프린트
- 스프린트 시작: 목표/범위/리스크 명시
- 스프린트 종료: 데모 + 회고 + 다음 스프린트 조정

## 5) 품질 게이트 (Definition of Done)

- 단위/통합 테스트 통과
- 핵심 E2E 시나리오 통과
- 권한 정책 테스트 통과
- 성능 기준 충족(p95)
- 감사 로그 기록 확인
- 업로드 복구(재시도/재개) 검증 통과

## 6) 리스크 및 대응

- 리스크: 권한 복잡도 증가
- 대응: RBAC 정책을 코드와 문서로 동기화

- 리스크: 시간표 스튜디오 UX 복잡도
- 대응: 탭형 이중 모드 + 공통 검증 패널 제공

- 리스크: Drive API 할당량/권한 이슈
- 대응: 백오프 재시도, 상태 대시보드, 관리자 경보

## 7) 초기 기술 스택 제안

- Web: Next.js + TypeScript
- App: React Native
- Backend: Node.js (NestJS) 또는 Kotlin/Spring
- DB: PostgreSQL
- Cache/Queue: Redis
- Infra: AWS (ECS/Fargate or Kubernetes)
- Monitoring: OpenTelemetry + Grafana

## 8) 즉시 실행 가능한 착수 항목

- 도메인 이벤트/API 명세 워크숍 (2일)
- 시간표 스튜디오 UX 프로토타입 (1주)
- Drive 연동 PoC (1주)
- 데이터 모델 확정 및 마이그레이션 시작 (1주)
