import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_error_boundary.dart';
import 'app/bootstrap.dart';
import 'app/provider.dart';
import 'app/provider_error_observer.dart';

Future<void> main() async {
  final errorHandler = AppGlobalErrorHandler(
    scaffoldMessengerKey: appScaffoldMessengerKey,
  );

  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final logFileSink = await bootstrap();
    errorHandler.install();

    runApp(
      ProviderScope(
        observers: [AppProviderErrorObserver()],
        overrides: [appLogFileSinkProvider.overrideWithValue(logFileSink)],
        child: SmartFlowApp(scaffoldMessengerKey: appScaffoldMessengerKey),
      ),
    );
  }, errorHandler.handleZoneError);
}
