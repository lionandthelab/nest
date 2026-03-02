// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'web_oauth_bridge.dart';

WebOauthBridge createBridge() => const _WebOauthBridgeWeb();

class _WebOauthBridgeWeb implements WebOauthBridge {
  const _WebOauthBridgeWeb();

  static const String _prefix = 'nest.oauth';

  @override
  bool get supported => true;

  @override
  Future<void> stashContext({
    required String homeschoolId,
    required String rootFolderId,
    required String folderPolicy,
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String accessToken,
  }) async {
    html.window.localStorage['$_prefix.homeschool_id'] = homeschoolId;
    html.window.localStorage['$_prefix.root_folder_id'] = rootFolderId;
    html.window.localStorage['$_prefix.folder_policy'] = folderPolicy;
    html.window.localStorage['$_prefix.supabase_url'] = supabaseUrl;
    html.window.localStorage['$_prefix.supabase_anon_key'] = supabaseAnonKey;
    html.window.localStorage['$_prefix.access_token'] = accessToken;
  }

  @override
  Future<void> openPopup(String url) async {
    html.window.open(
      url,
      'nest_google_oauth',
      'popup=yes,width=520,height=760,menubar=no,toolbar=no,location=no,status=no',
    );
  }

  @override
  Future<Map<String, dynamic>?> consumeResult() async {
    final raw = html.window.localStorage['$_prefix.result'];
    if (raw == null || raw.isEmpty) {
      return null;
    }

    html.window.localStorage.remove('$_prefix.result');

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
