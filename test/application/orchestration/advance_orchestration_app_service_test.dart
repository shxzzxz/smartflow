import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/orchestration/orchestration_command_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';
import 'package:smartflow/domain/orchestration/port/advance_ledger_port.dart';

import '../../helper/fake_advance_case_repository.dart';
import '../../helper/sequential_id_generator.dart';

void main() {
  test(
    'AA advance creates one case and submits explicit ledger shares',
    () async {
      final cases = FakeAdvanceCaseRepository();
      final ledger = _FakeLedgerPort();
      final service = _service(cases, ledger);

      await service.createAdvance(
        CreateAdvanceWorkflowCommand(
          amount: _money(7000),
          scenario: AdvanceScenario.aa,
          trackingMode: AdvanceTrackingMode.itemized,
          aaPeopleCount: 3,
          receivableAccountId: 'receivable',
          categoryAllocations: [
            _allocation('food', 4000),
            _allocation('travel', 3000),
          ],
          settlementAllocations: [_allocation('cash', 7000)],
          occurredAt: DateTime(2026, 10, 23),
        ),
      );

      final advanceCase = cases.values.single;
      expect(advanceCase.scenario, AdvanceScenario.aa);
      expect(advanceCase.trackingMode, AdvanceTrackingMode.itemized);
      expect(advanceCase.aaPeopleCount, 3);
      expect(
        ledger.advanceRequest!.ownership.ownerType,
        orchestrationAdvanceOwnerType,
      );
      expect(ledger.advanceRequest!.ownership.ownerId, advanceCase.id);
      expect(ledger.advanceRequest!.advanceAmount, _money(4668));
      expect(_shape(ledger.advanceRequest!.selfBorneAllocations), [
        'food:1332',
        'travel:1000',
      ]);
    },
  );

  test('ordinary expense scene delegates explicit facts to ledger', () async {
    final cases = FakeAdvanceCaseRepository();
    final ledger = _FakeLedgerPort();
    final service = _service(cases, ledger);

    await service.createExpenseScene(
      CreateExpenseSceneWorkflowCommand(
        amount: _money(1200),
        target: const OrdinaryExpenseSceneTarget(),
        categoryAllocations: [_allocation('food', 1200)],
        settlementAllocations: [_allocation('cash', 1200)],
        occurredAt: DateTime(2026, 10, 23),
      ),
    );

    expect(cases.values, isEmpty);
    expect(ledger.expenseRequests, hasLength(1));
    expect(ledger.expenseRequests.single, _money(1200));
  });

  test(
    'each account advance creates its own case and stores AA count',
    () async {
      final cases = FakeAdvanceCaseRepository();
      final ledger = _FakeLedgerPort();
      final service = _service(cases, ledger);
      for (final peopleCount in [3, 4]) {
        await service.createAdvance(
          CreateAdvanceWorkflowCommand(
            amount: _money(10000),
            scenario: AdvanceScenario.aa,
            trackingMode: AdvanceTrackingMode.account,
            aaPeopleCount: peopleCount,
            receivableAccountId: 'company',
            categoryAllocations: [_allocation('travel', 10000)],
            settlementAllocations: [_allocation('cash', 10000)],
            occurredAt: DateTime(2026, 10, 23 + peopleCount),
          ),
        );
      }

      expect(cases.values, hasLength(2));
      expect(ledger.advanceRequests, hasLength(2));
      expect(
        cases.values.map((advanceCase) => advanceCase.aaPeopleCount),
        containsAll([3, 4]),
      );
      expect(
        ledger.advanceRequests
            .map((request) => request.ownership.ownerId)
            .toSet(),
        cases.values.map((advanceCase) => advanceCase.id).toSet(),
      );
    },
  );

  test('on-behalf advances support account tracking', () async {
    final cases = FakeAdvanceCaseRepository();
    final ledger = _FakeLedgerPort();
    final service = _service(cases, ledger);

    await service.createAdvance(
      CreateAdvanceWorkflowCommand(
        amount: _money(1000),
        scenario: AdvanceScenario.onBehalf,
        trackingMode: AdvanceTrackingMode.account,
        aaPeopleCount: 2,
        receivableAccountId: 'company',
        categoryAllocations: [_allocation('travel', 1000)],
        settlementAllocations: [_allocation('cash', 1000)],
        occurredAt: DateTime(2026, 10, 23),
      ),
    );

    final advanceCase = cases.values.single;
    expect(advanceCase.scenario, AdvanceScenario.onBehalf);
    expect(advanceCase.trackingMode, AdvanceTrackingMode.account);
    expect(advanceCase.aaPeopleCount, isNull);
  });

  test('invalid AA participant count is a business failure', () async {
    final cases = FakeAdvanceCaseRepository();
    final service = _service(cases, _FakeLedgerPort());

    await expectLater(
      service.createAdvance(
        CreateAdvanceWorkflowCommand(
          amount: _money(1000),
          scenario: AdvanceScenario.aa,
          trackingMode: AdvanceTrackingMode.account,
          aaPeopleCount: 1,
          receivableAccountId: 'company',
          categoryAllocations: [_allocation('travel', 1000)],
          settlementAllocations: [_allocation('cash', 1000)],
          occurredAt: DateTime(2026, 10, 23),
        ),
      ),
      throwsA(isA<BusinessException>()),
    );
    expect(cases.values, isEmpty);
  });

  test(
    'changing an itemized AA advance to reimbursement rewrites refund shares',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'group'),
      );
      const ownership = TransactionOwnership(
        ownerType: orchestrationAdvanceOwnerType,
        ownerId: 'case',
      );
      final parent = engine.createAdvance(
        AdvanceInstruction(
          amount: _money(7000),
          advanceAmount: _money(4668),
          receivableAccountId: 'receivable',
          categoryAllocations: [
            _allocation('food', 4000),
            _allocation('travel', 3000),
          ],
          selfBorneAllocations: [
            _allocation('food', 1332),
            _allocation('travel', 1000),
          ],
          settlementAllocations: [_allocation('cash', 7000)],
          occurredAt: DateTime(2026, 10, 23),
          ownership: ownership,
        ),
      );
      final refund = engine.createRefund(
        instruction: RefundInstruction(
          parentTransactionId: parent.id,
          amount: _money(2000),
          categoryAllocations: [
            _allocation('food', 1000),
            _allocation('travel', 1000),
          ],
          selfBorneAllocations: [
            _allocation('food', 333),
            _allocation('travel', 333),
          ],
          settlementAllocations: [_allocation('cash', 2000)],
          occurredAt: DateTime(2026, 10, 24),
        ),
        parent: parent,
      );
      final ledger = _FakeLedgerPort(
        group: TransactionGroup(
          parentTransaction: parent,
          childTransactions: [refund],
        ),
      );
      final repo = FakeAdvanceCaseRepository(const [
        AdvanceCase(
          id: 'case',
          scenario: AdvanceScenario.aa,
          trackingMode: AdvanceTrackingMode.itemized,
          aaPeopleCount: 3,
        ),
      ]);
      final service = _service(repo, ledger);

      await service.editAdvance(
        EditAdvanceWorkflowCommand(
          transactionId: parent.id,
          scenario: AdvanceScenario.reimbursement,
          aaPeopleCount: 2,
          amount: _money(7000),
          categoryAllocations: [
            _allocation('food', 4000),
            _allocation('travel', 3000),
          ],
          settlementAllocations: [_allocation('cash', 7000)],
          occurredAt: parent.occurredAt,
        ),
      );

      expect(ledger.rewriteRequest!.ownership.ownerId, 'case');
      expect(ledger.rewriteRequest!.advanceAmount, _money(7000));
      expect(
        ledger.rewriteRequest!.refundSelfBorneAllocations[refund.id],
        isEmpty,
      );
      expect(repo.values.single.scenario, AdvanceScenario.reimbursement);
      expect(repo.values.single.aaPeopleCount, isNull);
    },
  );

  test(
    'account AA account-only edit preserves participants from current facts',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'group'),
      );
      const ownership = TransactionOwnership(
        ownerType: orchestrationAdvanceOwnerType,
        ownerId: 'case',
      );
      final parent = engine.createAdvance(
        AdvanceInstruction(
          amount: _money(7000),
          advanceAmount: _money(4668),
          receivableAccountId: 'receivable',
          categoryAllocations: [
            _allocation('food', 4000),
            _allocation('travel', 3000),
          ],
          selfBorneAllocations: [
            _allocation('food', 1332),
            _allocation('travel', 1000),
          ],
          settlementAllocations: [_allocation('cash', 7000)],
          occurredAt: DateTime(2026, 10, 23),
          ownership: ownership,
        ),
      );
      final ledger = _FakeLedgerPort(
        group: TransactionGroup(
          parentTransaction: parent,
          childTransactions: const [],
        ),
      );
      final cases = FakeAdvanceCaseRepository(const [
        AdvanceCase(
          id: 'case',
          scenario: AdvanceScenario.aa,
          trackingMode: AdvanceTrackingMode.account,
          receivableAccountId: 'receivable',
        ),
      ]);
      final service = _service(cases, ledger);

      await service.editAdvance(
        EditAdvanceWorkflowCommand(
          transactionId: parent.id,
          scenario: AdvanceScenario.aa,
        ),
      );

      expect(ledger.rewriteRequest!.advanceAmount, _money(4668));
    },
  );

  test(
    'ordinary expense converts to itemized advance through orchestration',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'convert'),
      );
      final parent = engine.createExpense(
        ExpenseInstruction(
          amount: _money(7000),
          categoryAllocations: [_allocation('food', 7000)],
          settlementAllocations: [_allocation('cash', 7000)],
          occurredAt: DateTime(2026, 10, 23),
        ),
      );
      final cases = FakeAdvanceCaseRepository();
      final ledger = _FakeLedgerPort(
        group: TransactionGroup(
          parentTransaction: parent,
          childTransactions: const [],
        ),
      );
      final service = _service(cases, ledger);

      await service.editExpenseScene(
        EditExpenseSceneWorkflowCommand(
          transactionId: parent.id,
          target: const ItemizedAdvanceSceneTarget(
            scenario: AdvanceScenario.reimbursement,
            aaPeopleCount: 2,
            receivableAccountId: 'receivable',
          ),
          amount: _money(7000),
          categoryAllocations: [_allocation('food', 7000)],
          settlementAllocations: [_allocation('cash', 7000)],
          occurredAt: parent.occurredAt,
        ),
      );

      final advanceCase = cases.values.single;
      expect(advanceCase.trackingMode, AdvanceTrackingMode.itemized);
      expect(ledger.rewriteRequest!.ownership.ownerId, advanceCase.id);
      expect(ledger.rewriteRequest!.advanceAmount, _money(7000));
    },
  );

  test(
    'itemized advance conversion to expense clears case and refund shares',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'convert'),
      );
      const ownership = TransactionOwnership(
        ownerType: orchestrationAdvanceOwnerType,
        ownerId: 'case',
      );
      final parent = engine.createAdvance(
        AdvanceInstruction(
          amount: _money(7000),
          advanceAmount: _money(4668),
          receivableAccountId: 'receivable',
          categoryAllocations: [_allocation('food', 7000)],
          selfBorneAllocations: [_allocation('food', 2332)],
          settlementAllocations: [_allocation('cash', 7000)],
          occurredAt: DateTime(2026, 10, 23),
          ownership: ownership,
        ),
      );
      final refund = engine.createRefund(
        instruction: RefundInstruction(
          parentTransactionId: parent.id,
          amount: _money(2000),
          categoryAllocations: [_allocation('food', 2000)],
          selfBorneAllocations: [_allocation('food', 666)],
          settlementAllocations: [_allocation('cash', 2000)],
          occurredAt: DateTime(2026, 10, 24),
        ),
        parent: parent,
      );
      final cases = FakeAdvanceCaseRepository(const [
        AdvanceCase(
          id: 'case',
          scenario: AdvanceScenario.aa,
          trackingMode: AdvanceTrackingMode.itemized,
          aaPeopleCount: 3,
        ),
      ]);
      final ledger = _FakeLedgerPort(
        group: TransactionGroup(
          parentTransaction: parent,
          childTransactions: [refund],
        ),
      );
      final service = _service(cases, ledger);

      await service.editExpenseScene(
        EditExpenseSceneWorkflowCommand(
          transactionId: parent.id,
          target: const OrdinaryExpenseSceneTarget(),
          amount: _money(7000),
          categoryAllocations: [_allocation('food', 7000)],
          settlementAllocations: [_allocation('cash', 7000)],
          occurredAt: parent.occurredAt,
        ),
      );

      expect(cases.values, isEmpty);
      expect(
        ledger.expenseRewriteRequest!.refundSelfBorneAllocations[refund.id],
        isEmpty,
      );
    },
  );

  test('account advance cannot convert to ordinary expense', () async {
    final engine = PostingEngine(
      idGenerator: SequentialIdGenerator(prefix: 'reject'),
    );
    const ownership = TransactionOwnership(
      ownerType: orchestrationAdvanceOwnerType,
      ownerId: 'case',
    );
    final parent = engine.createAdvance(
      AdvanceInstruction(
        amount: _money(7000),
        advanceAmount: _money(7000),
        receivableAccountId: 'receivable',
        categoryAllocations: [_allocation('food', 7000)],
        settlementAllocations: [_allocation('cash', 7000)],
        occurredAt: DateTime(2026, 10, 23),
        ownership: ownership,
      ),
    );
    final cases = FakeAdvanceCaseRepository(const [
      AdvanceCase(
        id: 'case',
        scenario: AdvanceScenario.reimbursement,
        trackingMode: AdvanceTrackingMode.account,
        receivableAccountId: 'receivable',
      ),
    ]);
    final service = _service(
      cases,
      _FakeLedgerPort(
        group: TransactionGroup(
          parentTransaction: parent,
          childTransactions: const [],
        ),
      ),
    );

    await expectLater(
      service.editExpenseScene(
        EditExpenseSceneWorkflowCommand(
          transactionId: parent.id,
          target: const OrdinaryExpenseSceneTarget(),
        ),
      ),
      throwsA(isA<BusinessException>()),
    );
  });
}

