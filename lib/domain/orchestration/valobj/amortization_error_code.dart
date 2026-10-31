import '../../../core/error/app_error_code.dart';

enum AmortizationErrorCode implements AppErrorCode {
  planNotFound(
    code: 'orchestration.amortization.plan_not_found',
    defaultMessage: '摊销计划不存在。',
  ),
  invalidCommand(
    code: 'orchestration.amortization.invalid_command',
    defaultMessage: '摊销计划参数不完整或不合法。',
  ),
  planTerminated(
    code: 'orchestration.amortization.plan_terminated',
    defaultMessage: '摊销计划已经终止。',
  ),
  refundExceedsRemaining(
    code: 'orchestration.amortization.refund_exceeds_remaining',
    defaultMessage: '退款金额不能超过当前未确认余额。',
  );

  const AmortizationErrorCode({
    required this.code,
    required this.defaultMessage,
  });

  @override
  final String code;

  @override
  final String defaultMessage;
}
