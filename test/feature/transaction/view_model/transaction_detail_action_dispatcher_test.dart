import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/orchestration_command_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail/transaction_detail_action_dispatcher.dart';
import '../../../helper/advance_ownership_fixtures.dart';

class _MockTransactionEditAppService extends Mock
    implements TransactionEditAppService {}

class _MockTransactionUpdateAppService extends Mock
    implements TransactionUpdateAppService {}

class _MockInstallmentContractAppService extends Mock
    implements InstallmentContractAppService {}

class _MockDisbursementInstallmentAppService extends Mock
    implements DisbursementInstallmentAppService {}

class _MockConsumptionInstallmentAppService extends Mock
    implements ConsumptionInstallmentAppService {}

class _MockBillRepaymentAppService extends Mock
    implements BillRepaymentAppService {}

class _MockInstallmentPrepaymentAppService extends Mock
    implements InstallmentPrepaymentAppService {}

class _MockAccountRepaymentAppService extends Mock
    implements AccountRepaymentAppService {}

class _MockAdvanceOrchestrationAppService extends Mock
    implements AdvanceOrchestrationAppService {}

class _FakeEditAdvanceWorkflowCommand extends Fake
    implements EditAdvanceWorkflowCommand {}

class _FakeEditAdvanceRefundWorkflowCommand extends Fake
    implements EditAdvanceRefundWorkflowCommand {}

class _FakeDeleteCreditRepaymentCommand extends Fake
    implements DeleteCreditRepaymentCommand {}

class _FakeEditCreditRepaymentTransactionCommand extends Fake
    implements EditCreditRepaymentTransactionCommand {}

class _FakeEditRepaymentCommand extends Fake implements EditRepaymentCommand {}

class _FakeUpdateTransactionBasicInfoCommand extends Fake
    implements UpdateTransactionBasicInfoCommand {}

