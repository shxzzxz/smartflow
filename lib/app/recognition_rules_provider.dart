import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/intake/rules/command/recognition_rules_app_service.dart';
import '../infrastructure/database/database_provider.dart';
import '../infrastructure/intake/rules/drift_recognition_rule_repository.dart';
import '../infrastructure/intake/rules/ledger_recognition_rule_target_query.dart';
import 'provider.dart';

final recognitionRulesAppServiceProvider = Provider<RecognitionRulesAppService>(
  (ref) => RecognitionRulesAppService(
    builtins: ref.watch(builtinRecognitionRuleCatalogProvider),
    repository: DriftRecognitionRuleRepository(ref.watch(appDatabaseProvider)),
    targets: LedgerRecognitionRuleTargetQuery(
      accounts: ref.watch(accountQueryServiceProvider),
      categories: ref.watch(categoryQueryServiceProvider),
    ),
    transactions: ref.watch(transactionRunnerProvider),
    ids: ref.watch(idGeneratorProvider),
  ),
);