AdvanceOrchestrationAppService _service(
  FakeAdvanceCaseRepository cases,
  _FakeLedgerPort ledger,
) {
  return AdvanceOrchestrationAppServiceImpl(
    cases: cases,
    ledger: ledger,
    transactionRunner: const _Runner(),
    idGenerator: SequentialIdGenerator(prefix: 'case'),
  );
}

class _Runner implements TransactionRunner {
  const _Runner();

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}

class _AdvanceRequest {
  const _AdvanceRequest({
    required this.advanceAmount,
    required this.selfBorneAllocations,
    required this.ownership,
  });

  final Money advanceAmount;
  final List<AccountAmountAllocation> selfBorneAllocations;
  final TransactionOwnership ownership;
}

class _RewriteRequest {
  const _RewriteRequest({
    required this.advanceAmount,
    required this.refundSelfBorneAllocations,
    required this.ownership,
  });

  final Money advanceAmount;
  final Map<String, List<AccountAmountAllocation>> refundSelfBorneAllocations;
  final TransactionOwnership ownership;
}

class _ExpenseRewriteRequest {
  const _ExpenseRewriteRequest({required this.refundSelfBorneAllocations});

  final Map<String, List<AccountAmountAllocation>> refundSelfBorneAllocations;
}

class _FakeLedgerPort implements AdvanceLedgerPort {
  _FakeLedgerPort({this.group});

