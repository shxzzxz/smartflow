import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail_action_dispatcher.dart';

class _MockTransactionEditAppService extends Mock
    implements TransactionEditAppService {}

class _MockTransactionUpdateAppService extends Mock
    implements TransactionUpdateAppService {}

class _MockInstallmentContractAppService extends Mock
    implements InstallmentContractAppService {}

class _MockRepaymentAppService extends Mock implements RepaymentAppService {}

class _FakeEditAdvanceCommand extends Fake implements EditAdvanceCommand {}

class _FakeEditRefundCommand extends Fake implements EditRefundCommand {}

void main() {
  late _MockTransactionEditAppService editService;
  late _MockTransactionUpdateAppService updateService;
  late _MockInstallmentContractAppService installmentAppService;
  late _MockRepaymentAppService repaymentAppService;

  setUpAll(() {
    registerFallbackValue(_FakeEditAdvanceCommand());
    registerFallbackValue(_FakeEditRefundCommand());
  });

  setUp(() {
    editService = _MockTransactionEditAppService();
    updateService = _MockTransactionUpdateAppService();
    installmentAppService = _MockInstallmentContractAppService();
    repaymentAppService = _MockRepaymentAppService();
  });

  test(
    'advance ownership keeps ledger actions in the default dispatcher',
    () async {
      final transaction = TransactionReadModel(
        id: 'advance',
        businessPurpose: BusinessPurpose.advance,
        occurredAt: DateTime(2026, 10, 23),
        primaryAmount: const Money(minorUnits: 10000),
        ownership: advanceOwnership(
          management: AdvanceManagement.itemized,
          ownerId: 'advance',
          scenario: AdvanceScenario.aa,
        ),
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
      );
      when(() => editService.editAdvance(any())).thenAnswer(
        (_) async => const PostedTransactionResult(transactionId: 'advance'),
      );

      final dispatcher = createTransactionDetailActionDispatcher(
        transaction: transaction,
        editService: editService,
        updateService: updateService,
        installmentAppService: installmentAppService,
        repaymentAppService: repaymentAppService,
      );
      final outcome = await dispatcher.changeSettlementAccount('cash');

      expect(outcome, isA<UiActionSuccess<void>>());
      verify(() => editService.editAdvance(any())).called(1);
    },
  );

  test(
    'advance refund inheritance keeps ledger actions in the default dispatcher',
    () async {
      final transaction = TransactionReadModel(
        id: 'refund',
        parentTransactionId: 'advance',
        businessPurpose: BusinessPurpose.refund,
        occurredAt: DateTime(2026, 10, 23),
        primaryAmount: const Money(minorUnits: 2000),
        ownership: advanceOwnership(
          management: AdvanceManagement.itemized,
          ownerId: 'advance',
          scenario: AdvanceScenario.aa,
        ),
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
      );
      when(() => editService.editRefund(any())).thenAnswer(
        (_) async => const PostedTransactionResult(transactionId: 'refund'),
      );

      final dispatcher = createTransactionDetailActionDispatcher(
        transaction: transaction,
        editService: editService,
        updateService: updateService,
        installmentAppService: installmentAppService,
        repaymentAppService: repaymentAppService,
      );
      final outcome = await dispatcher.changeSettlementAccount('cash');

      expect(outcome, isA<UiActionSuccess<void>>());
      verify(() => editService.editRefund(any())).called(1);
    },
  );
}
