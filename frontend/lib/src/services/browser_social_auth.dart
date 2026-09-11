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
  static const _naverStateKey = 'nest.naver.browser.state';

  static StreamSubscription<Uri>? _sub;
  static AppLinks? _links;
  static void Function(String message)? onMessage;

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
    final state = _randomState();
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
    return (uri.queryParameters['code'] ?? '').isNotEmpty;
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
    final code = uri.queryParameters['code'] ?? '';
    final state = uri.queryParameters['state'] ?? '';
    if (code.isEmpty || state.isEmpty) return null;
    return (code: code, state: state);
  }

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
