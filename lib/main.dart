import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_error_boundary.dart';
import 'app/bootstrap.dart';
import 'app/business_icon_provider.dart';
import 'app/provider.dart';
import 'app/provider_error_observer.dart';
import 'widget/business/icon/business_icon_catalog.dart';

Future<void> main() async {
  final errorHandler = AppGlobalErrorHandler(
    scaffoldMessengerKey: appScaffoldMessengerKey,
  );

  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final logFileSink = await bootstrap();
    errorHandler.install();
    final iconCatalog = await BusinessIconCatalog.load(rootBundle);

    runApp(
      ProviderScope(
        observers: [AppProviderErrorObserver()],
        overrides: [
          appLogFileSinkProvider.overrideWithValue(logFileSink),
          businessIconCatalogProvider.overrideWithValue(iconCatalog),
        ],
        child: SmartFlowApp(scaffoldMessengerKey: appScaffoldMessengerKey),
      ),
    );
  }, errorHandler.handleZoneError);
}
