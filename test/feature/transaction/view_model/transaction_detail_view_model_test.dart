import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/orchestration_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail_state.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_detail_view_model.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/credit/provider/installment_query_providers.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  group('TransactionDetailViewModel', () {
    test('derives dynamic state for daily expense', () async {
      final detail = _detail(
        purpose: BusinessPurpose.dailyExpense,
        entries: [
          _entry('cash', EntryDirection.credit),
          _entry('food', EntryDirection.debit),
        ],
        refundedTotal: const Money(minorUnits: 500),
      );
      final container = _container(detail: detail);

      final state = await _readState(container);

      final loaded = state as TransactionDetailLoaded;
      expect(loaded.hero.title, '午餐');
      expect(loaded.hero.iconKey, 'meal');
      expect(loaded.refund?.hasRefund, true);
      expect(loaded.showExcludeStats, true);
      expect(loaded.showExcludeBudget, true);
      expect(loaded.actionButtons.map((button) => button.kind), [
        DetailActionKind.refund,
        DetailActionKind.edit,
      ]);
      final accountRow = loaded.accountRows.singleWhere(
        (row) => row.label == '收支账户',
      );
      expect(accountRow.editPurpose, AccountSelectionPurpose.expenseSettlement);
      expect(accountRow.permission, isA<DetailEditAllowed>());
    });

    test(
      'dispatches plain expense account change to ledger edit service',
      () async {
        final editService = _FakeTransactionEditAppService();
        final container = _container(
          detail: _detail(purpose: BusinessPurpose.dailyExpense),
          editService: editService,
        );
        await _readState(container);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .changeAccount(AccountSelectionPurpose.expenseSettlement, 'bank');

        expect(outcome, isA<UiActionSuccess<void>>());
        final command = editService.expenseCommands.single;
        expect(command.transactionId, 'tx-1');
        expect(command.settlementAllocations!.single.accountId, 'bank');
        expect(
          command.settlementAllocations!.single.amount,
          const Money(minorUnits: 10000),
        );
      },
    );

    test('updates tags through the common transaction capability', () async {
      final update = _FakeTransactionUpdateAppService();
      final container = _container(
        detail: _detail(purpose: BusinessPurpose.dailyExpense),
        update: update,
      );
      await _readState(container);

      final outcome = await container
          .read(transactionDetailViewModelProvider('tx-1').notifier)
          .changeTags({'tag-1', 'tag-2'});

      expect(outcome, isA<UiActionSuccess<void>>());
      final command = update.tagCommands.single;
      expect(command.transactionId, 'tx-1');
      expect(command.tagIds, {'tag-1', 'tag-2'});
    });

    test(
      'dispatches plain income account change to ledger edit service',
      () async {
        final editService = _FakeTransactionEditAppService();
        final container = _container(
          detail: _detail(
            purpose: BusinessPurpose.dailyIncome,
            entries: [
              _entry('cash', EntryDirection.debit),
              _entry('salary', EntryDirection.credit),
            ],
          ),
          editService: editService,
        );
        await _readState(container);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .changeAccount(AccountSelectionPurpose.settlement, 'bank');

        expect(outcome, isA<UiActionSuccess<void>>());
        final command = editService.incomeCommands.single;
        expect(command.transactionId, 'tx-1');
        expect(command.settlementAllocations?.single.accountId, 'bank');
        expect(
          command.settlementAllocations?.single.amount,
          const Money(minorUnits: 10000),
        );
      },
    );

    test(
      'dispatches installment disbursement account change to credit app service',
      () async {
        final installment = _FakeInstallmentContractAppService();
        final detail = _detail(
          purpose: BusinessPurpose.borrowing,
          ownership: const TransactionOwnership(
            ownerType: installmentOwnerType,
            ownerId: 'contract-1',
          ),
          entries: [
            _entry('loan', EntryDirection.credit),
            _entry('cash', EntryDirection.debit),
          ],
        );
        final container = _container(detail: detail, installment: installment);
        await _readState(container);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .changeAccount(AccountSelectionPurpose.repaymentSource, 'bank');

        expect(outcome, isA<UiActionSuccess<void>>());
        final command = installment.updateContractCommands.single;
        expect(command.contractId, 'contract-1');
        expect(command.disbursementAccountId, 'bank');
      },
    );

    test(
      'maps installment disbursement update exception to action failure',
      () async {
        final installment = _FakeInstallmentContractAppService(
          updateContractException: BusinessException(
            CreditErrorCode.contractPersistenceConflict,
            message: '合同数据已变化，请刷新后重试。',
          ),
        );
        final detail = _detail(
          purpose: BusinessPurpose.borrowing,
          ownership: const TransactionOwnership(
            ownerType: installmentOwnerType,
            ownerId: 'contract-1',
          ),
        );
        final container = _container(detail: detail, installment: installment);
        await _readState(container);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .changeNote('new note');

        expect(outcome, isA<UiActionFailure<void>>());
        final failure = outcome as UiActionFailure<void>;
        expect(
          failure.error.code,
          CreditErrorCode.contractPersistenceConflict.code,
        );
        expect(failure.error.message, '合同数据已变化，请刷新后重试。');
      },
    );

    test(
      'routes credit repayment owner edits and delete to repayment app service',
      () async {
        final repayment = _FakeBillRepaymentAppService();
        final detail = _detail(
          purpose: BusinessPurpose.debtRepayment,
          ownership: const TransactionOwnership(
            ownerType: creditRepaymentOwnerType,
            ownerId: 'repayment-1',
          ),
          entries: [
            _entry('cash', EntryDirection.credit),
            _entry('loan', EntryDirection.debit),
          ],
        );
        final container = _container(detail: detail, repayment: repayment);

        final state = await _readState(container);
        final loaded = state as TransactionDetailLoaded;
        expect(
          loaded.behavior.editRoute,
          '/repayments/repayment-1/edit?transactionId=tx-1',
        );
        expect(loaded.behavior.canEditOccurredAt, isA<DetailEditAllowed>());
        expect(loaded.behavior.canEditNote, isA<DetailEditAllowed>());
        final accountRow = loaded.accountRows.singleWhere(
          (row) => row.label == '还款账户',
        );
        expect(accountRow.permission, isA<DetailEditAllowed>());

        final notifier = container.read(
          transactionDetailViewModelProvider('tx-1').notifier,
        );
        expect(
          await notifier.changeOccurredAt(DateTime(2026, 2, 1)),
          isA<UiActionSuccess<void>>(),
        );
        expect(
          await notifier.changeNote(' repayment note '),
          isA<UiActionSuccess<void>>(),
        );
        expect(
          await notifier.changeAccount(
            AccountSelectionPurpose.repaymentSource,
            'bank',
          ),
          isA<UiActionSuccess<void>>(),
        );
        expect(await notifier.delete(), isA<UiActionSuccess<void>>());

        expect(repayment.editCommands, hasLength(3));
        expect(repayment.editCommands[0].repaymentId, 'repayment-1');
        expect(repayment.editCommands[0].occurredAt, DateTime(2026, 2, 1));
        expect(
          (repayment.editCommands[1].note as PatchSet<String?>).value,
          'repayment note',
        );
        expect(repayment.editCommands[2].paidFromAccountId, 'bank');
        expect(repayment.deleteCommands.single.repaymentId, 'repayment-1');
      },
    );

    test(
      'maps installment disbursement regular exception to unknown failure',
      () async {
        final installment = _FakeInstallmentContractAppService(
          updateContractException: Exception('database failed'),
        );
        final detail = _detail(
          purpose: BusinessPurpose.borrowing,
          ownership: const TransactionOwnership(
            ownerType: installmentOwnerType,
            ownerId: 'contract-1',
          ),
        );
        final container = _container(detail: detail, installment: installment);
        await _readState(container);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .changeNote('new note');

        expect(outcome, isA<UiActionFailure<void>>());
        final failure = outcome as UiActionFailure<void>;
        expect(failure.error.code, 'unknown');
        expect(failure.error.message, '未知错误，请稍后重试。');
      },
    );

    for (final purpose in BusinessPurpose.values) {
      test(
        'allows group reporting flags for top-level ${purpose.name}',
        () async {
          final update = _FakeTransactionUpdateAppService();
          final container = _container(
            detail: _detail(purpose: purpose),
            update: update,
          );
          final state = await _readState(container) as TransactionDetailLoaded;
          expect(state.showExcludeStats, isTrue);
          expect(state.showExcludeBudget, isTrue);
          expect(state.canEditReportingFlags, isTrue);
          final notifier = container.read(
            transactionDetailViewModelProvider('tx-1').notifier,
          );
          expect(
            await notifier.toggleExcludeStats(true),
            isA<UiActionSuccess<void>>(),
          );
          expect(
            await notifier.toggleExcludeBudget(true),
            isA<UiActionSuccess<void>>(),
          );
          expect(update.reportingFlagCommands, hasLength(2));
        },
      );
    }

    test(
      'child reporting flags are read only and never reach the update service',
      () async {
        final update = _FakeTransactionUpdateAppService();
        final container = _container(
          detail: _detail(
            purpose: BusinessPurpose.refund,
            parentTransactionId: 'parent',
          ),
          update: update,
        );
        final state = await _readState(container) as TransactionDetailLoaded;
        expect(state.canEditReportingFlags, isFalse);
        expect(state.behavior.canEditTags, isA<DetailEditDenied>());
        final notifier = container.read(
          transactionDetailViewModelProvider('tx-1').notifier,
        );
        expect(
          await notifier.toggleExcludeStats(true),
          isA<UiActionFailure<void>>(),
        );
        expect(
          await notifier.toggleExcludeBudget(true),
          isA<UiActionFailure<void>>(),
        );
        expect(
          await notifier.changeTags({'tag-1'}),
          isA<UiActionFailure<void>>(),
        );
        expect(update.reportingFlagCommands, isEmpty);
        expect(update.tagCommands, isEmpty);
      },
    );

    test(
      'business-owned transactions use common reporting and tag updates',
      () async {
        final update = _FakeTransactionUpdateAppService();
        final container = _container(
          detail: _detail(
            purpose: BusinessPurpose.debtRepayment,
            ownership: const TransactionOwnership(
              ownerType: creditRepaymentOwnerType,
              ownerId: 'repayment',
            ),
          ),
          update: update,
        );
        await _readState(container);
        final notifier = container.read(
          transactionDetailViewModelProvider('tx-1').notifier,
        );
        expect(
          await notifier.toggleExcludeStats(true),
          isA<UiActionSuccess<void>>(),
        );
        expect(
          await notifier.toggleExcludeBudget(true),
          isA<UiActionSuccess<void>>(),
        );
        expect(
          await notifier.changeTags({'travel'}),
          isA<UiActionSuccess<void>>(),
        );
        expect(update.reportingFlagCommands, hasLength(2));
        expect(update.tagCommands.single.tagIds, {'travel'});
      },
    );

    test(
      'transfer edits the selected account without changing the opposite side',
      () async {
        final editing = _FakeTransactionEditAppService();
        final container = _container(
          detail: _detail(purpose: BusinessPurpose.transfer),
          editService: editing,
        );
        await _readState(container);
        final notifier = container.read(
          transactionDetailViewModelProvider('tx-1').notifier,
        );
        expect(
          await notifier.changeAccount(
            AccountSelectionPurpose.settlement,
            'bank',
            currentAccountId: 'cash',
          ),
          isA<UiActionSuccess<void>>(),
        );
        final command = editing.transferCommands.single;
        expect(command.fromAccountId, 'bank');
        expect(command.toAccountId, isNull);
        expect(command.feeAmount, isNull);
        expect(
          await notifier.changeAccount(
            AccountSelectionPurpose.settlement,
            'bank',
          ),
          isA<UiActionFailure<void>>(),
        );
        expect(editing.transferCommands, hasLength(1));
      },
    );

    for (final purpose in [
      BusinessPurpose.refund,
      BusinessPurpose.advanceCollection,
      BusinessPurpose.advanceSettlement,
    ]) {
      test('supports single receipt account editing for $purpose', () async {
        final editing = _FakeTransactionEditAppService();
        final container = _container(
          detail: _detail(purpose: purpose, parentTransactionId: 'parent'),
          editService: editing,
        );
        final state = await _readState(container) as TransactionDetailLoaded;
        expect(
          state.accountRows.first.editPurpose,
          AccountSelectionPurpose.settlement,
        );
        final notifier = container.read(
          transactionDetailViewModelProvider('tx-1').notifier,
        );
        expect(
          await notifier.changeAccount(
            AccountSelectionPurpose.settlement,
            'bank',
          ),
          isA<UiActionSuccess<void>>(),
        );
        final allocations = switch (purpose) {
          BusinessPurpose.refund =>
            editing.refundCommands.single.settlementAllocations!,
          BusinessPurpose.advanceCollection =>
            editing.receiptCommands.single.settlementAllocations!,
          _ => editing.closeCommands.single.settlementAllocations!,
        };
        expect(allocations.single.accountId, 'bank');
        expect(allocations.single.amount, const Money(minorUnits: 10000));
      });
    }

    test('maps update exception to UI action failure', () async {
      final update = _FakeTransactionUpdateAppService(
        reportingFlagException: BusinessException(
          LedgerErrorCode.transactionNotEditable,
          message: '交易当前不可编辑',
        ),
      );
      final container = _container(
        detail: _detail(purpose: BusinessPurpose.dailyIncome),
        update: update,
      );
      await _readState(container);

      final outcome = await container
          .read(transactionDetailViewModelProvider('tx-1').notifier)
          .toggleExcludeStats(true);

      expect(outcome, isA<UiActionFailure<void>>());
      final failure = outcome as UiActionFailure<void>;
      expect(failure.error.code, LedgerErrorCode.transactionNotEditable.code);
      expect(failure.error.message, '交易当前不可编辑');
    });

    test(
      'exposes bad debt flags like expense and debt relief like income',
      () async {
        final badDebt =
            await _readState(
                  _container(detail: _detail(purpose: BusinessPurpose.badDebt)),
                )
                as TransactionDetailLoaded;
        final reliefUpdate = _FakeTransactionUpdateAppService();
        final reliefContainer = _container(
          detail: _detail(purpose: BusinessPurpose.debtRelief),
          update: reliefUpdate,
        );
        final relief =
            await _readState(reliefContainer) as TransactionDetailLoaded;

        expect(badDebt.showExcludeStats, isTrue);
        expect(badDebt.showExcludeBudget, isTrue);
        expect(relief.showExcludeStats, isTrue);
        expect(relief.showExcludeBudget, isTrue);

        final outcome = await reliefContainer
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .toggleExcludeStats(true);
        expect(outcome, isA<UiActionSuccess<void>>());
        expect(
          reliefUpdate.reportingFlagCommands.single.isExcludedFromStats,
          isTrue,
        );
      },
    );

    test(
      'updates plain expense occurred time through the ledger service',
      () async {
        final update = _FakeTransactionUpdateAppService();
        final container = _container(
          detail: _detail(purpose: BusinessPurpose.dailyExpense),
          update: update,
        );
        await _readState(container);

        final occurredAt = DateTime(2026, 2, 2, 9);
        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .changeOccurredAt(occurredAt);

        expect(outcome, isA<UiActionSuccess<void>>());
        expect(update.basicInfoCommands.single.occurredAt, occurredAt);
      },
    );

    test(
      'purchase transaction time is editable without updating the contract date',
      () async {
        final update = _FakeTransactionUpdateAppService();
        final installment = _FakeInstallmentContractAppService();
        final container = _container(
          detail: _detail(
            purpose: BusinessPurpose.dailyExpense,
            ownership: const TransactionOwnership(
              ownerType: installmentOwnerType,
              ownerId: 'contract-1',
            ),
          ),
          update: update,
          installment: installment,
        );
        final loaded = await _readState(container) as TransactionDetailLoaded;
        expect(loaded.behavior.canEditOccurredAt, isA<DetailEditAllowed>());

        final occurredAt = DateTime(2026, 2, 4, 10);
        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .changeOccurredAt(occurredAt);

        expect(outcome, isA<UiActionSuccess<void>>());
        expect(update.basicInfoCommands.single.occurredAt, occurredAt);
        expect(installment.updateContractCommands, isEmpty);
      },
    );

    test(
      'purchase note updates the transaction instead of the contract',
      () async {
        final update = _FakeTransactionUpdateAppService();
        final installment = _FakeInstallmentContractAppService();
        final container = _container(
          detail: _detail(
            purpose: BusinessPurpose.dailyExpense,
            ownership: const TransactionOwnership(
              ownerType: installmentOwnerType,
              ownerId: 'purchase-contract',
            ),
          ),
          update: update,
          installment: installment,
        );
        await _readState(container);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .changeNote(' purchase note ');

        expect(outcome, isA<UiActionSuccess<void>>());
        expect(
          (update.basicInfoCommands.single.note as PatchSet<String?>).value,
          'purchase note',
        );
        expect(installment.updateContractCommands, isEmpty);
      },
    );

    test(
      'purchase transaction deletion uses the consumption installment module',
      () async {
        final consumption = _FakeConsumptionInstallmentAppService();
        final container = _container(
          detail: _detail(
            purpose: BusinessPurpose.dailyExpense,
            ownership: const TransactionOwnership(
              ownerType: installmentOwnerType,
              ownerId: 'purchase-contract',
            ),
          ),
          consumption: consumption,
        );
        await _readState(container);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .delete();

        expect(outcome, isA<UiActionSuccess<void>>());
        expect(
          consumption.installmentDeleteCommands.single.contractId,
          'purchase-contract',
        );
      },
    );

    test(
      'borrowing transaction deletion uses the disbursement installment module',
      () async {
        final disbursement = _FakeDisbursementInstallmentAppService();
        final container = _container(
          detail: _detail(
            purpose: BusinessPurpose.borrowing,
            ownership: const TransactionOwnership(
              ownerType: installmentOwnerType,
              ownerId: 'loan-contract',
            ),
          ),
          disbursement: disbursement,
        );
        await _readState(container);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .delete();

        expect(outcome, isA<UiActionSuccess<void>>());
        expect(disbursement.deleteCommands.single.contractId, 'loan-contract');
      },
    );

    test(
      'updates installment refund posted time through refund edit',
      () async {
        final refunds = _FakeConsumptionInstallmentAppService();
        final detail = _detail(
          purpose: BusinessPurpose.refund,
          parentTransactionId: 'parent',
          ownership: const TransactionOwnership(
            ownerType: installmentOwnerType,
            ownerId: 'purchase-contract',
          ),
        );
        final container = _container(detail: detail, consumption: refunds);
        final loaded = await _readState(container) as TransactionDetailLoaded;

        expect(loaded.behavior.canEditPostedAt, isA<DetailEditAllowed>());
        final postedAt = DateTime(2026, 2, 5, 11);
        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .changePostedAt(postedAt);

        expect(outcome, isA<UiActionSuccess<void>>());
        expect(refunds.editCommands.single.postedAt, postedAt);
        expect(refunds.editCommands.single.amount, isNull);
      },
    );

    test(
      'refreshes contract activity after deleting installment refund',
      () async {
        final refunds = _FakeConsumptionInstallmentAppService();
        var activityLoads = 0;
        final detail = _detail(
          purpose: BusinessPurpose.refund,
          parentTransactionId: 'parent',
          ownership: const TransactionOwnership(
            ownerType: installmentOwnerType,
            ownerId: 'purchase-contract',
          ),
        );
        final container = _container(
          detail: detail,
          consumption: refunds,
          activityLoader: (_) async {
            activityLoads++;
            return const [];
          },
        );
        await _readState(container);
        final activityProvider = installmentActivitiesProvider(
          'purchase-contract',
        );
        final activitySubscription = container.listen(
          activityProvider,
          (_, _) {},
        );
        addTearDown(activitySubscription.close);
        await container.read(activityProvider.future);
        expect(activityLoads, 1);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .delete();

        expect(outcome, isA<UiActionSuccess<void>>());
        expect(refunds.deleteCommands.single.transactionId, 'tx-1');
        await container.read(activityProvider.future);
        expect(activityLoads, 2);
      },
    );

    test('updates posted time through the ledger basic info service', () async {
      final update = _FakeTransactionUpdateAppService();
      final container = _container(
        detail: _detail(purpose: BusinessPurpose.dailyExpense),
        update: update,
      );
      await _readState(container);

      final postedAt = DateTime(2026, 2, 3, 10);
      final outcome = await container
          .read(transactionDetailViewModelProvider('tx-1').notifier)
          .changePostedAt(postedAt);

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(update.basicInfoCommands.single.postedAt, postedAt);
    });

    test('submits advance close command', () async {
      final orchestration = _FakeAdvanceOrchestrationService();
      final detail = _detail(
        purpose: BusinessPurpose.advance,
        entries: [
          _entry('cash', EntryDirection.credit),
          _entry('company', EntryDirection.debit),
          _entry('food', EntryDirection.debit),
        ],
        advanceSummary: const AdvanceSummary(
          advanceAmount: Money(minorUnits: 10000),
          receivedAmount: Money(minorUnits: 3000),
          outstanding: Money(minorUnits: 7000),
          isClosed: false,
        ),
      );
      final container = _container(
        detail: detail,
        orchestration: orchestration,
      );
      await _readState(container);

      final outcome = await container
          .read(transactionDetailViewModelProvider('tx-1').notifier)
          .submitAdvance(
            AdvanceSubmitInput(
              amount: const Money(minorUnits: 7000),
              receiveAccountId: 'bank',
              occurredAt: DateTime(2026, 1, 2, 9),
              settleAdvance: true,
              noteText: ' done ',
            ),
          );

      expect(outcome, isA<UiActionSuccess<void>>());
      final command = orchestration.closeCommands.single;
      expect(command.advanceTransactionId, 'tx-1');
      expect(command.receivableAccountId, 'company');
      expect(command.settlementAllocations.single.accountId, 'bank');
      expect(command.actualReceivedAmount, const Money(minorUnits: 7000));
      expect(command.note, 'done');
    });

    test(
      'submits a single remaining category for an advance shortfall',
      () async {
        final orchestration = _FakeAdvanceOrchestrationService();
        final detail = _detail(
          purpose: BusinessPurpose.advance,
          entries: [
            _entry('cash', EntryDirection.credit),
            _entry('company', EntryDirection.debit),
            _entry('food', EntryDirection.debit),
          ],
          refundSummary: const RefundSummary(
            refundedTotal: Money(minorUnits: 0),
            originalCategoryAllocations: [
              AccountAmountAllocation(
                accountId: 'food',
                amount: Money(minorUnits: 10000),
              ),
            ],
            refundedCategoryAllocations: [],
          ),
          advanceSummary: const AdvanceSummary(
            advanceAmount: Money(minorUnits: 10000),
            receivedAmount: Money(minorUnits: 0),
            outstanding: Money(minorUnits: 7000),
            isClosed: false,
          ),
        );
        final container = _container(
          detail: detail,
          orchestration: orchestration,
        );
        await _readState(container);

        final outcome = await container
            .read(transactionDetailViewModelProvider('tx-1').notifier)
            .submitAdvance(
              AdvanceSubmitInput(
                amount: const Money(minorUnits: 6000),
                receiveAccountId: 'bank',
                occurredAt: DateTime(2026, 1, 2, 9),
                settleAdvance: true,
              ),
            );

        expect(outcome, isA<UiActionSuccess<void>>());
        final command = orchestration.closeCommands.single;
        expect(command.gapExpenseAllocations, hasLength(1));
        expect(command.gapExpenseAllocations.single.accountId, 'food');
        expect(
          command.gapExpenseAllocations.single.amount,
          const Money(minorUnits: 1000),
        );
      },
    );

    test('unknown owner still allows note and posted time edits', () async {
      final update = _FakeTransactionUpdateAppService();
      final detail = _detail(
        purpose: BusinessPurpose.dailyExpense,
        ownership: const TransactionOwnership(
          ownerType: 'unknown-owner',
          ownerId: 'unknown',
        ),
      );
      final container = _container(detail: detail, update: update);

      final state = await _readState(container);
      final loaded = state as TransactionDetailLoaded;
      expect(loaded.behavior.canEditPostedAt, isA<DetailEditAllowed>());
      expect(loaded.showExcludeStats, true);
      final editAction = loaded.actionButtons.singleWhere(
        (button) => button.kind == DetailActionKind.edit,
      );
      expect(editAction.enabled, false);

      final accountOutcome = await container
          .read(transactionDetailViewModelProvider('tx-1').notifier)
          .changeAccount(AccountSelectionPurpose.settlement, 'bank');
      expect(accountOutcome, isA<UiActionFailure<void>>());

      final noteOutcome = await container
          .read(transactionDetailViewModelProvider('tx-1').notifier)
          .changeNote('new note');
      expect(noteOutcome, isA<UiActionSuccess<void>>());
      final postedOutcome = await container
          .read(transactionDetailViewModelProvider('tx-1').notifier)
          .changePostedAt(DateTime(2026, 3, 1));
      expect(postedOutcome, isA<UiActionSuccess<void>>());
      expect(update.basicInfoCommands.first.note, isNotNull);
      expect(update.basicInfoCommands.last.postedAt, DateTime(2026, 3, 1));
    });
  });
}

