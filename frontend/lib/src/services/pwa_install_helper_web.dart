// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:js' as js;

import 'pwa_install_helper.dart';

PwaInstallHelper createHelper() => _PwaInstallHelperWeb();

class _PwaInstallHelperWeb implements PwaInstallHelper {
  @override
  bool get isInstallable {
    final prompt = js.context['_nestDeferredPrompt'];
    return prompt != null && prompt is! bool;
  }

  @override
  bool get isRunningAsPwa {
    final mq = html.window.matchMedia('(display-mode: standalone)');
    if (mq.matches) return true;
    final nav = html.window.navigator;
    // iOS Safari standalone check
    final standalone = js.context['navigator']?['standalone'];
    if (standalone == true) return true;
    // Check if running in TWA or similar
    if (nav.userAgent.contains('wv')) return true;
    return false;
  }

  @override
  bool get isIos {
    final ua = html.window.navigator.userAgent.toLowerCase();
    return ua.contains('iphone') ||
        ua.contains('ipad') ||
        ua.contains('ipod');
  }

  @override
  Future<bool> promptInstall() async {
    final prompt = js.context['_nestDeferredPrompt'];
    if (prompt == null) return false;
    try {
      prompt.callMethod('prompt', []);
      // Clear stored prompt — it can only be used once
      js.context['_nestDeferredPrompt'] = null;
      return true;
    } catch (_) {
      return false;
    }
  }
}
