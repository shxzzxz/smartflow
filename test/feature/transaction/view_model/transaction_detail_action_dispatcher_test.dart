import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/repayment/query/repayment_owner_query.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/orchestration_command_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail_action_dispatcher.dart';
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

class _MockRepaymentOwnerQuery extends Mock implements RepaymentOwnerQuery {}

class _MockAdvanceOrchestrationAppService extends Mock
    implements AdvanceOrchestrationAppService {}

class _MockAdvanceCaseQueryService extends Mock
    implements AdvanceCaseQueryService {}

class _FakeEditAdvanceWorkflowCommand extends Fake
    implements EditAdvanceWorkflowCommand {}

class _FakeEditAdvanceRefundWorkflowCommand extends Fake
    implements EditAdvanceRefundWorkflowCommand {}

class _FakeDeleteCreditRepaymentCommand extends Fake
    implements DeleteCreditRepaymentCommand {}

class _FakeEditCreditRepaymentTransactionCommand extends Fake
    implements EditCreditRepaymentTransactionCommand {}

void main() {
  late _MockTransactionEditAppService editService;
  late _MockTransactionUpdateAppService updateService;
  late _MockInstallmentContractAppService installmentAppService;
  late _MockDisbursementInstallmentAppService disbursementInstallmentAppService;
  late _MockConsumptionInstallmentAppService consumptionInstallmentAppService;
  late _MockBillRepaymentAppService billRepaymentAppService;
  late _MockInstallmentPrepaymentAppService installmentPrepaymentAppService;
  late _MockAccountRepaymentAppService accountRepaymentAppService;
  late _MockRepaymentOwnerQuery repaymentOwnerQuery;
  late _MockAdvanceOrchestrationAppService advanceAppService;
  late _MockAdvanceCaseQueryService advanceCaseQuery;

  setUpAll(() {
    registerFallbackValue(_FakeEditAdvanceWorkflowCommand());
    registerFallbackValue(_FakeEditAdvanceRefundWorkflowCommand());
    registerFallbackValue(_FakeDeleteCreditRepaymentCommand());
    registerFallbackValue(_FakeEditCreditRepaymentTransactionCommand());
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
    repaymentOwnerQuery = _MockRepaymentOwnerQuery();
    advanceAppService = _MockAdvanceOrchestrationAppService();
    advanceCaseQuery = _MockAdvanceCaseQueryService();
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
      when(() => advanceCaseQuery.findById('advance')).thenAnswer(
        (_) async => const AdvanceCase(
          id: 'advance',
          scenario: AdvanceScenario.aa,
          trackingMode: AdvanceTrackingMode.itemized,
          aaPeopleCount: 2,
        ),
      );
      when(
        () => advanceAppService.editAdvance(any()),
      ).thenAnswer((_) async => 'advance');

      final dispatcher = createTransactionDetailActionDispatcher(
        transaction: transaction,
        editService: editService,
        updateService: updateService,
        installmentAppService: installmentAppService,
        disbursementInstallmentAppService: disbursementInstallmentAppService,
        consumptionInstallmentAppService: consumptionInstallmentAppService,
        billRepaymentAppService: billRepaymentAppService,
        installmentPrepaymentAppService: installmentPrepaymentAppService,
        accountRepaymentAppService: accountRepaymentAppService,
        repaymentOwnerQuery: repaymentOwnerQuery,
        advanceAppService: advanceAppService,
        advanceCaseQuery: advanceCaseQuery,
      );
      final outcome = await dispatcher.changeSettlementAccount('cash');

      expect(outcome, isA<UiActionSuccess<void>>());
      verify(() => advanceAppService.editAdvance(any())).called(1);
    },
  );

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
        transaction: transaction,
        editService: editService,
        updateService: updateService,
        installmentAppService: installmentAppService,
        disbursementInstallmentAppService: disbursementInstallmentAppService,
        consumptionInstallmentAppService: consumptionInstallmentAppService,
        billRepaymentAppService: billRepaymentAppService,
        installmentPrepaymentAppService: installmentPrepaymentAppService,
        accountRepaymentAppService: accountRepaymentAppService,
        repaymentOwnerQuery: repaymentOwnerQuery,
        advanceAppService: advanceAppService,
        advanceCaseQuery: advanceCaseQuery,
      );
      final outcome = await dispatcher.changeSettlementAccount('cash');

      expect(outcome, isA<UiActionSuccess<void>>());
      verify(() => advanceAppService.editRefund(any())).called(1);
    },
  );

  test('bill repayment ownership routes delete to the bill module', () async {
    when(
      () => repaymentOwnerQuery.findType('repayment-1'),
    ).thenAnswer((_) async => RepaymentType.bill);
    when(
      () => billRepaymentAppService.deleteRepayment(any()),
    ).thenAnswer((_) async {});
    final dispatcher = createTransactionDetailActionDispatcher(
      transaction: _creditRepaymentTransaction('repayment-1'),
      editService: editService,
      updateService: updateService,
      installmentAppService: installmentAppService,
      disbursementInstallmentAppService: disbursementInstallmentAppService,
      consumptionInstallmentAppService: consumptionInstallmentAppService,
      billRepaymentAppService: billRepaymentAppService,
      installmentPrepaymentAppService: installmentPrepaymentAppService,
      accountRepaymentAppService: accountRepaymentAppService,
      repaymentOwnerQuery: repaymentOwnerQuery,
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
        () => repaymentOwnerQuery.findType('repayment-1'),
      ).thenAnswer((_) async => RepaymentType.prepayment);
      when(
        () => installmentPrepaymentAppService.editRepaymentTransaction(any()),
      ).thenAnswer((_) async {});
      final dispatcher = createTransactionDetailActionDispatcher(
        transaction: _creditRepaymentTransaction('repayment-1'),
        editService: editService,
        updateService: updateService,
        installmentAppService: installmentAppService,
        disbursementInstallmentAppService: disbursementInstallmentAppService,
        consumptionInstallmentAppService: consumptionInstallmentAppService,
        billRepaymentAppService: billRepaymentAppService,
        installmentPrepaymentAppService: installmentPrepaymentAppService,
        accountRepaymentAppService: accountRepaymentAppService,
        repaymentOwnerQuery: repaymentOwnerQuery,
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
        () => repaymentOwnerQuery.findType('repayment-1'),
      ).thenAnswer((_) async => RepaymentType.unattributed);
      when(
        () => accountRepaymentAppService.editRepaymentTransaction(any()),
      ).thenAnswer((_) async {});
      final dispatcher = createTransactionDetailActionDispatcher(
        transaction: _creditRepaymentTransaction('repayment-1'),
        editService: editService,
        updateService: updateService,
        installmentAppService: installmentAppService,
        disbursementInstallmentAppService: disbursementInstallmentAppService,
        consumptionInstallmentAppService: consumptionInstallmentAppService,
        billRepaymentAppService: billRepaymentAppService,
        installmentPrepaymentAppService: installmentPrepaymentAppService,
        accountRepaymentAppService: accountRepaymentAppService,
        repaymentOwnerQuery: repaymentOwnerQuery,
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
