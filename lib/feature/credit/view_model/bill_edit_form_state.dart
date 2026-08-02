class BillEditFormState {
  const BillEditFormState({
    this.startDate,
    this.billingDate,
    this.repaymentDate,
    this.submitting = false,
  });

  final DateTime? startDate;
  final DateTime? billingDate;
  final DateTime? repaymentDate;
  final bool submitting;

  bool get loaded => startDate != null && billingDate != null;

  BillEditFormState copyWith({
    DateTime? startDate,
    DateTime? billingDate,
    DateTime? repaymentDate,
    bool? submitting,
  }) {
    return BillEditFormState(
      startDate: startDate ?? this.startDate,
      billingDate: billingDate ?? this.billingDate,
      repaymentDate: repaymentDate ?? this.repaymentDate,
      submitting: submitting ?? this.submitting,
    );
  }
}
