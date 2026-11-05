import 'package:flutter/foundation.dart';
import 'package:lion_auth/lion_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

    String? appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      final ver = info.version.trim();
      final build = info.buildNumber.trim();
      if (ver.isNotEmpty) {
        appVersion = build.isEmpty ? ver : '$ver+$build';
      }
    } catch (_) {}

    messaging = LionMessagingController(
      config: LionMessagingConfig(
        fcm: FcmOptions(
          vapidKey: _vapidKey.isEmpty ? null : _vapidKey,
          appVersion: appVersion,
          // 시스템 권한 요청은 홈 진입 시 안내 팝업 버튼 클릭(사용자 제스처)으로 수행하고,
          // 이미 권한이 허용된 기기는 syncTokenIfPermitted 로 조용히 토큰만 갱신한다.
          autoRegisterOnSignIn: false,
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
        await messaging!.syncTokenIfPermitted(currentUserId);
      }
    } catch (error) {
      debugPrint('[NestPush] init failed: $error');
    }
  }

  /// 로그인/복귀 시 이미 권한이 허용된 기기면 토큰만 조용히 동기화한다.
  static Future<void> onSignedIn(String userId) async {
    await initialize();
    final controller = messaging;
    if (controller == null || !firebaseReady) return;
    try {
      await controller.syncTokenIfPermitted(userId);
    } catch (error) {
      debugPrint('[NestPush] sync failed: $error');
    }
  }

  /// 현재 푸시 권한 상태를 조회하고, 이미 허용된 상태라면 토큰 동기화까지 마친 뒤 반환한다.
  static Future<({PushPermissionStatus status, bool hasToken})>
  inspectAndSyncIfPermitted(String userId) async {
    await initialize();
    final controller = messaging;
    if (controller == null || !firebaseReady || !controller.pushSupported) {
      return (status: PushPermissionStatus.unsupported, hasToken: false);
    }
    try {
      final status = await controller.checkPermissionStatus();
      if (status == PushPermissionStatus.authorized) {
        await controller.syncTokenIfPermitted(userId);
      }
      return (
        status: controller.permissionStatus,
        hasToken: (controller.currentToken ?? '').isNotEmpty,
      );
    } catch (error) {
      debugPrint('[NestPush] inspect failed: $error');
      return (status: PushPermissionStatus.unsupported, hasToken: false);
    }
  }

  /// 사용자 버튼 클릭 시 OS 푸시 권한 팝업을 띄우고 토큰을 `push_tokens` 에 등록한다.
  static Future<({PushPermissionStatus status, bool hasToken})>
  requestPermissionAndRegister(String userId) async {
    await initialize();
    final controller = messaging;
    if (controller == null || !firebaseReady || !controller.pushSupported) {
      return (status: PushPermissionStatus.unsupported, hasToken: false);
    }
    try {
      await controller.registerPush(userId: userId);
    } catch (error) {
      debugPrint('[NestPush] request/register failed: $error');
    }
    return (
      status: controller.permissionStatus,
      hasToken: (controller.currentToken ?? '').isNotEmpty,
    );
  }

  static Future<void> onSignedOut() async {
    try {
      await messaging?.onSignedOut();
    } catch (error) {
      debugPrint('[NestPush] sign-out failed: $error');
    }
  }
}
