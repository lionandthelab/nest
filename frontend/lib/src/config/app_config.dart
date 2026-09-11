import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppConfig {
  const AppConfig._();

  static const String appName = 'Nest';

  /// pubspec.yaml의 version 값이 자동으로 설정된다.
  /// 읽기에 실패한 경우에만 'unknown'으로 표시된다.
  static String appVersion = 'unknown';

  /// 앱 시작 시 호출하여 pubspec.yaml에서 버전을 읽어온다.
  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        appVersion = info.version;
      }
      debugPrint('[AppConfig] version loaded: $appVersion');
    } catch (e) {
      debugPrint('[AppConfig] version load failed: $e');
    }
  }
  static const String brandLine = '우리 아이가 날아오르기 전, 따뜻한 둥지';
  static const String androidApplicationId = 'com.lionandthelab.nest';
  static const String iosBundleId = 'com.lionandthelab.nest';
  static const String appDeepLinkScheme = 'com.lionandthelab.nest';
  static const String appDeepLinkHost = 'login-callback';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://avursvhmilcsssabqtkx.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2dXJzdmhtaWxjc3NzYWJxdGt4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0MjkyOTcsImV4cCI6MjA4ODAwNTI5N30.5hM86lAonGgnEVKfPH4iMkBsv6ayBpMHJm2tQ1FYyls',
  );

  static const String oauthStoragePrefix = 'nest.oauth';
  static const String oauthCallbackPath = '/oauth/google/callback.html';

  static const String authEmailRedirectUrlWeb = String.fromEnvironment(
    'AUTH_EMAIL_REDIRECT_URL',
    defaultValue: 'https://nestapp.life/',
  );

  static const String authEmailRedirectUrlMobile = String.fromEnvironment(
    'AUTH_EMAIL_REDIRECT_URL_MOBILE',
    defaultValue: '$appDeepLinkScheme://$appDeepLinkHost/',
  );

  static String get authEmailRedirectUrl =>
      kIsWeb ? authEmailRedirectUrlWeb : authEmailRedirectUrlMobile;

  /// 소셜 로그인 공개 식별자. CI `dart-define`과 동일한 값이며,
  /// 로컬 `flutter run`에도 버튼이 보이도록 기본값을 둔다.
  /// 시크릿(클라이언트 시크릿)은 넣지 않는다.
  static const String lionGoogleWebClientId = String.fromEnvironment(
    'LION_GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '875114759372-6mkob01lrrh9r6psh0lp717up9h3litp.apps.googleusercontent.com',
  );
  static const String lionGoogleIosClientId = String.fromEnvironment(
    'LION_GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '875114759372-2n9lulvdd9jmkatpugh8ilievvr1vfnn.apps.googleusercontent.com',
  );
  static const String lionKakaoNativeAppKey = String.fromEnvironment(
    'LION_KAKAO_NATIVE_APP_KEY',
    defaultValue: '0a51d6ea6e78e3565b8a45655bca8142',
  );
  static const String lionKakaoJsKey = String.fromEnvironment(
    'LION_KAKAO_JS_KEY',
    defaultValue: 'db129c862ec8fab23fe7cb85089eaa79',
  );
  static const String lionNaverClientId = String.fromEnvironment(
    'LION_NAVER_CLIENT_ID',
    defaultValue: 'Z1lpn0C9AFZ3BiXgLuno',
  );

  /// 비우면 현재 페이지 origin을 쓴다. 프로덕션 웹은 주소가 nestapp.life다.
  static const String lionNaverWebRedirectUri = String.fromEnvironment(
    'LION_NAVER_WEB_REDIRECT_URI',
  );
}
