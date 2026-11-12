import 'dart:convert';

import 'package:flutter/services.dart';

enum BusinessIconType { account, category }

enum BusinessIconUsage { expenseCategory, incomeCategory, system, account }

enum BusinessIconOrigin { builtin, user }

enum BusinessIconGroupKind { style, brand, user }

enum BusinessIconResourceKind { asset, file }

const defaultBusinessIconGroupId = 'rounded-line';
const userBusinessIconGroupId = 'my-icons';

/// Original preserves brand/multicolor artwork; the others retain SVG opacity.
enum BusinessIconColor { original, foreground, primary }

class BusinessIconRef {
  const BusinessIconRef({
    required this.origin,
    required this.type,
    required this.groupId,
    required this.key,
  });

  final BusinessIconOrigin origin;
  final BusinessIconType type;
  final String groupId;
  final String key;

  String get id => '${origin.name}:${type.name}:$groupId:$key';

  static BusinessIconRef? tryParse(String? value) {
    final parts = value?.trim().split(':') ?? const <String>[];
    if (parts.length != 4) return null;
    final origin = BusinessIconOrigin.values
        .where((candidate) => candidate.name == parts[0])
        .firstOrNull;
    final type = BusinessIconType.values
        .where((candidate) => candidate.name == parts[1])
        .firstOrNull;
    if (origin == null ||
        type == null ||
        !_isIdentifier(parts[2]) ||
        !_isIdentifier(parts[3])) {
      return null;
    }
    return BusinessIconRef(
      origin: origin,
      type: type,
      groupId: parts[2],
      key: parts[3],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BusinessIconRef &&
      other.origin == origin &&
      other.type == type &&
      other.groupId == groupId &&
      other.key == key;

  @override
  int get hashCode => Object.hash(origin, type, groupId, key);

  @override
  String toString() => id;
}

class BusinessIconSpec {
  const BusinessIconSpec({
    required this.ref,
    required this.label,
    required this.assetPath,
    required this.usage,
    required this.color,
    this.resourceKind = BusinessIconResourceKind.asset,
    this.keywords = const [],
  });

  final BusinessIconRef ref;
  final String label;
  final String assetPath;
  final BusinessIconUsage usage;
  final BusinessIconColor color;
  final BusinessIconResourceKind resourceKind;
  final List<String> keywords;

  String get iconKey => ref.key;
  BusinessIconOrigin get origin => ref.origin;
  BusinessIconType get type => ref.type;
  String get groupId => ref.groupId;
}

class BusinessIconGroup {
  BusinessIconGroup({
    required this.origin,
    required this.type,
    required this.id,
    required this.name,
    required this.kind,
    required Map<String, BusinessIconSpec> icons,
  }) : icons = Map.unmodifiable(icons);

  final BusinessIconOrigin origin;
  final BusinessIconType type;
  final String id;
  final String name;
  final BusinessIconGroupKind kind;
  final Map<String, BusinessIconSpec> icons;

  bool get isDefaultEligible => kind == BusinessIconGroupKind.style;
  String get identity => '${origin.name}:${type.name}:$id';
}

/// A source hides where icon manifests and files live from the registry.
abstract interface class BusinessIconSource {
  Future<List<BusinessIconGroup>> load();
}

/// Loads the icon groups bundled with the application from declarative JSON.
class BundledBusinessIconSource implements BusinessIconSource {
  const BundledBusinessIconSource(
    this._bundle, {
    this.roots = const {
      BusinessIconType.account: 'assets/styles/account/manifest.json',
      BusinessIconType.category: 'assets/styles/category/manifest.json',
    },
  });

  final AssetBundle _bundle;
  final Map<BusinessIconType, String> roots;

  @override
  Future<List<BusinessIconGroup>> load() async {
    final groups = await Future.wait(
      roots.entries.map((entry) async {
        final index = await _readJson(_bundle, entry.value);
        final groupEntries = index['groups'];
        if (groupEntries is! List || groupEntries.isEmpty) {
          throw FormatException('No icon groups: ${entry.value}');
        }
        final ids = <String>{};
        return Future.wait(
          groupEntries.map((raw) async {
            final group = raw as Map<String, dynamic>;
            final id = _identifier(group['id']);
            if (!ids.add(id)) {
              throw FormatException(
                'Duplicate icon group in ${entry.value}: $id',
              );
            }
            final name = _requiredString(group['name'], 'group name');
            final kind = _groupKind(group['kind'] ?? 'style');
            final manifestPath = _requiredString(
              group['manifest'],
              'group manifest',
            );
            return _loadGroup(
              bundle: _bundle,
              origin: BusinessIconOrigin.builtin,
              type: entry.key,
              id: id,
              name: name,
              kind: kind,
              manifestPath: manifestPath,
            );
          }),
        );
      }),
    );
    return List<BusinessIconGroup>.unmodifiable(
      groups.expand((group) => group),
    );
  }
}

/// The UI-facing module for querying and resolving icons from all sources.
class BusinessIconRegistry {
  const BusinessIconRegistry.empty() : _groups = const {};

  BusinessIconRegistry._(Map<BusinessIconType, List<BusinessIconGroup>> groups)
    : _groups = Map.unmodifiable({
        for (final type in BusinessIconType.values)
          type: List<BusinessIconGroup>.unmodifiable(groups[type] ?? const []),
      });

  final Map<BusinessIconType, List<BusinessIconGroup>> _groups;

  static Future<BusinessIconRegistry> load(AssetBundle bundle) async {
    return loadFromSources([BundledBusinessIconSource(bundle)]);
  }

  static Future<BusinessIconRegistry> loadFromSources(
    Iterable<BusinessIconSource> sources,
  ) async {
    final groups = <BusinessIconType, List<BusinessIconGroup>>{
      for (final type in BusinessIconType.values) type: [],
    };
    final identities = <String>{};
    for (final source in sources) {
      for (final group in await source.load()) {
        final identity = '${group.origin.name}:${group.type.name}:${group.id}';
        if (!identities.add(identity)) {
          throw FormatException('Duplicate icon source group: $identity');
        }
        groups[group.type]!.add(group);
      }
    }
    for (final type in BusinessIconType.values) {
      if (groups[type]!.isEmpty) {
        throw FormatException('No icon groups for ${type.name}');
      }
    }
    return BusinessIconRegistry._(groups);
  }

  List<BusinessIconGroup> groupsFor(BusinessIconType type) =>
      _groups[type] ?? const [];

  List<BusinessIconGroup> defaultGroupsFor(BusinessIconType type) =>
      List.unmodifiable(
        groupsFor(type).where((group) => group.isDefaultEligible),
      );

  BusinessIconGroup? groupFor(
    BusinessIconType type,
    String? id, {
    BusinessIconOrigin? origin,
  }) {
    for (final group in groupsFor(type)) {
      if (group.id == id && (origin == null || group.origin == origin)) {
        return group;
      }
    }
    return null;
  }

  BusinessIconGroup? groupForRef(BusinessIconRef ref) =>
      groupFor(ref.type, ref.groupId, origin: ref.origin);

  BusinessIconGroup? defaultGroupFor(
    BusinessIconType type,
    String? preferredGroupId,
  ) {
    final groups = groupsFor(type);
    for (final group in groups) {
      if (group.isDefaultEligible && group.id == preferredGroupId) {
        return group;
      }
    }
    return groups.where((group) => group.isDefaultEligible).firstOrNull ??
        groups.firstOrNull;
  }

  BusinessIconSpec? resolve(String? ref, {required BusinessIconType type}) {
    final value = ref?.trim();
    if (value == null || value.isEmpty) return null;

    final parsed = BusinessIconRef.tryParse(value);
    if (parsed == null || parsed.type != type) return null;
    return groupForRef(parsed)?.icons[parsed.key];
  }

  BusinessIconSpec? resolveLegacyKey(
    String key, {
    required BusinessIconType type,
    String? defaultGroupId,
  }) {
    final value = key.trim();
    if (value.isEmpty || BusinessIconRef.tryParse(value) != null) return null;
    final defaultGroup = defaultGroupFor(type, defaultGroupId);
    final preferred = defaultGroup?.icons[value];
    if (preferred != null) return preferred;

    // Legacy keys that do not exist in the selected style can belong to a
    // named pack such as the removable brand icon group.
    for (final group in groupsFor(type)) {
      if (group.kind == BusinessIconGroupKind.style) continue;
      final icon = group.icons[value];
      if (icon != null) return icon;
    }
    return null;
  }

  List<BusinessIconSpec> search({
    required BusinessIconType type,
    required BusinessIconUsage usage,
    String? groupId,
    BusinessIconOrigin? origin,
    String query = '',
  }) {
    final needle = query.trim().toLowerCase();
    return List.unmodifiable(
      groupsFor(type)
          .where(
            (group) =>
                (groupId == null || group.id == groupId) &&
                (origin == null || group.origin == origin),
          )
          .expand((group) => group.icons.values)
          .where(
            (icon) =>
                _acceptsUsage(icon, usage) &&
                (needle.isEmpty ||
                    [
                      icon.iconKey,
                      icon.label,
                      ...icon.keywords,
                    ].any((value) => value.toLowerCase().contains(needle))),
          ),
    );
  }
}

bool _acceptsUsage(BusinessIconSpec icon, BusinessIconUsage usage) {
  if (icon.usage == usage) return true;
  return icon.origin == BusinessIconOrigin.user &&
      icon.type == BusinessIconType.category &&
      (usage == BusinessIconUsage.expenseCategory ||
          usage == BusinessIconUsage.incomeCategory);
}

Future<BusinessIconGroup> _loadGroup({
  required AssetBundle bundle,
  required BusinessIconOrigin origin,
  required BusinessIconType type,
  required String id,
  required String name,
  required BusinessIconGroupKind kind,
  required String manifestPath,
}) async {
  final manifest = await _readJson(bundle, manifestPath);
  final defaultColor = _color(manifest['color']);
  final groupRoot = _parentPath(manifestPath);
  final icons = <String, BusinessIconSpec>{};
  for (final raw in manifest['icons'] as List) {
    final icon = raw as Map<String, dynamic>;
    final key = _identifier(icon['key']);
    if (icons.containsKey(key)) {
      throw FormatException('Duplicate icon: $manifestPath/$key');
    }
    final usage = type == BusinessIconType.account
        ? BusinessIconUsage.account
        : switch (icon['usage']) {
            'expenseCategory' => BusinessIconUsage.expenseCategory,
            'incomeCategory' => BusinessIconUsage.incomeCategory,
            _ => throw FormatException('Invalid category usage: $key'),
          };
    icons[key] = BusinessIconSpec(
      ref: BusinessIconRef(origin: origin, type: type, groupId: id, key: key),
      label: _requiredString(icon['label'], 'icon label'),
      assetPath: '$groupRoot/icons/$key.svg',
      usage: usage,
      color: icon.containsKey('color') ? _color(icon['color']) : defaultColor,
      keywords: List.unmodifiable(
        (icon['keywords'] as List? ?? []).cast<String>(),
      ),
    );
  }
  return BusinessIconGroup(
    origin: origin,
    type: type,
    id: id,
    name: name,
    kind: kind,
    icons: icons,
  );
}

Future<Map<String, dynamic>> _readJson(AssetBundle bundle, String path) async =>
    jsonDecode(await bundle.loadString(path)) as Map<String, dynamic>;

String _parentPath(String path) {
  final separator = path.lastIndexOf('/');
  if (separator <= 0) {
    throw FormatException('Invalid manifest path: $path');
  }
  return path.substring(0, separator);
}

String _identifier(Object? value) {
  if (value is! String || !_isIdentifier(value)) {
    throw FormatException('Invalid icon identifier: $value');
  }
  return value;
}

bool _isIdentifier(String value) =>
    RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(value);

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $field: $value');
  }
  return value;
}

BusinessIconGroupKind _groupKind(Object? value) => switch (value) {
  'style' => BusinessIconGroupKind.style,
  'brand' => BusinessIconGroupKind.brand,
  'user' => BusinessIconGroupKind.user,
  _ => throw FormatException('Invalid icon group kind: $value'),
};

BusinessIconColor _color(Object? value) => switch (value) {
  null || 'original' => BusinessIconColor.original,
  'foreground' => BusinessIconColor.foreground,
  'primary' => BusinessIconColor.primary,
  _ => throw FormatException('Invalid icon color mode: $value'),
};
