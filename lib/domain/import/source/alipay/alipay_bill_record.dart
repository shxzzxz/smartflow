import '../../../../core/money/money.dart';
import '../../import_models.dart';
import '../../service/source_parsing_models.dart';

enum AlipayBillFilterReason {
  directionNotSupported,
  transactionStatusNotSupported,
  zeroAmount,
  unknownDirection,
}

extension AlipayBillFilterReasonDescription on AlipayBillFilterReason {
  String get reasonCode => switch (this) {
    AlipayBillFilterReason.directionNotSupported =>
      'alipay_direction_not_supported',
    AlipayBillFilterReason.transactionStatusNotSupported =>
      'alipay_transaction_status_not_supported',
    AlipayBillFilterReason.zeroAmount => 'alipay_amount_zero',
    AlipayBillFilterReason.unknownDirection => 'alipay_direction_unknown',
  };

  String get reason => switch (this) {
    AlipayBillFilterReason.directionNotSupported => '支付宝收/支不是收入或支出。',
    AlipayBillFilterReason.transactionStatusNotSupported => '支付宝交易状态不是交易成功。',
    AlipayBillFilterReason.zeroAmount => '支付宝交易金额为 0。',
    AlipayBillFilterReason.unknownDirection => '支付宝收/支为空或无法识别。',
  };
}

final class AlipayBillRecord implements SourceRecord {
  AlipayBillRecord({
    required this.rowNumber,
    required this.direction,
    required this.status,
    required this.occurredAt,
    required this.amount,
    required this.categoryPath,
    required this.paymentMethod,
    required this.note,
    required this.sourceOperationKey,
    required this.filterReason,
    Iterable<ImportIssue> issues = const [],
  }) : issues = List.unmodifiable(issues);

  @override
  final int rowNumber;

  final String? direction;
  final String? status;
  final DateTime? occurredAt;
  final Money? amount;
  final String? categoryPath;
  final String? paymentMethod;
  final String? note;
  final String? sourceOperationKey;
  final AlipayBillFilterReason? filterReason;

  @override
  final List<ImportIssue> issues;
}