void main() {
  late _MockTransactionEditAppService editService;
  late _MockTransactionUpdateAppService updateService;
  late _MockInstallmentContractAppService installmentAppService;
  late _MockDisbursementInstallmentAppService disbursementInstallmentAppService;
  late _MockConsumptionInstallmentAppService consumptionInstallmentAppService;
  late _MockBillRepaymentAppService billRepaymentAppService;
  late _MockInstallmentPrepaymentAppService installmentPrepaymentAppService;
  late _MockAccountRepaymentAppService accountRepaymentAppService;
  late _MockAdvanceOrchestrationAppService advanceAppService;

  setUpAll(() {
    registerFallbackValue(_FakeEditAdvanceWorkflowCommand());
    registerFallbackValue(_FakeEditAdvanceRefundWorkflowCommand());
    registerFallbackValue(_FakeDeleteCreditRepaymentCommand());
    registerFallbackValue(_FakeEditCreditRepaymentTransactionCommand());
    registerFallbackValue(_FakeEditRepaymentCommand());
    registerFallbackValue(_FakeUpdateTransactionBasicInfoCommand());
  });

  setUp(() {
    editService = _MockTransactionEditAppService();
    updateService = _MockTransactionUpdateAppService();
    installmentAppService = _MockInstallmentContractAppService();
    disbursementInstallmentAppService =
        _MockDisbursementInstallmentAppService();
    consumptionInstallmentAppService = _MockConsumptionInstallmentAppService();
    billRepaymentAppService = _MockBillRepaymentAppService();
    installmentPrepaymentAppService = _MockInstallmentPrepaymentAppService();
    accountRepaymentAppService = _MockAccountRepaymentAppService();
    advanceAppService = _MockAdvanceOrchestrationAppService();
  });

  test(
    'advance ownership routes account edits through orchestration',
    () async {
      final transaction = TransactionReadModel(
        id: 'advance',
        businessPurpose: BusinessPurpose.advance,
        occurredAt: DateTime(2026, 10, 23),
        primaryAmount: const Money(minorUnits: 10000),
        ownership: advanceOwnership(
          management: AdvanceTrackingMode.itemized,
          ownerId: 'advance',
          scenario: AdvanceScenario.aa,
        ),
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
      );
      when(
        () => advanceAppService.editAdvance(any()),
      ).thenAnswer((_) async => 'advance');

      final dispatcher = createTransactionDetailActionDispatcher(
        context: _context(
          transaction,
          owner: AdvanceTransactionDetailOwnerContext(
            ownerType: orchestrationAdvanceOwnerType,
            ownerId: 'advance',
            scenario: AdvanceScenario.aa,
            trackingMode: AdvanceTrackingMode.itemized,
            advanceAmount: transaction.primaryAmount,
            receivedAmount: Money.zero(),
            outstanding: transaction.primaryAmount,
            isClosed: false,
          ),
        ),
        editService: editService,
        updateService: updateService,
        installmentAppService: installmentAppService,
        disbursementInstallmentAppService: disbursementInstallmentAppService,
        consumptionInstallmentAppService: consumptionInstallmentAppService,
        billRepaymentAppService: billRepaymentAppService,
        installmentPrepaymentAppService: installmentPrepaymentAppService,
        accountRepaymentAppService: accountRepaymentAppService,
        advanceAppService: advanceAppService,
      );
      final outcome = await dispatcher.changeSettlementAccount('cash');

      expect(outcome, isA<UiActionSuccess<void>>());
      verify(() => advanceAppService.editAdvance(any())).called(1);
    },
  );

  test('amortization business fields update the ledger transaction', () async {
    final transaction = TransactionReadModel(
      id: 'amortization-entry',
      businessPurpose: BusinessPurpose.dailyExpense,
      occurredAt: DateTime(2026, 1, 31),
      primaryAmount: const Money(minorUnits: 10000),
      ownership: const TransactionOwnership(
        ownerType: orchestrationAmortizationOwnerType,
        ownerId: 'plan',
      ),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
    );
    when(() => updateService.updateBasicInfo(any())).thenAnswer(
      (_) async =>
          const PostedTransactionResult(transactionId: 'amortization-entry'),
    );
    final dispatcher = createTransactionDetailActionDispatcher(
      context: _context(
        transaction,
        owner: AmortizationTransactionDetailOwnerContext(
          ownerType: orchestrationAmortizationOwnerType,
          ownerId: 'plan',
          initialTransactionId: 'amortization-entry',
          kind: AmortizationKind.prepaidExpense,
          status: AmortizationStatus.active,
          originalAmount: transaction.primaryAmount,
          recognizedAmount: Money.zero(),
          remainingAmount: transaction.primaryAmount,
          postedPeriodCount: 0,
          totalPeriodCount: 3,
        ),
      ),
      editService: editService,
      updateService: updateService,
      installmentAppService: installmentAppService,
      disbursementInstallmentAppService: disbursementInstallmentAppService,
      consumptionInstallmentAppService: consumptionInstallmentAppService,
      billRepaymentAppService: billRepaymentAppService,
      installmentPrepaymentAppService: installmentPrepaymentAppService,
      accountRepaymentAppService: accountRepaymentAppService,
    );

    expect(
      await dispatcher.changeNote('updated note'),
      isA<UiActionSuccess<void>>(),
    );
    expect(
      await dispatcher.changeOccurredAt(DateTime(2026, 2, 1)),
      isA<UiActionSuccess<void>>(),
    );
    expect(
      await dispatcher.changePostedAt(DateTime(2026, 2, 2)),
      isA<UiActionSuccess<void>>(),
    );

    final commands = verify(
      () => updateService.updateBasicInfo(captureAny()),
    ).captured.cast<UpdateTransactionBasicInfoCommand>();
    expect(commands, hasLength(3));
    expect(commands[0].note, isNotNull);
    expect(commands[1].occurredAt, DateTime(2026, 2, 1));
    expect(commands[2].postedAt, DateTime(2026, 2, 2));
  });

  test(
    'advance refund inheritance routes account edits through orchestration',
    () async {
      final transaction = TransactionReadModel(
        id: 'refund',
        parentTransactionId: 'advance',
        businessPurpose: BusinessPurpose.refund,
        occurredAt: DateTime(2026, 10, 23),
        primaryAmount: const Money(minorUnits: 2000),
        ownership: advanceOwnership(
          management: AdvanceTrackingMode.itemized,
          ownerId: 'advance',
          scenario: AdvanceScenario.aa,
        ),
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
      );
      when(
        () => advanceAppService.editRefund(any()),
      ).thenAnswer((_) async => 'refund');

      final dispatcher = createTransactionDetailActionDispatcher(
        context: _context(
          transaction,
          owner: AdvanceTransactionDetailOwnerContext(
            ownerType: orchestrationAdvanceOwnerType,
            ownerId: 'advance',
            scenario: AdvanceScenario.aa,
            trackingMode: AdvanceTrackingMode.itemized,
            advanceAmount: transaction.primaryAmount,
            receivedAmount: Money.zero(),
            outstanding: transaction.primaryAmount,
            isClosed: false,
          ),
        ),
        editService: editService,
        updateService: updateService,
        installmentAppService: installmentAppService,
        disbursementInstallmentAppService: disbursementInstallmentAppService,
        consumptionInstallmentAppService: consumptionInstallmentAppService,
        billRepaymentAppService: billRepaymentAppService,
        installmentPrepaymentAppService: installmentPrepaymentAppService,
        accountRepaymentAppService: accountRepaymentAppService,
        advanceAppService: advanceAppService,
      );
      final outcome = await dispatcher.changeSettlementAccount('cash');

      expect(outcome, isA<UiActionSuccess<void>>());
      verify(() => advanceAppService.editRefund(any())).called(1);
    },
  );

  test('plain debt repayment routes account edits through ledger', () async {
    final transaction = TransactionReadModel(
      id: 'repayment-transaction',
      businessPurpose: BusinessPurpose.debtRepayment,
      occurredAt: DateTime(2026, 10, 23),
      primaryAmount: const Money(minorUnits: 10000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
    );
    when(() => editService.editRepayment(any())).thenAnswer(
      (_) async =>
          const PostedTransactionResult(transactionId: 'repayment-transaction'),
    );
    final dispatcher = createTransactionDetailActionDispatcher(
      context: _context(transaction),
      editService: editService,
      updateService: updateService,
      installmentAppService: installmentAppService,
      disbursementInstallmentAppService: disbursementInstallmentAppService,
      consumptionInstallmentAppService: consumptionInstallmentAppService,
      billRepaymentAppService: billRepaymentAppService,
      installmentPrepaymentAppService: installmentPrepaymentAppService,
      accountRepaymentAppService: accountRepaymentAppService,
    );

    expect(
      await dispatcher.changeSettlementAccount('cash'),
      isA<UiActionSuccess<void>>(),
    );
    verify(() => editService.editRepayment(any())).called(1);
  });

  test('bill repayment ownership routes delete to the bill module', () async {
    when(
      () => billRepaymentAppService.deleteRepayment(any()),
    ).thenAnswer((_) async {});
    final dispatcher = createTransactionDetailActionDispatcher(
      context: _context(
        _creditRepaymentTransaction('repayment-1'),
        owner: _repaymentOwner(RepaymentType.bill),
      ),
      editService: editService,
      updateService: updateService,
      installmentAppService: installmentAppService,
      disbursementInstallmentAppService: disbursementInstallmentAppService,
      consumptionInstallmentAppService: consumptionInstallmentAppService,
      billRepaymentAppService: billRepaymentAppService,
      installmentPrepaymentAppService: installmentPrepaymentAppService,
      accountRepaymentAppService: accountRepaymentAppService,
    );

    expect(await dispatcher.delete(), isA<UiActionSuccess<void>>());
    verify(() => billRepaymentAppService.deleteRepayment(any())).called(1);
    verifyNever(() => installmentPrepaymentAppService.deleteRepayment(any()));
    verifyNever(() => accountRepaymentAppService.deleteRepayment(any()));
  });

  test(
    'prepayment ownership routes transaction edits to the prepayment module',
    () async {
      when(
        () => installmentPrepaymentAppService.editRepaymentTransaction(any()),
      ).thenAnswer((_) async {});
      final dispatcher = createTransactionDetailActionDispatcher(
        context: _context(
          _creditRepaymentTransaction('repayment-1'),
          owner: _repaymentOwner(RepaymentType.prepayment),
        ),
        editService: editService,
        updateService: updateService,
        installmentAppService: installmentAppService,
        disbursementInstallmentAppService: disbursementInstallmentAppService,
        consumptionInstallmentAppService: consumptionInstallmentAppService,
        billRepaymentAppService: billRepaymentAppService,
        installmentPrepaymentAppService: installmentPrepaymentAppService,
        accountRepaymentAppService: accountRepaymentAppService,
      );

      expect(
        await dispatcher.changeNote('updated'),
        isA<UiActionSuccess<void>>(),
      );
      verify(
        () => installmentPrepaymentAppService.editRepaymentTransaction(any()),
      ).called(1);
      verifyNever(
        () => billRepaymentAppService.editRepaymentTransaction(any()),
      );
      verifyNever(
        () => accountRepaymentAppService.editRepaymentTransaction(any()),
      );
    },
  );

  test(
    'account repayment ownership routes account edits to the account module',
    () async {
      when(
        () => accountRepaymentAppService.editRepaymentTransaction(any()),
      ).thenAnswer((_) async {});
      final dispatcher = createTransactionDetailActionDispatcher(
        context: _context(
          _creditRepaymentTransaction('repayment-1'),
          owner: _repaymentOwner(RepaymentType.unattributed),
        ),
        editService: editService,
        updateService: updateService,
        installmentAppService: installmentAppService,
        disbursementInstallmentAppService: disbursementInstallmentAppService,
        consumptionInstallmentAppService: consumptionInstallmentAppService,
        billRepaymentAppService: billRepaymentAppService,
        installmentPrepaymentAppService: installmentPrepaymentAppService,
        accountRepaymentAppService: accountRepaymentAppService,
      );

      expect(
        await dispatcher.changeSettlementAccount('cash'),
        isA<UiActionSuccess<void>>(),
      );
      verify(
        () => accountRepaymentAppService.editRepaymentTransaction(any()),
      ).called(1);
      verifyNever(
        () => billRepaymentAppService.editRepaymentTransaction(any()),
      );
      verifyNever(
        () => installmentPrepaymentAppService.editRepaymentTransaction(any()),
      );
    },
  );
}

TransactionDetailContext _context(
  TransactionReadModel transaction, {
  TransactionDetailOwnerContext? owner,
}) {
  final group = TransactionDetailGroup(
    anchor: transaction,
    children: transaction.children,
  );
  return TransactionDetailContext(
    transaction: transaction,
    currentGroup: group,
    anchorGroup: group,
    owner: owner,
  );
}

RepaymentTransactionDetailOwnerContext _repaymentOwner(RepaymentType type) {
  return RepaymentTransactionDetailOwnerContext(
    ownerType: creditRepaymentOwnerType,
    ownerId: 'repayment-1',
    repaymentType: type,
    targetType: switch (type) {
      RepaymentType.bill ||
      RepaymentType.installment => RepaymentTargetType.bill,
      RepaymentType.prepayment => RepaymentTargetType.contract,
      RepaymentType.unattributed => RepaymentTargetType.account,
    },
    targetId: 'target-1',
  );
}

TransactionReadModel _creditRepaymentTransaction(String repaymentId) {
  return TransactionReadModel(
    id: 'repayment-transaction',
    businessPurpose: BusinessPurpose.debtRepayment,
    occurredAt: DateTime(2026, 10, 23),
    primaryAmount: const Money(minorUnits: 10000),
    ownership: TransactionOwnership(
      ownerType: creditRepaymentOwnerType,
      ownerId: repaymentId,
    ),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}
