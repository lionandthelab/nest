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
    defaultValue: 'https://lionandthelab.github.io/nest/',
  );

  static const String authEmailRedirectUrlMobile = String.fromEnvironment(
    'AUTH_EMAIL_REDIRECT_URL_MOBILE',
    defaultValue: '$appDeepLinkScheme://$appDeepLinkHost/',
  );

  static String get authEmailRedirectUrl =>
      kIsWeb ? authEmailRedirectUrlWeb : authEmailRedirectUrlMobile;
}
