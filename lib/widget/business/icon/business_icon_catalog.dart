import 'dart:convert';

import 'package:flutter/services.dart';

enum BusinessIconType { account, category }

enum BusinessIconUsage { expenseCategory, incomeCategory, system, account }

/// Original preserves brand/multicolor artwork; the others retain SVG opacity.
enum BusinessIconColor { original, foreground, primary }

class BusinessIconSpec {
  const BusinessIconSpec({
    required this.iconKey,
    required this.label,
    required this.assetPath,
    required this.usage,
    required this.color,
    this.keywords = const [],
  });

  final String iconKey;
  final String label;
  final String assetPath;
  final BusinessIconUsage usage;
  final BusinessIconColor color;
  final List<String> keywords;
}

class BusinessIconStyle {
  BusinessIconStyle({
    required this.id,
    required this.name,
    required Map<String, BusinessIconSpec> icons,
  }) : icons = Map.unmodifiable(icons);

  final String id;
  final String name;
  final Map<String, BusinessIconSpec> icons;
}

/// JSON is the only registry. An absent key stays absent in the selected style.
class BusinessIconCatalog {
  const BusinessIconCatalog.empty() : _styles = const {};

  BusinessIconCatalog._(Map<BusinessIconType, List<BusinessIconStyle>> styles)
    : _styles = Map.unmodifiable(styles);

  final Map<BusinessIconType, List<BusinessIconStyle>> _styles;

  static Future<BusinessIconCatalog> load(AssetBundle bundle) async {
    final types = await Future.wait(
      BusinessIconType.values.map((type) async {
        final base = 'assets/styles/${type.name}';
        final index = await _readJson(bundle, '$base/manifest.json');
        final ids = <String>{};
        final styles = await Future.wait(
          (index['styles'] as List).map((item) async {
            final entry = item as Map<String, dynamic>;
            final id = _identifier(entry['id']);
            if (!ids.add(id)) {
              throw FormatException('Duplicate style: $base/$id');
            }
            final manifest = await _readJson(bundle, '$base/$id/manifest.json');
            final defaultColor = _color(manifest['color']);
            final icons = <String, BusinessIconSpec>{};
            for (final raw in manifest['icons'] as List) {
              final icon = raw as Map<String, dynamic>;
              final key = _identifier(icon['key']);
              if (icons.containsKey(key)) {
                throw FormatException('Duplicate icon: $base/$id/$key');
              }
              final usage = type == BusinessIconType.account
                  ? BusinessIconUsage.account
                  : switch (icon['usage']) {
                      'expenseCategory' => BusinessIconUsage.expenseCategory,
                      'incomeCategory' => BusinessIconUsage.incomeCategory,
                      _ => throw FormatException(
                        'Invalid category usage: $key',
                      ),
                    };
              icons[key] = BusinessIconSpec(
                iconKey: key,
                label: icon['label'] as String,
                assetPath: '$base/$id/icons/$key.svg',
                usage: usage,
                color: icon.containsKey('color')
                    ? _color(icon['color'])
                    : defaultColor,
                keywords: List.unmodifiable(
                  (icon['keywords'] as List? ?? []).cast<String>(),
                ),
              );
            }
            return BusinessIconStyle(
              id: id,
              name: entry['name'] as String,
              icons: icons,
            );
          }),
        );
        if (styles.isEmpty) throw FormatException('No icon styles: $base');
        return MapEntry(type, List<BusinessIconStyle>.unmodifiable(styles));
      }),
    );
    return BusinessIconCatalog._(Map.fromEntries(types));
  }

  List<BusinessIconStyle> stylesFor(BusinessIconType type) =>
      _styles[type] ?? const [];

  BusinessIconStyle? styleFor(BusinessIconType type, String? id) {
    final styles = stylesFor(type);
    for (final style in styles) {
      if (style.id == id) return style;
    }
    return styles.firstOrNull;
  }

  BusinessIconSpec? resolve(
    String? key, {
    required BusinessIconType type,
    String? style,
  }) {
    return styleFor(type, style)?.icons[key?.trim()];
  }

  List<BusinessIconSpec> search({
    required BusinessIconType type,
    required BusinessIconUsage usage,
    String? style,
    String query = '',
  }) {
    final needle = query.trim().toLowerCase();
    return List.unmodifiable(
      (styleFor(type, style)?.icons.values ?? const <BusinessIconSpec>[]).where(
        (icon) =>
            icon.usage == usage &&
            (needle.isEmpty ||
                [
                  icon.iconKey,
                  icon.label,
                  ...icon.keywords,
                ].any((value) => value.toLowerCase().contains(needle))),
      ),
    );
  }

  static Future<Map<String, dynamic>> _readJson(
    AssetBundle bundle,
    String path,
  ) async => jsonDecode(await bundle.loadString(path)) as Map<String, dynamic>;

  static String _identifier(Object? value) {
    if (value is! String || !RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(value)) {
      throw FormatException('Invalid icon identifier: $value');
    }
    return value;
  }

  static BusinessIconColor _color(Object? value) => switch (value) {
    null || 'original' => BusinessIconColor.original,
    'foreground' => BusinessIconColor.foreground,
    'primary' => BusinessIconColor.primary,
    _ => throw FormatException('Invalid icon color mode: $value'),
  };
}
