import 'recognition_rule.dart';

/// User edits and execution order are independent of builtin rule identities.
class RecognitionRuleConfiguration {
  const RecognitionRuleConfiguration({
    this.overrides = const [],
    this.order,
    this.targetBindings = const {},
    this.deletedRuleIds = const {},
  });
  final List<RecognitionRule> overrides;

  /// Null denotes a legacy configuration ordered by its numeric priorities.
  final List<String>? order;

  /// Null records an unavailable target so a later namesake is not rebound.
  final Map<String, String?> targetBindings;
  final Set<String> deletedRuleIds;
}
