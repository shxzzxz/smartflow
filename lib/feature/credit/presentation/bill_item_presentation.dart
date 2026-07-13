import '../../../application/credit/credit_query_api.dart';

String billItemLabel(BillItemReadModel item) {
  if (item.itemType == BillItemType.consumption) return '消费';
  return switch (item.installmentSourceType) {
    null => '分期',
    InstallmentSourceType.billConversion => '账单分期',
    InstallmentSourceType.disbursement =>
      item.accountKind == CreditLiabilityAccountKind.credit ? '现金分期' : '贷款分期',
  };
}
