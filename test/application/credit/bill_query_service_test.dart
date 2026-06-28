import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart' as credit;
import 'package:smartflow/application/credit/credit_query_api.dart'
    as credit_query;
import 'package:smartflow/application/ledger/ledger_query_api.dart' as ledger;
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_credit_account_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';

import '../../helper/test_app_database.dart';

void main() {
  test(
    'bill detail derives no-transaction repayment display from record',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      await fixture.seedBill();
      await fixture.seedRepayment(rootTransactionId: null);

      final detail = await fixture.query.findBillDetail('bill-1');

      expect(detail!.repayments, hasLength(1));
      expect(
        detail.repayments.single.timeSource,
        credit_query.BillRepaymentTimeSource.recordCreatedAt,
      );
      expect(
        detail.repayments.single.allocated.principal,
        const Money(minorUnits: 1000),
      );
      expect(detail.repayments.single.paidFromAccountId, isNull);
    },
  );

  test(
    'bill detail derives repayment display from current transaction',
    () async {
      final fixture = _Fixture(
        transactionDetails: {'tx-root': _transactionDetail()},
      );
      addTearDown(fixture.close);
      await fixture.seedBill();
      await fixture.seedRepayment(rootTransactionId: 'tx-root');

      final detail = await fixture.query.findBillDetail('bill-1');

      final repayment = detail!.repayments.single;
      expect(
        repayment.timeSource,
        credit_query.BillRepaymentTimeSource.transaction,
      );
      expect(repayment.displayTime, DateTime(2026, 6, 20));
      expect(repayment.paidFromAccountId, 'cash-1');
    },
  );
}

class _Fixture {
  _Fixture({
    Map<String, ledger.TransactionDetail> transactionDetails = const {},
  }) : transactions = _FakeTransactionQueryService(transactionDetails) {
    query = credit_query.BillQueryServiceImpl(
      bills: bills,
      creditAccounts: creditAccounts,
      installments: installments,
      repayments: repayments,
      transactionQueryService: transactions,
      generationService: const _NoopGenerationService(),
      now: () => DateTime(2026, 7, 1),
    );
  }

  final database = createTestDatabase();
  late final DriftBillRepository bills = DriftBillRepository(database);
  late final DriftCreditAccountRepository creditAccounts =
      DriftCreditAccountRepository(database);
  late final DriftInstallmentRepository installments =
      DriftInstallmentRepository(database);
  late final DriftRepaymentRepository repayments = DriftRepaymentRepository(
    database,
  );
  final _FakeTransactionQueryService transactions;
  late final credit_query.BillQueryService query;

  Future<void> seedBill() async {
    await bills.saveBill(
      Bill(
        id: 'bill-1',
        accountId: 'credit-1',
        period: credit.BillPeriod.fromInt(202606),
        status: credit.BillStatus.billed,
        items: const [],
      ),
    );
    await bills.upsertBillItems('bill-1', [
      BillItem(
        id: 'bill-item-1',
        billId: 'bill-1',
        itemType: credit.BillItemType.consumption,
        repaymentDate: DateTime(2026, 6, 25),
        expectedPrincipal: const Money(minorUnits: 1000),
        expectedInterest: Money.zero(),
        expectedFee: Money.zero(),
        status: credit.BillItemStatus.pending,
      ),
    ]);
  }

  Future<void> seedRepayment({required String? rootTransactionId}) {
    return repayments.saveRepayment(
      Repayment(
        id: 'repayment-1',
        repaymentType: credit.RepaymentType.bill,
        targetType: credit.RepaymentTargetType.bill,
        targetId: 'bill-1',
        rootTransactionId: rootTransactionId,
        items: [
          RepaymentItem(
            id: 'repayment-item-1',
            repaymentId: 'repayment-1',
            billItemId: 'bill-item-1',
            allocated: credit.RepaymentAmountBreakdown(
              principal: const Money(minorUnits: 1000),
              interest: Money.zero(),
              fee: Money.zero(),
              discount: Money.zero(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> close() => database.close();
}

ledger.TransactionDetail _transactionDetail() {
  final transaction = ledger.Transaction(
    id: 'tx-root',
    rootTransactionId: 'tx-root',
    businessPurpose: ledger.BusinessPurpose.debtRepayment,
    occurredAt: DateTime(2026, 6, 20),
    primaryAmount: const Money(minorUnits: 1000),
    mutationKind: ledger.MutationKind.original,
    businessState: ledger.BusinessState.current,
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    sourceKind: ledger.SourceKind.manual,
  );
  return ledger.TransactionDetail(
    transaction: transaction,
    createdAt: DateTime(2026, 6, 20),
    details: const [],
    entries: [
      ledger.Entry(
        id: 'entry-1',
        transactionId: 'tx-root',
        accountId: 'credit-1',
        direction: ledger.EntryDirection.debit,
        amount: const Money(minorUnits: 1000),
      ),
      ledger.Entry(
        id: 'entry-2',
        transactionId: 'tx-root',
        accountId: 'cash-1',
        direction: ledger.EntryDirection.credit,
        amount: const Money(minorUnits: 1000),
      ),
    ],
  );
}

class _NoopGenerationService implements credit.CreditBillGenerationService {
  const _NoopGenerationService();

  @override
  Future<void> generateDueBills({required DateTime now}) async {}

  @override
  Future<void> generateDueBillsForAccount({
    required String accountId,
    required DateTime now,
  }) async {}
}

class _FakeTransactionQueryService implements ledger.TransactionQueryService {
  const _FakeTransactionQueryService(this.details);

  final Map<String, ledger.TransactionDetail> details;

  @override
  Future<ledger.TransactionDetail?> findTransactionDetail(
    String transactionId,
  ) {
    return Future.value(details[transactionId]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
