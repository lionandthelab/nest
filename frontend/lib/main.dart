import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/config/app_config.dart';
import 'src/services/nest_cache.dart';
import 'src/ui/nest_app.dart';

Future<void> main() async {
  // Global error boundary – catches uncaught async errors.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Capture Flutter framework errors (widget build / layout / painting).
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      // In release mode, log silently instead of crashing.
      if (kReleaseMode) {
        debugPrint('[NestCrash] ${details.exceptionAsString()}');
      }
    };

    // Catch errors in the platform dispatcher (e.g. shader compilation).
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('[NestPlatformError] $error\n$stack');
      return true; // handled
    };

    await Future.wait([
      Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      ),
      NestCache.initialize(),
    ]);

    runApp(const NestAppRoot());
  }, (error, stack) {
    // Fallback for uncaught async errors outside Flutter framework.
    debugPrint('[NestUncaught] $error\n$stack');
  });
}
