import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widget/business/icon/business_icon_registry.dart';

final businessIconRegistryProvider = Provider<BusinessIconRegistry>(
  (ref) => const BusinessIconRegistry.empty(),
);
