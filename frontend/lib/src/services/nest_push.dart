import 'package:flutter/foundation.dart';
import 'package:lion_auth/lion_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _vapidKey = String.fromEnvironment('LION_FCM_WEB_VAPID_KEY');
const _fcmWebApiKey = String.fromEnvironment('LION_FCM_WEB_API_KEY');
const _fcmWebAppId = String.fromEnvironment('LION_FCM_WEB_APP_ID');
const _fcmWebSenderId = String.fromEnvironment('LION_FCM_WEB_SENDER_ID');
const _fcmWebProjectId = String.fromEnvironment('LION_FCM_WEB_PROJECT_ID');

/// 프로덕션 앱의 FCM 토큰 등록. Firebase가 없으면 조용히 비활성이다.
class NestPush {
  NestPush._();

  static LionMessagingController? messaging;
  static bool firebaseReady = false;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    firebaseReady = await initLionFirebase(
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

    messaging = LionMessagingController(
      config: LionMessagingConfig(
        fcm: FcmOptions(
          vapidKey: _vapidKey.isEmpty ? null : _vapidKey,
          autoRegisterOnSignIn: true,
        ),
      ),
      backend: SupabaseLionMessagingBackend(Supabase.instance.client),
    );
    try {
      await messaging!.initialize();
    } catch (error) {
      debugPrint('[NestPush] init failed: $error');
    }
  }

  static Future<void> onSignedIn(String userId) async {
    final controller = messaging;
    if (controller == null || !firebaseReady) return;
    try {
      await controller.onSignedIn(userId);
    } catch (error) {
      debugPrint('[NestPush] register failed: $error');
    }
  }

  static Future<void> onSignedOut() async {
    try {
      await messaging?.onSignedOut();
    } catch (error) {
      debugPrint('[NestPush] sign-out failed: $error');
    }
  }
}
