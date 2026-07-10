import '../../../core/money/money.dart';

class RepaymentAmountBreakdown {
  const RepaymentAmountBreakdown({
    required this.principal,
    required this.interest,
    required this.fee,
    required this.discount,
  });

  static const zero = RepaymentAmountBreakdown(
    principal: Money(minorUnits: 0),
    interest: Money(minorUnits: 0),
    fee: Money(minorUnits: 0),
    discount: Money(minorUnits: 0),
  );

  final Money principal;
  final Money interest;
  final Money fee;
  final Money discount;

  bool get hasNegativePart =>
      principal.minorUnits < 0 ||
      interest.minorUnits < 0 ||
      fee.minorUnits < 0 ||
      discount.minorUnits < 0;

  Money get cashPaid => principal + interest + fee - discount;

  RepaymentAmountBreakdown operator +(RepaymentAmountBreakdown other) {
    return RepaymentAmountBreakdown(
      principal: principal + other.principal,
      interest: interest + other.interest,
      fee: fee + other.fee,
      discount: discount + other.discount,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RepaymentAmountBreakdown &&
        other.principal == principal &&
        other.interest == interest &&
        other.fee == fee &&
        other.discount == discount;
  }

  @override
  int get hashCode => Object.hash(principal, interest, fee, discount);
}