  final TransactionGroup? group;
  final advanceRequests = <_AdvanceRequest>[];
  final collectionOwnerships = <TransactionOwnership?>[];
  final settlementOwnerships = <TransactionOwnership?>[];
  final expenseRequests = <Money>[];
  _RewriteRequest? rewriteRequest;
  _ExpenseRewriteRequest? expenseRewriteRequest;

  _AdvanceRequest? get advanceRequest =>
      advanceRequests.isEmpty ? null : advanceRequests.last;

  @override
  Future<String> postExpense({
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required DateTime occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
    SourceKind sourceKind = SourceKind.manual,
    Set<String> tagIds = const {},
  }) async {
    expenseRequests.add(amount);
    return 'expense';
  }

  @override
  Future<String> postAdvance({
    required Money amount,
    required Money advanceAmount,
    required String receivableAccountId,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> selfBorneAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required TransactionOwnership ownership,
    required DateTime occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
    SourceKind sourceKind = SourceKind.manual,
    Set<String> tagIds = const {},
  }) async {
    advanceRequests.add(
      _AdvanceRequest(
        advanceAmount: advanceAmount,
        selfBorneAllocations: selfBorneAllocations,
        ownership: ownership,
      ),
    );
    return 'advance';
  }

  @override
  Future<TransactionGroup?> findGroup(String transactionId) async => group;

