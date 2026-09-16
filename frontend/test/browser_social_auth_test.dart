import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/services/browser_social_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BrowserSocialAuth.resetForTest();
  });

  tearDown(() => BrowserSocialAuth.onMessage = null);
  test('parseNaverCallback reads code and state from the app scheme', () {
    final uri = Uri.parse(
      'nestnaverlogin://callback?code=abc123&state=xyz789',
    );
    expect(BrowserSocialAuth.isNaverCallback(uri), isTrue);
    final parsed = BrowserSocialAuth.parseNaverCallback(uri);
    expect(parsed?.code, 'abc123');
    expect(parsed?.state, 'xyz789');
  });

  test('Naver authorize redirect is the HTTPS bridge, not a custom scheme', () {
    expect(
      BrowserSocialAuth.naverRedirectUri,
      startsWith('https://'),
    );
    expect(
      BrowserSocialAuth.naverRedirectUri,
      contains('naver-oauth-bridge'),
    );
    expect(BrowserSocialAuth.naverAppScheme, 'nestnaverlogin://callback');
  });

  test('parseNaverCallback ignores unrelated deep links', () {
    final uri = Uri.parse(
      'com.lionandthelab.nest://login-callback/#access_token=x',
    );
    expect(BrowserSocialAuth.isNaverCallback(uri), isFalse);
    expect(BrowserSocialAuth.parseNaverCallback(uri), isNull);
  });

  // app_links는 콜드 스타트에서 초기 링크를 getInitialLink()와 uriLinkStream
  // 양쪽으로 흘린다. 같은 콜백을 두 번 처리하면 두 번째는 state가 이미 소비돼
  // 로그인이 성공했는데도 "상태 검증 실패" 스낵바가 뜬다.
  test('같은 네이버 콜백이 두 번 도착해도 한 번만 처리한다', () async {
    final messages = <String>[];
    BrowserSocialAuth.onMessage = messages.add;
    final uri = Uri.parse('nestnaverlogin://callback?code=abc123&state=xyz789');

    await BrowserSocialAuth.handleIncoming(uri);
    await BrowserSocialAuth.handleIncoming(uri);

    expect(messages.length, 1, reason: '중복 전달은 무시되어야 한다');
  });

  test('다른 콜백은 계속 처리한다 (중복 차단이 과하지 않다)', () async {
    final messages = <String>[];
    BrowserSocialAuth.onMessage = messages.add;

    await BrowserSocialAuth.handleIncoming(
      Uri.parse('nestnaverlogin://callback?code=first&state=s1'),
    );
    await BrowserSocialAuth.handleIncoming(
      Uri.parse('nestnaverlogin://callback?code=second&state=s2'),
    );

    expect(messages.length, 2);
  });
}
