import '../recognition_rule_target.dart';

abstract interface class RecognitionRuleTargetQuery {
  Future<List<RecognitionRuleTarget>> findAvailableTargets();
}
