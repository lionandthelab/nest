# Info.plist 문법 해석

## 파일의 역할

iOS 앱의 **설정 명세서**이다. 앱을 설치하고 실행할 때 iOS가 이 파일을 읽어서
앱의 이름, 버전, 지원 방향, URL 스킴, 씬 구성 등을 파악한다.
iOS 개발에서 가장 중요한 설정 파일 중 하나이다.

> 앱을 실행하기 전에 iOS가 먼저 이 파일을 읽는다.
> 따라서 이 파일의 설정이 잘못되면 앱이 아예 실행되지 않을 수 있다.

## 각 키 상세 해석

---

### CADisableMinimumFrameDurationOnPhone

```xml
<key>CADisableMinimumFrameDurationOnPhone</key>
<true/>
```

- **의미**: iPhone에서 최소 프레임 지속 시간 제한을 비활성화한다
- **효과**: ProMotion 디스플레이(120Hz)를 지원하는 기기에서 **120fps 렌더링이 가능**해진다
- **`<true/>`**: Boolean 값. plist에서 true는 `<true/>`, false는 `<false/>`로 표현한다
- **이 설정이 없으면**: 120Hz 기기에서도 60fps로 제한된다

---

### CFBundleDevelopmentRegion

```xml
<key>CFBundleDevelopmentRegion</key>
<string>$(DEVELOPMENT_LANGUAGE)</string>
```

- **의미**: 앱의 기본 개발 언어
- **`$(DEVELOPMENT_LANGUAGE)`**: Xcode 빌드 변수. 빌드 시점에 실제 값으로 치환된다
  - `$(...)`는 Xcode의 변수 참조 문법이다
  - 프로젝트 설정의 Development Language 값을 그대로 사용한다는 의미이다

> `$(변수명)` 문법은 이 파일 전체에서 여러 번 등장한다.
> 값을 하드코딩하지 않고, 빌드 설정에서 중앙 관리하기 위한 것이다.

---

### CFBundleDisplayName

```xml
<key>CFBundleDisplayName</key>
<string>Nest</string>
```

- **의미**: 홈 화면에서 앱 아이콘 아래에 표시되는 이름
- **값**: `Nest`
- **CFBundleName과의 차이**:
  - `DisplayName` = 사용자에게 보이는 이름 (긴 이름 가능)
  - `Name` = 시스템 내부용 이름 (짧은 이름)

---

### CFBundleExecutable

```xml
<key>CFBundleExecutable</key>
<string>$(EXECUTABLE_NAME)</string>
```

- **의미**: 실행 파일의 이름
- **`$(EXECUTABLE_NAME)`**: Xcode가 빌드 시 자동으로 설정하는 실행 파일명 (보통 `Runner`)

---

### CFBundleIdentifier

```xml
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
```

- **의미**: 앱의 고유 식별자 (전 세계에서 유일해야 한다)
- **`$(PRODUCT_BUNDLE_IDENTIFIER)`**: Xcode 프로젝트 설정에서 지정한 Bundle Identifier
  - 이 프로젝트에서는 `com.lionandthelab.nest`이다
- **용도**: App Store 등록, 푸시 알림, 키체인 접근 등에서 앱을 구분하는 데 사용한다

---

### CFBundleInfoDictionaryVersion

```xml
<key>CFBundleInfoDictionaryVersion</key>
<string>6.0</string>
```

- **의미**: Info.plist 파일 포맷의 버전. 사실상 항상 `6.0`이다

---

### CFBundleName

```xml
<key>CFBundleName</key>
<string>Nest</string>
```

- **의미**: 앱의 시스템 내부용 짧은 이름 (16자 이하 권장)

---

### CFBundlePackageType

```xml
<key>CFBundlePackageType</key>
<string>APPL</string>
```

- **의미**: 이 번들이 **앱(Application)**이라는 것을 명시한다
- **APPL**: Application. AppFrameworkInfo.plist에서는 `FMWK`(Framework)이었다
- iOS가 이 값을 보고 "이것은 실행 가능한 앱이다"라고 판단한다

---

### CFBundleShortVersionString / CFBundleVersion

```xml
<key>CFBundleShortVersionString</key>
<string>$(FLUTTER_BUILD_NAME)</string>

<key>CFBundleVersion</key>
<string>$(FLUTTER_BUILD_NUMBER)</string>
```

- **ShortVersionString**: 사용자에게 보이는 버전 (예: `1.2.0`) ← `pubspec.yaml`의 `version: 1.2.0+3`에서 `1.2.0` 부분
- **Version**: 내부 빌드 번호 (예: `3`) ← `version: 1.2.0+3`에서 `+3` 부분
- Flutter의 `pubspec.yaml`에서 설정한 버전이 빌드 시 자동으로 주입된다

---

### CFBundleSignature

```xml
<key>CFBundleSignature</key>
<string>????</string>
```

