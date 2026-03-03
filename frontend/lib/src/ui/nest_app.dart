import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../services/nest_repository.dart';
import '../services/web_oauth_bridge.dart';
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
    final repository = NestRepository(Supabase.instance.client);
    controller = NestController(
      repository: repository,
      webOauthBridge: createWebOauthBridge(),
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
