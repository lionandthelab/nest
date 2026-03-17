# Nest 스크린샷 제작 가이드

Last updated: 2026-03-13

이 문서는 Apple App Store 및 Google Play Store 제출용 스크린샷 제작을 위한 실무 가이드입니다.

---

## 1. 필수 사이즈 및 사양

### iOS (App Store Connect)

App Store는 디바이스 그룹별로 별도 스크린샷 세트를 요구합니다. 가장 큰 사이즈(6.9" 또는 6.7")로 제작하면 하위 사이즈에 자동 적용되나, 각 사이즈별 최적화를 권장합니다.

| 디바이스 | 해상도 (px) | 필수 여부 | 비고 |
|----------|------------|-----------|------|
| iPhone 6.9" (iPhone 16 Pro Max) | 1320 × 2868 | 권장 (최신 기기) | 가장 큰 사이즈, 우선 제작 |
| iPhone 6.7" (iPhone 15 Plus / 14 Pro Max) | 1290 × 2796 | 필수 | 기존 최대 사이즈 |
| iPhone 6.5" (iPhone 11 Pro Max / XS Max) | 1284 × 2778 | 권장 | 구형 Plus 기기 대응 |
| iPhone 5.5" (iPhone 8 Plus) | 1242 × 2208 | 권장 | 구형 기기 대응 |
| iPad Pro 12.9" (3세대 이후) | 2048 × 2732 | iPad 지원 시 필수 | 현재 iPad 미지원이면 생략 가능 |

**공통 규칙**
- 포맷: PNG 또는 JPEG (투명 배경 불가)
- 방향: 세로 (Portrait) 권장. 가로도 허용되나 세로 통일 권장
- 최소 3장, 최대 10장 (6~8장 권장)
- 텍스트, 마케팅 문구 오버레이 허용 (앱 UI 가려도 됨)

### Android (Google Play)

| 유형 | 해상도 (px) | 최소/최대 | 비고 |
|------|------------|-----------|------|
| 휴대전화 스크린샷 | 권장 1080 × 1920 이상 | 320~3840px, 비율 16:9 또는 9:16 | 최소 2장, 최대 8장 |
| 태블릿 7" 스크린샷 | 권장 1080 × 1920 | 선택 (권장 4장) | |
| 태블릿 10" 스크린샷 | 권장 1920 × 1200 | 선택 (권장 4장) | |
| 특성 그래픽 (Feature Graphic) | 1024 × 500 | 필수 1장 | Play Store 상단 배너 |

**공통 규칙**
- 포맷: JPEG 또는 24bit PNG (알파 없음)
- 파일 크기: 8MB 이하

---

## 2. 권장 스크린샷 구성 (6~8장)

아래 순서로 스크린샷을 구성합니다. 각 스크린샷은 하나의 핵심 가치를 전달합니다.

| 순서 | 화면 | 역할 | 핵심 메시지 (텍스트 오버레이) | 캡처 포인트 |
|------|------|------|-------------------------------|-------------|
| 1 | 온보딩 / 로그인 | 브랜드 인트로 | 우리 아이가 날아오르기 전, 따뜻한 둥지 Nest | 로고 + 브랜드 라인 + 로그인 폼 |
| 2 | 관리자 대시보드 | 관리자 | 한눈에 보는 홈스쿨 운영 현황 | KPI 카드 (학기·반·아이 수) + 설정 가이드 체크리스트 |
| 3 | 시간표 스튜디오 | 관리자 | 드래그앤드롭으로 쉬운 시간표 편성 | 그리드 시간표 + 과목 팔레트 + 충돌 감지 표시 |
| 4 | 학부모 시간표 뷰 | 학부모 | 내 아이 한 주를 한눈에 | 아이 선택 탭 + 주간 시간표 카드 |
| 5 | 커뮤니티 피드 | 공통 | 함께 나누는 홈스쿨 이야기 | 게시글 카드 리스트 + 댓글 미리보기 |
| 6 | 갤러리 | 공통 | 수업 순간을 안전하게 보관 | 사진 그리드 + 반/아이 필터 |
| 7 | 학기 설정 (선택) | 관리자 | 체계적인 학기와 반 운영 | 학기 카드 + 반 배정 현황 |
| 8 | 교사 허브 (선택) | 교사 | 담당 수업에 집중하는 교사 공간 | 수업 목록 + 활동 기록 버튼 |

---

## 3. 텍스트 오버레이 가이드

각 스크린샷 상단 또는 하단에 한 줄 마케팅 문구를 오버레이합니다.

### 레이아웃 원칙
- 텍스트 영역 높이: 전체 이미지의 약 20~25%
- 텍스트 배치: 스크린샷 위쪽(앱 UI는 하단 75%)에 텍스트 오버레이 권장
- 배경: `#F9F7F2` (Creamy White) 단색 또는 `#DCAE96` → `#F9F7F2` 부드러운 그라데이션

