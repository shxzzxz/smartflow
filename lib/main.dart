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
import 'app/user_business_icon_providers.dart';
import 'app/user_business_icon_source.dart';
import 'infrastructure/data_management/icons/platform_user_business_icon_store.dart';
import 'infrastructure/import/wechat/wechat_category_lexicon_loader.dart';
import 'infrastructure/shared/uuid_id_generator.dart';

Future<void> main() async {
  final errorHandler = AppGlobalErrorHandler(
    scaffoldMessengerKey: appScaffoldMessengerKey,
  );

  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final logFileSink = await bootstrap();
    errorHandler.install();
    final userIconStore = PlatformUserBusinessIconStore(
      ids: const UuidIdGenerator(),
    );
    final iconRegistry = await BusinessIconRegistryLoader(
      bundle: rootBundle,
      userIcons: AppUserBusinessIconSource(userIconStore),
    ).load();
    final wechatCategoryLexicon = await const WechatCategoryLexiconLoader()
        .load(rootBundle);

    runApp(
      ProviderScope(
        observers: [AppProviderErrorObserver()],
        overrides: [
          appLogFileSinkProvider.overrideWithValue(logFileSink),
          userBusinessIconStoreProvider.overrideWithValue(userIconStore),
          businessIconRegistryProvider.overrideWith(
            () => BusinessIconRegistryNotifier(iconRegistry),
          ),
          wechatCategoryLexiconProvider.overrideWithValue(
            wechatCategoryLexicon,
          ),
        ],
        child: SmartFlowApp(scaffoldMessengerKey: appScaffoldMessengerKey),
      ),
    );
  }, errorHandler.handleZoneError);
}
