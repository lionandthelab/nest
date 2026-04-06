# AppFrameworkInfo.plist 문법 해석

## 파일의 역할

Flutter 프레임워크(`App.framework`) 자체의 메타데이터를 정의하는 파일이다.
이것은 **우리 앱(Runner)**의 정보가 아니라, 앱에 포함되는 **Flutter 프레임워크 번들**의 정보이다.

> iOS에서 `.framework`는 재사용 가능한 코드 라이브러리 패키지이다.
> Flutter 엔진이 이 형태로 앱에 포함되며, 이 plist는 그 패키지의 신분증 역할을 한다.

## plist 파일이란?

Property List의 약자로, Apple 플랫폼에서 설정 데이터를 저장하는 XML 형식의 파일이다.
`<key>`와 값(`<string>`, `<true/>`, `<array>`, `<dict>` 등)이 쌍으로 구성된다.

```xml
<key>키_이름</key>
<string>값</string>
```

이 구조는 프로그래밍의 Dictionary(사전)와 동일하다: `{ "키_이름": "값" }`.

## 각 키 상세 해석

### CFBundleDevelopmentRegion

```xml
<key>CFBundleDevelopmentRegion</key>
<string>en</string>
```

- **의미**: 이 번들의 기본 개발 언어
- **값**: `en` (영어)
- **역할**: 사용자 기기의 언어에 맞는 번역이 없을 때, 이 언어로 폴백(fallback)한다
- **CF 접두사**: `CF` = Core Foundation. Apple의 저수준 프레임워크 이름에서 유래한 네이밍 컨벤션이다

### CFBundleExecutable

```xml
<key>CFBundleExecutable</key>
<string>App</string>
```

- **의미**: 실행 가능한 바이너리 파일의 이름
- **값**: `App` (프레임워크 내부의 실제 실행 파일명)
- **역할**: iOS가 이 프레임워크를 로딩할 때, 이 이름의 바이너리를 찾아 메모리에 올린다

### CFBundleIdentifier

```xml
<key>CFBundleIdentifier</key>
<string>io.flutter.flutter.app</string>
```

- **의미**: 이 번들의 고유 식별자 (사람의 주민등록번호와 같은 역할)
- **값**: `io.flutter.flutter.app`
- **형식**: 역방향 도메인 표기법 (Reverse Domain Notation)
  - `io.flutter` = flutter.io 도메인의 역순
  - `.flutter.app` = 조직 내 프로젝트 구분
- **역할**: iOS가 설치된 수많은 프레임워크 중에서 이 번들을 유일하게 구분하는 데 사용한다

### CFBundleInfoDictionaryVersion

```xml
<key>CFBundleInfoDictionaryVersion</key>
<string>6.0</string>
```

- **의미**: 이 plist 파일 자체의 포맷 버전
- **값**: `6.0` (현재 표준)
- **역할**: iOS가 이 plist를 파싱할 때 어떤 형식인지 판단하는 데 사용한다. 사실상 항상 `6.0`이다

### CFBundleName

```xml
<key>CFBundleName</key>
<string>App</string>
```

- **의미**: 번들의 짧은 표시 이름
- **값**: `App`
- **역할**: 시스템 내부에서 이 프레임워크를 지칭할 때 사용하는 이름이다. 사용자에게 직접 노출되지 않는다

### CFBundlePackageType

```xml
<key>CFBundlePackageType</key>
<string>FMWK</string>
```

- **의미**: 이 번들의 종류 (패키지 타입)
- **값**: `FMWK` = Framework
- **다른 값 예시**:
  - `APPL` = Application (앱)
  - `BNDL` = Bundle (일반 번들)
  - `FMWK` = Framework (프레임워크)
- **역할**: iOS에게 "이 번들은 앱이 아니라 프레임워크야"라고 알려준다

> 참고: Runner/Info.plist에서는 `APPL`로 되어 있다. 그쪽은 앱 자체이기 때문이다.

### CFBundleShortVersionString

```xml
<key>CFBundleShortVersionString</key>
<string>1.0</string>
```

- **의미**: 사용자에게 보이는 버전 번호 (마케팅 버전)
- **값**: `1.0`
- **역할**: "현재 포함된 Flutter 프레임워크의 버전이 1.0이다"라는 의미. 실제 Flutter SDK 버전과는 별개이다

### CFBundleSignature

```xml
<key>CFBundleSignature</key>
<string>????</string>
```

- **의미**: 번들의 4글자 서명 코드 (크리에이터 코드)
- **값**: `????` (미지정)
- **역할**: macOS Classic 시절의 유산으로, 현재는 사실상 사용되지 않는다. `????`는 "지정하지 않음"을 의미한다

### CFBundleVersion

```xml
<key>CFBundleVersion</key>
<string>1.0</string>
```

- **의미**: 내부 빌드 번호
- **값**: `1.0`
- **CFBundleShortVersionString과의 차이**:
  - `ShortVersionString` = 사용자에게 보이는 버전 (예: "2.1")
  - `Version` = 내부 빌드 번호 (예: "2.1.347")
  - 하나의 사용자 버전에 여러 빌드가 있을 수 있다

## 이전 버전과의 차이

이전에는 `MinimumOSVersion` 키가 포함되어 있었으나 제거되었다:

```xml
<!-- 제거됨 -->
<key>MinimumOSVersion</key>
<string>13.0</string>
```

- **이유**: Flutter SDK가 이 값을 빌드 시점에 자동으로 설정하도록 변경되었다
- **장점**: Flutter 업그레이드 시 수동으로 이 값을 맞출 필요가 없어 호환성 문제를 방지한다

## 전체 구조 요약

```
AppFrameworkInfo.plist
├── CFBundleDevelopmentRegion: "en"          ← 기본 언어
├── CFBundleExecutable: "App"               ← 실행 바이너리명
├── CFBundleIdentifier: "io.flutter..."      ← 고유 식별자
├── CFBundleInfoDictionaryVersion: "6.0"     ← plist 포맷 버전
├── CFBundleName: "App"                      ← 표시 이름
├── CFBundlePackageType: "FMWK"             ← 번들 타입 (프레임워크)
├── CFBundleShortVersionString: "1.0"        ← 마케팅 버전
├── CFBundleSignature: "????"                ← 서명 코드 (미사용)
└── CFBundleVersion: "1.0"                   ← 빌드 번호
```