  @override
  Future<String> postAdvanceCollection({
    required Money amount,
    required String? advanceTransactionId,
    required String receivableAccountId,
    required List<AccountAmountAllocation> settlementAllocations,
    required TransactionOwnership? ownership,
    required DateTime occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
  }) async {
    collectionOwnerships.add(ownership);
    return 'collection';
  }

  @override
  Future<String> postAdvanceSettlement({
    required Money actualReceivedAmount,
    required String? advanceTransactionId,
    required String receivableAccountId,
    required List<AccountAmountAllocation> settlementAllocations,
    required List<AccountAmountAllocation> gapExpenseAllocations,
    required AdvanceShortfallKind shortfallKind,
    required TransactionOwnership? ownership,
    required DateTime occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
  }) async {
    settlementOwnerships.add(ownership);
    return 'settlement';
  }

  @override
  Future<String> rewriteAdvance({
    required String transactionId,
    required Money amount,
    required Money advanceAmount,
    required String receivableAccountId,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> selfBorneAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required TransactionOwnership ownership,
    required Map<String, List<AccountAmountAllocation>>
    refundSelfBorneAllocations,
    required DateTime occurredAt,
    Patch<String?>? counterpartyId,
    Patch<String?>? note,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
    Set<String>? tagIds,
  }) async {
    rewriteRequest = _RewriteRequest(
      advanceAmount: advanceAmount,
      refundSelfBorneAllocations: refundSelfBorneAllocations,
      ownership: ownership,
    );
    return transactionId;
  }

  @override
  Future<String> rewriteExpense({
    required String transactionId,
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required Map<String, List<AccountAmountAllocation>>
    refundSelfBorneAllocations,
    required DateTime occurredAt,
    Patch<String?>? counterpartyId,
    Patch<String?>? note,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
    Set<String>? tagIds,
  }) async {
    expenseRewriteRequest = _ExpenseRewriteRequest(
      refundSelfBorneAllocations: refundSelfBorneAllocations,
    );
    return transactionId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

AccountAmountAllocation _allocation(String accountId, int minorUnits) {
  return AccountAmountAllocation(
    accountId: accountId,
    amount: _money(minorUnits),
  );
}

Money _money(int minorUnits) => Money(minorUnits: minorUnits);

List<String> _shape(Iterable<AccountAmountAllocation> allocations) {
  return [
    for (final allocation in allocations)
      '${allocation.accountId}:${allocation.amount.minorUnits}',
  ];
}
