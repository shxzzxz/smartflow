import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/data_management/icons/command/user_business_icon_app_service.dart';
import '../application/data_management/icons/query/port/user_business_icon_reference_query.dart';
import '../application/data_management/icons/query/user_business_icon_query_service.dart';
import '../infrastructure/data_management/icons/drift_user_business_icon_reference_query.dart';
import '../infrastructure/database/database_provider.dart';
import '../widget/business/icon/business_icon_registry.dart';
import 'provider.dart';
import 'user_business_icon_source.dart';

final userBusinessIconReferenceQueryProvider =
    Provider<UserBusinessIconReferenceQuery>((ref) {
      return DriftUserBusinessIconReferenceQuery(
        ref.watch(appDatabaseProvider),
      );
    });

final userBusinessIconQueryServiceProvider =
    Provider<UserBusinessIconQueryService>((ref) {
      return UserBusinessIconQueryServiceImpl(
        store: ref.watch(userBusinessIconStoreProvider),
        references: ref.watch(userBusinessIconReferenceQueryProvider),
      );
    });

final userBusinessIconAppServiceProvider = Provider<UserBusinessIconAppService>(
  (ref) {
    return UserBusinessIconAppService(
      store: ref.watch(userBusinessIconStoreProvider),
      references: ref.watch(userBusinessIconReferenceQueryProvider),
    );
  },
);

final userBusinessIconSourceProvider = Provider<BusinessIconSource>((ref) {
  return AppUserBusinessIconSource(ref.watch(userBusinessIconStoreProvider));
});

final businessIconRegistryLoaderProvider = Provider<BusinessIconRegistryLoader>(
  (ref) {
    return BusinessIconRegistryLoader(
      bundle: rootBundle,
      userIcons: ref.watch(userBusinessIconSourceProvider),
    );
  },
);

class BusinessIconRegistryLoader {
  const BusinessIconRegistryLoader({
    required AssetBundle bundle,
    required BusinessIconSource userIcons,
  }) : _bundle = bundle,
       _userIcons = userIcons;

  final AssetBundle _bundle;
  final BusinessIconSource _userIcons;

  Future<BusinessIconRegistry> load() {
    return BusinessIconRegistry.loadFromSources([
      BundledBusinessIconSource(_bundle),
      _userIcons,
    ]);
  }
}
