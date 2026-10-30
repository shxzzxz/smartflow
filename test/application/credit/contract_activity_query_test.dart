import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/installment/query/contract_activity_query.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/installment_refund_reduction.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/installment_refund_reduction_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

void main() {
  test('projects repayments and refund reductions by business time', () async {
    final repayments = _FakeRepaymentRepository(
      repayments: [
        Repayment(
          id: 'prepayment',
          repaymentType: RepaymentType.prepayment,
          targetType: RepaymentTargetType.contract,
          targetId: 'contract',
          transactionId: 'tx-repayment',
          repaymentDate: DateTime(2026, 2, 10),
          items: const [
            RepaymentItem(
              id: 'repayment-item',
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
    final refundReductions = _FakeRefundReductionRepository(
      reductions: [
        InstallmentRefundReduction(
          id: 'refund-reduction',
          contractId: 'contract',
          refundTransactionId: 'tx-refund',
          principal: const Money(minorUnits: 800),
          occurredAt: DateTime(2026, 3, 1),
          createdAt: DateTime(2026, 3, 2),
        ),
      ],
    );
    final query = ContractActivityQueryImpl(
      repayments: repayments,
      refundReductions: refundReductions,
    );

    final result = await query.listContractActivities('contract');

    expect(result.map((activity) => activity.id), [
      'refund-reduction',
      'prepayment',
    ]);
    final refund = result.first as ContractRefundReductionActivity;
    expect(refund.transactionId, 'tx-refund');
    expect(refund.principal, const Money(minorUnits: 800));
    expect(refund.occurredAt, DateTime(2026, 3, 1));
    final repayment = result.last as ContractRepaymentActivity;
    expect(repayment.transactionId, 'tx-repayment');
    expect(repayment.repaymentType, RepaymentType.prepayment);
    expect(repayment.principal, const Money(minorUnits: 1000));
    expect(repayment.interest, const Money(minorUnits: 50));
    expect(repayment.fee, const Money(minorUnits: 10));
  });
}

class _FakeRepaymentRepository implements RepaymentRepository {
  _FakeRepaymentRepository({required this.repayments});

  final List<Repayment> repayments;

  @override
  Future<List<Repayment>> listByContract(String contractId) async => repayments;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRefundReductionRepository
    implements InstallmentRefundReductionRepository {
  _FakeRefundReductionRepository({required this.reductions});

  final List<InstallmentRefundReduction> reductions;

  @override
  Future<List<InstallmentRefundReduction>> listByContract(
    String contractId,
  ) async => reductions;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
