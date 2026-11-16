import '../import/import_models.dart' show ImportCategoryKind;
import 'recognition_rule_target.dart';
import 'recognition_rule.dart';
import 'recognition_rule_catalog.dart';
import 'settlement_account_aliases.dart';

/// Resolves caller-prepared account and category text against one target snapshot.
/// Source mappings and target creation belong to the caller's workflow.
class IntakeTargetResolver {
  IntakeTargetResolver({
    required RecognitionRuleCatalog rules,
    required List<RecognitionRuleTarget> targets,
  }) : _rules = rules.withTargets(targets),
       _targets = List.unmodifiable(targets);

  final RecognitionRuleCatalog _rules;
  final List<RecognitionRuleTarget> _targets;

  String? resolveAccount({
    required String matchingText,
    String? accountName,
    RecognitionRuleSource? source,
  }) {
    final exact = matchSettlementAccountName(accountName, _targets);
    if (exact != null) return exact;
    final rule = _rules.match(
      text: matchingText,
      kind: RecognitionRuleKind.account,
      source: source,
    );
    if (rule?.targetAccountId != null) return rule!.targetAccountId;
    return matchSettlementAccountAlias(accountName, _targets, source: source);
  }

  RecognitionRuleMatch? resolveCategory({
    required String matchingText,
    required ImportCategoryKind direction,
    RecognitionRuleSource? source,
  }) =>
      _rules.match(text: matchingText, categoryKind: direction, source: source);
}

String? resolveRecognitionRuleTarget({
  required RecognitionRuleMatch match,
  required List<RecognitionRuleTarget> targets,
  required RecognitionRuleKind kind,
  required ImportCategoryKind direction,
}) {
  if (match.isFallback && match.targetAccountId == null) return null;
  final available = targets
      .where(
        (target) =>
            target.kind == kind &&
            (kind == RecognitionRuleKind.account ||
                target.direction == direction),
      )
      .toList();
  final id = match.targetAccountId;
  if (id != null) {
    return available.any((target) => target.id == id) ? id : null;
  }
  if (match.path.isEmpty) return null;
  final normalized = match.path.map(normalizeRecognitionText).join('/');
  var matches = available
      .where(
        (target) =>
            target.path.map(normalizeRecognitionText).join('/') == normalized,
      )
      .toList();
  if (matches.length == 1) return matches.single.id;
  return null;
}

String? matchSettlementAccountName(
  String? paymentMethod,
  List<RecognitionRuleTarget> targets,
) {
  if (paymentMethod == null) return null;
  final method = normalizeRecognitionText(paymentMethod);
  final available = targets
      .where((target) => target.kind == RecognitionRuleKind.account)
      .toList();
  final matches = available
      .where((target) => normalizeRecognitionText(target.name) == method)
      .toList();
  return matches.firstOrNull?.id;
}
