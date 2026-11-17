import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/app/recognition_rules_provider.dart';
import 'package:smartflow/application/intake/intake_recognition_api.dart';
import 'package:smartflow/application/intake/intake_rules_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/intake/rules/port/recognition_rule_target_query.dart';
import 'package:smartflow/domain/intake/rules/recognition_rule_configuration.dart';
import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/database_provider.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/intake/rules/drift_recognition_rule_repository.dart';
import 'package:smartflow/infrastructure/intake/rules/recognition_rule_catalog_loader.dart';

import '../../../helper/test_app_database.dart';

void main() {
  final builtins = RecognitionRuleCatalogLoader.decode(
    File(RecognitionRuleCatalogLoader.assetPath).readAsStringSync(),
  );
  late AppDatabase database;
  late DriftRecognitionRuleRepository repository;
  late _Targets targets;
  late RecognitionRulesAppService service;

  setUp(() {
    database = createTestDatabase();
    repository = DriftRecognitionRuleRepository(database);
    targets = _Targets();
    service = RecognitionRulesAppService(
      builtins: builtins,
      repository: repository,
      targets: targets,
      transactions: DriftTransactionRunner(database),
      ids: _Ids(),
    );
  });
  tearDown(() => database.close());

  RecognitionRule custom(String keyword, {String target = 'drinks'}) => service
      .newRule(RecognitionRuleKind.category)
      .copyWith(keywords: [keyword], targetAccountId: target);

  Future<void> store(Map<String, Object?> value) => database
      .into(database.appMetadata)
      .insertOnConflictUpdate(
        AppMetadataCompanion.insert(
          key: DriftRecognitionRuleRepository.storageKey,
          value: jsonEncode(value),
        ),
      );

  test(
    'builtin deletion survives reload and leaves other edits and order intact',
    () async {
      final original = (await service.loadCatalog()).rules.firstWhere(
        (rule) => rule.id == 'expense_food_tea',
      );
      await service.save(original.copyWith(keywords: ['我的咖啡店']));
      final mine = custom('常用饮料');
      await service.save(mine);
      await service.setEnabled(original.id, false);
      await service.moveToTop(original.id);
      final before = await service.loadCatalog();
      expect(before.rules.first.id, original.id);
      expect(before.rules.first.enabled, isFalse);
      expect(before.rules.first.keywords, ['我的咖啡店']);
      final others = before.rules
          .where((rule) => rule.id != original.id)
          .map((rule) => rule.id)
          .toList();
      await service.delete(original.id);
      final reloaded = await service.loadCatalog();
      expect(reloaded.rules.map((rule) => rule.id), others);
      expect(
        (await repository.loadConfiguration()).deletedRuleIds,
        contains(original.id),
      );
      expect(reloaded.rules.any((rule) => rule.id == original.id), isFalse);
      expect(reloaded.rules.first.keywords, ['常用饮料']);
    },
  );

  test('simultaneous independent saves retain both rules', () async {
    final a = custom('规则一');
    final b = custom('规则二');
    await Future.wait([service.save(a), service.save(b)]);
    expect(
      (await repository.loadConfiguration()).overrides
          .map((rule) => rule.id)
          .toSet(),
      {a.id, b.id},
    );
  });

  test('drag reorder and move to top persist within one kind', () async {
    final a = custom('瑞幸');
    final b = custom('瑞幸', target: 'other-drinks');
    final account = service
        .newRule(RecognitionRuleKind.account)
        .copyWith(keywords: ['6620'], targetAccountId: 'wallet');
    await service.save(a);
    await service.save(account);
    await service.save(b);
    expect(
      (await service.loadCatalog()).match(text: '瑞幸')!.targetAccountId,
      'other-drinks',
    );
    final accountOrder = (await service.loadCatalog()).rules
        .where((rule) => rule.kind == RecognitionRuleKind.account)
        .map((rule) => rule.id)
        .toList();
    await service.reorder(b.id, 1);
    expect(
      (await service.loadCatalog()).match(text: '瑞幸')!.targetAccountId,
      'drinks',
    );
    await service.moveToTop(b.id);
    final reloaded = await service.loadCatalog();
    expect(reloaded.match(text: '瑞幸')!.targetAccountId, 'other-drinks');
    expect(
      reloaded.rules
          .where((rule) => rule.kind == RecognitionRuleKind.account)
          .map((rule) => rule.id),
      accountOrder,
    );
    await service.setEnabled(b.id, false);
    expect(
      (await service.loadCatalog()).match(text: '瑞幸')!.targetAccountId,
      'drinks',
    );
  });

  test('category nature comes from the chosen target', () async {
    await service.save(custom('工资', target: 'salary'));
    final saved = (await repository.loadConfiguration()).overrides.single;
    expect(saved.targetCategoryKind, ImportCategoryKind.income);
    expect(saved.toJson().keys, isNot(contains('direction')));
    expect(
      (await service.loadCatalog())
          .match(text: '工资', categoryKind: ImportCategoryKind.income)!
          .targetAccountId,
      'salary',
    );
  });

  test(
    'invalid or unconfigured targets cannot change stored settings',
    () async {
      await expectLater(
        service.save(custom('失效规则', target: 'missing')),
        throwsA(
          isA<BusinessException>().having(
            (error) => error.code,
            'code',
            'intake.recognition_rule.target_unavailable',
          ),
        ),
      );
      final original = builtins.rules.firstWhere(
        (rule) => rule.id == 'expense_food_tea',
      );
      await expectLater(
        service.save(original),
        throwsA(isA<BusinessException>()),
      );
      final configuration = await repository.loadConfiguration();
      expect(configuration.overrides, isEmpty);
      expect(configuration.targetBindings, isEmpty);
    },
  );

  test(
    'deleted targets are skipped so the next matching rule can win',
    () async {
      final valid = custom('瑞幸', target: 'food');
      final invalid = custom('瑞幸');
      await service.save(valid);
      await service.save(invalid);
      targets.items.removeWhere((target) => target.id == 'drinks');
      final catalog = await service.loadCatalog();
      expect(catalog.rules.first.id, invalid.id);
      expect(
        catalog
            .match(text: '瑞幸', categoryKind: ImportCategoryKind.expense)!
            .targetAccountId,
        'food',
      );
    },
  );

  test(
    'a missing child does not fall back to its parent or a later namesake',
    () async {
      await service.loadCatalog();
      targets.items.removeWhere((target) => target.id == 'drinks');
      targets.items.add(_category('new-drinks', ['食品餐饮', '茶饮']));
      final mapping = await service.resolvePayment(_payment(text: '瑞幸'));
      expect(mapping.categoryId, 'expense-other');
      final rule = (await service.loadCatalog()).rules.firstWhere(
        (rule) => rule.id == 'expense_food_tea',
      );
      expect(rule.targetAccountId, 'drinks');
      await service.save(rule.copyWith(targetAccountId: 'new-drinks'));
      expect(
        (await service.resolvePayment(_payment(text: '瑞幸'))).categoryId,
        'new-drinks',
      );
    },
  );

  test(
    'initially absent targets stay unconfigured when a same-name category appears',
    () async {
      await service.loadCatalog();
      expect(
        (await repository.loadConfiguration())
            .targetBindings['expense_personal_care'],
        isNull,
      );
      targets.items.add(_category('home', ['居家生活']));
      targets.items.add(_category('haircut', ['居家生活', '理发']));
      final mapping = await service.resolvePayment(_payment(text: '理发'));
      expect(mapping.categoryId, 'expense-other');
    },
  );

  test(
    'bound default and fallback categories keep working after renaming',
    () async {
      await service.loadCatalog();
      targets.items = [
        for (final target in targets.items)
          if (target.id == 'drinks')
            _category('drinks', ['餐食', '饮料'])
          else if (target.id == 'expense-other')
            _category('expense-other', ['剩余支出'])
          else
            target,
      ];
      expect(
        (await service.resolvePayment(_payment(text: '瑞幸'))).categoryId,
        'drinks',
      );
      expect(
        (await service.resolvePayment(_payment(text: '未识别商户'))).categoryId,
        'expense-other',
      );
    },
  );

  test(
    'source-scoped rules remain configured for imports but do not map screenshots',
    () async {
      final cases = [
        (RecognitionRuleSource.wechat, 'wechat-wallet', 'drinks'),
        (RecognitionRuleSource.alipay, 'alipay-wallet', 'other-drinks'),
      ];
      await service.save(custom('来源隔离分类', target: 'food'));
      await service.save(
        service
            .newRule(RecognitionRuleKind.account)
            .copyWith(keywords: ['来源隔离付款'], targetAccountId: 'wallet'),
      );
      for (final entry in cases) {
        targets.items.add(_account(entry.$2, '指定来源账户'));
        await service.save(
          custom('来源隔离分类', target: entry.$3).copyWith(source: entry.$1),
        );
        await service.save(
          service
              .newRule(RecognitionRuleKind.account)
              .copyWith(
                keywords: ['来源隔离付款'],
                targetAccountId: entry.$2,
                source: entry.$1,
              ),
        );
      }

      final mapping = await service.resolvePayment(
        _payment(text: '来源隔离分类', method: '来源隔离付款'),
      );
      expect(mapping.categoryId, 'food');
      expect(mapping.settlementAccountId, 'wallet');

      final catalog = await service.loadCatalog();
      for (final entry in cases) {
        expect(
          catalog
              .match(
                text: '来源隔离分类',
                source: entry.$1,
                categoryKind: ImportCategoryKind.expense,
              )!
              .targetAccountId,
          entry.$3,
        );
        expect(
          catalog
              .match(
                text: '来源隔离付款',
                kind: RecognitionRuleKind.account,
                source: entry.$1,
              )!
              .targetAccountId,
          entry.$2,
        );
      }
      final retained = (await service.loadData()).rules.where(
        (rule) =>
            rule.source != null &&
            rule.keywords.any((keyword) => keyword.startsWith('来源隔离')),
      );
      expect(retained, hasLength(4));
    },
  );

  test(
    'transfer sides use separate reliable account text and user rules',
    () async {
      targets.items.add(_account('destination', '收款储蓄卡'));
      for (final entry in [
        ('零钱通', 'wallet'),
        ('7641', 'destination'),
        ('转出金额', 'wallet'),
      ]) {
        await service.save(
          service
              .newRule(RecognitionRuleKind.account)
              .copyWith(keywords: [entry.$1], targetAccountId: entry.$2),
        );
      }
      final payment = RecognizedPayment(
        scene: PaymentScreenshotScene.transfer,
        amount: Money.parse('465.75'),
        transferFromAccount: '零钱通',
        transferToAccount: '建设银行(7641)',
        accountMatchingText: '转出金额 零钱通 建设银行(7641)',
      );
      final mapping = await service.resolveTransfer(payment);
      expect(mapping.fromAccountId, 'wallet');
      expect(mapping.toAccountId, 'destination');
      final ordinary = await service.resolvePayment(payment);
      expect(ordinary.settlementAccountId, isNull);
      expect(ordinary.categoryId, isNull);
    },
  );

  test(
    'transfer suggestions skip nonfund targets and unreliable clues',
    () async {
      targets.items.insertAll(0, [
        _account('credit', '建设银行信用卡', isFundAccount: false),
        _account('bank', '建行储蓄卡'),
      ]);
      await service.save(
        service
            .newRule(RecognitionRuleKind.account)
            .copyWith(keywords: ['7641'], targetAccountId: 'credit'),
      );
      for (final reliable in [true, false]) {
        final mapping = await service.resolveTransfer(
          RecognizedPayment(
            scene: PaymentScreenshotScene.transfer,
            amount: Money.parse('465.75'),
            transferFromAccount: '零钱通',
            transferFromAccountReliable: false,
            transferToAccount: '建设银行(7641)',
            transferToAccountReliable: reliable,
            accountMatchingText: '日常付款 建设银行(7641)',
          ),
        );
        expect(mapping.fromAccountId, isNull);
        expect(mapping.toAccountId, reliable ? 'bank' : null);
      }
    },
  );

  test('exact account names precede rules and rules precede aliases', () async {
    targets.items.insertAll(0, [
      _account('postal-first', '邮储620'),
      _account('postal-second', '中国邮政储蓄银行'),
      _account('exact', 'ＡＢＣ（6620）'),
    ]);
    final account = service
        .newRule(RecognitionRuleKind.account)
        .copyWith(keywords: ['6620'], targetAccountId: 'wallet');
    await service.save(account);
    final exact = await service.resolvePayment(
      _payment(method: ' a b c (6620) '),
    );
    expect(exact.settlementAccountId, 'exact');
    final configured = await service.resolvePayment(
      _payment(method: '邮储银行储蓄卡（6620）'),
    );
    expect(configured.settlementAccountId, 'wallet');
    await service.setEnabled(account.id, false);
    final alias = await service.resolvePayment(
      _payment(method: '邮储银行储蓄卡（6620）'),
    );
    expect(alias.settlementAccountId, 'postal-first');
  });

  test(
    'unknown account names stay empty until an explicit account rule matches',
    () async {
      targets.items.add(_account('suffix', '工资卡1234'));
      final mapping = await service.resolvePayment(
        _payment(method: '银行卡（1234）', text: '瑞幸'),
      );
      expect(mapping.categoryId, 'drinks');
      expect(mapping.settlementAccountId, isNull);
      await service.save(
        service
            .newRule(RecognitionRuleKind.account)
            .copyWith(keywords: ['1234'], targetAccountId: 'wallet'),
      );
      expect(
        (await service.resolvePayment(
          _payment(method: '银行卡（1234）', text: '瑞幸'),
        )).settlementAccountId,
        'wallet',
      );
    },
  );

  test('different wallet products leave unmatched accounts empty', () async {
    targets.items.insert(0, _account('wechat', '微信零钱'));
    targets.items.insert(1, _account('alipay', '支付宝余额'));
    for (final method in ['零钱通', '微信零钱通', '余额宝', '支付宝余额宝']) {
      expect(
        (await service.resolvePayment(
          _payment(method: method, text: '瑞幸'),
        )).settlementAccountId,
        isNull,
        reason: method,
      );
    }
  });

  test(
    'category text follows keyword rules and direction isolates fallback',
    () async {
      await service.save(custom('奶茶', target: 'other-drinks'));
      final mapping = await service.resolvePayment(
        _payment(text: '奶茶', categoryName: ' 茶饮 '),
      );
      expect(mapping.categoryId, 'other-drinks');
      final income = await service.resolvePayment(
        _payment(
          text: '不明收入',
          categoryName: '茶饮',
          direction: RecognizedPaymentDirection.income,
        ),
      );
      expect(income.categoryId, 'income-other');
    },
  );

  test(
    'missing other categories remain empty instead of being recreated',
    () async {
      await service.loadCatalog();
      targets.items.removeWhere((target) => target.id == 'expense-other');
      targets.items.add(_category('new-other', ['其他']));
      final mapping = await service.resolvePayment(_payment(text: '不明消费'));
      expect(mapping.categoryId, isNull);
      expect(mapping.settlementAccountId, isNull);
    },
  );

  for (final version in [1, 2]) {
    test(
      'version $version settings retain account edits, scope, disabled state and order',
      () async {
        await store({
          'version': version,
          if (version == 2) 'order': ['account_wechat_change', 'legacy-custom'],
          'rules': [
            {
              'id': 'account_wechat_change',
              'kind': 'account',
              'keywords': ['迁移零钱'],
              'priority': 200,
              'targetAccountId': 'wallet',
              'targetPath': ['旧账户名'],
              'source': 'wechat',
              'enabled': false,
            },
            {
              'id': 'legacy-custom',
              'kind': 'category',
              'direction': 'income',
              'keywords': ['工资'],
              'priority': 200,
              'targetAccountId': 'salary',
              'targetPath': ['旧分类名'],
            },
          ],
        });
        final migrated = await service.loadCatalog();
        final account = migrated.rules.first;
        expect(account.id, 'account_wechat_change');
        expect(account.kind, RecognitionRuleKind.account);
        expect(account.isBuiltin, isFalse);
        expect(account.enabled, isFalse);
        expect(account.source, RecognitionRuleSource.wechat);
        expect(account.targetAccountId, 'wallet');
        expect(account.keywords, ['迁移零钱']);
        expect(migrated.rules[1].id, 'legacy-custom');
        final encoded =
            jsonDecode(
                  (await (database.select(database.appMetadata)..where(
                            (row) => row.key.equals(
                              DriftRecognitionRuleRepository.storageKey,
                            ),
                          ))
                          .getSingle())
                      .value,
                )
                as Map;
        expect(encoded['version'], 3);
        expect(encoded['order'].take(2), [
          'account_wechat_change',
          'legacy-custom',
        ]);
        expect(encoded['targetBindings']['legacy-custom'], 'salary');
        expect((await repository.loadConfiguration()).overrides, hasLength(2));
      },
    );
  }

  test(
    'backup restores edits, order, target bindings and builtin deletion',
    () async {
      final mine = custom('我的饮料');
      await service.save(mine);
      await service.reorder(mine.id, 1);
      await service.delete('expense_food_tea');
      final before = await service.loadCatalog();
      final previous = await repository.loadConfiguration();
      final gateway = DriftBackupGateway(database);
      final backup = await gateway.readSnapshot();
      expect(
        backup.preferences,
        contains(DriftRecognitionRuleRepository.storageKey),
      );
      await repository.saveConfiguration(
        const RecognitionRuleConfiguration(order: []),
      );
      await gateway.replaceSnapshot(backup);
      final restored = await repository.loadConfiguration();
      expect(restored.targetBindings, previous.targetBindings);
      expect(restored.deletedRuleIds, previous.deletedRuleIds);
      expect(restored.overrides.single.targetAccountId, 'drinks');
      expect(
        (await service.loadCatalog()).rules.map((rule) => rule.id),
        before.rules.map((rule) => rule.id),
      );
    },
  );

  test(
    'real ledger target queries preserve identity across deletion and recreation',
    () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          builtinRecognitionRuleCatalogProvider.overrideWithValue(builtins),
        ],
      );
      addTearDown(container.dispose);
      final actual = container.read(recognitionRulesAppServiceProvider);
      final data = await actual.loadData();
      final tea = data.targets.firstWhere(
        (target) => target.path.join('/') == '食品餐饮/茶饮',
      );
      final food = data.targets.firstWhere(
        (target) => target.path.join('/') == '食品餐饮',
      );
      final other = data.targets.firstWhere(
        (target) =>
            target.direction == ImportCategoryKind.expense &&
            target.name == '其他',
      );
      await (database.delete(
        database.accounts,
      )..where((row) => row.id.equals(tea.id))).go();
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'recreated-tea',
              name: '茶饮',
              accountType: AccountType.expense,
              parentId: Value(food.id),
            ),
          );
      expect(
        (await actual.resolvePayment(_payment(text: '瑞幸'))).categoryId,
        other.id,
      );
      final bound = (await actual.loadCatalog()).rules.firstWhere(
        (rule) => rule.id == 'expense_food_tea',
      );
      expect(bound.targetAccountId, tea.id);
      await actual.save(bound.copyWith(targetAccountId: 'recreated-tea'));
      expect(
        (await actual.resolvePayment(_payment(text: '瑞幸'))).categoryId,
        'recreated-tea',
      );
    },
  );

  test(
    'malformed version-three settings expose safe configuration errors',
    () async {
      for (final value in [
        '{"version":1,"rules":"invalid private configuration"}',
        '{"version":2,"rules":[],"order":["duplicate","duplicate"]}',
        '{"version":3,"rules":[],"order":[],"targetBindings":{"x":42},"deletedRuleIds":[]}',
        '{"version":3,"rules":[],"order":[],"targetBindings":{},"deletedRuleIds":["x","x"]}',
      ]) {
        await database
            .into(database.appMetadata)
            .insertOnConflictUpdate(
              AppMetadataCompanion.insert(
                key: DriftRecognitionRuleRepository.storageKey,
                value: value,
              ),
            );
        await expectLater(
          repository.loadConfiguration(),
          throwsA(
            isA<InfrastructureException>()
                .having(
                  (error) => error.code,
                  'code',
                  'intake.recognition_rule.configuration_unavailable',
                )
                .having(
                  (error) => error.message,
                  'message',
                  isNot(contains('private')),
                ),
          ),
        );
      }
    },
  );
}

