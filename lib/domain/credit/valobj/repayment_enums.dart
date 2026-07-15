enum RepaymentType {
  bill('BILL', '账单还款'),
  installment('INSTALLMENT', '分期还款'),
  prepayment('PREPAYMENT', '提前还款'),
  unattributed('UNATTRIBUTED', '未归属还款');

  const RepaymentType(this.code, this.label);

  final String code;
  final String label;

  static RepaymentType fromCode(String code) {
    for (final value in RepaymentType.values) {
      if (value.code == code) return value;
    }
    throw ArgumentError.value(code, 'code', 'Unknown repayment type code.');
  }
}

const String creditRepaymentOwnerType = 'credit_repayment';

enum RepaymentTargetType {
  bill('BILL', '账单'),
  contract('CONTRACT', '合同'),
  account('ACCOUNT', '账户');

  const RepaymentTargetType(this.code, this.label);

  final String code;
  final String label;

  static RepaymentTargetType fromCode(String code) {
    for (final value in RepaymentTargetType.values) {
      if (value.code == code) return value;
    }
    throw ArgumentError.value(
      code,
      'code',
      'Unknown repayment target type code.',
    );
  }
}
