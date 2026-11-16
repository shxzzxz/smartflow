import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/app/recognition_rules_provider.dart';
import 'package:smartflow/application/intake/intake_rules_api.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/database_provider.dart';
import 'package:smartflow/infrastructure/intake/rules/drift_recognition_rule_repository.dart';
import 'package:smartflow/infrastructure/intake/rules/recognition_rule_catalog_loader.dart';

import '../../../helper/test_app_database.dart';

void main() {
  final builtins = RecognitionRuleCatalogLoader.decode(
    File(RecognitionRuleCatalogLoader.assetPath).readAsStringSync(),
  );
  late AppDatabase database;
  late ProviderContainer container;
  late RecognitionRulesAppService service;

  setUp(() {
    database = createTestDatabase();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        builtinRecognitionRuleCatalogProvider.overrideWithValue(builtins),
      ],
    );
    service = container.read(recognitionRulesAppServiceProvider);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test(
    'shared database initialization and rule edits retain both edits',
    () async {
      final tea = await (database.select(
        database.accounts,
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
        database,
      ).loadConfiguration();
      expect(configuration.targetBindings['expense_food_tea'], tea.id);
      expect(
        configuration.overrides.map((rule) => rule.id),
        containsAll([first.id, second.id]),
      );
    },
  );
}
