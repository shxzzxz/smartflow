import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../domain/intake/rules/recognition_rule_catalog.dart';

class RecognitionRuleCatalogLoader {
  const RecognitionRuleCatalogLoader();

  static const assetPath = 'assets/intake/recognition_rules.json';

  Future<RecognitionRuleCatalog> load(AssetBundle bundle) async =>
      decode(await bundle.loadString(assetPath));

  static RecognitionRuleCatalog decode(String source) =>
      RecognitionRuleCatalog.fromJson(
        Map<String, Object?>.from(jsonDecode(source) as Map),
      );
}
