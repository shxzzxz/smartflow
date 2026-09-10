/// 校验并修复后的状态变更汇总，以及仍需处理的数据冲突。
class ContractStatusValidationResult {
  const ContractStatusValidationResult({
    required this.repairedScheduleCount,
    required this.contractStatusChanged,
    this.issues = const [],
  });

  final int repairedScheduleCount;
  final bool contractStatusChanged;
  final List<ContractStatusValidationIssue> issues;

  bool get hasChanges => repairedScheduleCount > 0 || contractStatusChanged;
}

class ContractStatusValidationIssue {
  const ContractStatusValidationIssue({
    required this.type,
    required this.message,
    this.scheduleId,
  });

  final ContractStatusValidationIssueType type;
  final String message;
  final String? scheduleId;
}

enum ContractStatusValidationIssueType {
  skippedScheduleHasAllocation,
  repaymentMissing,
  zeroAllocation,
  noSchedules,
  scheduleMissing,
  repaymentTargetMismatch,
  billItemMissing,
  billItemReferenceMismatch,
}
