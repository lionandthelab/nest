import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/services/browser_social_auth.dart';

void main() {
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
}
