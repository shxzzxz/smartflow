import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/app/recognition_rules_provider.dart';
import 'package:smartflow/application/intake/intake_recognition_api.dart';
import 'package:smartflow/application/intake/intake_rules_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/database_provider.dart';
import 'package:smartflow/infrastructure/intake/rules/drift_recognition_rule_repository.dart';
import 'package:smartflow/infrastructure/intake/rules/recognition_rule_catalog_loader.dart';

import '../../../helper/database_write_lock.dart';

void main() {
  final builtins = RecognitionRuleCatalogLoader.decode(
    File(RecognitionRuleCatalogLoader.assetPath).readAsStringSync(),
  );
  late Directory directory;
  late AppDatabase writer;
  late AppDatabase reader;
  late ProviderContainer container;
  late RecognitionRulesAppService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'smartflow-recognition-concurrency-',
    );
    final file = File('${directory.path}/ledger.sqlite');
    writer = AppDatabase(NativeDatabase(file));
    reader = AppDatabase(NativeDatabase(file));
    await writer.customSelect('SELECT 1 AS value').getSingle();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(reader),
        builtinRecognitionRuleCatalogProvider.overrideWithValue(builtins),
      ],
    );
    service = container.read(recognitionRulesAppServiceProvider);
  });

  tearDown(() async {
    container.dispose();
    await reader.close();
    await writer.close();
    await directory.delete(recursive: true);
  });

  test(
    'initialized recognition paths remain readable during another write',
    () async {
      final original = await service.loadCatalog();
      final tea = original.rules.firstWhere(
        (rule) => rule.id == 'expense_food_tea',
      );
      await whileDatabaseWriteLocked(writer, () async {
        final loaded = await service.loadCatalog();
        expect(
          loaded.rules.map((rule) => rule.id),
          original.rules.map((rule) => rule.id),
        );
        final data = await service.loadData();
        expect(
          data.rules.map((rule) => rule.id),
          original.rules.map((rule) => rule.id),
        );
        final mapping = await service.resolvePayment(
          RecognizedPayment(
            direction: RecognizedPaymentDirection.expense,
            amount: Money.parse('12.35'),
            categoryMatchingText: '瑞幸',
            accountMatchingText: '',
          ),
        );
        expect(mapping.categoryId, tea.targetAccountId);
      });
    },
  );

  test('concurrent initialization and rule edits retain both edits', () async {
    final tea = await (reader.select(
      reader.accounts,
    )..where((row) => row.name.equals('茶饮'))).getSingle();
    final first = service
        .newRule(RecognitionRuleKind.category)
        .copyWith(keywords: ['并发关键词一'], targetAccountId: tea.id);
    final second = service
        .newRule(RecognitionRuleKind.category)
        .copyWith(keywords: ['并发关键词二'], targetAccountId: tea.id);
    await Future.wait([
      service.loadCatalog().then((_) {}),
      service.save(first),
      service.save(second),
    ]);
    final catalog = await service.loadCatalog();
    expect(
      catalog.rules.map((rule) => rule.id),
      containsAll([first.id, second.id]),
    );
    final configuration = await DriftRecognitionRuleRepository(
      reader,
    ).loadConfiguration();
    expect(configuration.targetBindings['expense_food_tea'], tea.id);
    expect(
      configuration.overrides.map((rule) => rule.id),
      containsAll([first.id, second.id]),
    );
  });
}
