import 'dart:async';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:lion_auth/lion_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

/// 모바일에서 시스템 브라우저(Custom Tabs / Safari)로 인가한다.
///
/// - 구글: iOS GID가 없으면 Supabase PKCE + `com.lionandthelab.nest://login-callback/`
/// - 네이버: `nid.naver.com` → HTTPS 브릿지 → `nestnaverlogin://callback` → social-broker
/// 카카오는 공식 `loginWithKakaoAccount()`를 쓰므로 여기로 오지 않는다.
class BrowserSocialAuth {
  BrowserSocialAuth._();

  /// 네이버 콘솔 Callback URL. custom scheme은 거부되므로 HTTPS 브릿지를 쓴다.
  static const naverRedirectUri =
      'https://avursvhmilcsssabqtkx.supabase.co/functions/v1/naver-oauth-bridge';
  static const naverAppScheme = 'nestnaverlogin://callback';

  /// 브릿지에 "새 앱이다"라고 알리는 state 표식.
  ///
  /// supabase_flutter 는 PKCE 모드에서 `?code=` 가 붙은 **모든** 딥링크를
  /// 자기 콜백으로 착각해 코드 교환을 시도한다. 네이버 코드가 Supabase 로
  /// 날아가고, 직전 구글/카카오 시도가 남긴 code_verifier 가 있으면 실제로
  /// 교환이 수행된다. 그래서 네이버는 `code` 가 아닌 이름으로 받는다.
  ///
  /// 브릿지가 이름을 한 번에 바꾸면 이미 설치된 앱이 `code` 를 못 찾아
  /// 네이버 로그인이 즉시 죽는다. 표식이 있는 요청에만 새 이름을 쓰게 해서
  /// 신·구 앱이 함께 동작한다. (브릿지 쪽 APP_STATE_MARKER 와 같은 값)
  static const naverStateMarker = 'nestv2';
  static const _naverStateKey = 'nest.naver.browser.state';

  static StreamSubscription<Uri>? _sub;
  static AppLinks? _links;
  static void Function(String message)? onMessage;

  /// 이미 처리한 콜백 코드. app_links 는 콜드 스타트에서 초기 링크를
  /// `getInitialLink()` 와 `uriLinkStream` 양쪽으로 흘린다. 같은 콜백을 두 번
  /// 처리하면 두 번째는 state 가 이미 소비돼, 로그인에 성공하고도 사용자에게는
  /// "상태 검증에 실패했습니다" 가 뜬다.
  static final Set<String> _handledCodes = <String>{};

  @visibleForTesting
  static void resetForTest() {
    _handledCodes.clear();
    onMessage = null;
  }

  /// 앱 시작 시 한 번. 네이버 브라우저 복귀(콜드 스타트 포함)를 받는다.
  static Future<void> bindDeepLinks() async {
    if (kIsWeb) return;
    if (_links != null) return;
    final links = AppLinks();
    _links = links;
    try {
      final initial = await links.getInitialLink();
      if (initial != null) {
        await handleIncoming(initial);
      }
    } catch (error) {
      debugPrint('[BrowserSocialAuth] initial link failed: $error');
    }
    _sub = links.uriLinkStream.listen(
      (uri) => unawaited(handleIncoming(uri)),
      onError: (Object error) {
        debugPrint('[BrowserSocialAuth] link stream failed: $error');
      },
    );
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _links = null;
  }

  /// 모바일에서 이 공급자를 시스템 브라우저로 처리할지.
  ///
  /// 카카오를 여기로 보내는 이유: id_token 경로는 Supabase 가 거절하면
  /// "로그인에 실패했습니다"만 남는다 — aud/OIDC 는 콘솔 설정이라 사용자가
  /// 할 수 있는 게 없다. 서버 리다이렉트는 코드 교환을 Supabase 가 자기 REST
  /// 키로 하므로 그 실패 자체가 생기지 않는다.
  ///
  /// 인앱 브라우저가 아니라 시스템 브라우저를 쓰는 이유는 네이버에서 이미
  /// 겪었다 — 시트가 앱 위에 남아 로그인 화면을 가린다.
  static bool shouldUseBrowser(
    LionAuthProviderId id, {
    required bool isWeb,
    required bool canUseNativeGoogle,
  }) {
    if (isWeb) return false;
    return switch (id) {
      LionAuthProviderId.naver => true,
      LionAuthProviderId.kakao => true,
      LionAuthProviderId.google => !canUseNativeGoogle,
      LionAuthProviderId.apple => false,
    };
  }

  static Future<void> start(LionAuthProviderId id) {
    return switch (id) {
      LionAuthProviderId.google => startGoogle(),
      LionAuthProviderId.kakao => startKakao(),
      LionAuthProviderId.naver => startNaver(),
      _ => throw StateError('브라우저 소셜 로그인을 지원하지 않습니다.'),
    };
  }

