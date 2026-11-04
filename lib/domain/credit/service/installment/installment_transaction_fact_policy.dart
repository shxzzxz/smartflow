import '../../../ledger/valobj/ledger_enum.dart';
import '../../valobj/installment_enums.dart';

/// Resolves the credit-owned transaction fact represented by an installment
/// activity item.
InstallmentTransactionFactKind? resolveInstallmentTransactionFactKind({
  required InstallmentType installmentType,
  required BusinessPurpose businessPurpose,
}) {
  return switch ((installmentType, businessPurpose)) {
    (InstallmentType.purchase, BusinessPurpose.dailyExpense) =>
      InstallmentTransactionFactKind.purchase,
    (InstallmentType.disbursement, BusinessPurpose.borrowing) =>
      InstallmentTransactionFactKind.disbursement,
    (InstallmentType.purchase, BusinessPurpose.refund) ||
    (
      InstallmentType.disbursement,
      BusinessPurpose.refund,
    ) => InstallmentTransactionFactKind.refund,
    _ => null,
  };
}
