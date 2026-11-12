import 'package:flutter/widgets.dart';

import 'business_icon_registry.dart';

export 'business_icon_registry.dart';

/// Shares the loaded registry with business widgets.
class BusinessIconScope extends InheritedWidget {
  const BusinessIconScope({
    required this.registry,
    required super.child,
    super.key,
  });

  final BusinessIconRegistry registry;

  static BusinessIconScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BusinessIconScope>() ??
      const BusinessIconScope(
        registry: BusinessIconRegistry.empty(),
        child: SizedBox.shrink(),
      );

  BusinessIconGroup? defaultGroupFor(BusinessIconType type) =>
      registry.defaultGroupFor(type, null);

  List<BusinessIconGroup> groupsFor(BusinessIconType type) =>
      registry.groupsFor(type);

  BusinessIconGroup? groupForRef(BusinessIconRef ref) =>
      registry.groupForRef(ref);

  BusinessIconSpec? resolve(String? refOrKey, BusinessIconUsage usage) {
    if (usage == BusinessIconUsage.system) return null;
    final type = _type(usage);
    return registry.resolve(refOrKey, type: type);
  }

  String canonicalizeIconRef(String value, BusinessIconType type) {
    final parsed = BusinessIconRef.tryParse(value);
    if (parsed != null && parsed.type == type) return parsed.id;

    final group = defaultGroupFor(type);
    final resolved = registry.resolveLegacyKey(
      value,
      type: type,
      defaultGroupId: group?.id,
    );
    return (resolved?.ref ??
            BusinessIconRef(
              origin: BusinessIconOrigin.builtin,
              type: type,
              groupId: group?.id ?? defaultBusinessIconGroupId,
              key: value,
            ))
        .id;
  }

  List<BusinessIconSpec> search({
    required BusinessIconUsage usage,
    String? groupId,
    BusinessIconOrigin? origin,
    String query = '',
  }) {
    if (usage == BusinessIconUsage.system) return const [];
    final type = _type(usage);
    return registry.search(
      type: type,
      usage: usage,
      groupId: groupId,
      origin: origin,
      query: query,
    );
  }

  static BusinessIconType _type(BusinessIconUsage usage) =>
      usage == BusinessIconUsage.account
      ? BusinessIconType.account
      : BusinessIconType.category;

  @override
  bool updateShouldNotify(BusinessIconScope oldWidget) =>
      registry != oldWidget.registry;
}
