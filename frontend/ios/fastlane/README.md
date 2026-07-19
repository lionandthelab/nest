fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios status

```sh
[bundle exec] fastlane ios status
```

스토어 상태 조회 (라이브 버전 / TestFlight 최신 빌드)

### ios build

```sh
[bundle exec] fastlane ios build
```

서명된 릴리스 IPA 빌드만 (업로드 없음)

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

메타데이터/스크린샷만 업로드 (바이너리·심사 제출 없음)

### ios upload

```sh
[bundle exec] fastlane ios upload
```

이미 빌드된 IPA를 TestFlight에 업로드만 (options: ipa)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

빌드 + TestFlight 업로드

### ios release

```sh
[bundle exec] fastlane ios release
```

빌드 + 업로드 + 프로덕션 심사 제출 (기존 메타데이터/스크린샷 재사용)

### ios submit

```sh
[bundle exec] fastlane ios submit
```

이미 업로드된 빌드를 심사 제출만 (options: build)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
