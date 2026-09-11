import 'package:lion_auth/lion_auth.dart';

import 'app_config.dart';

/// Nest 로그인에 쓰는 lion_auth 설정.
///
/// Apple은 스토어 심사/콘솔이 준비되기 전까지 넣지 않는다.
/// 구글·카카오·네이버는 공개 클라이언트 식별자가 있을 때만 버튼이 나온다.
LionAuthConfig buildNestLionAuthConfig({String brandLine = ''}) {
  final googleId = AppConfig.lionGoogleWebClientId.trim();
  final iosId = AppConfig.lionGoogleIosClientId.trim();
  final kakaoNative = AppConfig.lionKakaoNativeAppKey.trim();
  final kakaoJs = AppConfig.lionKakaoJsKey.trim();
  final naverId = AppConfig.lionNaverClientId.trim();
  final naverRedirect = AppConfig.lionNaverWebRedirectUri.trim();

  return LionAuthConfig(
    appName: AppConfig.appName,
    brandLine: brandLine,
    google: googleId.isEmpty
        ? null
        : GoogleAuthOptions(
            webClientId: googleId,
            iosClientId: iosId.isEmpty ? null : iosId,
          ),
    kakao: (kakaoNative.isEmpty && kakaoJs.isEmpty)
        ? null
        : KakaoAuthOptions(
            nativeAppKey: kakaoNative,
            javaScriptAppKey: kakaoJs,
          ),
    naver: naverId.isEmpty
        ? null
        : NaverAuthOptions(
            clientId: naverId,
            clientName: AppConfig.appName,
            webRedirectUri: naverRedirect.isEmpty ? null : naverRedirect,
          ),
  );
}
