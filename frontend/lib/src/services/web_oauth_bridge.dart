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

  /// True once [openPopup] has run and the popup window has since been closed
  /// (the user finished or abandoned the flow). Always false where there is no
  /// popup (non-web) or before a popup was opened.
  bool get isPopupClosed;

  /// Removes any stashed OAuth context (including the user access token) from
  /// client-side storage. Call once the flow finishes — success or failure.
  Future<void> clearContext();
}

WebOauthBridge createWebOauthBridge() => createBridge();
