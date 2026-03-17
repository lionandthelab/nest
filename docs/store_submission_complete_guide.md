# Nest (네스트) 앱 스토어 출시 완전 가이드 2026

*홈스쿨 관리 플랫폼 / Flutter 앱 / 한국 사용자 대상*

---

## 목차

1. [Google Play Store 요구사항](#1-google-play-store)
2. [Apple App Store 요구사항](#2-apple-app-store)
3. [공통 필수 문서](#3-공통-필수-문서)
4. [스크린샷 제작 가이드](#4-스크린샷-제작-가이드)

---

## 1. Google Play Store 요구사항

### 1-1. 개발자 계정 설정

- [ ] **Google Play Console 계정 생성** — [play.google.com/console](https://play.google.com/console)
- [ ] **등록비 납부** — 최초 1회 $25 USD (일회성)
- [ ] **개발자 신원 인증 완료** — 실명 또는 사업자 정보 등록
- [ ] **결제 프로필 연결** — 인앱 결제 수익 수령을 위한 Google Payments 설정
- [ ] **개발자 페이지 프로필 작성** — 개발자 이름, 웹사이트, 이메일 주소
- [ ] **2단계 인증(2FA) 활성화** — 계정 보안 필수

### 1-2. 앱 빌드 요구사항

#### Target SDK / 버전 요구사항 (2026 기준)
- [ ] **targetSdkVersion = 35** (Android 15) — 2025년 8월 31일부터 신규 앱/업데이트 모두 필수
- [ ] **minSdkVersion** — Flutter 기본값 사용 (최소 API 21 권장)
- [ ] **compileSdkVersion** — Flutter가 자동 관리 (`flutter.compileSdkVersion`)
- [ ] **16KB 메모리 페이지 지원** — Android 15 호환성을 위해 필요 (NDK 사용 시 특히 중요)
- [ ] **Play Integrity API** 사용 — SafetyNet은 완전히 폐기됨, 보안 검증 시 필수

#### AAB 빌드 생성
- [ ] **AAB(Android App Bundle) 형식 필수** — APK는 프로덕션 제출 불가
- [ ] 빌드 명령어: `flutter build appbundle --release`
- [ ] 출력 경로: `build/app/outputs/bundle/release/app.aab`
- [ ] 지원 아키텍처 확인: `armeabi-v7a`, `arm64-v8a`, `x86_64`

#### 앱 서명 (App Signing)
- [ ] **업로드 키스토어(Upload Keystore) 생성**:
  ```bash
  keytool -genkey -v -keystore ~/upload-keystore.jks \
    -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```
- [ ] `android/key.properties` 파일 생성 (`.gitignore`에 반드시 추가):
  ```properties
  storePassword=<비밀번호>
  keyPassword=<비밀번호>
  keyAlias=upload
  storeFile=<keystore 파일 절대경로>
  ```
- [ ] `android/app/build.gradle.kts`에 서명 설정 추가
- [ ] **Play App Signing 활성화** — 신규 앱 필수; Google이 최종 배포 키 관리
- [ ] **키스토어 파일 안전한 곳에 백업** — 분실 시 앱 업데이트 불가

#### 앱 버전 관리
- [ ] `pubspec.yaml`에서 버전 관리: `version: 1.0.0+1`
- [ ] `versionCode` (build number)는 매 업로드마다 반드시 증가
- [ ] `versionName` (version name)은 사용자에게 표시되는 버전

### 1-3. 스토어 등록 정보 (Store Listing)

#### 앱 기본 정보
- [ ] **앱 이름** — 최대 30자 (예: `Nest - 홈스쿨 관리 플랫폼`)
- [ ] **짧은 설명** — 최대 80자; 핵심 기능을 간결하게
- [ ] **전체 설명** — 최대 4,000자; HTML 불가, 일반 텍스트만
- [ ] **앱 카테고리** 선택 — `교육(Education)` 카테고리 권장
- [ ] **앱 태그** — 관련 키워드 5개 이하 선택
- [ ] **이메일 주소** — 사용자 문의를 위한 연락처 (필수)
- [ ] **웹사이트 URL** — 개인정보처리방침 페이지 포함
- [ ] **개인정보처리방침 URL** — 반드시 별도 URL로 등록 (필수)

#### 그래픽 에셋
- [ ] **앱 아이콘** — 512×512px, PNG 32비트(알파 포함), 최대 1MB
- [ ] **특성 그래픽(Feature Graphic)** — 1,024×500px, JPEG 또는 PNG 24비트(알파 없음), 최대 1MB
- [ ] **스크린샷** — 최소 2장, 최대 8장 (폰/태블릿/Chromebook 등 기기별 별도)
  - JPEG 또는 PNG 24비트 (알파 없음)
  - 한 변 최소 320px, 최대 3,840px
  - 가로세로 비율 16:9 또는 9:16 필수
  - 파일당 최대 8MB
- [ ] **홍보 영상(Promo Video)** — YouTube URL 형식 (선택사항이나 강력 권장)

### 1-4. 콘텐츠 등급 질문지 답변 가이드 (교육 앱)

Play Console의 **정책 → 앱 콘텐츠 → 콘텐츠 등급** 메뉴에서 IARC 설문지 작성:

| 질문 항목 | Nest 앱 예상 답변 | 비고 |
|-----------|------------------|------|
| 폭력적 콘텐츠 | 없음 | |
| 성적 콘텐츠 | 없음 | |
| 도박 관련 기능 | 없음 | |
| 사용자 생성 콘텐츠(UGC) | 있음 (과제, 학습 기록) | |
| 위치정보 공유 | 없음 또는 선택적 | |
| 소셜 기능 (채팅, 커뮤니티) | 있을 경우 신고 | |
| 개인정보 수집 | 있음 (계정 정보) | |
| 인앱 결제 | 있을 경우 신고 | |
| **타겟 연령 그룹** | **어린이 포함 여부 명시** | Families Policy 적용 가능 |

- [ ] 설문 완료 후 등급 확인 — **만 3세 이상(Everyone)** 또는 그 이상 등급 예상
- [ ] 아동이 대상에 포함될 경우 **Google Play Families Policy** 준수 확인
- [ ] 설문 응답은 정확하게 작성 — 허위 응답 시 앱 삭제/정지 처분

### 1-5. 데이터 안전(Data Safety) 섹션 작성 가이드

Play Console의 **정책 → 앱 콘텐츠 → 데이터 안전** 메뉴:

#### Nest 앱에서 선언해야 할 데이터 유형

| 데이터 범주 | 구체적 항목 | 수집 여부 | 사용자에 연결 | 공유 여부 |
|-------------|-----------|---------|------------|---------|
| 개인정보 | 이름, 이메일 주소 | ✅ | ✅ | 조건부 |
| 앱 활동 | 앱 내 활동 기록 | ✅ | ✅ | ❌ |
| 식별자 | 사용자 ID | ✅ | ✅ | ❌ |
| 기기 정보 | 기기 ID (푸시 알림용) | 조건부 | ❌ | ❌ |
| 진단 정보 | 충돌 로그 (Firebase 등) | 조건부 | ❌ | 제3자에 공유 |

- [ ] **데이터 수집 여부** 항목 모두 정확히 선택
- [ ] **데이터 암호화 전송** 여부 선언 (HTTPS 사용 시 ✅)
- [ ] **데이터 삭제 요청 방법** 제공 여부 — 계정 삭제 기능 앱 내 필수 (2026년 정책)
- [ ] **제3자 라이브러리 확인** — Firebase, Analytics SDK 등이 수집하는 데이터 포함해서 신고
- [ ] 아동 대상 앱: 아동 개인정보 수집 관련 별도 고지

---

## 2. Apple App Store 요구사항

### 2-1. 개발자 계정 설정 (Apple Developer Program)

- [ ] **Apple Developer Program 등록** — [developer.apple.com/programs](https://developer.apple.com/programs/)
- [ ] **연간 구독료 납부** — $99 USD/년 (개인 또는 조직)
- [ ] **법인 등록 시** — D-U-N-S 번호 필요 (Dun & Bradstreet)
- [ ] **App Store Connect 접근** — [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
- [ ] **Bundle ID 등록** — Apple Developer 포털에서 고유한 Bundle ID 생성
  - 현재 프로젝트: `com.lionandthelab.nest` (이미 설정됨)
- [ ] **인증서 및 프로비저닝 프로파일** — Xcode 자동 관리 모드 권장

### 2-2. 앱 빌드 요구사항

#### 최소 요구사항
- [ ] **Xcode 최신 버전 사용** — App Store 제출은 최신 Xcode 필수
- [ ] **iOS 최소 지원 버전** — iOS 13 이상 (Flutter 공식 지원 최솟값)
  - Xcode → Build Settings → Deployment → iOS Deployment Target 확인
- [ ] **Swift/Objective-C 브리징** — Flutter가 자동 처리

#### 코드 서명 (Code Signing)
- [ ] Xcode에서 **Automatically manage signing** 활성화 (권장)
- [ ] **개발 팀(Team)** 올바르게 선택
- [ ] **Distribution Certificate** — App Store 배포용 자동 생성
- [ ] **App Store Provisioning Profile** — 자동 생성 또는 수동 생성

#### IPA 빌드 생성
- [ ] Flutter로 IPA 빌드:
  ```bash
  flutter build ipa
  ```
- [ ] 출력 경로:
  - `.xcarchive`: `build/ios/archive/`
  - `.ipa`: `build/ios/ipa/`

#### App Store Connect 업로드 방법
- [ ] **방법 1 (권장)** — Xcode에서 `.xcarchive` 열기 → Validate App → Distribute App
- [ ] **방법 2** — Apple Transporter 앱 (`.ipa` 드래그앤드롭)
- [ ] **방법 3** — 커맨드라인:
  ```bash
  xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa \
    --apiKey your_api_key --apiIssuer your_issuer_id
  ```

### 2-3. App Store Connect 등록 정보

- [ ] **앱 이름** — 최대 **30자** (예: `Nest - 홈스쿨 관리`)
- [ ] **부제목(Subtitle)** — 최대 30자 (선택); 검색 최적화에 활용
- [ ] **키워드** — 최대 100자, 쉼표로 구분; 검색 노출 최적화
- [ ] **설명(Description)** — 최대 4,000자; 첫 세 줄이 가장 중요 (더 보기 전 노출)
- [ ] **홍보 문구(Promotional Text)** — 최대 170자; 업데이트 없이 수정 가능
- [ ] **카테고리** — 기본: `교육(Education)`, 보조: `생산성(Productivity)` 권장
- [ ] **지원 URL** — 사용자 지원 웹페이지 URL (필수)
- [ ] **마케팅 URL** — 앱 소개 페이지 (선택)
- [ ] **개인정보처리방침 URL** — 반드시 입력 (필수)
- [ ] **연령 등급** — 설문 응답 기반 자동 결정
- [ ] **가격 및 제공 국가** 설정 — 한국(KR) 반드시 포함
- [ ] **앱 심사 메모(Review Notes)** — 심사관을 위한 설명, 테스트 계정 정보 포함

### 2-4. 스크린샷 사양 (기기별)

2026년 기준 **필수 제출 크기**:

#### iPhone (필수)
| 기기 | 화면 크기 | 세로 해상도 | 가로 해상도 |
|------|---------|------------|------------|
| **iPhone 16 Pro Max / 17 Pro Max** (필수) | 6.9인치 | **1260 × 2736** | 2736 × 1260 |
| iPhone 16 Pro / 17 / 17 Pro | 6.3인치 | 1179 × 2556 | 2556 × 1179 |
| iPhone 16 Plus / 15 Plus 등 | 6.5인치 | 1284 × 2778 | 2778 × 1284 |

> 2026년 기준: **6.9인치(1260×2736) 스크린샷이 있으면 소형 iPhone에 자동 적용됨**. 이 크기가 없을 경우 6.5인치(1284×2778) 대체 가능.

#### iPad (앱이 iPad를 지원하는 경우 필수)
| 기기 | 화면 크기 | 세로 해상도 | 가로 해상도 |
|------|---------|------------|------------|
| **iPad Pro M4/M5, iPad Air M4** (필수) | 13인치 | **2064 × 2752** | 2752 × 2064 |
| iPad Pro 11인치 | 11인치 | 1488 × 2266 | 2266 × 1488 |
| iPad Pro 12.9인치 (구형) | 12.9인치 | 2048 × 2732 | 2732 × 2048 |

> **13인치(2064×2752) 스크린샷**이 있으면 구형 iPad에 자동 적용됨.

#### 공통 스크린샷 요구사항
- [ ] 형식: `.jpeg`, `.jpg`, `.png` (알파 없음, RGB)
- [ ] 최소 1장, 최대 10장
- [ ] 앱 UI가 실제로 작동하는 화면 보여야 함 (타이틀/스플래시 화면만 있으면 거절)
- [ ] 기기 프레임 추가는 선택사항

### 2-5. 앱 심사 가이드라인 체크리스트

#### 기능 및 안정성
- [ ] 실제 기기에서 충돌/버그 없이 작동 테스트 완료
- [ ] 모든 링크, 버튼, 화면 전환 정상 작동
- [ ] 백엔드 서버 및 API 심사 기간 중 정상 운영 중
- [ ] 플레이스홀더 텍스트, 임시 콘텐츠, 빈 URL 없음
- [ ] **심사관용 테스트 계정(부모 역할 + 선생님 역할)** Review Notes에 포함

#### 메타데이터 정확성
- [ ] 앱 이름 최대 30자, 상표권 침해 없음
- [ ] 설명이 실제 앱 기능과 일치
- [ ] 스크린샷이 실제 앱 화면 반영 (타 플랫폼 UI 금지)
- [ ] 경쟁 앱 이름 언급 금지

#### 개인정보 및 법적 요구사항
- [ ] **개인정보처리방침 URL** — 메타데이터 및 앱 내부 모두 링크
- [ ] **App Tracking Transparency(ATT)** — 추적 시 반드시 권한 요청
- [ ] 제3자 로그인(Google, Kakao 등) 사용 시 **대체 로그인 수단** 반드시 제공
- [ ] **계정 삭제 기능** 앱 내 제공 (2024년부터 필수)
- [ ] 수집 데이터에 대한 명확한 동의 절차

#### 어린이/교육 앱 특이사항
- [ ] 아동 대상 앱: 제3자 광고/분석 SDK 사용 제한
  - 예외: 아동 데이터 미수집 서비스(IDFA, 이름, 생년월일, 이메일, 위치, 기기정보 미수집)
- [ ] Kids 카테고리 등록 시 **부모 게이트(Parental Gate)** 필수 구현
- [ ] 앱 내 쉽게 접근 가능한 **고객지원 연락처** 포함 (교육 앱 필수)
- [ ] 미성년자 개인정보 수집 시 개인정보처리방침 필수

### 2-6. 개인정보 라벨 (Privacy Nutrition Labels)

App Store Connect → 앱 개인정보 메뉴에서 작성:

#### Nest 앱 예상 신고 항목

| 데이터 유형 | 사용 목적 | 사용자에 연결 | 추적 사용 |
|------------|---------|------------|---------|
| 이름 | 앱 기능, 계정 관리 | ✅ | ❌ |
| 이메일 주소 | 계정 관리, 앱 기능 | ✅ | ❌ |
| 사용자 ID | 앱 기능 | ✅ | ❌ |
| 앱 내 활동 | 앱 기능, 분석 | ✅ | ❌ |
| 충돌 데이터 | 앱 개선 | ❌ | ❌ |
| 기기 ID (푸시용) | 앱 기능 | 조건부 | ❌ |

- [ ] **추적(Tracking)** 해당 여부 판단 — 제3자 광고 미사용 시 "추적 없음" 선택 가능
- [ ] 사용하는 **모든 제3자 SDK** 데이터 수집 포함해 신고 (Firebase, Sentry 등)
- [ ] 신고 후 앱 업데이트 시마다 내용 변경되면 재신고 필요

#### 2026년 신규 요구사항
- [ ] **연령 등급 상세 정보 제출** — 2026년 1월 31일 마감, 모든 앱 필수
  - Apple이 Privacy Nutrition Labels와 유사한 방식으로 아동 보호 강화

---

## 3. 공통 필수 문서

### 3-1. 개인정보처리방침 (한국 개인정보보호법 PIPA 준수)

#### 법적 근거
- **개인정보 보호법(PIPA)** — 주요 규제법
- **정보통신망 이용촉진 및 정보보호 등에 관한 법률** — 온라인 서비스 적용
- 2026년 2월 12일 개정: **위반 시 매출액의 최대 10% 과징금** 부과 가능

#### 개인정보처리방침 필수 포함 항목

- [ ] **수집하는 개인정보 항목** — 이름, 이메일, 학습 기록 등 구체적 열거
- [ ] **개인정보 수집 및 이용 목적** — 서비스 제공, 회원 관리, 공지사항 전달 등
- [ ] **개인정보 보유 및 이용기간** — 회원 탈퇴 즉시 삭제 또는 법정 보존 기간
- [ ] **개인정보 제3자 제공 현황** — 미제공 또는 제공 대상/목적/항목/기간 명시
- [ ] **개인정보 처리 위탁 현황** — Firebase, 호스팅 업체 등 수탁자 명시
- [ ] **정보주체의 권리** — 열람, 정정, 삭제, 처리정지 요구 방법
- [ ] **개인정보 보호책임자** — 이름, 직책, 연락처
- [ ] **개인정보 처리방침 변경 고지 방법**
- [ ] **안전성 확보 조치** — 암호화, 접근권한 관리 등
- [ ] **해외 이전 여부** — Firebase(미국), 클라우드 서버 위치 명시

#### 해외 서비스(외국 기업) 특이 요건
- [ ] **국내 대리인 지정** — 개정 PIPA 제31조의2 (2025년 10월 2일 시행)
  - 1천만 명 이상 또는 매출 1조원 이상 서비스에 해당
  - 해당하지 않더라도 사전 지정 권장
- [ ] **개인정보 침해 발생 시 PIPC 및 정보주체 통지 의무**

#### 아동 개인정보 특별 규정 (한국 개인정보보호법 제22조의2)
- [ ] **만 14세 미만 아동** 개인정보 수집 시 **법정대리인(부모/보호자) 동의** 필수
- [ ] 법정대리인 동의 확인 방법 명시 (SMS, 카드정보, 휴대전화 본인인증 등)
- [ ] **아동 친화적 개인정보처리방침** 별도 제공 권장 (개인정보보호위원회 2025년 4월 개정 지침)
- [ ] 아동용 개인정보처리방침: 쉬운 언어, 큰 글씨, 그림 활용 권장

### 3-2. 이용약관

- [ ] **서비스 이용 자격** — 연령 제한 명시 (만 14세 미만 보호자 동의 요구)
- [ ] **서비스 내용 및 변경** — 제공 기능, 변경 시 고지 방법
- [ ] **금지 행위** — 계정 공유, 악용 행위 등
- [ ] **지식재산권** — 앱 콘텐츠 저작권 귀속
- [ ] **면책조항** — 서비스 중단, 제3자 콘텐츠 책임 한계
- [ ] **분쟁 해결** — 준거법(대한민국 법), 관할 법원(서울중앙지방법원 등)
- [ ] **연락처 및 사업자 정보** — 상호, 주소, 대표자, 사업자등록번호

### 3-3. 아동 관련 데이터 정책

#### COPPA (미국 아동 온라인 개인정보보호법) — 미국 앱 스토어 출시 시 적용
- [ ] 13세 미만 아동 대상 서비스 시 COPPA 준수
- [ ] 검증 가능한 부모 동의 획득 절차
- [ ] 수집 데이터 최소화, 제3자 공유 제한

#### 한국 아동 개인정보보호
- [ ] 만 14세 미만 아동 서비스 이용 가입 흐름에서 **법정대리인 동의 절차** 구현
- [ ] 동의 확인 방법: 법정대리인 휴대전화 인증, 신용카드 정보 확인 등
- [ ] 아동 계정의 데이터 삭제 요청은 **부모도 신청 가능**하도록 처리
- [ ] 홈스쿨 앱 특성상 **학생 데이터(학습 기록, 과제 등)**는 민감 정보로 취급 권장

#### Google Play Families Policy (아동 대상 앱)
- [ ] 타겟 연령에 아동 포함 시 [Families Policy](https://support.google.com/googleplay/android-developer/answer/9893335) 준수
- [ ] 승인된 광고 네트워크만 사용 (또는 광고 완전 제거)
- [ ] COPPA, GDPR-K, 한국 아동 개인정보보호법 준수 명시

---

## 4. 스크린샷 제작 가이드

### 4-1. 각 스토어별 필요한 해상도/기기 목록

#### Google Play Store

| 기기 유형 | 최소 해상도 | 최대 해상도 | 비율 | 최대 장 수 |
|-----------|-----------|-----------|------|----------|
| 전화(Phone) | 320px (한 변) | 3,840px (한 변) | 9:16 또는 16:9 | 8장 |
| 7인치 태블릿 | 320px | 3,840px | 9:16 또는 16:9 | 8장 |
| 10인치 태블릿 | 320px | 3,840px | 9:16 또는 16:9 | 8장 |

**실용 권장 해상도 (Phone):** `1080 × 1920px` (세로) 또는 `1080 × 2340px` (최신 비율)

#### Apple App Store (2026 필수 제출 목록)

| 필수 여부 | 기기 | 세로 (픽셀) |
|---------|------|------------|
| **필수** | iPhone 6.9인치 (16 Pro Max / 17 Pro Max) | 1260 × 2736 |
| **필수** (iPad 지원 시) | iPad 13인치 (Pro M4/M5, Air M4) | 2064 × 2752 |
| 선택 | iPhone 6.5인치 | 1284 × 2778 |
| 선택 | iPhone 6.3인치 | 1179 × 2556 |
| 선택 | iPad 11인치 | 1488 × 2266 |

> **실용 전략:** iPhone 6.9인치(1260×2736) + iPad 13인치(2064×2752) 두 가지 크기만 제작하면 나머지 기기에 자동 적용됨.

### 4-2. 효과적인 스크린샷 구성 전략

#### 장수별 콘텐츠 구성 권장안 (6~8장 기준)

| 순서 | 화면 내용 | 목적 |
|------|---------|------|
| 1장 | 앱의 핵심 가치 — 대시보드 또는 홈 화면 + 한 줄 캐치프레이즈 | 첫인상, 즉시 가치 전달 |
| 2장 | 학습 일정/커리큘럼 관리 화면 | 핵심 기능 #1 소개 |
| 3장 | 과제 추적 / 학습 기록 화면 | 핵심 기능 #2 소개 |
| 4장 | 부모-선생님 협업 / 알림 화면 | 차별화 포인트 |
| 5장 | 학습 통계 / 진도 리포트 화면 | 데이터 기반 관리 강조 |
| 6장 | 멀티 자녀 지원 또는 설정 화면 | 추가 기능 |
| 7장 | 한국어 인터페이스 강조 화면 | 한국 사용자 타겟 명시 |
| 8장 | CTA — "지금 시작하기" 스타일 마무리 | 다운로드 유도 |

#### 디자인 원칙

- [ ] **텍스트 영역 확보** — 상단 또는 하단 20~30%를 캡션/설명 텍스트 영역으로 확보
- [ ] **실제 앱 UI 반드시 포함** — 텍스트만 있는 이미지 거절 사유 (Apple 기준)
- [ ] **브랜드 일관성** — Nest 앱 색상 팔레트와 폰트 통일
- [ ] **한국어 텍스트** — 대상 사용자가 한국인이므로 스크린샷 캡션도 한국어로
- [ ] **다크모드 대응** — 가능하면 라이트/다크 혼합 구성
- [ ] **기기 프레임(Device Frame)** — Google Play는 선택사항, Apple은 선택사항이나 시각적 효과 있음
- [ ] **Safe Zone 준수** — 노치, Dynamic Island, 홈 인디케이터 영역에 핵심 UI 배치 금지

#### 추천 제작 도구

| 도구 | 특징 | 비용 |
|------|------|------|
| Figma | 커스텀 디자인, 기기 프레임 플러그인 | 무료 플랜 있음 |
| Canva | 빠른 제작, 템플릿 풍부 | 무료/유료 |
| AppScreens.com | 스토어 최적화 특화 | 유료 |
| Screenhance | 자동 크기 조정 | 유료 |

---

## 최종 제출 전 체크리스트 요약

### Google Play Store

- [ ] targetSdkVersion 35 (Android 15) 설정
- [ ] `flutter build appbundle --release`로 AAB 생성
- [ ] 업로드 키스토어 서명 완료
- [ ] Play App Signing 활성화
- [ ] 개인정보처리방침 URL 등록
- [ ] 데이터 안전 섹션 전부 작성
- [ ] IARC 콘텐츠 등급 질문지 완료
- [ ] 앱 아이콘 (512×512), 특성 그래픽 (1024×500), 스크린샷 준비
- [ ] 계정 삭제 기능 앱 내 구현

### Apple App Store

- [ ] Apple Developer Program 등록 ($99/년)
- [ ] Bundle ID `com.lionandthelab.nest` 등록 확인
- [ ] Xcode 자동 서명 설정
- [ ] `flutter build ipa` 빌드 및 App Store Connect 업로드
- [ ] iOS 최소 버전 13 확인
- [ ] 앱 이름 30자 이하
- [ ] 스크린샷: iPhone 6.9인치(1260×2736) + iPad 13인치(2064×2752) 필수
- [ ] Privacy Nutrition Labels 전부 입력
- [ ] 연령 등급 상세 정보 제출 (2026년 신규 필수)
- [ ] 개인정보처리방침 URL + 지원 URL 입력
- [ ] 심사관용 테스트 계정 Review Notes에 포함
- [ ] 계정 삭제 기능 앱 내 구현

### 공통 문서

- [ ] 한국 개인정보보호법(PIPA) 준수 개인정보처리방침 작성 및 게시
- [ ] 이용약관 작성 및 게시
- [ ] 만 14세 미만 아동 법정대리인 동의 절차 구현
- [ ] 국내 대리인 지정 검토 (해당 규모 시)
- [ ] 개인정보보호책임자 지정 및 연락처 공개

---

## 참고 공식 문서 출처

- [Flutter Android 배포 공식 문서](https://docs.flutter.dev/deployment/android) — Flutter 공식
- [Flutter iOS 배포 공식 문서](https://docs.flutter.dev/deployment/ios) — Flutter 공식
- [Google Play 데이터 안전 섹션 작성 가이드](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en) — Google 공식
- [Google Play 콘텐츠 등급 요구사항](https://support.google.com/googleplay/android-developer/answer/9859655?hl=en) — Google 공식
- [Google Play 스크린샷/그래픽 자산 추가](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en) — Google 공식
- [Apple App Store 스크린샷 사양 공식](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) — Apple 공식
- [Apple 앱 개인정보 상세 정보(Nutrition Labels)](https://developer.apple.com/app-store/app-privacy-details/) — Apple 공식
- [Apple App Store 심사 가이드라인](https://developer.apple.com/app-store/review/guidelines/) — Apple 공식
- [Apple App Store Connect 업로드 가이드](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/) — Apple 공식
- [한국 개인정보보호법(PIPA) 영문 번역](https://elaw.klri.re.kr/eng_service/lawView.do?hseq=62389&lang=ENG) — 한국법제연구원
- [개인정보보호위원회 공식 사이트](https://www.pipc.go.kr/eng/user/ltn/new/noticeDetail.do?bbsId=BBSMSTR_000000000001&nttId=2331) — PIPC 공식
- [한국 PIPA 2026 개요](https://pureumlawoffice.com/personal-information-protection-act-pipa/) — 전문 법률 분석
- [아동청소년 개인정보보호 가이드라인](https://www.cisp.or.kr/wp-content/uploads/2022/08/%EC%95%84%EB%8F%99%EC%B2%AD%EC%86%8C%EB%85%84-%EA%B0%9C%EC%9D%B8%EC%A0%95%EB%B3%B4-%EB%B3%B4%ED%98%B8-%EA%B0%80%EC%9D%B4%EB%93%9C%EB%9D%BC%EC%9D%B8%EC%B5%9C%EC%A2%85.pdf) — 개인정보보호위원회
- [Google Play 2026 Flutter 배포 가이드](https://flutterfever.com/how-to-deploy-flutter-app-on-google-play-store/) — Flutter Fever
- [앱 스토어 요구사항 2026 종합](https://natively.dev/articles/app-store-requirements) — Natively
