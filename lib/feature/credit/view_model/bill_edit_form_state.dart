class BillEditFormState {
  const BillEditFormState({
    this.billItemId,
    this.startDate,
    this.billingDate,
    this.repaymentDate,
    this.submitting = false,
  });

  final String? billItemId;
  final DateTime? startDate;
  final DateTime? billingDate;
  final DateTime? repaymentDate;
  final bool submitting;

  bool get loaded => startDate != null && billingDate != null;

  BillEditFormState copyWith({
    String? billItemId,
    DateTime? startDate,
    DateTime? billingDate,
    DateTime? repaymentDate,
    bool? submitting,
  }) {
    return BillEditFormState(
      billItemId: billItemId ?? this.billItemId,
      startDate: startDate ?? this.startDate,
      billingDate: billingDate ?? this.billingDate,
      repaymentDate: repaymentDate ?? this.repaymentDate,
      submitting: submitting ?? this.submitting,
    );
  }
}