- **의미**: 4글자 크리에이터 코드. macOS Classic 시절의 유산으로, 현재는 사용되지 않는다

---

### CFBundleURLTypes (URL Scheme 설정)

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.lionandthelab.nest</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.lionandthelab.nest</string>
        </array>
    </dict>
</array>
```

- **의미**: 이 앱이 처리할 수 있는 커스텀 URL 스킴을 정의한다
- **`<array>`**: 배열. 여러 URL 타입을 등록할 수 있다
- **`<dict>`**: 딕셔너리(사전). 하나의 URL 타입 설정을 키-값 쌍으로 담는다

각 키의 의미:

| 키 | 값 | 의미 |
|---|---|---|
| `CFBundleTypeRole` | `Editor` | 이 URL 타입에 대해 앱이 편집 권한을 가진다 |
| `CFBundleURLName` | `com.lionandthelab.nest` | URL 스킴의 식별자 |
| `CFBundleURLSchemes` | `["com.lionandthelab.nest"]` | 실제 URL 스킴 문자열 |

**동작 예시**:
```
com.lionandthelab.nest://some-path
```
이런 URL을 브라우저나 다른 앱에서 열면, iOS가 이 앱을 실행시켜준다.
딥링크(Deep Link)나 OAuth 콜백 등에 사용된다.

---

### LSRequiresIPhoneOS

```xml
<key>LSRequiresIPhoneOS</key>
<true/>
```

- **의미**: 이 앱은 iPhone OS (iOS) 전용이다
- **LS 접두사**: `LS` = Launch Services. 앱 실행을 관리하는 Apple 프레임워크이다
- **효과**: Mac Catalyst (iOS 앱을 Mac에서 실행)를 비활성화한다

---

### UIApplicationSceneManifest (Scene Lifecycle 설정)

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>UIWindowSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneClassName</key>
                <string>UIWindowScene</string>
                <key>UISceneConfigurationName</key>
                <string>flutter</string>
                <key>UISceneDelegateClassName</key>
                <string>FlutterSceneDelegate</string>
                <key>UISceneStoryboardFile</key>
                <string>Main</string>
            </dict>
        </array>
    </dict>
</dict>
```

이 섹션은 iOS 13+에서 도입된 **Scene 기반 앱 생명주기**를 설정한다.

#### 배경: 왜 Scene Lifecycle이 도입되었는가

iOS 12까지는 앱 = 화면 1개였다. 하지만 iOS 13부터 iPad에서 같은 앱의 **여러 창**을
동시에 띄울 수 있게 되었다 (Split View, Slide Over). 이를 위해 Apple은 앱의 구조를 변경했다:

```
[기존] 앱 1개 = 화면 1개
  AppDelegate가 화면(UIWindow)을 직접 관리

[현재] 앱 1개 = 씬(Scene) N개
  AppDelegate → 앱 전체 관리 (화면 관리 X)
  SceneDelegate → 각 화면(씬)을 개별 관리
```

#### 각 키의 의미

**UIApplicationSupportsMultipleScenes**

```xml
<key>UIApplicationSupportsMultipleScenes</key>
<false/>
```

- `false`: 멀티 씬을 사용하지 않는다 (화면 1개만)
- `true`로 설정하면 iPad에서 앱의 여러 인스턴스를 동시에 띄울 수 있다

**UIWindowSceneSessionRoleApplication**

- 이 씬이 "일반 앱 화면" 역할을 한다는 것을 명시한다
- 다른 역할로는 `UIWindowSceneSessionRoleExternalDisplayNonInteractive` (외부 디스플레이) 등이 있다

**UISceneClassName**

```xml
<string>UIWindowScene</string>
```

- 사용할 씬 클래스. `UIWindowScene`은 화면을 가진 표준 씬이다

**UISceneConfigurationName**

```xml
<string>flutter</string>
```

- 이 설정의 이름 (식별자). Flutter가 내부적으로 이 이름으로 설정을 찾는다

**UISceneDelegateClassName**

```xml
<string>FlutterSceneDelegate</string>
```

- **핵심**: 이 씬을 관리할 Delegate 클래스
- `FlutterSceneDelegate`는 Flutter SDK가 제공하는 클래스로, 다음을 담당한다:
  - UIWindow 생성
  - Flutter 엔진 초기화
  - Flutter UI 렌더링 시작
- iOS가 씬을 생성할 때, 이 클래스를 자동으로 인스턴스화하여 씬 관리를 위임한다

**UISceneStoryboardFile**

```xml
<string>Main</string>
```

- 씬이 처음 로드될 때 사용할 스토리보드 파일. `Main.storyboard`를 참조한다

#### Scene Lifecycle 실행 흐름

