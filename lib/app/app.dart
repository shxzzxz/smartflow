import 'package:flutter/material.dart';

import '../design_system/theme/app_theme.dart';
import 'app_error_boundary.dart';
import 'router.dart';

class SmartFlowApp extends StatelessWidget {
  const SmartFlowApp({super.key, this.scaffoldMessengerKey});

  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SmartFlow',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        ErrorWidget.builder =
            AppGlobalErrorHandler(
              scaffoldMessengerKey:
                  scaffoldMessengerKey ?? appScaffoldMessengerKey,
            ).buildErrorWidget;
        return child ?? const SizedBox.shrink();
      },
      routerConfig: appRouter,
    );
  }
}
