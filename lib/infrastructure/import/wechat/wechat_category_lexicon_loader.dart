import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../domain/import/source/wechat/wechat_category_lexicon.dart';

class WechatCategoryLexiconLoader {
  const WechatCategoryLexiconLoader();

  static const assetPath = 'assets/import/wechat/category_lexicon.json';

  Future<WechatCategoryLexicon> load(AssetBundle bundle) async {
    return decode(await bundle.loadString(assetPath));
  }

  static WechatCategoryLexicon decode(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, Object?>) {
      throw const FormatException('WeChat category lexicon must be an object.');
    }
    return WechatCategoryLexicon.fromJson(json);
  }
}
