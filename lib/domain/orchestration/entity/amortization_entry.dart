import '../../../core/money/money.dart';

class AmortizationEntry {
  const AmortizationEntry({
    required this.id,
    required this.planId,
    required this.sequenceNo,
    required this.dueAt,
    required this.amount,
    this.transactionId,
    this.canceledAt,
  });

  final String id;
  final String planId;
  final int sequenceNo;
  final DateTime dueAt;
  final Money amount;
  final String? transactionId;
  final DateTime? canceledAt;

  bool get isGenerated => transactionId != null;

  bool get isCanceled => canceledAt != null;

  AmortizationEntry generated(String transactionId) {
    return AmortizationEntry(
      id: id,
      planId: planId,
      sequenceNo: sequenceNo,
      dueAt: dueAt,
      amount: amount,
      transactionId: transactionId,
      canceledAt: canceledAt,
    );
  }

  AmortizationEntry canceled(DateTime canceledAt) {
    return AmortizationEntry(
      id: id,
      planId: planId,
      sequenceNo: sequenceNo,
      dueAt: dueAt,
      amount: amount,
      canceledAt: canceledAt,
    );
  }
}