RecognizedPayment _payment({
  String? method,
  String text = '未识别商户',
  String? categoryName,
  RecognizedPaymentDirection direction = RecognizedPaymentDirection.expense,
}) => RecognizedPayment(
  direction: direction,
  amount: Money.parse('12.35'),
  paymentMethod: method,
  accountMatchingText: method ?? '',
  categoryName: categoryName,
  categoryMatchingText: categoryName == null ? text : '$categoryName $text',
);

RecognitionRuleTarget _account(
  String id,
  String name, {
  bool isFundAccount = true,
}) => RecognitionRuleTarget(
  id: id,
  kind: RecognitionRuleKind.account,
  path: [name],
  isFundAccount: isFundAccount,
);
RecognitionRuleTarget _category(
  String id,
  List<String> path, {
  ImportCategoryKind direction = ImportCategoryKind.expense,
}) => RecognitionRuleTarget(
  id: id,
  kind: RecognitionRuleKind.category,
  direction: direction,
  path: path,
);

class _Targets implements RecognitionRuleTargetQuery {
  List<RecognitionRuleTarget> items = [
    _account('wallet', '日常付款'),
    _category('food', ['食品餐饮']),
    _category('drinks', ['食品餐饮', '茶饮']),
    _category('other-drinks', ['其他饮料']),
    _category('expense-other', ['其他']),
    _category('income-other', ['其他'], direction: ImportCategoryKind.income),
    _category('salary', ['工作', '工资'], direction: ImportCategoryKind.income),
  ];
  @override
  Future<List<RecognitionRuleTarget>> findAvailableTargets() async => [
    ...items,
  ];
}

class _Ids implements IdGenerator {
  int _next = 0;
  @override
  String newId() => 'rule-${++_next}';
}
