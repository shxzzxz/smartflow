import 'package:flutter/widgets.dart';

import 'business_icon_catalog.dart';

export 'business_icon_catalog.dart';

/// Shares the loaded catalog and independent style choices with business widgets.
class BusinessIconScope extends InheritedWidget {
  const BusinessIconScope({
    required this.catalog,
    required super.child,
    this.accountStyle,
    this.categoryStyle,
    super.key,
  });

  final BusinessIconCatalog catalog;
  final String? accountStyle;
  final String? categoryStyle;

  static BusinessIconScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BusinessIconScope>() ??
      const BusinessIconScope(
        catalog: BusinessIconCatalog.empty(),
        child: SizedBox.shrink(),
      );

  String? styleFor(BusinessIconType type) =>
      type == BusinessIconType.account ? accountStyle : categoryStyle;

  BusinessIconSpec? resolve(String? key, BusinessIconUsage usage) =>
      usage == BusinessIconUsage.system
      ? null
      : catalog.resolve(key, type: _type(usage), style: styleFor(_type(usage)));

  List<BusinessIconSpec> search({
    required BusinessIconUsage usage,
    String query = '',
  }) => catalog.search(
    type: _type(usage),
    style: styleFor(_type(usage)),
    usage: usage,
    query: query,
  );

  static BusinessIconType _type(BusinessIconUsage usage) =>
      usage == BusinessIconUsage.account
      ? BusinessIconType.account
      : BusinessIconType.category;

  @override
  bool updateShouldNotify(BusinessIconScope oldWidget) =>
      catalog != oldWidget.catalog ||
      accountStyle != oldWidget.accountStyle ||
      categoryStyle != oldWidget.categoryStyle;
}
