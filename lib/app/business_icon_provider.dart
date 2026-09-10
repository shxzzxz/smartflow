import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widget/business/icon/business_icon_catalog.dart';

final businessIconCatalogProvider = Provider<BusinessIconCatalog>(
  (ref) => const BusinessIconCatalog.empty(),
);
