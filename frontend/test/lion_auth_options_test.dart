import 'package:flutter_test/flutter_test.dart';
import 'package:lion_auth/lion_auth.dart';
import 'package:nest_frontend/src/config/lion_auth_options.dart';

void main() {
  test('Nest social login enables Google, Kakao, Naver and hides Apple', () {
    final config = buildNestLionAuthConfig();
    expect(config.enabledProviders, contains(LionAuthProviderId.google));
    expect(config.enabledProviders, contains(LionAuthProviderId.kakao));
    expect(config.enabledProviders, contains(LionAuthProviderId.naver));
    expect(config.enabledProviders, isNot(contains(LionAuthProviderId.apple)));
    expect(config.apple, isNull);
    expect(config.google?.iosClientId, isNotEmpty);
  });
}