  /// 구글: iOS에 GIDClientID가 없어도 브라우저 OAuth로 진행한다.
  static Future<void> startGoogle() async {
    final ok = await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.authEmailRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    if (!ok) {
      throw StateError('구글 로그인 브라우저를 열지 못했습니다.');
    }
  }

  /// 카카오: Supabase OAuth가 브라우저를 연 뒤 앱 딥링크로 돌아온다.
  static Future<void> startKakao() async {
    final ok = await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: AppConfig.authEmailRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    if (!ok) {
      throw StateError('카카오 로그인 브라우저를 열지 못했습니다.');
    }
  }

  /// 네이버: 인가 페이지를 연 뒤 HTTPS 브릿지가 앱 스킴으로 코드를 넘긴다.
  static Future<void> startNaver() async {
    final clientId = AppConfig.lionNaverClientId.trim();
    if (clientId.isEmpty) {
      throw StateError('네이버 클라이언트 ID가 없습니다.');
    }
    final state = newState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_naverStateKey, state);

    final authorizeUri = Uri.https('nid.naver.com', '/oauth2.0/authorize', {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': naverRedirectUri,
      'state': state,
    });
    // 인앱 Safari는 딥링크 후에도 시트가 남아 로그인이 가려진다.
    // 시스템 브라우저로 연 뒤 스킴 복귀하면 앱이 앞으로 온다.
    var ok = await launchUrl(
      authorizeUri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      ok = await launchUrl(
        authorizeUri,
        mode: LaunchMode.inAppBrowserView,
      );
    }
    if (!ok) {
      throw StateError('네이버 로그인 브라우저를 열지 못했습니다.');
    }
  }

  static Future<void> handleIncoming(Uri uri) async {
    if (uri.scheme != 'nestnaverlogin') return;
    final oauthError = uri.queryParameters['error'] ?? '';
    if (oauthError.isNotEmpty) {
      onMessage?.call('네이버 로그인이 취소되었거나 거부되었습니다.');
      return;
    }
    if (!isNaverCallback(uri)) return;
    // 같은 코드는 한 번만 — 중복 전달이 성공한 로그인을 실패로 덮지 않도록.
    if (!_handledCodes.add(_codeOf(uri))) return;
    try {
      await _completeNaver(uri);
    } catch (error) {
      final message = error is StateError
          ? error.message
          : '네이버 로그인에 실패했습니다.';
      debugPrint('[BrowserSocialAuth] $error');
      onMessage?.call(message);
    }
  }

  static bool isNaverCallback(Uri uri) {
    if (uri.scheme != 'nestnaverlogin') return false;
    return _codeOf(uri).isNotEmpty;
  }

  /// 새 이름을 먼저 보고, 없으면 예전 이름을 본다.
  /// (구버전 브릿지가 아직 살아 있는 전환기 동안의 호환)
  static String _codeOf(Uri uri) {
    final fresh = uri.queryParameters['naver_code'] ?? '';
    if (fresh.isNotEmpty) return fresh;
    return uri.queryParameters['code'] ?? '';
  }

  static Future<void> _completeNaver(Uri uri) async {
    final parsed = parseNaverCallback(uri);
    if (parsed == null) return;

    final prefs = await SharedPreferences.getInstance();
    final expected = prefs.getString(_naverStateKey);
    await prefs.remove(_naverStateKey);
    if (expected == null || expected != parsed.state) {
      throw StateError('네이버 로그인 상태 검증에 실패했습니다. 다시 시도해 주세요.');
    }

    final client = Supabase.instance.client;
    late final Map<String, dynamic> data;
    try {
      final response = await client.functions.invoke(
        'social-broker',
        body: {
          'provider': 'naver',
          'auth_code': parsed.code,
          'state': parsed.state,
          'redirect_uri': naverRedirectUri,
        },
      );
      data = Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (error) {
      final detail = error.details;
      final message = detail is Map && detail['error'] is String
          ? detail['error'] as String
          : '네이버 로그인 처리 중 서버 오류가 발생했습니다.';
      throw StateError(message);
    }
    final tokenHash = data['token_hash'] as String?;
    if (tokenHash == null || tokenHash.isEmpty) {
      final serverError = data['error'] as String?;
      throw StateError(serverError ?? '서버에서 로그인 토큰을 받지 못했습니다.');
    }

    await client.auth.verifyOTP(
      type: OtpType.magiclink,
      tokenHash: tokenHash,
    );
    await closeInAppWebView();
  }

  static ({String code, String state})? parseNaverCallback(Uri uri) {
    if (!isNaverCallback(uri)) return null;
    final code = _codeOf(uri);
    final state = uri.queryParameters['state'] ?? '';
    if (code.isEmpty || state.isEmpty) return null;
    return (code: code, state: state);
  }

  /// 브릿지가 새 앱임을 알아볼 수 있게 표식을 붙인 CSRF state.
  @visibleForTesting
  static String newState() => '$naverStateMarker${_randomState()}';

  static String _randomState([int length = 24]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}
