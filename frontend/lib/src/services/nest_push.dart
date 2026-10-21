import 'package:flutter/foundation.dart';
import 'package:lion_auth/lion_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _vapidKey = String.fromEnvironment('LION_FCM_WEB_VAPID_KEY');
const _fcmWebApiKey = String.fromEnvironment(
  'LION_FCM_WEB_API_KEY',
  defaultValue: 'AIzaSyDX4h-Xsmtbc0fgmWnBRVCs4U6LEIuXj5M',
);
const _fcmWebAppId = String.fromEnvironment(
  'LION_FCM_WEB_APP_ID',
  defaultValue: '1:62668430721:web:c28341e74a628675e45c80',
);
const _fcmWebSenderId = String.fromEnvironment(
  'LION_FCM_WEB_SENDER_ID',
  defaultValue: '62668430721',
);
const _fcmWebProjectId = String.fromEnvironment(
  'LION_FCM_WEB_PROJECT_ID',
  defaultValue: 'nest-lionandthelab',
);

const _defaultAndroidOptions = <String, String>{
  'apiKey': 'AIzaSyBxWG5R4SR_rdsDXWxJl09UUhtpqlQSSM0',
  'appId': '1:62668430721:android:f1a729444193a94ce45c80',
  'messagingSenderId': '62668430721',
  'projectId': 'nest-lionandthelab',
  'storageBucket': 'nest-lionandthelab.firebasestorage.app',
};

const _defaultIosOptions = <String, String>{
  'apiKey': 'AIzaSyAm5yU5PX0gastnP7Pa2Q6kYhowG-H7E-A',
  'appId': '1:62668430721:ios:d845b91ed1bc9419e45c80',
  'messagingSenderId': '62668430721',
  'projectId': 'nest-lionandthelab',
  'storageBucket': 'nest-lionandthelab.firebasestorage.app',
  'iosBundleId': 'com.lionandthelab.nest',
};

/// 프로덕션 앱의 FCM 토큰 등록. Firebase가 없으면 조용히 비활성이다.
class NestPush {
  NestPush._();

  static LionMessagingController? messaging;
  static bool firebaseReady = false;
  static Future<void>? _initFuture;
  static void Function(PushMessage message)? onForegroundMessage;

  static Future<void> initialize() {
    return _initFuture ??= _doInitialize();
  }

  static Future<void> _doInitialize() async {
    firebaseReady = await initLionFirebase(
      webOptions: _fcmWebApiKey.isEmpty
          ? null
          : {
              'apiKey': _fcmWebApiKey,
              'appId': _fcmWebAppId,
              'messagingSenderId': _fcmWebSenderId,
              'projectId': _fcmWebProjectId,
              'authDomain': '$_fcmWebProjectId.firebaseapp.com',
              'storageBucket': '$_fcmWebProjectId.firebasestorage.app',
            },
      androidOptions: _defaultAndroidOptions,
      iosOptions: _defaultIosOptions,
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
      onForegroundMessage: (message) {
        onForegroundMessage?.call(message);
      },
    );
    try {
      await messaging!.initialize();
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (firebaseReady && currentUserId != null && currentUserId.isNotEmpty) {
        await messaging!.onSignedIn(currentUserId);
      }
    } catch (error) {
      debugPrint('[NestPush] init failed: $error');
    }
  }

  static Future<void> onSignedIn(String userId) async {
    await initialize();
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
