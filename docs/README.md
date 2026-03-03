# Nest 개발 문서 패키지

이 디렉토리는 **Nest(네스트) 홈스쿨링 플랫폼**의 초기 개발 착수를 위한 핵심 문서 모음입니다.

브랜드 문장: **"우리 아이가 날아오르기 전, 따뜻한 둥지 Nest"**

## 문서 목록

1. `01_product_vision_and_brand.md`
- 브랜드 철학, Warm Nest 컨셉, 컬러 시스템, 핵심 모듈

2. `02_prd_mvp.md`
- MVP 범위 중심의 제품 요구사항 문서(PRD)

3. `03_information_architecture_and_permissions.md`
- 웹/앱 정보구조(IA), 역할 체계, 권한 매트릭스

4. `04_data_model_and_erd.md`
- 도메인 데이터 모델, 핵심 엔티티, ERD

5. `05_timetable_assignment_engine.md`
- 시간표 편성 도구(채팅 프롬프트 + 수동 드래그앤드롭) 상세 설계

6. `06_team_structure_and_delivery_plan.md`
- 전문 개발팀 구성, 단계별 로드맵, 운영 체계

7. `07_system_architecture_and_integration.md`
- 시스템 아키텍처, 서비스 경계, Google Drive 연동 구조

8. `08_mvp_user_stories_and_acceptance.md`
- 사용자 스토리, 수용 기준, E2E 시나리오

9. `09_api_design_v1.md`
- API 엔드포인트 설계, 요청/응답 규약, 오류 코드

10. `../openapi/nest-api-v1.yaml`
- OpenAPI 3.1 명세서

11. `10_supabase_execution_guide.md`
- Supabase 마이그레이션/함수 배포/프론트 실행 가이드

12. `architecture.md`
- Flutter 프론트엔드 구조, 상태관리, OAuth/Drive 흐름, 배포/검증 가이드

13. `execution_tracker.md`
- 다국어/결제 제외 기준의 실행 체크리스트, 반복 개발 로그, 검증 이력

## 권장 읽기 순서

1. 비전/브랜드
2. PRD
3. IA/권한
4. 데이터모델
5. 시간표 엔진
6. 아키텍처/연동
7. API 설계
8. OpenAPI
9. Supabase 실행 가이드

## 문서 사용 원칙

- 본 문서는 MVP 기준으로 작성되었습니다.
- 상세 구현(화면/DB/API)은 본 문서를 기준으로 스프린트별 상세 설계 문서로 분화합니다.
- 정책이 변경되면 `02_prd_mvp.md`를 단일 진실원천(SSOT)으로 우선 업데이트합니다.
