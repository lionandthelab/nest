# AppDelegate.swift 문법 해석

## 파일의 역할

iOS 앱의 **진입점(Entry Point)**이다.
앱이 시작될 때 iOS가 가장 먼저 이 클래스를 인스턴스화하고, 생명주기 메서드를 호출한다.
Flutter 앱에서는 Flutter 엔진 초기화와 플러그인 등록을 이 파일에서 처리한다.

## 전체 코드

```swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
```

## 줄별 상세 해석

### import 문

```swift
import Flutter    // Flutter SDK의 iOS 프레임워크. FlutterAppDelegate 등을 제공한다
import UIKit      // Apple의 UI 프레임워크. UIApplication, UIWindow 등 iOS UI의 기반이다
```

### @main

```swift
@main
```

- **의미**: "이 클래스가 앱의 시작점이다"
- **역할**: 앱이 실행되면 iOS가 이 어노테이션이 붙은 클래스를 찾아 앱의 메인 루프를 시작한다
- **비유**: C 언어의 `main()` 함수와 같은 역할
- **제약**: 전체 프로젝트에서 단 하나의 클래스에만 붙일 수 있다

### @objc

```swift
@objc class AppDelegate
```

- **의미**: "이 Swift 클래스를 Objective-C 런타임에서도 접근할 수 있게 한다"
- **이유**: iOS의 UIKit 프레임워크는 내부적으로 Objective-C 기반이다.
  `UIApplication`이 AppDelegate를 찾고 호출할 때 Objective-C 런타임을 사용하므로, 이 어노테이션이 필요하다
- **없으면**: iOS가 AppDelegate를 인식하지 못해 앱이 시작되지 않는다

### 클래스 선언과 상속

```swift
class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
```

이 한 줄에 세 가지 문법이 포함되어 있다:

#### 1. 클래스 상속: `FlutterAppDelegate`

```
AppDelegate → FlutterAppDelegate → UIResponder, UIApplicationDelegate
```

- `FlutterAppDelegate`는 Flutter SDK가 제공하는 클래스이다
- Apple의 `UIApplicationDelegate` 프로토콜을 이미 구현해둔 상태이다
- Flutter 엔진 생성, 플러그인 채널 설정 등의 기본 로직이 들어 있다
- 우리의 `AppDelegate`가 이것을 **상속**하면, 이 모든 기능을 물려받는다

**상속이란**: 부모 클래스의 모든 속성과 메서드를 자식 클래스가 그대로 사용할 수 있는 것.
마치 부모의 재산을 상속받는 것과 같다.

#### 2. 프로토콜 채택: `FlutterImplicitEngineDelegate`

```swift
protocol FlutterImplicitEngineDelegate {
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge)
}
```

- **프로토콜**: "이 메서드들을 반드시 구현하겠다"는 계약 (Java의 Interface와 동일한 개념)
- 이 프로토콜을 채택하면 `didInitializeImplicitFlutterEngine` 메서드를 반드시 구현해야 한다
- Flutter 엔진이 초기화를 완료하면, 이 메서드를 자동으로 호출해준다 (Delegate 패턴)

#### 3. 콤마(,)로 구분

```swift
class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate
//                 ↑ 클래스 상속 (1개만)   ↑ 프로토콜 채택 (여러 개 가능)
```

- Swift에서 클래스 상속은 **1개만** 가능하다 (단일 상속)
- 프로토콜 채택은 **여러 개** 가능하다
- 콜론(`:`) 뒤에 상속 클래스를 먼저 쓰고, 콤마로 구분하여 프로토콜을 나열한다

### application(_:didFinishLaunchingWithOptions:)

