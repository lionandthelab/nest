import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../services/nest_repository.dart';
import '../services/web_oauth_bridge.dart';
import '../state/nest_controller.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'nest_theme.dart';

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
          if (!controller.isBootstrapped) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (!controller.isLoggedIn) {
            return LoginPage(controller: controller);
          }

          return HomePage(controller: controller);
        },
      ),
    );
  }
}
