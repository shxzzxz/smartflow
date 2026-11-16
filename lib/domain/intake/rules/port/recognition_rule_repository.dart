import '../recognition_rule_configuration.dart';

/// Stores only user rules and overrides of stable builtin rule identities.
abstract interface class RecognitionRuleRepository {
  Future<RecognitionRuleConfiguration> loadConfiguration();

  Future<void> saveConfiguration(RecognitionRuleConfiguration configuration);
}