### 타이포그래피
| 용도 | 폰트 | 크기 (6.7" 기준) | 색상 |
|------|------|-----------------|------|
| 메인 헤드라인 | 고운바탕 (KoPub Batang 대안 가능) | 52~60pt | `#2E2A27` |
| 서브 캡션 | Noto Sans KR Regular | 32~36pt | `#6C625C` |
| 브랜드 강조 | 고운바탕 Bold | 52pt | `#DCAE96` (Dusty Rose) |

### 각 화면별 문구 초안

```
[1] 온보딩
메인: 따뜻한 둥지에서 시작하세요
서브: 홈스쿨 운영의 새로운 기준, Nest

[2] 대시보드
메인: 한눈에 보는 홈스쿨 운영 현황
서브: 학기 · 반 · 아이 · 교사를 한 화면에서

[3] 시간표
메인: 드래그 한 번으로 완성되는 시간표
서브: 교사 · 교실 충돌 자동 감지

[4] 학부모 뷰
메인: 우리 아이 한 주를 한눈에
서브: 맞춤형 시간표를 언제 어디서나

[5] 커뮤니티
메인: 함께 나누는 홈스쿨 이야기
서브: 게시글 · 댓글 · 좋아요로 활발한 소통

[6] 갤러리
메인: 수업 순간을 안전하게 보관
서브: Google Drive 연동, 권한 기반 접근
```

---

## 4. 특성 그래픽 (Feature Graphic) — Android 전용

- 사이즈: 1024 × 500 px
- 내용: 앱 로고 중앙 배치 + 브랜드 슬로건 + 앱 이름
- 배경: `#DCAE96` (Dusty Rose) 단색 또는 브랜드 그라데이션
- 텍스트: "Nest – 홈스쿨 운영 플랫폼" / "우리 아이가 날아오르기 전, 따뜻한 둥지"
- 이미지 또는 아이콘을 포함할 경우 저작권 없는 일러스트 사용

---

## 5. 디바이스 목업 프레임

스크린샷에 디바이스 목업을 씌워 실감 나는 이미지를 만듭니다.

### 권장 목업 도구
| 도구 | 특징 | URL |
|------|------|-----|
| Figma (Device Mockup 플러그인) | 무료, 커스텀 가능 | https://figma.com |
| Rotato | 고품질 3D 목업 | https://rotato.app |
| AppMockUp | 스토어 전용 스크린샷 자동 생성 | https://app-mockup.com |
| MaCosmos (Previewed) | 다중 디바이스 동시 생성 | https://previewed.app |

### 권장 목업 기기
- iOS: iPhone 15 Pro Max (티타늄 프레임)
- Android: Pixel 8 Pro 또는 Samsung Galaxy S24 Ultra

---

## 6. fastlane 자동화 (선택)

반복 스크린샷 캡처를 자동화하려면 fastlane `snapshot` (iOS) 또는 `screengrab` (Android)을 사용합니다.

### iOS — fastlane snapshot 설정

```ruby
# frontend/ios/fastlane/Snapfile
devices([
  "iPhone 15 Pro Max",
  "iPhone 14 Plus",
  "iPhone 8 Plus"
])

languages(["ko-KR"])

scheme("Runner")
output_directory("../screenshots/ios")
clear_previous_screenshots(true)
```

```bash
cd frontend/ios
fastlane snapshot
```

### Android — fastlane screengrab 설정

```ruby
# frontend/android/fastlane/Screengrabfile
locales(["ko-KR"])
output_directory("../screenshots/android")
clear_previous_screenshots(true)
app_apk_path("build/app/outputs/apk/release/app-release.apk")
```

```bash
cd frontend/android
fastlane screengrab
```

### 사전 요건
- fastlane 설치: `gem install fastlane`
- iOS: XCUITest 기반 스크린샷 액션 작성 필요
- Android: Espresso 기반 스크린샷 액션 작성 필요
- 언어별 Localizable 파일 준비

> 현재 단계에서는 수동 캡처 후 Figma 목업 적용 방식이 더 빠를 수 있습니다. 앱이 안정화되면 fastlane 자동화를 도입하는 것을 권장합니다.

---

## 7. 스크린샷 제작 워크플로우 체크리스트

```
[ ] 1. 스크린샷 캡처할 화면 목록 확정 (위 6~8장 구성 참고)
[ ] 2. 앱 내 테스트 데이터 준비 (실제처럼 보이는 샘플 홈스쿨·반·시간표)
[ ] 3. 시뮬레이터 또는 실기기에서 각 화면 스크린샷 캡처
[ ] 4. Figma에 디바이스 목업 프레임 배치
[ ] 5. 텍스트 오버레이 추가 (위 문구 초안 참고)
[ ] 6. 브랜드 컬러(#F9F7F2, #DCAE96) 및 폰트 일관성 확인
[ ] 7. 각 스토어 사이즈 내보내기 (iOS: 1290×2796 우선, Android: 1080×1920)
[ ] 8. 파일명 규칙: nest_screenshot_{순서}_{플랫폼}_{해상도}.png
     예: nest_screenshot_01_ios_1290x2796.png
[ ] 9. 최종 검수: 앱 아이콘·버전·UI가 제출 빌드와 일치하는지 확인
```
