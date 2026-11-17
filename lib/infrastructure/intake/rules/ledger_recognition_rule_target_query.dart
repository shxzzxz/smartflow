import '../../../application/ledger/ledger_query_api.dart';
import '../../../domain/intake/import/import_models.dart'
    show ImportCategoryKind;
import '../../../domain/intake/rules/port/recognition_rule_target_query.dart';
import '../../../domain/intake/rules/recognition_rule_target.dart';
import '../../../domain/intake/rules/recognition_rule.dart';
import '../../../shared/account_profile/account_selection_policy.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';

class LedgerRecognitionRuleTargetQuery implements RecognitionRuleTargetQuery {
  const LedgerRecognitionRuleTargetQuery({
    required AccountQueryService accounts,
    required CategoryQueryService categories,
  }) : _accounts = accounts,
       _categories = categories;

  final AccountQueryService _accounts;
  final CategoryQueryService _categories;

  @override
  Future<List<RecognitionRuleTarget>> findAvailableTargets() async {
    final accounts = await _accounts.findAccounts({
      AccountType.asset,
      AccountType.liability,
    });
    final targets = <RecognitionRuleTarget>[
      for (final account in accountsMatchingSelectionPurpose(
        accounts,
        AccountSelectionPurpose.settlement,
      ))
        RecognitionRuleTarget(
          id: account.id,
          kind: RecognitionRuleKind.account,
          path: [account.name],
          iconKey: account.iconKey,
          profileKey: account.profileKey,
          isFundAccount: accountMatchesSelectionPurpose(
            account,
            AccountSelectionPurpose.fund,
          ),
        ),
    ];
    for (final direction in ImportCategoryKind.values) {
      final tree = await _categories.findCategoryTree(
        direction == ImportCategoryKind.expense
            ? AccountType.expense
            : AccountType.income,
      );
      for (final root in tree) {
        targets.add(
          RecognitionRuleTarget(
            id: root.account.id,
            kind: RecognitionRuleKind.category,
            direction: direction,
            path: [root.account.name],
            iconKey: root.account.iconKey,
          ),
        );
        targets.addAll([
          for (final child in root.children)
            RecognitionRuleTarget(
              id: child.id,
              kind: RecognitionRuleKind.category,
              direction: direction,
              path: [root.account.name, child.name],
              parentId: root.account.id,
              iconKey: child.iconKey,
            ),
        ]);
      }
    }
    return targets;
  }
}
