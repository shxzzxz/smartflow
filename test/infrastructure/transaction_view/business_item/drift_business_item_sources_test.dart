import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_read_repository.dart';
import 'package:smartflow/infrastructure/transaction_view/business_item/drift_advance_business_item_source.dart';
import 'package:smartflow/infrastructure/transaction_view/business_item/drift_amortization_business_item_source.dart';
import 'package:smartflow/infrastructure/transaction_view/business_item/drift_credit_business_item_source.dart';
import 'package:smartflow/infrastructure/transaction_view/business_item/drift_ledger_business_item_source.dart';

import '../../../helper/test_app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() => db.close());

  group('DriftLedgerBusinessItemSource', () {
    test(
      'returns only ownerless top-level anchors with filters and limits',
      () async {
        await _insertTransaction(
          db,
          id: 'ledger-old',
          occurredAt: DateTime(2026, 10, 1),
          counterpartyId: 'counterparty-1',
        );
        await _insertLine(
          db,
          id: 'ledger-old-food',
          transactionId: 'ledger-old',
          lineNo: 1,
          role: TransactionRole.category,
          accountId: 'food',
          amountMinor: 1000,
        );
        await _insertLine(
          db,
          id: 'ledger-old-cash',
          transactionId: 'ledger-old',
          lineNo: 2,
          role: TransactionRole.settlementOut,
          accountId: 'cash',
          amountMinor: 1000,
        );
        await db
            .into(db.tags)
            .insert(TagsCompanion.insert(id: 'tag-1', name: 'work'));
        await db
            .into(db.transactionTags)
            .insert(
              TransactionTagsCompanion.insert(
                transactionId: 'ledger-old',
                tagId: 'tag-1',
              ),
            );
        await _insertTransaction(
          db,
          id: 'ledger-new',
          occurredAt: DateTime(2026, 10, 3),
        );
        await _insertLine(
          db,
          id: 'ledger-new-travel',
          transactionId: 'ledger-new',
          lineNo: 1,
          role: TransactionRole.category,
          accountId: 'travel',
          amountMinor: 2000,
        );
        await _insertTransaction(
          db,
          id: 'owned',
          occurredAt: DateTime(2026, 10, 4),
          ownerType: 'orchestration.advance',
          ownerId: 'advance-1',
        );
        await _insertTransaction(
          db,
          id: 'child',
          occurredAt: DateTime(2026, 10, 5),
          parentTransactionId: 'ledger-new',
        );

        final source = DriftLedgerBusinessItemSource(db);
        final firstPage = await source.findAnchorPage(
          _query(limit: 1, occurredUntil: DateTime(2026, 11)),
        );

        expect(firstPage.hasMore, isTrue);
        expect(firstPage.anchors.first.anchorTransactionId, 'ledger-new');
        final secondPage = await source.findAnchorPage(
          _query(
            limit: 1,
            before: BusinessItemCursor(
              anchorAt: DateTime(2026, 10, 3),
              itemKey: const BusinessItemKey.transactionGroup('ledger-new'),
            ),
          ),
        );
        expect(secondPage.hasMore, isFalse);
        expect(secondPage.anchors.single.anchorTransactionId, 'ledger-old');

        final filtered = await source.findAnchorPage(
          _query(categoryAccountIds: const {'food'}),
        );
        expect(filtered.anchors.map((anchor) => anchor.anchorTransactionId), [
          'ledger-old',
        ]);
        expect(
          (await source.findAnchorPage(
            _query(settlementAccountIds: const {'cash'}),
          )).anchors.map((anchor) => anchor.anchorTransactionId),
          ['ledger-old'],
        );
        expect(
          (await source.findAnchorPage(
            _query(tagIds: const {'tag-1'}),
          )).anchors.map((anchor) => anchor.anchorTransactionId),
          ['ledger-old'],
        );
        expect(
          (await source.findAnchorPage(
            _query(untaggedOnly: true),
          )).anchors.map((anchor) => anchor.anchorTransactionId),
          ['ledger-new'],
        );
        expect(
          (await source.findAnchorPage(
            _query(counterpartyId: 'counterparty-1'),
          )).anchors.map((anchor) => anchor.anchorTransactionId),
          ['ledger-old'],
        );
      },
    );
  });

  group('DriftAdvanceBusinessItemSource', () {
    test(
      'anchors the top-level advance and batches its outstanding facts',
      () async {
        await db
            .into(db.advanceCases)
            .insert(
              AdvanceCasesCompanion.insert(
                id: 'advance-1',
                scenario: AdvanceScenario.aa,
                trackingMode: AdvanceTrackingMode.itemized,
                aaPeopleCount: const Value(3),
              ),
            );
        await _insertTransaction(
          db,
          id: 'advance-parent',
          occurredAt: DateTime(2026, 10, 10),
          businessPurpose: BusinessPurpose.advance,
          ownerType: 'orchestration.advance',
          ownerId: 'advance-1',
          amountMinor: 10000,
        );
        await _insertLine(
          db,
          id: 'advance-receivable',
          transactionId: 'advance-parent',
          lineNo: 1,
          role: TransactionRole.receivable,
          accountId: 'receivable',
          amountMinor: 9000,
        );
        await _insertTransaction(
          db,
          id: 'advance-refund',
          occurredAt: DateTime(2026, 10, 11),
          businessPurpose: BusinessPurpose.refund,
          parentTransactionId: 'advance-parent',
          ownerType: 'orchestration.advance',
          ownerId: 'advance-1',
        );
        await _insertLine(
          db,
          id: 'advance-refund-receivable',
          transactionId: 'advance-refund',
          lineNo: 1,
          role: TransactionRole.receivable,
          accountId: 'receivable',
          amountMinor: 1000,
        );
        await _insertTransaction(
          db,
          id: 'advance-collection',
          occurredAt: DateTime(2026, 10, 12),
          businessPurpose: BusinessPurpose.advanceCollection,
          parentTransactionId: 'advance-parent',
          ownerType: 'orchestration.advance',
          ownerId: 'advance-1',
        );
        await _insertLine(
          db,
          id: 'advance-collection-cash',
          transactionId: 'advance-collection',
          lineNo: 1,
          role: TransactionRole.settlementIn,
          accountId: 'cash',
          amountMinor: 4000,
        );

        final source = DriftAdvanceBusinessItemSource(db);
        final page = await source.findAnchorPage(_query());

        expect(page.anchors, hasLength(1));
        expect(page.anchors.single.anchorTransactionId, 'advance-parent');
        expect(
          page.anchors.single.itemKey,
          const BusinessItemKey(type: 'orchestration.advance', id: 'advance-1'),
        );
        final summary =
            (await source.findSummaries({
                  page.anchors.single.itemKey,
                }))[page.anchors.single.itemKey]
                as AdvanceBusinessItemSummary;
        expect(summary.scenario, AdvanceScenario.aa);
        expect(summary.trackingMode, AdvanceTrackingMode.itemized);
        expect(summary.aaPeopleCount, 3);
        expect(summary.outstanding, const Money(minorUnits: 4000));
        expect(summary.isClosed, isFalse);
      },
    );
  });

  group('DriftAmortizationBusinessItemSource', () {
    test(
      'uses the initial transaction and original plan categories as anchor facts',
      () async {
        for (final (id, occurredAt, purpose) in [
          ('plan-initial', DateTime(2026, 10, 7), BusinessPurpose.transfer),
          ('plan-refund', DateTime(2026, 10, 8), BusinessPurpose.transfer),
          ('plan-period', DateTime(2026, 10, 9), BusinessPurpose.dailyExpense),
        ]) {
          await _insertTransaction(
            db,
            id: id,
            occurredAt: occurredAt,
            businessPurpose: purpose,
            ownerType: 'orchestration.amortization',
            ownerId: 'plan-1',
          );
        }
        await db
            .into(db.amortizationPlans)
            .insert(
              AmortizationPlansCompanion.insert(
                id: 'plan-1',
                kind: AmortizationKind.prepaidExpense,
                deferralAccountId: 'prepaid',
                totalAmountMinor: 10000,
                cadenceUnit: AmortizationCadenceUnit.monthly,
                cadenceInterval: 1,
                firstRecognitionAt: DateTime(2026, 11),
                recognitionCount: 1,
                initialTransactionId: 'plan-initial',
              ),
            );
        await db
            .into(db.amortizationPeriods)
            .insert(
              AmortizationPeriodsCompanion.insert(
                id: 'period-1',
                planId: 'plan-1',
                sequenceNo: 1,
                dueAt: DateTime(2026, 11),
                amountMinor: 10000,
                status: AmortizationPeriodStatus.pending,
              ),
            );
        await db
            .into(db.amortizationRefunds)
            .insert(
              AmortizationRefundsCompanion.insert(
                id: 'refund-1',
                planId: 'plan-1',
                transferTransactionId: 'plan-refund',
              ),
            );
        await _insertAmortizationAllocation(
          db,
          id: 'plan-category',
          subjectType: AmortizationSubjectType.plan,
          subjectId: 'plan-1',
          dimension: AmortizationAllocationDimension.category,
          accountId: 'software',
          amountMinor: 10000,
        );
        await _insertAmortizationAllocation(
          db,
          id: 'refund-category',
          subjectType: AmortizationSubjectType.refund,
          subjectId: 'refund-1',
          dimension: AmortizationAllocationDimension.category,
          accountId: 'software',
          amountMinor: 10000,
        );

        final source = DriftAmortizationBusinessItemSource(db);
        final page = await source.findAnchorPage(
          _query(categoryAccountIds: const {'software'}),
        );

        expect(page.anchors, hasLength(1));
        expect(page.anchors.single.anchorTransactionId, 'plan-initial');
        final key = page.anchors.single.itemKey;
        final summary =
            (await source.findSummaries({key}))[key]
                as AmortizationBusinessItemSummary;
        expect(summary.status, AmortizationStatus.completed);
        expect(summary.originalAmount, const Money(minorUnits: 10000));
        expect(summary.remainingAmount, Money.zero());
        expect(summary.totalPeriodCount, 1);
      },
    );
  });

  group('DriftCreditBusinessItemSource', () {
    test(
      'excludes record-only installments and transactionless repayments',
      () async {
        await _insertTransaction(
          db,
          id: 'purchase-tx',
          occurredAt: DateTime(2026, 10, 4),
          ownerType: installmentOwnerType,
          ownerId: 'purchase-contract',
        );
        await _insertTransaction(
          db,
          id: 'loan-tx',
          occurredAt: DateTime(2026, 10, 2),
          ownerType: installmentOwnerType,
          ownerId: 'loan-contract',
        );
        await _insertTransaction(
          db,
          id: 'repayment-tx',
          occurredAt: DateTime(2026, 10, 3),
          businessPurpose: BusinessPurpose.debtRepayment,
          ownerType: creditRepaymentOwnerType,
          ownerId: 'repayment-1',
        );
        await _insertContract(
          db,
          id: 'purchase-contract',
          type: InstallmentType.purchase,
          sourceRefId: 'purchase-tx',
          principalMinor: 12000,
        );
        await _insertContract(
          db,
          id: 'loan-contract',
          type: InstallmentType.disbursement,
          sourceRefId: 'loan-tx',
          principalMinor: 20000,
        );
        await _insertContract(
          db,
          id: 'record-loan',
          type: InstallmentType.disbursement,
          principalMinor: 30000,
        );
        await db
            .into(db.repayments)
            .insert(
              RepaymentsCompanion.insert(
                id: 'repayment-1',
                repaymentType: RepaymentType.unattributed.code,
                targetType: RepaymentTargetType.account.code,
                targetId: 'credit-account',
                transactionId: const Value('repayment-tx'),
                repaymentDate: DateTime(2026, 10, 3),
              ),
            );
        await db
            .into(db.repayments)
            .insert(
              RepaymentsCompanion.insert(
                id: 'record-repayment',
                repaymentType: RepaymentType.installment.code,
                targetType: RepaymentTargetType.bill.code,
                targetId: 'bill-1',
                generatedContractId: const Value('generated-contract'),
                repaymentDate: DateTime(2026, 10, 5),
              ),
            );
        await db
            .into(db.installmentSchedules)
            .insert(
              InstallmentSchedulesCompanion.insert(
                id: 'schedule-paid',
                contractId: 'purchase-contract',
                periodNo: 1,
                expectedRepaymentDate: DateTime(2026, 11),
                expectedPrincipalMinor: const Value(6000),
                status: InstallmentScheduleStatus.paid,
              ),
            );
        await db
            .into(db.installmentSchedules)
            .insert(
              InstallmentSchedulesCompanion.insert(
                id: 'schedule-pending',
                contractId: 'purchase-contract',
                periodNo: 2,
                expectedRepaymentDate: DateTime(2026, 12),
                expectedPrincipalMinor: const Value(6000),
                status: InstallmentScheduleStatus.pending,
              ),
            );

        final source = DriftCreditBusinessItemSource(db);
        final firstPage = await source.findAnchorPage(_query(limit: 2));
        expect(
          firstPage.anchors.take(2).map((anchor) => anchor.anchorTransactionId),
          ['purchase-tx', 'repayment-tx'],
        );
        expect(firstPage.hasMore, isTrue);
        final contractKey = firstPage.anchors.first.itemKey;
        final creditSummary =
            (await source.findSummaries({contractKey}))[contractKey]
                as InstallmentBusinessItemSummary;
        expect(creditSummary.installmentType, InstallmentType.purchase);
        expect(creditSummary.paidPeriodCount, 1);
        expect(creditSummary.totalPeriodCount, 2);
        expect(creditSummary.remainingPrincipal, const Money(minorUnits: 6000));
        final allKeys = {
          for (final anchor in firstPage.anchors) anchor.itemKey,
        };
        final summaries = await source.findSummaries(allKeys);
        expect(summaries.keys, containsAll(allKeys));
        expect(
          summaries[const BusinessItemKey(
            type: creditRepaymentOwnerType,
            id: 'repayment-1',
          )],
          isA<RepaymentBusinessItemSummary>(),
        );

        final secondPage = await source.findAnchorPage(
          _query(
            limit: 2,
            before: BusinessItemCursor(
              anchorAt: firstPage.anchors[1].anchorAt,
              itemKey: firstPage.anchors[1].itemKey,
            ),
          ),
        );
        expect(secondPage.hasMore, isFalse);
        expect(secondPage.anchors.map((anchor) => anchor.anchorTransactionId), [
          'loan-tx',
        ]);
      },
    );
  });

  test('query service merges sources with one stable cursor chain', () async {
    await _insertTransaction(
      db,
      id: 'ledger-tx',
      occurredAt: DateTime(2026, 10, 5, 12),
    );
    await db
        .into(db.advanceCases)
        .insert(
          AdvanceCasesCompanion.insert(
            id: 'advance-1',
            scenario: AdvanceScenario.reimbursement,
            trackingMode: AdvanceTrackingMode.account,
            receivableAccountId: const Value('receivable'),
          ),
        );
    await _insertTransaction(
      db,
      id: 'advance-tx',
      occurredAt: DateTime(2026, 10, 5, 12),
      businessPurpose: BusinessPurpose.advance,
      ownerType: 'orchestration.advance',
      ownerId: 'advance-1',
    );
    await _insertLine(
      db,
      id: 'advance-tx-receivable',
      transactionId: 'advance-tx',
      lineNo: 1,
      role: TransactionRole.receivable,
      accountId: 'receivable',
      amountMinor: 5000,
    );
    await _insertTransaction(
      db,
      id: 'amortization-tx',
      occurredAt: DateTime(2026, 10, 5, 12),
      businessPurpose: BusinessPurpose.transfer,
      ownerType: 'orchestration.amortization',
      ownerId: 'plan-1',
    );
    await db
        .into(db.amortizationPlans)
        .insert(
          AmortizationPlansCompanion.insert(
            id: 'plan-1',
            kind: AmortizationKind.deferredIncome,
            deferralAccountId: 'deferred',
            totalAmountMinor: 3000,
            cadenceUnit: AmortizationCadenceUnit.monthly,
            cadenceInterval: 1,
            firstRecognitionAt: DateTime(2026, 11),
            recognitionCount: 1,
            initialTransactionId: 'amortization-tx',
          ),
        );
    await db
        .into(db.amortizationPeriods)
        .insert(
          AmortizationPeriodsCompanion.insert(
            id: 'period-1',
            planId: 'plan-1',
            sequenceNo: 1,
            dueAt: DateTime(2026, 11),
            amountMinor: 3000,
            status: AmortizationPeriodStatus.pending,
          ),
        );
    await _insertTransaction(
      db,
      id: 'repayment-tx',
      occurredAt: DateTime(2026, 10, 5, 12),
      businessPurpose: BusinessPurpose.debtRepayment,
      ownerType: creditRepaymentOwnerType,
      ownerId: 'repayment-1',
    );
    await db
        .into(db.repayments)
        .insert(
          RepaymentsCompanion.insert(
            id: 'repayment-1',
            repaymentType: RepaymentType.prepayment.code,
            targetType: RepaymentTargetType.contract.code,
            targetId: 'contract-1',
            transactionId: const Value('repayment-tx'),
            repaymentDate: DateTime(2026, 10, 2),
          ),
        );

    final service = BusinessItemQueryServiceImpl(
      sources: [
        DriftLedgerBusinessItemSource(db),
        DriftAdvanceBusinessItemSource(db),
        DriftAmortizationBusinessItemSource(db),
        DriftCreditBusinessItemSource(db),
      ],
      transactionRead: DriftTransactionReadRepository(db),
    );
    final firstPage = await service.findPage(_query(limit: 2));
    expect(firstPage.items.map((item) => item.anchorTransactionId), [
      'amortization-tx',
      'advance-tx',
    ]);
    expect(firstPage.hasMore, isTrue);

    final secondPage = await service.findPage(
      _query(limit: 2, before: firstPage.nextCursor),
    );
    expect(secondPage.items.map((item) => item.anchorTransactionId), [
      'ledger-tx',
      'repayment-tx',
    ]);
    expect(secondPage.hasMore, isFalse);
  });

  test('watchPage reacts to summary-only source table changes', () async {
    await _insertTransaction(
      db,
      id: 'amortization-tx',
      occurredAt: DateTime(2026, 10, 4),
      businessPurpose: BusinessPurpose.transfer,
      ownerType: 'orchestration.amortization',
      ownerId: 'plan-1',
    );
    await db
        .into(db.amortizationPlans)
        .insert(
          AmortizationPlansCompanion.insert(
            id: 'plan-1',
            kind: AmortizationKind.prepaidExpense,
            deferralAccountId: 'prepaid',
            totalAmountMinor: 3000,
            cadenceUnit: AmortizationCadenceUnit.monthly,
            cadenceInterval: 1,
            firstRecognitionAt: DateTime(2026, 11),
            recognitionCount: 1,
            initialTransactionId: 'amortization-tx',
          ),
        );
    final service = BusinessItemQueryServiceImpl(
      sources: [
        DriftLedgerBusinessItemSource(db),
        DriftAmortizationBusinessItemSource(db),
      ],
      transactionRead: DriftTransactionReadRepository(db),
    );
    final iterator = StreamIterator(service.watchPage(_query()));

    expect(await iterator.moveNext(), isTrue);
    final initialSummary =
        iterator.current.items.single.summary
            as AmortizationBusinessItemSummary;
    expect(initialSummary.totalPeriodCount, 0);

    await db
        .into(db.amortizationPeriods)
        .insert(
          AmortizationPeriodsCompanion.insert(
            id: 'period-1',
            planId: 'plan-1',
            sequenceNo: 1,
            dueAt: DateTime(2026, 11),
            amountMinor: 3000,
            status: AmortizationPeriodStatus.pending,
          ),
        );

    expect(await iterator.moveNext(), isTrue);
    final updatedSummary =
        iterator.current.items.single.summary
            as AmortizationBusinessItemSummary;
    expect(updatedSummary.totalPeriodCount, 1);
    expect(updatedSummary.currentPeriodSequence, 1);
    await iterator.cancel();
  });

  test('uses business-item indexes for bounded anchor queries', () async {
    final ownerPlan = await db.customSelect('''
EXPLAIN QUERY PLAN
SELECT anchor.id
FROM advance_cases advance_case
JOIN transactions anchor
  ON anchor.owner_type = 'orchestration.advance'
  AND anchor.owner_id = advance_case.id
WHERE anchor.parent_transaction_id IS NULL
  AND anchor.occurred_at >= 0
  AND anchor.occurred_at < 9999999999
ORDER BY anchor.occurred_at DESC, anchor.owner_id DESC
LIMIT 21
''').get();
    expect(
      ownerPlan.map((row) => row.read<String>('detail')).join('\n'),
      contains('transactions_top_level_owner_occurred_idx'),
    );

    final ledgerPlan = await db.customSelect('''
EXPLAIN QUERY PLAN
SELECT id
FROM transactions
WHERE parent_transaction_id IS NULL
  AND owner_type IS NULL
  AND owner_id IS NULL
  AND occurred_at >= 0
  AND occurred_at < 9999999999
ORDER BY occurred_at DESC, id DESC
LIMIT 21
''').get();
    expect(
      ledgerPlan.map((row) => row.read<String>('detail')).join('\n'),
      contains('transactions_top_level_occurred_idx'),
    );
  });

  test('keeps a bounded page against a large candidate set', () async {
    final start = DateTime(2026, 10);
    await db.batch((batch) {
      batch.insertAll(db.transactions, [
        for (var index = 0; index < 6000; index++)
          TransactionsCompanion.insert(
            id: 'tx-$index',
            businessPurpose: BusinessPurpose.dailyExpense,
            occurredAt: start.add(Duration(minutes: index)),
            postedAt: start.add(Duration(minutes: index)),
            primaryAmountMinor: 100,
            sourceKind: SourceKind.manual,
            ownerType: index.isEven
                ? const Value('orchestration.advance')
                : const Value(null),
            ownerId: index.isEven
                ? Value('advance-${index ~/ 2}')
                : const Value(null),
          ),
      ]);
      batch.insertAll(db.advanceCases, [
        for (var index = 0; index < 3000; index++)
          AdvanceCasesCompanion.insert(
            id: 'advance-$index',
            scenario: AdvanceScenario.reimbursement,
            trackingMode: AdvanceTrackingMode.itemized,
          ),
      ]);
    });
    final service = BusinessItemQueryServiceImpl(
      sources: [
        DriftLedgerBusinessItemSource(db),
        DriftAdvanceBusinessItemSource(db),
      ],
      transactionRead: DriftTransactionReadRepository(db),
    );

    final stopwatch = Stopwatch()..start();
    final page = await service.findPage(_query(limit: 20));
    stopwatch.stop();

    expect(page.items, hasLength(20));
    expect(page.hasMore, isTrue);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  });
}

