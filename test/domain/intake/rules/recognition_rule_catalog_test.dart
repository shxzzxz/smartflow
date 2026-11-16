import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/intake/import/import_models.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule_target.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule_catalog.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule_configuration.dart';
import 'package:smartflow/domain/intake/rules/recognition_target_resolution.dart';
import 'package:smartflow/infrastructure/intake/rules/recognition_rule_catalog_loader.dart';

void main() {
  final builtins = RecognitionRuleCatalogLoader.decode(
    File(RecognitionRuleCatalogLoader.assetPath).readAsStringSync(),
  );
  test(
    'builtin category keywords are shared across known and unknown sources',
    () {
      for (final source in [...RecognitionRuleSource.values, null]) {
        final match = builtins.match(
          text: '瑞幸咖啡',
          categoryKind: ImportCategoryKind.expense,
          source: source,
        );
        expect(match!.path, ['食品餐饮', '茶饮']);
        expect(match.isFallback, isFalse);
      }
      expect(
        builtins.rules.map((r) => r.priority).toSet(),
        hasLength(builtins.rules.length),
      );
    },
  );

  test(
    'account rules are user-configured and scoped to the recognized source',
    () {
      expect(
        builtins.rules.every(
          (rule) => rule.kind == RecognitionRuleKind.category,
        ),
        isTrue,
      );
      expect(
        builtins.match(text: '零钱', kind: RecognitionRuleKind.account),
        isNull,
      );
      final accounts = RecognitionRuleCatalog(
        rules: [
          RecognitionRule(
            id: 'user-account',
            kind: RecognitionRuleKind.account,
            keywords: const ['零钱'],
            priority: 1,
            source: RecognitionRuleSource.wechat,
            targetAccountId: 'wallet',
            targetPath: const ['日常付款'],
          ),
        ],
      );
      expect(
        accounts
            .match(
              text: '零钱',
              kind: RecognitionRuleKind.account,
              source: RecognitionRuleSource.wechat,
            )!
            .targetAccountId,
        'wallet',
      );
      for (final source in [RecognitionRuleSource.alipay, null]) {
        expect(
          accounts.match(
            text: '零钱',
            kind: RecognitionRuleKind.account,
            source: source,
          ),
          isNull,
        );
      }
    },
  );

  test('builtin keywords classify probable meals and specific expenses', () {
    final examples = <String, List<String>>{
      '豆浆': ['食品餐饮', '早餐'],
      '油条': ['食品餐饮', '早餐'],
      '烤鱼': ['食品餐饮'],
      '拉面': ['食品餐饮'],
      '包子': ['食品餐饮'],
      '午饭': ['食品餐饮', '午餐'],
      '晚饭': ['食品餐饮', '晚餐'],
      '理发': ['居家生活', '理发'],
      '美容': ['居家生活', '美容'],
      '地铁': ['出行交通', '地铁'],
      '公交车': ['出行交通', '公交'],
      '电影票': ['休闲娱乐', '电影'],
      '桌游': ['休闲娱乐', '棋牌桌游'],
      '手机充值': ['通讯'],
      '超市洗衣液': ['购物消费', '日用品'],
    };
    for (final entry in examples.entries) {
      expect(
        builtins
            .match(text: entry.key, categoryKind: ImportCategoryKind.expense)!
            .path,
        entry.value,
        reason: entry.key,
      );
    }
    for (final product in ['基金', '股票', '余额宝', '零钱通']) {
      expect(
        builtins
            .match(text: product, categoryKind: ImportCategoryKind.income)!
            .isFallback,
        isTrue,
      );
    }
    expect(
      builtins.match(text: '分红', categoryKind: ImportCategoryKind.income)!.path,
      ['投资收益'],
    );
  });

  test(
    'a strict stable order resolves legacy equal scores without conflicts',
    () {
      final catalog = builtins.withOverrides([
        _rule('a', 'drinks'),
        _rule('b', 'other'),
      ]);
      final match = catalog.match(
        text: '瑞幸',
        categoryKind: ImportCategoryKind.expense,
      )!;
      expect(match.targetAccountId, 'drinks');
      expect(match.isFallback, isFalse);
      expect(
        catalog.rules.map((rule) => rule.priority).toSet(),
        hasLength(catalog.rules.length),
      );
      final reversed = builtins.withConfiguration(
        catalog.configurationFor([
          catalog.rules.firstWhere((r) => r.id == 'b'),
          ...catalog.rules.where((r) => r.id != 'b'),
        ]),
      );
      expect(reversed.match(text: '瑞幸')!.targetAccountId, 'other');
    },
  );

  test('source scope filters rules without adding precedence', () {
    final catalog = RecognitionRuleCatalog(
      rules: [
        _rule('all', 'general'),
        _rule(
          'wechat',
          'specific',
        ).copyWith(source: RecognitionRuleSource.wechat),
      ],
    );
    expect(
      catalog.match(text: '瑞幸', source: RecognitionRuleSource.wechat)!.ruleId,
      'all',
    );
    final specificFirst = catalog.withConfiguration(
      RecognitionRuleConfiguration(order: const ['wechat', 'all']),
    );
    expect(
      specificFirst
          .match(text: '瑞幸', source: RecognitionRuleSource.wechat)!
          .ruleId,
      'wechat',
    );
    expect(specificFirst.match(text: '瑞幸')!.ruleId, 'all');
    expect(
      specificFirst
          .match(text: '瑞幸', source: RecognitionRuleSource.alipay)!
          .ruleId,
      'all',
    );
  });

  test(
    'account and category each select their own first match; disabled rules are skipped',
    () {
      final catalog = RecognitionRuleCatalog(
        rules: [
          _rule('category', 'drinks'),
          RecognitionRule(
            id: 'account',
            kind: RecognitionRuleKind.account,
            keywords: const ['瑞幸'],
            priority: 80,
            targetAccountId: 'wallet',
          ),
          _rule('later', 'other').copyWith(priority: 20),
        ],
      );
      expect(catalog.match(text: '瑞幸')!.ruleId, 'category');
      expect(
        catalog.match(text: '瑞幸', kind: RecognitionRuleKind.account)!.ruleId,
        'account',
      );
      final disabled = catalog.withOverrides([
        _rule('category', 'drinks').copyWith(enabled: false),
      ]);
      expect(disabled.match(text: '瑞幸')!.ruleId, 'later');
    },
  );

  test('category target nature stays compatible with the transaction', () {
    final catalog = RecognitionRuleCatalog(
      rules: [
        _rule('expense', 'expense-category'),
        _rule(
          'income',
          'income-category',
        ).copyWith(targetCategoryKind: ImportCategoryKind.income),
      ],
    );
    expect(
      catalog
          .match(text: '瑞幸', categoryKind: ImportCategoryKind.income)!
          .ruleId,
      'income',
    );
    expect(
      catalog
          .match(text: '瑞幸', categoryKind: ImportCategoryKind.expense)!
          .ruleId,
      'expense',
    );
  });

  test(
    'normalization supports full width and spacing without joining distinct rows',
    () {
      final catalog = RecognitionRuleCatalog(
        rules: [
          _rule('coffee', 'drinks').copyWith(keywords: ['COFFEE', '咖啡']),
        ],
      );
      expect(catalog.match(text: 'ＣＯＦＦＥＥ')!.ruleId, 'coffee');
      expect(catalog.match(text: '咖 啡')!.ruleId, 'coffee');
      expect(catalog.match(text: '咖\n啡'), isNull);
    },
  );

  test(
    'inferred source paths remain stable when a bound target is renamed',
    () {
      final catalog = RecognitionRuleCatalog(rules: [_rule('coffee', 'drinks')])
          .withTargets([
            RecognitionRuleTarget(
              id: 'drinks',
              kind: RecognitionRuleKind.category,
              direction: ImportCategoryKind.expense,
              path: ['重命名餐食', '重命名饮料'],
            ),
          ]);
      final matched = catalog.match(
        text: '瑞幸',
        categoryKind: ImportCategoryKind.expense,
      )!;
      expect(matched.path, ['我的分类']);
      expect(matched.targetAccountId, 'drinks');
    },
  );

  test(
    'bound targets survive renaming and never fall back to another identity',
    () {
      const match = RecognitionRuleMatch(
        path: ['食品餐饮', '茶饮'],
        ruleId: 'coffee',
        targetAccountId: 'drinks',
        isFallback: false,
      );
      String? resolve(
        String id,
        ImportCategoryKind direction,
        List<String> path,
      ) => resolveRecognitionRuleTarget(
        match: match,
        kind: RecognitionRuleKind.category,
        direction: ImportCategoryKind.expense,
        targets: [
          RecognitionRuleTarget(
            id: id,
            kind: RecognitionRuleKind.category,
            direction: direction,
            path: path,
          ),
        ],
      );
      expect(
        resolve('drinks', ImportCategoryKind.expense, ['餐食', '饮料']),
        'drinks',
      );
      expect(
        resolve('another', ImportCategoryKind.expense, ['食品餐饮', '茶饮']),
        isNull,
      );
      expect(resolve('drinks', ImportCategoryKind.income, ['收入']), isNull);
    },
  );
}

RecognitionRule _rule(String id, String target) => RecognitionRule(
  id: id,
  kind: RecognitionRuleKind.category,
  targetCategoryKind: ImportCategoryKind.expense,
  keywords: const ['瑞幸'],
  priority: 100,
  targetAccountId: target,
  targetPath: const ['我的分类'],
);
