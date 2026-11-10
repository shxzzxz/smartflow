import '../../../../core/money/money.dart';
import '../../import_models.dart';
import '../../service/source_parsing_models.dart';

enum JdBillFilterReason { directionNotSupported, unknownDirection, zeroAmount }

extension JdBillFilterReasonDescription on JdBillFilterReason {
  String get reasonCode => switch (this) {
    JdBillFilterReason.directionNotSupported => 'jd_direction_not_supported',
    JdBillFilterReason.unknownDirection => 'jd_direction_unknown',
    JdBillFilterReason.zeroAmount => 'jd_amount_zero',
  };

  String get reason => switch (this) {
    JdBillFilterReason.directionNotSupported => '京东收/支不是收入或支出。',
    JdBillFilterReason.unknownDirection => '京东收/支为空或无法识别。',
    JdBillFilterReason.zeroAmount => '京东交易金额为 0。',
  };
}

final class JdBillRecord implements SourceRecord {
  JdBillRecord({
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
  final JdBillFilterReason? filterReason;

  @override
  final List<ImportIssue> issues;
}