ProviderContainer _container({
  required TransactionReadModel detail,
  _FakeTransactionUpdateAppService? update,
  _FakeTransactionEditAppService? editService,
  _FakeTransactionPostingAppService? posting,
  _FakeAdvanceOrchestrationService? orchestration,
  _FakeInstallmentContractAppService? installment,
  _FakeDisbursementInstallmentAppService? disbursement,
  _FakeBillRepaymentAppService? repayment,
  _FakeConsumptionInstallmentAppService? consumption,
  Future<List<ContractActivity>> Function(String contractId)? activityLoader,
}) {
  final accounts = <String, Account>{
    'cash': _account('cash', '现金', iconKey: 'cash'),
    'bank': _account('bank', '银行卡', iconKey: 'account'),
    'company': _account(
      'company',
      '公司报销',
      subtype: AccountSubtype.receivable,
      iconKey: 'reimburse',
    ),
    'loan': _account('loan', '贷款', type: AccountType.liability),
    'food': _account('food', '午餐', type: AccountType.expense, iconKey: 'meal'),
    'salary': _account('salary', '工资', type: AccountType.income),
  };
  final container = ProviderContainer(
    overrides: [
      transactionDetailProvider(
        'tx-1',
      ).overrideWith((ref) => Stream.value(detail)),
      if (detail.parentTransactionId != null)
        transactionDetailProvider(
          detail.parentTransactionId!,
        ).overrideWith((ref) => Stream.value(_detail())),
      accountLookupProvider.overrideWith(
        (ref) => Stream.value(AccountLookup(accounts)),
      ),
      accountQueryServiceProvider.overrideWith(
        (ref) => _FakeAccountQueryService(accounts),
      ),
      transactionUpdateAppServiceProvider.overrideWithValue(
        update ?? _FakeTransactionUpdateAppService(),
      ),
      transactionEditAppServiceProvider.overrideWithValue(
        editService ?? _FakeTransactionEditAppService(),
      ),
      transactionPostingAppServiceProvider.overrideWithValue(
        posting ?? _FakeTransactionPostingAppService(),
      ),
      advanceOrchestrationAppServiceProvider.overrideWithValue(
        orchestration ?? _FakeAdvanceOrchestrationService(),
      ),
      repaymentOwnerQueryProvider.overrideWithValue(
        const _FakeRepaymentOwnerQuery(),
      ),
      installmentContractAppServiceProvider.overrideWithValue(
        installment ?? _FakeInstallmentContractAppService(),
      ),
      disbursementInstallmentAppServiceProvider.overrideWithValue(
        disbursement ?? _FakeDisbursementInstallmentAppService(),
      ),
      billRepaymentAppServiceProvider.overrideWithValue(
        repayment ?? _FakeBillRepaymentAppService(),
      ),
      installmentPrepaymentAppServiceProvider.overrideWithValue(
        _FakeInstallmentPrepaymentAppService(),
      ),
      accountRepaymentAppServiceProvider.overrideWithValue(
        _FakeAccountRepaymentAppService(),
      ),
      consumptionInstallmentAppServiceProvider.overrideWithValue(
        consumption ?? _FakeConsumptionInstallmentAppService(),
      ),
      if (activityLoader != null)
        installmentActivitiesProvider.overrideWith(
          (ref, contractId) => activityLoader(contractId),
        ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<TransactionDetailUiState> _readState(ProviderContainer container) {
  final subscription = container.listen(
    transactionDetailViewModelProvider('tx-1'),
    (_, _) {},
  );
  addTearDown(subscription.close);
  return container.read(transactionDetailViewModelProvider('tx-1').future);
}

TransactionReadModel _detail({
  BusinessPurpose purpose = BusinessPurpose.dailyExpense,
  TransactionOwnership? ownership,
  String? parentTransactionId,
  List<Entry>? entries,
  Money? refundedTotal,
  RefundSummary? refundSummary,
  AdvanceSummary? advanceSummary,
}) {
  final sourceEntries =
      entries ??
      [
        _entry('cash', EntryDirection.credit),
        _entry('food', EntryDirection.debit),
      ];
  final lines = purpose == BusinessPurpose.advance
      ? _advanceLines
      : [
          for (var index = 0; index < sourceEntries.length; index++)
            TransactionLine(
              id: 'line-$index',
              transactionId: 'tx-1',
              lineNo: index + 1,
              role: switch (purpose) {
                BusinessPurpose.dailyExpense =>
                  sourceEntries[index].accountId == 'food'
                      ? TransactionRole.category
                      : TransactionRole.settlementOut,
                BusinessPurpose.dailyIncome =>
                  sourceEntries[index].accountId == 'salary'
                      ? TransactionRole.category
                      : TransactionRole.settlementIn,
                BusinessPurpose.borrowing =>
                  sourceEntries[index].accountId == 'loan'
                      ? TransactionRole.liability
                      : TransactionRole.settlementIn,
                BusinessPurpose.debtRepayment =>
                  sourceEntries[index].accountId == 'loan'
                      ? TransactionRole.liability
                      : TransactionRole.settlementOut,
                _ =>
                  sourceEntries[index].direction == EntryDirection.debit
                      ? TransactionRole.settlementIn
                      : TransactionRole.settlementOut,
              },
              accountId: sourceEntries[index].accountId,
              amount: sourceEntries[index].amount,
            ),
        ];
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'tx-1',
      parentTransactionId: parentTransactionId,
      businessPurpose: purpose,
      occurredAt: DateTime(2026, 1, 1, 8),
      primaryAmount: const Money(minorUnits: 10000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      ownership: ownership,
      lines: lines,
    ),
    createdAt: DateTime(2026, 1, 1, 8, 1),
    lines: lines,
    refundSummary:
        refundSummary ??
        (refundedTotal == null
            ? null
            : RefundSummary(
                refundedTotal: refundedTotal,
                originalCategoryAllocations: const [],
                refundedCategoryAllocations: const [],
              )),
    advanceSummary: advanceSummary,
    children: [
      if (refundedTotal != null)
        TransactionReadModel(
          id: 'refund',
          parentTransactionId: 'tx-1',
          businessPurpose: BusinessPurpose.refund,
          occurredAt: DateTime(2026, 1, 2),
          primaryAmount: refundedTotal,
          isExcludedFromStats: false,
          isExcludedFromBudget: false,
          lines: [
            TransactionLine(
              id: 'refund-settlement',
              transactionId: 'refund',
              lineNo: 1,
              role: TransactionRole.settlementIn,
              accountId: 'cash',
              amount: refundedTotal,
            ),
          ],
        ),
      if (advanceSummary != null &&
          advanceSummary.receivedAmount.minorUnits > 0)
        TransactionReadModel(
          id: advanceSummary.isClosed ? 'close' : 'receipt',
          parentTransactionId: 'tx-1',
          businessPurpose: advanceSummary.isClosed
              ? BusinessPurpose.advanceSettlement
              : BusinessPurpose.advanceCollection,
          occurredAt: DateTime(2026, 1, 2),
          primaryAmount: advanceSummary.receivedAmount,
          isExcludedFromStats: false,
          isExcludedFromBudget: false,
          lines: [
            TransactionLine(
              id: 'advance-settlement',
              transactionId: advanceSummary.isClosed ? 'close' : 'receipt',
              lineNo: 1,
              role: TransactionRole.settlementIn,
              accountId: 'cash',
              amount: advanceSummary.receivedAmount,
            ),
          ],
        ),
    ],
  );
}

Entry _entry(String accountId, EntryDirection direction) {
  return Entry(
    id: 'entry-$accountId-$direction',
    transactionId: 'tx-1',
    accountId: accountId,
    direction: direction,
    amount: const Money(minorUnits: 10000),
  );
}

Account _account(
  String id,
  String name, {
  AccountType type = AccountType.asset,
  AccountSubtype? subtype,
  String? iconKey,
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    subtype: subtype,
    iconKey: iconKey,
    balance: const Money(minorUnits: 0),
  );
}

PostedTransactionResult _posted() {
  return const PostedTransactionResult(transactionId: 'tx-1');
}

class _FakeAccountQueryService implements AccountQueryService {
  _FakeAccountQueryService(this._accountsById);

  final Map<String, Account> _accountsById;

  @override
  Future<Map<String, Account>> findAccountsById() async => _accountsById;

  @override
  Future<List<Account>> findAccounts(Set<AccountType> types) async {
    return _accountsById.values
        .where((account) => types.contains(account.type))
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeTransactionUpdateAppService implements TransactionUpdateAppService {
  _FakeTransactionUpdateAppService({this.reportingFlagException});

  final Object? reportingFlagException;
  final tagCommands = <UpdateTransactionTagsCommand>[];

  @override
  Future<PostedTransactionResult> updateTags(
    UpdateTransactionTagsCommand command,
  ) async {
    tagCommands.add(command);
    return const PostedTransactionResult(transactionId: 'tx-1');
  }

  final basicInfoCommands = <UpdateTransactionBasicInfoCommand>[];
  final reportingFlagCommands = <UpdateTransactionReportingFlagCommand>[];

  @override
  Future<PostedTransactionResult> updateBasicInfo(
    UpdateTransactionBasicInfoCommand command,
  ) async {
    basicInfoCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> updateReportingFlag(
    UpdateTransactionReportingFlagCommand command,
  ) async {
    reportingFlagCommands.add(command);
    final exception = reportingFlagException;
    if (exception != null) throw exception;
    return _posted();
  }

  @override
  Future<PostedTransactionResult> updateOwnership(
    UpdateTransactionOwnershipCommand command,
  ) {
    throw UnimplementedError();
  }
}

class _FakeTransactionEditAppService implements TransactionEditAppService {
  final canceledTransactionIds = <String>[];
  final expenseCommands = <EditExpenseCommand>[];
  final incomeCommands = <EditIncomeCommand>[];
  final advanceCommands = <EditAdvanceCommand>[];
  final transferCommands = <EditTransferCommand>[];
  final refundCommands = <EditRefundCommand>[];
  final receiptCommands = <EditAdvanceCollectionCommand>[];
  final closeCommands = <EditAdvanceSettlementCommand>[];

  @override
  Future<void> deleteTransaction(DeleteTransactionCommand command) async {
    canceledTransactionIds.add(command.transactionId);
  }

  @override
  Future<PostedTransactionResult> editAdvance(
    EditAdvanceCommand command,
  ) async {
    advanceCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> editBorrowing(EditBorrowingCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editExpense(
    EditExpenseCommand command,
  ) async {
    expenseCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> editIncome(EditIncomeCommand command) async {
    incomeCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> editRefund(EditRefundCommand command) async {
    refundCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> editAdvanceSettlement(
    EditAdvanceSettlementCommand command,
  ) async {
    closeCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> editAdvanceCollection(
    EditAdvanceCollectionCommand command,
  ) async {
    receiptCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> editRepayment(EditRepaymentCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> editTransfer(
    EditTransferCommand command,
  ) async {
    transferCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> replaceTransactionCategory(
    ReplaceTransactionCategoryCommand command,
  ) {
    throw UnimplementedError();
  }
}

class _FakeRepaymentOwnerQuery implements RepaymentOwnerQuery {
  const _FakeRepaymentOwnerQuery();

  @override
  Future<RepaymentType?> findType(String repaymentId) async {
    return RepaymentType.bill;
  }
}

class _FakeAdvanceOrchestrationService
    implements AdvanceOrchestrationAppService {
  final closeCommands = <CreateAdvanceSettlementWorkflowCommand>[];

  @override
  Future<String> createSettlement(
    CreateAdvanceSettlementWorkflowCommand command,
  ) async {
    closeCommands.add(command);
    return 'close';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeTransactionPostingAppService
    implements TransactionPostingAppService {
  final receiptCommands = <CreateAdvanceCollectionCommand>[];
  final closeCommands = <CreateAdvanceSettlementCommand>[];

  @override
  Future<PostedTransactionResult> createAdvanceCollection(
    CreateAdvanceCollectionCommand command,
  ) async {
    receiptCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> settleAdvance(
    CreateAdvanceSettlementCommand command,
  ) async {
    closeCommands.add(command);
    return _posted();
  }

  @override
  Future<PostedTransactionResult> adjustBalance(AdjustBalanceCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createBorrowing(
    CreateBorrowingCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createExpense(CreateExpenseCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createOpeningBalance(
    CreateOpeningBalanceCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createRefund(CreateRefundCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createRepayment(
    CreateRepaymentCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createAdvance(CreateAdvanceCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createIncome(CreateIncomeCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createTransfer(
    CreateTransferCommand command,
  ) {
    throw UnimplementedError();
  }
}

class _FakeInstallmentContractAppService
    implements InstallmentContractAppService {
  _FakeInstallmentContractAppService({this.updateContractException});

  final Object? updateContractException;
  final updateContractCommands = <UpdateContractCommand>[];
  final deleteContractCommands = <DeleteContractCommand>[];

  Future<void> updateContract(UpdateContractCommand command) async {
    updateContractCommands.add(command);
    final exception = updateContractException;
    if (exception != null) throw exception;
  }

  @override
  Future<void> updateContractDetails(
    UpdateContractDetailsCommand command,
  ) async {
    updateContractCommands.add(
      UpdateContractCommand(
        contractId: command.contractId,
        name: command.name,
        disbursementAccountId: command.disbursementAccountId,
        note: command.note,
      ),
    );
    final exception = updateContractException;
    if (exception != null) throw exception;
  }

  Future<ContractRecalculationPreview> previewContractRecalculation(
    PreviewContractRecalculationCommand command,
  ) {
    throw UnimplementedError();
  }

  Future<void> skipSchedule(SkipInstallmentScheduleCommand command) {
    throw UnimplementedError();
  }

  Future<void> restoreSchedule(RestoreInstallmentScheduleCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteContract(DeleteContractCommand command) async {
    deleteContractCommands.add(command);
  }
}

class _FakeDisbursementInstallmentAppService
    implements DisbursementInstallmentAppService {
  final deleteCommands = <DeleteInstallmentCommand>[];

  @override
  Future<void> delete(DeleteInstallmentCommand command) async {
    deleteCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeBillRepaymentAppService implements BillRepaymentAppService {
  final editCommands = <EditCreditRepaymentTransactionCommand>[];
  final deleteCommands = <DeleteCreditRepaymentCommand>[];

  @override
  Future<void> editRepaymentTransaction(
    EditCreditRepaymentTransactionCommand command,
  ) async {
    editCommands.add(command);
  }

  @override
  Future<void> deleteRepayment(DeleteCreditRepaymentCommand command) async {
    deleteCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInstallmentPrepaymentAppService
    implements InstallmentPrepaymentAppService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccountRepaymentAppService implements AccountRepaymentAppService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeConsumptionInstallmentAppService
    implements ConsumptionInstallmentAppService {
  final createCommands = <CreateConsumptionInstallmentRefundCommand>[];
  final editCommands = <EditConsumptionInstallmentRefundCommand>[];
  final deleteCommands = <DeleteConsumptionInstallmentRefundCommand>[];
  final installmentDeleteCommands = <DeleteInstallmentCommand>[];

  @override
  Future<ConsumptionInstallmentRefundResult> createRefund(
    CreateConsumptionInstallmentRefundCommand command,
  ) async {
    createCommands.add(command);
    return ConsumptionInstallmentRefundResult(
      refundTransactionId: 'refund-1',
      principalReduction: Money.zero(),
    );
  }

  @override
  Future<ConsumptionInstallmentRefundResult> editRefund(
    EditConsumptionInstallmentRefundCommand command,
  ) async {
    editCommands.add(command);
    return ConsumptionInstallmentRefundResult(
      refundTransactionId: command.transactionId,
      principalReduction: Money.zero(),
    );
  }

  @override
  Future<Money> refundablePrincipal({
    required String contractId,
    required DateTime refundDate,
    String? excludedRefundTransactionId,
  }) async => Money.zero();

  @override
  Future<void> deleteRefund(
    DeleteConsumptionInstallmentRefundCommand command,
  ) async {
    deleteCommands.add(command);
  }

  @override
  Future<void> delete(DeleteInstallmentCommand command) async {
    installmentDeleteCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const _advanceLines = [
  TransactionLine(
    id: 'advance-category',
    transactionId: 'tx-1',
    lineNo: 1,
    role: TransactionRole.advanceExpenseCategory,
    accountId: 'food',
    amount: Money(minorUnits: 10000),
  ),
  TransactionLine(
    id: 'advance-out',
    transactionId: 'tx-1',
    lineNo: 2,
    role: TransactionRole.settlementOut,
    accountId: 'cash',
    amount: Money(minorUnits: 10000),
  ),
  TransactionLine(
    id: 'advance-receivable',
    transactionId: 'tx-1',
    lineNo: 3,
    role: TransactionRole.receivable,
    accountId: 'company',
    amount: Money(minorUnits: 10000),
  ),
];
