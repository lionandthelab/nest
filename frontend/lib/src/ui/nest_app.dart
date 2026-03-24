import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../services/nest_repository.dart';
import '../state/nest_controller.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'nest_theme.dart';
import 'widgets/nest_motion.dart';

class NestAppRoot extends StatefulWidget {
  const NestAppRoot({super.key});

  @override
  State<NestAppRoot> createState() => _NestAppRootState();
}

class _NestAppRootState extends State<NestAppRoot> {
  late final NestController controller;

  @override
  void initState() {
    super.initState();

    // Replace red error screen with a branded fallback in all modes.
    ErrorWidget.builder = (details) => const _NestErrorFallback();

    final repository = NestRepository(Supabase.instance.client);
    controller = NestController(
      repository: repository,
    );

    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: NestTheme.light(),
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final page = switch ((
            controller.isBootstrapped,
            controller.isLoggedIn,
          )) {
            (false, _) => const NestLoadingScreen(),
            (true, false) => LoginPage(controller: controller),
            (true, true) => HomePage(controller: controller),
          };

          final key = switch ((
            controller.isBootstrapped,
            controller.isLoggedIn,
          )) {
            (false, _) => const ValueKey<String>('boot'),
            (true, false) => const ValueKey<String>('login'),
            (true, true) => const ValueKey<String>('home'),
          };

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 340),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) =>
                nestFadeSlideTransition(child, animation),
            child: KeyedSubtree(key: key, child: page),
          );
        },
      ),
    );
  }
}

/// Branded error fallback shown instead of the red error screen in release.
class _NestErrorFallback extends StatelessWidget {
  const _NestErrorFallback();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NestColors.creamyWhite,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: NestColors.roseMist,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.sentiment_dissatisfied_outlined,
                  size: 36,
                  color: NestColors.deepWood,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '화면을 표시하는 중 문제가 발생했습니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: NestColors.deepWood,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '앱을 다시 시작해 주세요.\n문제가 계속되면 관리자에게 문의해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: NestColors.deepWood.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
