import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/installment/query/contract_repayment_query.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

void main() {
  test('contract repayment query returns application read models', () async {
    final repayments = _FakeRepaymentRepository(
      repayments: [
        Repayment(
          id: 'prepayment',
          repaymentType: RepaymentType.prepayment,
          targetType: RepaymentTargetType.contract,
          targetId: 'contract',
          transactionId: 'root',
          repaymentDate: DateTime(2026, 2, 10),
          items: const [
            RepaymentItem(
              id: 'item',
              repaymentId: 'prepayment',
              allocated: RepaymentAmountBreakdown(
                principal: Money(minorUnits: 1000),
                interest: Money(minorUnits: 50),
                fee: Money(minorUnits: 10),
                discount: Money(minorUnits: 0),
              ),
            ),
          ],
        ),
      ],
    );
    final query = ContractRepaymentQueryImpl(repayments: repayments);

    final result = await query.listContractRepayments('contract');

    expect(result.single.id, 'prepayment');
    expect(result.single.transactionId, 'root');
    expect(result.single.occurredAt, DateTime(2026, 2, 10));
    expect(result.single.principal, const Money(minorUnits: 1000));
    expect(result.single.interest, const Money(minorUnits: 50));
    expect(result.single.fee, const Money(minorUnits: 10));
  });
}

class _FakeRepaymentRepository implements RepaymentRepository {
  _FakeRepaymentRepository({required this.repayments});

  final List<Repayment> repayments;

  @override
  Future<List<Repayment>> listByTarget(
    RepaymentTargetType targetType,
    String targetId,
  ) async => repayments;

  @override
  Future<List<Repayment>> listByContract(String contractId) async => repayments;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
