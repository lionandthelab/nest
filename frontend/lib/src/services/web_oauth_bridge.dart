import 'web_oauth_bridge_stub.dart'
    if (dart.library.html) 'web_oauth_bridge_web.dart';

abstract class WebOauthBridge {
  bool get supported;

  Future<void> stashContext({
    required String homeschoolId,
    required String rootFolderId,
    required String folderPolicy,
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String accessToken,
  });

  Future<void> openPopup(String url);

  Future<Map<String, dynamic>?> consumeResult();
}

WebOauthBridge createWebOauthBridge() => createBridge();
