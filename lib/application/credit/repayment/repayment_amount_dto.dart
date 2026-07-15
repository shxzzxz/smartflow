import '../../../core/money/money.dart';

class RepaymentAmountDto {
  const RepaymentAmountDto({
    required this.principal,
    required this.interest,
    required this.fee,
    required this.discount,
  });

  static const zero = RepaymentAmountDto(
    principal: Money(minorUnits: 0),
    interest: Money(minorUnits: 0),
    fee: Money(minorUnits: 0),
    discount: Money(minorUnits: 0),
  );

  final Money principal;
  final Money interest;
  final Money fee;
  final Money discount;
}
