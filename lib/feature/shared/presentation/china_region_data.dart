import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../design_system/widget/app_region_picker.dart';

Future<List<AppRegionNode>> loadChinaRegions({AssetBundle? bundle}) {
  return (bundle ?? rootBundle).loadStructuredData<List<AppRegionNode>>(
    'assets/regions/china_regions.json',
    (text) async {
      final data = jsonDecode(text) as Map<String, dynamic>;
      return List.unmodifiable(
        _nodes(data['provinces'] as List<dynamic>).map(_withMunicipalityCity),
      );
    },
  );
}

AppRegionSelection? findChinaRegionCitySelection({
  required List<AppRegionNode> regions,
  required String label,
}) {
  final names = label.split('/').map((name) => name.trim()).toList();
  if (names.length != 2 || names.any((name) => name.isEmpty)) return null;
  final path = <AppRegionNode>[];
  var nodes = regions;
  for (final name in names) {
    final node = nodes.where((node) => node.name == name).firstOrNull;
    if (node == null) return null;
    path.add(node);
    nodes = node.children;
  }
  return AppRegionSelection(path);
}

AppRegionNode _withMunicipalityCity(AppRegionNode province) {
  const municipalities = {'110000', '120000', '310000', '500000'};
  if (!municipalities.contains(province.code) ||
      province.children.any((node) => node.children.isNotEmpty)) {
    return province;
  }
  // The source places municipality districts directly under the province.
  return AppRegionNode(
    code: province.code,
    name: province.name,
    children: List.unmodifiable([
      AppRegionNode(
        code: '${province.code.substring(0, 2)}0100',
        name: province.name,
        children: province.children,
      ),
    ]),
  );
}

List<AppRegionNode> _nodes(List<dynamic> items) => [
  for (final item in items)
    AppRegionNode(
      code: item['code'] as String,
      name: item['name'] as String,
      children: List.unmodifiable(
        _nodes(item['children'] as List<dynamic>? ?? const []),
      ),
    ),
];
