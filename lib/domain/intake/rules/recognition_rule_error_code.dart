import '../../../core/error/app_error_code.dart';

enum RecognitionRuleErrorCode implements AppErrorCode {
  invalidRule('intake.recognition_rule.invalid', '请完善关键词和目标。'),
  targetUnavailable(
    'intake.recognition_rule.target_unavailable',
    '目标已不可用，请重新选择账户或分类。',
  ),
  configurationUnavailable(
    'intake.recognition_rule.configuration_unavailable',
    '无法读取识别规则，请检查数据或恢复备份。',
  );

  const RecognitionRuleErrorCode(this.code, this.defaultMessage);

  @override
  final String code;
  @override
  final String defaultMessage;
}
