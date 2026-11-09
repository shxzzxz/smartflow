part of 'yimu_file_handlers.dart';

abstract interface class YimuFileHandler {
  YimuFileType get fileType;

  List<ImportIssue> validate({
    required String fileName,
    required ImportTabularSheet sheet,
  });

  SourceFileFact handle({
    required int fileIndex,
    required String fileName,
    required ImportTabularSheet sheet,
  });
}

enum YimuBillFilterReason { advanceGap, repaymentInterest, repaymentDiscount }

extension YimuBillFilterReasonDescription on YimuBillFilterReason {
  String get reasonCode => switch (this) {
    YimuBillFilterReason.advanceGap => 'advance_gap_generated',
    YimuBillFilterReason.repaymentInterest => 'repayment_interest_generated',
    YimuBillFilterReason.repaymentDiscount => 'repayment_discount_generated',
  };

  String get reason => switch (this) {
    YimuBillFilterReason.advanceGap => '报销差额是原报销交易自动生成的结果行。',
    YimuBillFilterReason.repaymentInterest => '还款利息应由转账或债务文件中的还款记录导入。',
    YimuBillFilterReason.repaymentDiscount => '还款优惠应由转账或债务文件中的还款记录导入。',
  };
}

class YimuAdvanceDetail {
  const YimuAdvanceDetail({
    required this.occurredAt,
    required this.amount,
    required this.accountName,
  });

  final DateTime? occurredAt;
  final Money? amount;
  final String? accountName;
}

sealed class YimuSourceRecord implements SourceRecord {
  YimuSourceRecord({
    required this.rowNumber,
    required this.sourceOperationKey,
    Iterable<ImportIssue> issues = const [],
  }) : issues = List.unmodifiable(issues);

  @override
  final int rowNumber;
  final String? sourceOperationKey;
  @override
  final List<ImportIssue> issues;
}

final class YimuBillRecord extends YimuSourceRecord {
  YimuBillRecord({
    required super.rowNumber,
    required super.sourceOperationKey,
    required this.kind,
    required this.occurredAt,
    required this.postedAt,
    required this.amount,
    this.categoryPath,
    this.accountName,
    this.refundSource,
    this.refundAmount,
    this.hasAdvanceFields = false,
    this.advanceAccountName,
    this.advanceAmountSource,
    this.advanceAmount,
    Iterable<YimuAdvanceDetail> advanceDetails = const [],
    this.advanceDetailsSource,
    this.note,
    this.other,
    this.filterReason,
    super.issues,
  }) : advanceDetails = List.unmodifiable(advanceDetails);

  final String? kind;
  final DateTime occurredAt;
  final DateTime postedAt;
  final Money amount;
  final String? categoryPath;
  final String? accountName;
  final String? refundSource;
  final Money? refundAmount;
  final bool hasAdvanceFields;
  final String? advanceAccountName;
  final String? advanceAmountSource;
  final Money? advanceAmount;
  final List<YimuAdvanceDetail> advanceDetails;
  final String? advanceDetailsSource;
  final String? note;
  final String? other;
  final YimuBillFilterReason? filterReason;
}

sealed class YimuAccountMovementRecord extends YimuSourceRecord {
  YimuAccountMovementRecord({
    required super.rowNumber,
    required super.sourceOperationKey,
    required this.kind,
    required this.occurredAt,
    required this.postedAt,
    required this.amount,
    required this.fromAccountName,
    required this.toAccountName,
    required this.feeAmount,
    required this.feeSource,
    required this.note,
    super.issues,
  });

  final String? kind;
  final DateTime occurredAt;
  final DateTime postedAt;
  final Money amount;
  final String? fromAccountName;
  final String? toAccountName;
  final Money? feeAmount;
  final String? feeSource;
  final String? note;
}

final class YimuTransferRecord extends YimuAccountMovementRecord {
  YimuTransferRecord({
    required super.rowNumber,
    required super.sourceOperationKey,
    required super.kind,
    required super.occurredAt,
    required super.postedAt,
    required super.amount,
    required super.fromAccountName,
    required super.toAccountName,
    required super.feeAmount,
    required super.feeSource,
    required super.note,
    super.issues,
  });
}

final class YimuDebtRecord extends YimuAccountMovementRecord {
  YimuDebtRecord({
    required super.rowNumber,
    required super.sourceOperationKey,
    required super.kind,
    required super.occurredAt,
    required super.postedAt,
    required super.amount,
    required super.fromAccountName,
    required super.toAccountName,
    required super.feeAmount,
    required super.feeSource,
    required super.note,
    super.issues,
  });
}
