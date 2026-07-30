// MessagingLab — lion_auth 메시징 서브모듈(알림톡·푸시) 독립 검증 타깃.
//
// 기존 앱(main.dart)과 완전히 분리된 엔트리포인트다. 메시징 전체 플로우가
// 여기서 검증되기 전까지 실제 앱의 알림 트리거에는 연결하지 않는다.
//
// 실행 (키는 .env에서 자동 주입):
//   node scripts/run_messaging_lab.mjs                 # Chrome (웹, 포트 8080)
//   node scripts/run_messaging_lab.mjs -d emulator-5554    # Android 에뮬레이터
//   node scripts/messaging_lab_smoke.mjs               # 헤드리스 스모크
//
// 그린필드(콘솔 미설정) 상태에서도 죽지 않고 실행된다:
//   - Firebase 미설정 → 푸시 비활성(패널에 안내), 나머지 UI/발송 경로는 동작
//   - Solapi 미설정 → 발송 버튼은 서버에서 실패 메시지를 그대로 표시

import 'package:flutter/material.dart';
import 'package:lion_auth/lion_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/config/app_config.dart';
import 'src/ui/nest_theme.dart';

// 로그인용(세션 확보) — 이메일만으로 충분. 소셜 키가 있으면 함께 노출.
const _googleWebClientId = String.fromEnvironment('LION_GOOGLE_WEB_CLIENT_ID');
const _kakaoNativeAppKey = String.fromEnvironment('LION_KAKAO_NATIVE_APP_KEY');
const _kakaoJsKey = String.fromEnvironment('LION_KAKAO_JS_KEY');

// 메시징 설정(클라이언트 안전 값만). pfId 등 발송 시크릿은 서버(Edge Function)에만 있다.
const _vapidKey = String.fromEnvironment('LION_FCM_WEB_VAPID_KEY');
const _solapiTemplateId = String.fromEnvironment('LION_SOLAPI_TEMPLATE_ID');

// 웹 Firebase 설정(공개값 — 웹 앱에 그대로 노출되는 값이라 dart-define OK).
const _fcmWebApiKey = String.fromEnvironment('LION_FCM_WEB_API_KEY');
const _fcmWebAppId = String.fromEnvironment('LION_FCM_WEB_APP_ID');
const _fcmWebSenderId = String.fromEnvironment('LION_FCM_WEB_SENDER_ID');
const _fcmWebProjectId = String.fromEnvironment('LION_FCM_WEB_PROJECT_ID');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Firebase 초기화(미설정이면 false → 푸시 비활성). firebase_core 는 lion_auth 내부.
  final firebaseReady = await initLionFirebase(
    webOptions: _fcmWebApiKey.isEmpty
        ? null
        : {
            'apiKey': _fcmWebApiKey,
            'appId': _fcmWebAppId,
            'messagingSenderId': _fcmWebSenderId,
            'projectId': _fcmWebProjectId,
          },
  );
  if (firebaseReady) {
    registerLionPushBackgroundHandler();
  }

  runApp(MessagingLabApp(firebaseReady: firebaseReady));
}

LionAuthConfig _buildAuthConfig() {
  return LionAuthConfig(
    appName: 'Nest MessagingLab',
    brandLine: '메시징 검증용 · 로그인 후 알림톡/푸시 테스트',
    google: _googleWebClientId.isEmpty
        ? null
        : GoogleAuthOptions(webClientId: _googleWebClientId),
    kakao: _kakaoNativeAppKey.isEmpty
        ? null
        : KakaoAuthOptions(
            nativeAppKey: _kakaoNativeAppKey,
            javaScriptAppKey: _kakaoJsKey,
          ),
  );
}

LionMessagingConfig _buildMessagingConfig() {
  return LionMessagingConfig(
    fcm: FcmOptions(
      vapidKey: _vapidKey.isEmpty ? null : _vapidKey,
      autoRegisterOnSignIn: false, // 랩에서는 버튼으로 수동 등록해 관찰.
    ),
    solapi: SolapiOptions(
      defaultTemplateId: _solapiTemplateId.isEmpty ? null : _solapiTemplateId,
    ),
  );
}

class MessagingLabApp extends StatefulWidget {
  const MessagingLabApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  State<MessagingLabApp> createState() => _MessagingLabAppState();
}

class _MessagingLabAppState extends State<MessagingLabApp> {
  late final LionAuthController auth;
  late final LionMessagingController messaging;

