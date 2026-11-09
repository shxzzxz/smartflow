import '../../../../core/money/money.dart';
import '../../import_models.dart';
import '../../service/source_parsing_models.dart';

enum WechatBillFilterReason { neutralDirection, unknownDirection, zeroAmount }

extension WechatBillFilterReasonDescription on WechatBillFilterReason {
  String get reasonCode => switch (this) {
    WechatBillFilterReason.neutralDirection => 'wechat_direction_neutral',
    WechatBillFilterReason.unknownDirection => 'wechat_direction_unknown',
    WechatBillFilterReason.zeroAmount => 'wechat_amount_zero',
  };

  String get reason => switch (this) {
    WechatBillFilterReason.neutralDirection => '微信收/支为“/”，不是收入或支出。',
    WechatBillFilterReason.unknownDirection => '微信收/支为空或无法识别。',
    WechatBillFilterReason.zeroAmount => '微信交易金额为 0。',
  };
}

class WechatBillRecord implements SourceRecord {
  const WechatBillRecord({
    required this.rowNumber,
    required this.direction,
    required this.transactionType,
    required this.counterparty,
    required this.product,
    required this.status,
    required this.paymentMethod,
    required this.transactionId,
    required this.merchantOrderId,
    required this.occurredAt,
    required this.amount,
    required this.filterReason,
    this.issues = const [],
  });

  @override
  final int rowNumber;
  final String? direction;
  final String? transactionType;
  final String? counterparty;
  final String? product;
  final String? status;
  final String? paymentMethod;
  final String? transactionId;
  final String? merchantOrderId;
  final DateTime? occurredAt;
  final Money? amount;
  final WechatBillFilterReason? filterReason;

  @override
  final List<ImportIssue> issues;
}