```swift
override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

#### override

- **의미**: 부모 클래스(`FlutterAppDelegate`)에 이미 있는 메서드를 **재정의**한다
- **안전장치**: `override` 키워드 없이 부모의 메서드를 재정의하면 컴파일 에러가 발생한다.
  실수로 부모 메서드를 덮어쓰는 것을 방지하기 위함이다

#### 파라미터 해석

```swift
_ application: UIApplication,
// ↑ 외부이름 없음   ↑ 내부이름    ↑ 타입
```

- `_` (언더스코어): 호출할 때 파라미터 이름을 생략할 수 있다는 의미
- `application`: 함수 내부에서 사용하는 이름
- `UIApplication`: iOS 앱 자체를 나타내는 객체. 앱 당 1개 존재한다

```swift
didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
// ↑ 외부이름 (호출 시 사용)        ↑ 내부이름    ↑ Dictionary 타입            ↑ Optional
```

- `launchOptions`: 앱이 어떻게 시작되었는지에 대한 정보 (예: 푸시 알림으로 시작, URL로 시작 등)
- `?` (Optional): 이 값이 `nil`일 수 있다는 의미. 일반 앱 아이콘 탭으로 시작하면 `nil`이다

#### super.application(...)

```swift
return super.application(application, didFinishLaunchingWithOptions: launchOptions)
```

- `super`: 부모 클래스 (`FlutterAppDelegate`)를 가리킨다
- 부모의 동일 메서드를 호출하여, Flutter 엔진 초기화 등 기본 설정을 실행한다
- **super를 호출하지 않으면**: Flutter 엔진이 초기화되지 않아 앱이 동작하지 않는다

#### 반환값: `-> Bool`

- `true`: 앱 시작 성공
- `false`: 앱 시작 거부 (iOS가 앱을 종료한다)

### didInitializeImplicitFlutterEngine

```swift
func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
}
```

#### 이 메서드가 호출되는 시점

이 메서드는 **우리가 직접 호출하지 않는다**. Flutter 엔진이 초기화를 완료한 후,
Delegate 패턴에 의해 **자동으로 호출**된다.

```
Flutter 엔진 초기화 완료
  → 엔진 내부: delegate?.didInitializeImplicitFlutterEngine(self)
    → 우리의 이 메서드가 실행됨
```

#### engineBridge 파라미터

- `FlutterImplicitEngineBridge`: 초기화된 Flutter 엔진에 접근하기 위한 브릿지 객체
- `engineBridge.pluginRegistry`: 플러그인을 등록할 수 있는 레지스트리

#### GeneratedPluginRegistrant.register(...)

- `GeneratedPluginRegistrant`: Flutter가 `pubspec.yaml`의 플러그인 목록을 보고 **자동 생성**하는 클래스이다
- `flutter pub get` 실행 시 `ios/Runner/GeneratedPluginRegistrant.m` 파일이 갱신된다
- 이 클래스의 `register` 메서드는 모든 Flutter 플러그인 (카메라, GPS, 파일 시스템 등)을 한 번에 등록한다

## 이전 방식과의 비교

### 이전 (Flutter 3.x 이전)

```swift
@objc class AppDelegate: FlutterAppDelegate {
  override func application(...) -> Bool {
    GeneratedPluginRegistrant.register(with: self)  // ← 여기서 직접 등록
    return super.application(...)
  }
}
```

- **문제점**: `didFinishLaunchingWithOptions` 시점에서는 Flutter 엔진이 아직 완전히 초기화되지 않았을 수 있다
- 일부 플러그인이 엔진에 의존하는 경우 타이밍 문제로 크래시 가능성이 있었다

### 현재 (Scene Lifecycle 방식)

```swift
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(...) -> Bool {
    return super.application(...)  // ← 플러그인 등록을 여기서 하지 않음
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: ...) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // ↑ 엔진이 완전히 초기화된 후에 등록 (안전)
  }
}
```

- **장점**: 엔진 초기화가 보장된 시점에서 플러그인을 등록하므로 안전하다
- iPad 멀티태스킹 등 멀티 씬 환경에서도 각 씬마다 올바르게 동작한다

## 실행 흐름 요약

```
1. 앱 시작
   └→ iOS가 @main이 붙은 AppDelegate를 찾아 인스턴스화

2. didFinishLaunchingWithOptions 호출
   └→ super.application(...) → FlutterAppDelegate의 기본 설정 실행

3. iOS가 Info.plist의 SceneManifest를 읽음
   └→ FlutterSceneDelegate가 씬을 생성

4. FlutterSceneDelegate가 Flutter 엔진을 초기화

5. 엔진 초기화 완료
   └→ didInitializeImplicitFlutterEngine 콜백 호출
      └→ 모든 플러그인 등록

6. Flutter의 Dart 코드 (main.dart) 실행 시작
```
