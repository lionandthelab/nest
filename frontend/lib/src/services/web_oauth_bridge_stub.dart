import 'web_oauth_bridge.dart';

WebOauthBridge createBridge() => const _WebOauthBridgeStub();

class _WebOauthBridgeStub implements WebOauthBridge {
  const _WebOauthBridgeStub();

  @override
  bool get supported => false;

  @override
  Future<Map<String, dynamic>?> consumeResult() async => null;

  @override
  Future<void> openPopup(String url) async {}

  @override
  Future<void> stashContext({
    required String homeschoolId,
    required String rootFolderId,
    required String folderPolicy,
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String accessToken,
  }) async {}
}
