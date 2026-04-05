# Nest Flutter 앱 실행 가이드

## 사전 준비

```bash
# Flutter 환경 확인 (누락 항목이 있으면 안내에 따라 설치)
flutter doctor

# 프로젝트 의존성 설치
cd ~/dev/nest/frontend
flutter pub get
```

---

## 1. Chrome 웹 브라우저에서 실행

```bash
cd ~/dev/nest/frontend
flutter run -d chrome
```

Google OAuth 콜백 테스트가 필요하면 포트를 지정한다:

```bash
flutter run -d chrome --web-port=8080
```

---

## 2. iOS Simulator에서 실행 (macOS 전용)

### 사전 조건

- Xcode 설치 (App Store)
- Xcode 라이선스 동의: `sudo xcodebuild -license accept`
- CocoaPods 설치: `sudo gem install cocoapods`

### 실행

```bash
# 시뮬레이터 열기
open -a Simulator

# 앱 실행
cd ~/dev/nest/frontend
flutter run -d iPhone
```

---

## 3. Android Emulator에서 실행

### 사전 조건

- Android Studio 설치
- Android SDK 설치 (Android Studio 설치 시 함께 설치됨)
- Android 라이선스 동의: `flutter doctor --android-licenses`

### 에뮬레이터 생성

1. Android Studio > **Tools > Device Manager**
2. **Create Virtual Device** 클릭
3. 디바이스 선택 (예: Pixel 7) > **Next**
4. 시스템 이미지 선택 (최신 API 권장, 없으면 Download) > **Next** > **Finish**

### 실행

1. Device Manager에서 생성한 에뮬레이터 옆 **▶ 버튼** 클릭 (부팅 대기)
2. 앱 실행:

```bash
cd ~/dev/nest/frontend
flutter run -d emulator
```

### PC 키보드 입력 활성화

Device Manager > 에뮬레이터 **연필 아이콘(Edit)** > **Show Advanced Settings** > **Enable keyboard input** 체크 > **Finish** > 에뮬레이터 재시작

---

## 모든 디바이스에 동시 실행

```bash
flutter run -d all
```

---

## Hot Reload (실시간 코드 반영)

앱 실행 중 코드를 수정한 뒤:

| 키 | 동작 |
|---|---|
| `r` | Hot Reload (State 유지, UI만 갱신) |
| `R` | Hot Restart (앱 처음부터 재시작) |
| `q` | 앱 종료 |

Android Studio에서는 `Ctrl+S` (저장) 시 자동으로 Hot Reload가 발동한다.

---

## 빌드 에러 발생 시

```bash
flutter clean
flutter pub get
flutter run
```