BusinessItemPageQuery _query({
  int limit = 20,
  DateTime? occurredUntil,
  BusinessItemCursor? before,
  Set<String>? categoryAccountIds,
  Set<String>? settlementAccountIds,
  Set<String>? tagIds,
  bool untaggedOnly = false,
  String? counterpartyId,
}) {
  return BusinessItemPageQuery(
    occurredFrom: DateTime(2026, 10),
    occurredUntil: occurredUntil ?? DateTime(2026, 11),
    before: before,
    limit: limit,
    categoryAccountIds: categoryAccountIds,
    settlementAccountIds: settlementAccountIds,
    tagIds: tagIds,
    untaggedOnly: untaggedOnly,
    counterpartyId: counterpartyId,
  );
}

Future<void> _insertTransaction(
  AppDatabase db, {
  required String id,
  required DateTime occurredAt,
  BusinessPurpose businessPurpose = BusinessPurpose.dailyExpense,
  int amountMinor = 1000,
  String? parentTransactionId,
  String? ownerType,
  String? ownerId,
  String? counterpartyId,
}) {
  return db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: id,
          businessPurpose: businessPurpose,
          occurredAt: occurredAt,
          postedAt: occurredAt,
          primaryAmountMinor: amountMinor,
          sourceKind: SourceKind.manual,
          parentTransactionId: Value(parentTransactionId),
          ownerType: Value(ownerType),
          ownerId: Value(ownerId),
          counterpartyId: Value(counterpartyId),
        ),
      );
}