  @override
  void initState() {
    super.initState();
    messaging = LionMessagingController(
      config: _buildMessagingConfig(),
      backend: SupabaseLionMessagingBackend(Supabase.instance.client),
    );
    auth = LionAuthController(
      config: _buildAuthConfig(),
      backend: SupabaseLionAuthBackend(
        Supabase.instance.client,
        emailRedirectUrl: AppConfig.authEmailRedirectUrl,
      ),
      // 로그인 성공 → 메시징 컨트롤러에 단방향 통지(자동 등록은 off라 세션만 전달).
      onAuthenticated: (session) => messaging.onSignedIn(session.userId),
    );
    messaging.initialize();
  }

  @override
  void dispose() {
    auth.dispose();
    messaging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nest MessagingLab',
      debugShowCheckedModeBanner: false,
      theme: NestTheme.light(),
      home: AnimatedBuilder(
        animation: auth,
        builder: (context, _) {
          if (auth.isLoggedIn) {
            return _MessagingLabPanel(
              auth: auth,
              messaging: messaging,
              firebaseReady: widget.firebaseReady,
            );
          }
          return LionAuthScreen(
            controller: auth,
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

class _MessagingLabPanel extends StatelessWidget {
  const _MessagingLabPanel({
    required this.auth,
    required this.messaging,
    required this.firebaseReady,
  });

  final LionAuthController auth;
  final LionMessagingController messaging;
  final bool firebaseReady;

  String get _userId => auth.session!.userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NestColors.creamyWhite,
      appBar: AppBar(
        title: const Text('MessagingLab'),
        backgroundColor: NestColors.dustyRose,
        actions: [
          TextButton(
            onPressed: auth.isBusy
                ? null
                : () async {
                    await messaging.onSignedOut();
                    await auth.signOut();
                  },
            child: const Text('로그아웃', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: messaging,
        builder: (context, _) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  key: const ValueKey('messaging_lab_panel'),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '메시징 검증',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: NestColors.deepWood,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _statusRow('userId', _userId),
                        _statusRow('firebase', firebaseReady ? '초기화됨' : '미설정(푸시 비활성)'),
                        _statusRow('pushSupported', messaging.pushSupported.toString()),
                        _statusRow('permission', messaging.permissionGranted.toString()),
                        _statusRow('token', messaging.currentToken ?? '(없음)'),
                        if (messaging.latestMessage != null)
                          _statusRow(
                            'lastMsg',
                            '${messaging.latestMessage!.title ?? ''} / ${messaging.latestMessage!.body ?? ''}',
                          ),
                        if (messaging.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              messaging.errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _actionButton(
                              '권한 요청',
                              messaging.isBusy ? null : messaging.ensurePermission,
                            ),
                            _actionButton(
                              '토큰 등록',
                              messaging.isBusy ? null : messaging.registerPush,
                            ),
                            _actionButton(
                              '나에게 테스트 푸시',
                              messaging.isBusy ? null : () => _sendPush(context),
                            ),
                            _actionButton(
                              '나에게 SMS',
                              messaging.isBusy ? null : () => _sendSms(context),
                            ),
                            _actionButton(
                              '나에게 알림톡',
                              messaging.isBusy ? null : () => _sendAlimtalk(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendPush(BuildContext context) async {
    final result = await messaging.send(NotificationRequest(
      channel: NotificationChannel.push,
      toUserIds: [_userId],
      title: 'MessagingLab 테스트',
      body: '푸시 발송 테스트입니다.',
      data: const {'route': '/messaging-lab'},
    ));
    if (!context.mounted) return;
    _showResult(context, result);
  }

  Future<void> _sendSms(BuildContext context) async {
    final result = await messaging.send(NotificationRequest(
      channel: NotificationChannel.sms,
      toUserIds: [_userId],
      body: '[Nest] MessagingLab SMS 테스트',
    ));
    if (!context.mounted) return;
    _showResult(context, result);
  }

  Future<void> _sendAlimtalk(BuildContext context) async {
    final result = await messaging.send(NotificationRequest(
      channel: NotificationChannel.auto, // 실패 시 SMS 자동 대체
      toUserIds: [_userId],
      templateId: _solapiTemplateId.isEmpty ? null : _solapiTemplateId,
      body: '[Nest] MessagingLab 알림톡 테스트',
    ));
    if (!context.mounted) return;
    _showResult(context, result);
  }

  void _showResult(BuildContext context, NotificationResult? result) {
    if (!context.mounted) return;
    final text = result == null
        ? (messaging.errorMessage ?? '요청 실패')
        : 'accepted=${result.accepted} id=${result.messageId ?? '-'} '
            'fallback=${result.fallbackUsed ?? '-'}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
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
    );
  }

  Widget _actionButton(String label, VoidCallback? onPressed) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(backgroundColor: NestColors.dustyRose),
      child: Text(label),
    );
  }
}