```
1. 앱 시작
   └→ iOS가 Info.plist의 UIApplicationSceneManifest를 발견
      └→ "이 앱은 Scene 기반이다"

2. iOS가 AppDelegate.didFinishLaunchingWithOptions 호출
   └→ 앱 수준 초기화 (화면 관리는 하지 않음)

3. iOS가 UISceneConfigurations를 읽음
   └→ UISceneDelegateClassName = "FlutterSceneDelegate"
   └→ FlutterSceneDelegate 인스턴스 생성

4. FlutterSceneDelegate.scene(_:willConnectTo:options:) 호출
   └→ UIWindow 생성
   └→ Flutter 엔진 초기화 시작

5. 엔진 초기화 완료
   └→ AppDelegate.didInitializeImplicitFlutterEngine 콜백
   └→ 플러그인 등록

6. Flutter Dart 코드 실행 (main.dart)
```

---

### UIApplicationSupportsIndirectInputEvents

```xml
<key>UIApplicationSupportsIndirectInputEvents</key>
<true/>
```

- **의미**: 간접 입력 이벤트를 지원한다
- **간접 입력**: Apple Pencil 호버, 트랙패드 커서 등 화면을 직접 터치하지 않는 입력
- **`true`**: iOS 13.4+에서 마우스/트랙패드 지원이 활성화된다

---

### UILaunchStoryboardName

```xml
<key>UILaunchStoryboardName</key>
<string>LaunchScreen</string>
```

- **의미**: 앱이 시작될 때 보이는 스플래시 화면의 스토리보드 파일명
- **값**: `LaunchScreen` → `LaunchScreen.storyboard` 파일을 참조한다
- 앱이 완전히 로딩되기 전에 사용자에게 보이는 첫 화면이다

---

### UIMainStoryboardFile

```xml
<key>UIMainStoryboardFile</key>
<string>Main</string>
```

- **의미**: 앱의 메인 UI 스토리보드 파일명
- **값**: `Main` → `Main.storyboard` 파일을 참조한다
- Scene Lifecycle에서는 `UISceneStoryboardFile`과 함께 사용된다

---

### UIStatusBarHidden

```xml
<key>UIStatusBarHidden</key>
<false/>
```

- **의미**: 상태바 (시간, 배터리, 와이파이 아이콘이 있는 상단 바)를 숨길지 여부
- **`<false/>`**: 상태바를 숨기지 않는다 (보이게 한다)

---

### UISupportedInterfaceOrientations

```xml
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```

- **의미**: iPhone에서 지원하는 화면 방향
- **값들**:
  - `Portrait` = 세로 모드 (기본)
  - `LandscapeLeft` = 가로 모드 (홈버튼이 왼쪽)
  - `LandscapeRight` = 가로 모드 (홈버튼이 오른쪽)
- `PortraitUpsideDown`(뒤집힌 세로)은 포함되어 있지 않다 → iPhone에서는 지원하지 않음

### UISupportedInterfaceOrientations~ipad

```xml
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```

- **`~ipad` 접미사**: iPad에서만 적용되는 설정. plist의 디바이스별 오버라이드 문법이다
- iPad에서는 4방향 모두 지원한다 (`PortraitUpsideDown` 포함)

---

## 전체 구조 요약

```
Info.plist
├── [앱 성능]
│   └── CADisableMinimumFrameDurationOnPhone: true     ← 120Hz 허용
│
├── [앱 식별 정보]
│   ├── CFBundleDevelopmentRegion: $(DEVELOPMENT_LANGUAGE)
│   ├── CFBundleDisplayName: "Nest"                    ← 홈 화면 표시 이름
│   ├── CFBundleExecutable: $(EXECUTABLE_NAME)
│   ├── CFBundleIdentifier: $(PRODUCT_BUNDLE_IDENTIFIER)
│   ├── CFBundleName: "Nest"
│   ├── CFBundlePackageType: "APPL"                    ← 앱 타입
│   ├── CFBundleShortVersionString: $(FLUTTER_BUILD_NAME)
│   ├── CFBundleSignature: "????"
│   └── CFBundleVersion: $(FLUTTER_BUILD_NUMBER)
│
├── [URL 스킴]
│   └── CFBundleURLTypes: com.lionandthelab.nest       ← 딥링크 처리
│
├── [Scene Lifecycle]  ★ 핵심 설정
│   └── UIApplicationSceneManifest
│       ├── UIApplicationSupportsMultipleScenes: false
│       └── UISceneConfigurations
│           └── FlutterSceneDelegate                   ← 화면 관리 위임
│
├── [UI 설정]
│   ├── UIApplicationSupportsIndirectInputEvents: true  ← 트랙패드 지원
│   ├── UILaunchStoryboardName: "LaunchScreen"         ← 스플래시 화면
│   ├── UIMainStoryboardFile: "Main"
│   └── UIStatusBarHidden: false                       ← 상태바 표시
│
├── [기기 설정]
│   ├── LSRequiresIPhoneOS: true                       ← iOS 전용
│   ├── UISupportedInterfaceOrientations: 3방향         ← iPhone 방향
│   └── UISupportedInterfaceOrientations~ipad: 4방향    ← iPad 방향
```