Future<void> _insertLine(
  AppDatabase db, {
  required String id,
  required String transactionId,
  required int lineNo,
  required TransactionRole role,
  required String accountId,
  required int amountMinor,
}) {
  return db
      .into(db.transactionLines)
      .insert(
        TransactionLinesCompanion.insert(
          id: id,
          transactionId: transactionId,
          lineNo: lineNo,
          role: role,
          accountId: Value(accountId),
          amountMinor: amountMinor,
        ),
      );
}

Future<void> _insertContract(
  AppDatabase db, {
  required String id,
  required InstallmentType type,
  required int principalMinor,
  String? sourceRefId,
}) {
  return db
      .into(db.installmentContracts)
      .insert(
        InstallmentContractsCompanion.insert(
          id: id,
          liabilityAccountId: 'credit-account',
          installmentType: type,
          sourceRefId: Value(sourceRefId),
          principalMinor: principalMinor,
          borrowingDate: DateTime(2026, 10),
          status: InstallmentContractStatus.active,
        ),
      );
}

Future<void> _insertAmortizationAllocation(
  AppDatabase db, {
  required String id,
  required AmortizationSubjectType subjectType,
  required String subjectId,
  required AmortizationAllocationDimension dimension,
  required String accountId,
  required int amountMinor,
}) {
  return db
      .into(db.amortizationAllocations)
      .insert(
        AmortizationAllocationsCompanion.insert(
          id: id,
          subjectType: subjectType,
          subjectId: subjectId,
          dimension: dimension,
          lineNo: 1,
          accountId: accountId,
          amountMinor: amountMinor,
        ),
      );
}
