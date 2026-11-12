import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widget/business/icon/business_icon_registry.dart';
import 'user_business_icon_providers.dart';

final businessIconRegistryProvider =
    NotifierProvider<BusinessIconRegistryNotifier, BusinessIconRegistry>(
      BusinessIconRegistryNotifier.new,
    );

class BusinessIconRegistryNotifier extends Notifier<BusinessIconRegistry> {
  BusinessIconRegistryNotifier([
    this._initial = const BusinessIconRegistry.empty(),
  ]);

  final BusinessIconRegistry _initial;

  @override
  BusinessIconRegistry build() => _initial;

  void replace(BusinessIconRegistry registry) => state = registry;

  Future<void> reload() async {
    state = await ref.read(businessIconRegistryLoaderProvider).load();
  }
}
