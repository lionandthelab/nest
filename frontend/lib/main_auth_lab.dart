// AuthLab — lion_auth 모듈 독립 검증 타깃.
//
// 기존 앱(main.dart / login_page.dart)과 완전히 분리된 엔트리포인트로,
// 소셜 로그인 전체 플로우가 여기서 검증되기 전까지 기존 로그인은 변경하지 않는다.
//
// 실행 (키는 .env에서 자동 주입):
//   node scripts/run_auth_lab.mjs                # Chrome (웹, 포트 8080)
//   node scripts/run_auth_lab.mjs -d emulator-5554   # Android 에뮬레이터
//
// 직접 실행:
//   flutter run -t lib/main_auth_lab.dart -d chrome --web-port=8080 \
//     --dart-define=LION_GOOGLE_WEB_CLIENT_ID=... --dart-define=LION_KAKAO_NATIVE_APP_KEY=...

import 'package:flutter/material.dart';
import 'package:lion_auth/lion_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/config/app_config.dart';
import 'src/ui/nest_theme.dart';

const _googleWebClientId = String.fromEnvironment('LION_GOOGLE_WEB_CLIENT_ID');
const _googleIosClientId = String.fromEnvironment('LION_GOOGLE_IOS_CLIENT_ID');
const _kakaoNativeAppKey = String.fromEnvironment('LION_KAKAO_NATIVE_APP_KEY');
const _kakaoJsKey = String.fromEnvironment('LION_KAKAO_JS_KEY');
const _naverClientId = String.fromEnvironment('LION_NAVER_CLIENT_ID');
const _naverWebRedirectUri =
    String.fromEnvironment('LION_NAVER_WEB_REDIRECT_URI');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  runApp(const AuthLabApp());
}

LionAuthConfig _buildConfig() {
  return LionAuthConfig(
    appName: 'Nest AuthLab',
    brandLine: _activeProvidersLine(),
    google: _googleWebClientId.isEmpty
        ? null
        : GoogleAuthOptions(
            webClientId: _googleWebClientId,
            iosClientId: _googleIosClientId.isEmpty ? null : _googleIosClientId,
          ),
    kakao: _kakaoNativeAppKey.isEmpty
        ? null
        : KakaoAuthOptions(
            nativeAppKey: _kakaoNativeAppKey,
            javaScriptAppKey: _kakaoJsKey,
          ),
    naver: _naverClientId.isEmpty
        ? null
        : NaverAuthOptions(
            clientId: _naverClientId,
            clientName: 'Nest',
            webRedirectUri:
                _naverWebRedirectUri.isEmpty ? null : _naverWebRedirectUri,
          ),
    apple: const AppleAuthOptions(), // appleOnlyOnIos 기본값 → iOS에서만 노출
    // Nest 기존 회원가입과 동일한 추가 수집 필드.
    extraSignUpFields: const [
      LionSignUpField(
        key: 'full_name',
        label: '닉네임',
        hint: '앱에서 표시될 이름',
      ),
      LionSignUpField(
        key: 'real_name',
        label: '실명',
        hint: '홍길동',
        helper: '교사/감독 매칭과 관리자 확인에 사용됩니다.',
      ),
    ],
  );
}

String _activeProvidersLine() {
  final active = [
    if (_googleWebClientId.isNotEmpty) 'Google',
    if (_kakaoNativeAppKey.isNotEmpty) 'Kakao',
    if (_naverClientId.isNotEmpty) 'Naver',
  ];
  return active.isEmpty
      ? 'lion_auth 검증용 · 소셜 키 미주입 (이메일만 테스트 가능)'
      : 'lion_auth 검증용 · 활성: ${active.join(', ')}';
}

class AuthLabApp extends StatefulWidget {
  const AuthLabApp({super.key});

  @override
  State<AuthLabApp> createState() => _AuthLabAppState();
}

class _AuthLabAppState extends State<AuthLabApp> {
  late final LionAuthController controller;

  @override
  void initState() {
    super.initState();
    controller = LionAuthController(
      config: _buildConfig(),
      backend: SupabaseLionAuthBackend(
        Supabase.instance.client,
        emailRedirectUrl: AppConfig.authEmailRedirectUrl,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nest AuthLab',
      debugShowCheckedModeBanner: false,
      theme: NestTheme.light(),
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.isLoggedIn) {
            return _SessionPanel(controller: controller);
          }
          return LionAuthScreen(
            controller: controller,
            theme: const LionAuthTheme(
              primary: NestColors.dustyRose,
              background: NestColors.creamyWhite,
              onBackground: NestColors.deepWood,
              fontFamily: 'Pretendard Variable',
            ),
          );
        },
      ),
    );
  }
}

/// 로그인 성공 후 세션 정보를 그대로 보여주는 검증 패널.
class _SessionPanel extends StatelessWidget {
  const _SessionPanel({required this.controller});

  final LionAuthController controller;

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    final rows = <(String, String)>[
      ('userId', session.userId),
      ('email', session.email),
      ('provider', session.provider),
      ('displayName', session.displayName),
      ('isNewUser', session.isNewUser.toString()),
      for (final entry in session.metadata.entries)
        ('meta.${entry.key}', '${entry.value}'),
    ];

    return Scaffold(
      backgroundColor: NestColors.creamyWhite,
      appBar: AppBar(
        title: const Text('AuthLab — 로그인 성공'),
        backgroundColor: NestColors.dustyRose,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              key: const ValueKey('auth_lab_session_panel'),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '세션 발급 확인',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: NestColors.deepWood,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final (label, value) in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: NestColors.clay,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                value.isEmpty ? '(비어 있음)' : value,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed:
                          controller.isBusy ? null : controller.signOut,
                      style: FilledButton.styleFrom(
                        backgroundColor: NestColors.dustyRose,
                      ),
                      child: const Text('로그아웃 후 다시 테스트'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
