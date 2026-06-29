import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart'
    hide CreateRepaymentCommand;
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';

void main() {
  group('InstallmentAppServiceImpl', () {
    test(
      'creates disbursement contract without borrowing transaction',
      () async {
        final fixture = _Fixture();

        final result = await fixture.service.createDisbursementContract(
          _createDisbursementCommand(disbursementAccountId: null),
        );

        expect(result.disbursementTransactionId, isNull);
        expect(fixture.posting.borrowingCommands, isEmpty);
        final contract = fixture.installments.contracts[result.contractId]!;
        expect(contract.disbursementAccountId, isNull);
        expect(contract.disbursementTransactionId, isNull);
        expect(
          fixture.installments.schedulesFor(result.contractId),
          hasLength(2),
        );
      },
    );

    test(
      'marks borrowing owner when disbursement transaction is created',
      () async {
        final fixture = _Fixture();

        final result = await fixture.service.createDisbursementContract(
          _createDisbursementCommand(disbursementAccountId: 'asset-cash'),
        );

        expect(result.disbursementTransactionId, 'tx-borrowing-1');
        expect(
          fixture.posting.borrowingCommands.single.receiveAccountId,
          'asset-cash',
        );
        final ownership = fixture.update.ownershipCommands.single.ownership;
        expect(ownership.ownerType, installmentOwnerType);
        expect(ownership.ownerId, result.contractId);
        expect(
          ownership.ownerRole,
          InstallmentOwnerRole.disbursement.wireValue,
        );
      },
    );

    test(
      'uses next credit billing cycle for cash installment schedules',
      () async {
        final fixture = _Fixture();
        fixture
            .creditAccounts
            .accounts['credit-liability'] = CreditLiabilityAccount(
          id: 'credit-ext',
          accountId: 'credit-liability',
          kind: CreditLiabilityAccountKind.credit,
          billingDay: 5,
          repaymentDay: 25,
          billingStartPeriod: BillPeriod(year: 2026, month: 6),
          billingDayToNext: true,
        );

        final result = await fixture.service.createDisbursementContract(
          _createDisbursementCommand(
            liabilityAccountId: 'credit-liability',
            disbursementAccountId: null,
            borrowingDate: DateTime(2026, 6, 4),
            firstRepaymentDate: DateTime(2026, 6, 10),
            lastRepaymentDate: DateTime(2026, 6, 10),
          ),
        );

        final contract = fixture.installments.contracts[result.contractId]!;
        expect(contract.firstRepaymentDate, DateTime(2026, 7, 25));
        expect(contract.lastRepaymentDate, DateTime(2026, 8, 25));
        expect(
          fixture.installments
              .schedulesFor(result.contractId)
              .map((s) => s.expectedRepaymentDate),
          [DateTime(2026, 7, 25), DateTime(2026, 8, 25)],
        );
      },
    );

    test(
      'updates parameter snapshot without recalculating schedules',
      () async {
        final fixture = _Fixture();
        fixture.installments.putContract(_contract(id: 'contract-1'));
        fixture.installments.putSchedules('contract-1', [
          _schedule(
            id: 'schedule-1',
            contractId: 'contract-1',
            periodNo: 1,
            principal: const Money(minorUnits: 5000),
            date: DateTime(2026, 7, 10),
          ),
        ]);

        await fixture.service.updateContract(
          UpdateContractCommand(
            contractId: 'contract-1',
            totalPeriods: 3,
            firstRepaymentDate: DateTime(2026, 8, 10),
            lastRepaymentDate: DateTime(2026, 10, 10),
            totalFeeMinor: 900,
          ),
        );

        final contract = fixture.installments.contracts['contract-1']!;
        expect(contract.totalPeriods, 3);
        expect(contract.firstRepaymentDate, DateTime(2026, 8, 10));
        final schedule = fixture.installments.schedulesFor('contract-1').single;
        expect(schedule.expectedRepaymentDate, DateTime(2026, 7, 10));
        expect(schedule.expectedPrincipal, const Money(minorUnits: 5000));
      },
    );

    test(
      'explicit recalculation changes pending amounts and preserves dates',
      () async {
        final fixture = _Fixture();
        fixture.installments.putContract(
          _contract(
            id: 'contract-1',
            principal: const Money(minorUnits: 10000),
            totalFeeMinor: 300,
            repaymentMethod: InstallmentRepaymentMethod.flatFee,
          ),
        );
        fixture.installments.putSchedules('contract-1', [
          _schedule(
            id: 'schedule-1',
            contractId: 'contract-1',
            periodNo: 1,
            principal: const Money(minorUnits: 1),
            fee: Money.zero(),
            date: DateTime(2026, 7, 10),
          ),
          _schedule(
            id: 'schedule-2',
            contractId: 'contract-1',
            periodNo: 2,
            principal: const Money(minorUnits: 1),
            fee: Money.zero(),
            date: DateTime(2026, 9, 10),
          ),
          _schedule(
            id: 'schedule-3',
            contractId: 'contract-1',
            periodNo: 3,
            status: InstallmentScheduleStatus.skipped,
            principal: const Money(minorUnits: 99),
            date: DateTime(2026, 10, 10),
          ),
        ]);

        final preview = await fixture.service.previewContractRecalculation(
          const RecalculateContractSchedulesCommand(contractId: 'contract-1'),
        );
        await fixture.service.recalculateContractSchedules(
          const RecalculateContractSchedulesCommand(contractId: 'contract-1'),
        );

        expect(preview.map((row) => row.expectedRepaymentDate), [
          DateTime(2026, 7, 10),
          DateTime(2026, 9, 10),
        ]);
        final schedules = fixture.installments.schedulesFor('contract-1');
        expect(schedules[0].expectedPrincipal, const Money(minorUnits: 5000));
        expect(schedules[0].expectedFee, const Money(minorUnits: 150));
        expect(schedules[0].expectedRepaymentDate, DateTime(2026, 7, 10));
        expect(schedules[2].expectedPrincipal, const Money(minorUnits: 99));
        expect(schedules[2].status, InstallmentScheduleStatus.skipped);
      },
    );

    test('manual schedule patches reject non-pending rows', () async {
      final fixture = _Fixture();
      fixture.installments.putContract(_contract(id: 'contract-1'));
      fixture.installments.putSchedules('contract-1', [
        _schedule(
          id: 'schedule-1',
          contractId: 'contract-1',
          periodNo: 1,
          status: InstallmentScheduleStatus.skipped,
        ),
      ]);

      await expectLater(
        fixture.service.updateContract(
          UpdateContractCommand(
            contractId: 'contract-1',
            schedulePatches: [
              SchedulePendingPatch(
                periodNo: 1,
                expectedPrincipal: const Money(minorUnits: 200),
              ),
            ],
          ),
        ),
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            CreditErrorCode.scheduleNotPending.code,
          ),
        ),
      );
    });

    test('skips and restores pending schedules', () async {
      final fixture = _Fixture();
      fixture.installments.putContract(_contract(id: 'contract-1'));
      fixture.installments.putSchedules('contract-1', [
        _schedule(id: 'schedule-1', contractId: 'contract-1', periodNo: 1),
      ]);

      await fixture.service.skipSchedule(
        const SkipInstallmentScheduleCommand(
          contractId: 'contract-1',
          scheduleId: 'schedule-1',
        ),
      );
      expect(
        fixture.installments.schedulesFor('contract-1').single.status,
        InstallmentScheduleStatus.skipped,
      );

      await fixture.service.restoreSchedule(
        const RestoreInstallmentScheduleCommand(
          contractId: 'contract-1',
          scheduleId: 'schedule-1',
        ),
      );
      expect(
        fixture.installments.schedulesFor('contract-1').single.status,
        InstallmentScheduleStatus.pending,
      );
    });

    test(
      'deletes only contracts without repayments or disbursement transaction',
      () async {
        final fixture = _Fixture();
        fixture.installments
          ..putContract(
            _contract(id: 'with-tx', disbursementTransactionId: 'tx-borrowing'),
          )
          ..putContract(_contract(id: 'with-repayment'))
          ..putContract(_contract(id: 'deletable'));
        fixture.repayments.putRepayment(
          Repayment(
            id: 'repayment-1',
            repaymentType: RepaymentType.prepayment,
            targetType: RepaymentTargetType.contract,
            targetId: 'with-repayment',
            rootTransactionId: 'tx-repay',
            items: [
              RepaymentItem(
                id: 'repayment-item-1',
                repaymentId: 'repayment-1',
                allocated: const RepaymentAmountBreakdown(
                  principal: Money(minorUnits: 1000),
                  interest: Money(minorUnits: 0),
                  fee: Money(minorUnits: 0),
                  discount: Money(minorUnits: 0),
                ),
                createdAt: DateTime(2026, 6, 1),
              ),
            ],
            createdAt: DateTime(2026, 6, 1),
          ),
        );

        await expectLater(
          fixture.service.deleteContract(
            const DeleteContractCommand(contractId: 'with-tx'),
          ),
          throwsA(isA<BusinessException>()),
        );
        await expectLater(
          fixture.service.deleteContract(
            const DeleteContractCommand(contractId: 'with-repayment'),
          ),
          throwsA(isA<BusinessException>()),
        );
        await fixture.service.deleteContract(
          const DeleteContractCommand(contractId: 'deletable'),
        );

        expect(fixture.installments.contracts.containsKey('with-tx'), true);
        expect(
          fixture.installments.contracts.containsKey('with-repayment'),
          true,
        );
        expect(fixture.installments.contracts.containsKey('deletable'), false);
      },
    );
  });
}

CreateDisbursementContractCommand _createDisbursementCommand({
  String liabilityAccountId = 'loan-liability',
  String? disbursementAccountId,
  DateTime? borrowingDate,
  DateTime? firstRepaymentDate,
  DateTime? lastRepaymentDate,
}) {
  return CreateDisbursementContractCommand(
    liabilityAccountId: liabilityAccountId,
    disbursementAccountId: disbursementAccountId,
    principal: const Money(minorUnits: 120000),
    totalPeriods: 2,
    borrowingDate: borrowingDate ?? DateTime(2026, 6, 1),
    firstRepaymentDate: firstRepaymentDate ?? DateTime(2026, 7, 10),
    lastRepaymentDate: lastRepaymentDate ?? DateTime(2026, 9, 10),
    repaymentMethod: InstallmentRepaymentMethod.flatFee,
    totalFeeMinor: 1200,
  );
}

InstallmentContract _contract({
  required String id,
  Money principal = const Money(minorUnits: 120000),
  int totalPeriods = 2,
  int totalFeeMinor = 0,
  InstallmentRepaymentMethod repaymentMethod =
      InstallmentRepaymentMethod.equalPrincipal,
  String? disbursementTransactionId,
}) {
  return InstallmentContract(
    id: id,
    liabilityAccountId: 'loan-liability',
    sourceType: InstallmentSourceType.disbursement,
    disbursementAccountId:
        disbursementTransactionId == null ? null : 'asset-cash',
    disbursementTransactionId: disbursementTransactionId,
    principal: principal,
    totalPeriods: totalPeriods,
    borrowingDate: DateTime(2026, 6, 1),
    firstRepaymentDate: DateTime(2026, 7, 10),
    lastRepaymentDate: DateTime(2026, 9, 10),
    repaymentMethod: repaymentMethod,
    interestAccrualMethod: InterestAccrualMethod.daily,
    totalFeeMinor: totalFeeMinor,
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 6, 1),
  );
}

InstallmentSchedule _schedule({
  required String id,
  required String contractId,
  required int periodNo,
  InstallmentScheduleStatus status = InstallmentScheduleStatus.pending,
  Money principal = const Money(minorUnits: 5000),
  Money interest = const Money(minorUnits: 50),
  Money? fee,
  DateTime? date,
}) {
  return InstallmentSchedule(
    id: id,
    contractId: contractId,
    periodNo: periodNo,
    expectedRepaymentDate: date ?? DateTime(2026, 6 + periodNo, 10),
    expectedPrincipal: principal,
    expectedInterest: interest,
    expectedFee: fee ?? Money.zero(),
    status: status,
    createdAt: DateTime(2026, 6, 1),
  );
}

class _Fixture {
  final installments = _FakeInstallmentRepository();
  final repayments = _FakeRepaymentRepository();
  final creditAccounts = _FakeCreditAccountRepository();
  final posting = _FakePostingService();
  final correction = _FakeCorrectionService();
  final update = _FakeUpdateService();
  final query = _FakeTransactionQueryService();

  late final InstallmentAppService service = InstallmentAppServiceImpl(
    repository: installments,
    creditAccounts: creditAccounts,
    postingService: posting,
    correctionService: correction,
    updateService: update,
    repayments: repayments,
    transactionRunner: const _ImmediateRunner(),
  );
}

class _ImmediateRunner implements TransactionRunner {
  const _ImmediateRunner();

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}

class _FakeCreditAccountRepository implements CreditAccountRepository {
  final accounts = <String, CreditLiabilityAccount>{};

  @override
  Future<CreditLiabilityAccount?> findByAccountId(String accountId) async {
    return accounts[accountId];
  }

  @override
  Future<List<CreditLiabilityAccount>> listAll() async =>
      accounts.values.toList();

  @override
  Stream<Map<String, CreditLiabilityAccount>> watchByAccountId() {
    return Stream.value(accounts);
  }

  @override
  Future<void> insert(CreditLiabilityAccountDraft draft) async {
    accounts[draft.accountId] = CreditLiabilityAccount(
      id: draft.id,
      accountId: draft.accountId,
      kind: draft.kind,
      creditLimit: draft.creditLimit,
      billingDay: draft.billingDay,
      repaymentDay: draft.repaymentDay,
      billingStartPeriod: draft.billingStartPeriod,
      billingDayToNext: draft.billingDayToNext,
    );
  }

  @override
  Future<void> update(
    String accountId,
    CreditLiabilityAccountPersistencePatch patch,
  ) async {}
}

class _FakeInstallmentRepository implements InstallmentRepository {
  final contracts = <String, InstallmentContract>{};
  final _schedules = <String, List<InstallmentSchedule>>{};
  int _nextContractId = 0;

  void putContract(InstallmentContract contract) {
    contracts[contract.id] = contract;
  }

  void putSchedules(String contractId, List<InstallmentSchedule> schedules) {
    _schedules[contractId] = [...schedules];
  }

  List<InstallmentSchedule> schedulesFor(String contractId) {
    return [...?_schedules[contractId]]
      ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
  }

  @override
  Future<InstallmentContract?> findContract(String id) async => contracts[id];

  @override
  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  ) async {
    return contracts.values
        .where((contract) => contract.liabilityAccountId == liabilityAccountId)
        .toList();
  }

  @override
  Future<List<InstallmentSchedule>> listSchedules(String contractId) async {
    return schedulesFor(contractId);
  }

  @override
  Future<List<InstallmentSchedule>> listSchedulesByLiabilityAccount(
    String liabilityAccountId,
  ) async {
    final result = <InstallmentSchedule>[];
    for (final contract in contracts.values) {
      if (contract.liabilityAccountId == liabilityAccountId) {
        result.addAll(schedulesFor(contract.id));
      }
    }
    return result;
  }

  @override
  Future<InstallmentSchedule?> findSchedule(String scheduleId) async {
    for (final schedules in _schedules.values) {
      for (final schedule in schedules) {
        if (schedule.id == scheduleId) return schedule;
      }
    }
    return null;
  }

  @override
  Future<InstallmentContract?> findContractByDisbursementTransaction(
    String transactionId,
  ) async {
    for (final contract in contracts.values) {
      if (contract.disbursementTransactionId == transactionId) return contract;
    }
    return null;
  }

  @override
  Future<String> insertContract(InstallmentContractDraft draft) async {
    final id = 'contract-${++_nextContractId}';
    contracts[id] = InstallmentContract(
      id: id,
      liabilityAccountId: draft.liabilityAccountId,
      sourceType: draft.sourceType,
      disbursementAccountId: draft.disbursementAccountId,
      disbursementTransactionId: draft.disbursementTransactionId,
      principal: draft.principal,
      totalPeriods: draft.totalPeriods,
      borrowingDate: draft.borrowingDate,
      firstRepaymentDate: draft.firstRepaymentDate,
      lastRepaymentDate: draft.lastRepaymentDate,
      repaymentMethod: draft.repaymentMethod,
      interestRatePeriod: draft.interestRatePeriod,
      interestRatePpm: draft.interestRatePpm,
      interestAccrualMethod: draft.interestAccrualMethod,
      totalFeeMinor: draft.totalFeeMinor,
      status: draft.status,
      note: draft.note,
      createdAt: DateTime(2026, 6, 1),
    );
    return id;
  }

  @override
  Future<void> updateContract(
    String contractId,
    InstallmentContractPatch patch,
  ) async {
    final current = contracts[contractId]!;
    contracts[contractId] = InstallmentContract(
      id: current.id,
      liabilityAccountId: current.liabilityAccountId,
      sourceType: current.sourceType,
      disbursementAccountId:
          patch.disbursementAccountId ?? current.disbursementAccountId,
      disbursementTransactionId: current.disbursementTransactionId,
      principal: current.principal,
      totalPeriods: patch.totalPeriods ?? current.totalPeriods,
      borrowingDate: patch.borrowingDate ?? current.borrowingDate,
      firstRepaymentDate:
          patch.firstRepaymentDate ?? current.firstRepaymentDate,
      lastRepaymentDate: patch.lastRepaymentDate ?? current.lastRepaymentDate,
      repaymentMethod: patch.repaymentMethod ?? current.repaymentMethod,
      interestRatePeriod: patch.interestRatePeriod.applyTo(
        current.interestRatePeriod,
      ),
      interestRatePpm: patch.interestRatePpm.applyTo(current.interestRatePpm),
      interestAccrualMethod:
          patch.interestAccrualMethod ?? current.interestAccrualMethod,
      totalFeeMinor: patch.totalFeeMinor ?? current.totalFeeMinor,
      status: current.status,
      note: patch.note.applyTo(current.note),
      createdAt: current.createdAt,
    );
  }

  @override
  Future<void> replaceSchedules(
    String contractId,
    List<InstallmentScheduleDraft> drafts,
  ) async {
    _schedules[contractId] = [
      for (final draft in drafts)
        _schedule(
          id: '$contractId-schedule-${draft.periodNo}',
          contractId: contractId,
          periodNo: draft.periodNo,
          principal: draft.expectedPrincipal,
          interest: draft.expectedInterest,
          fee: draft.expectedFee,
          date: draft.expectedRepaymentDate,
        ),
    ];
  }

  @override
  Future<void> appendSchedules(
    String contractId,
    List<InstallmentScheduleDraft> drafts,
  ) async {
    _schedules.putIfAbsent(contractId, () => []).addAll([
      for (final draft in drafts)
        _schedule(
          id: '$contractId-schedule-${draft.periodNo}',
          contractId: contractId,
          periodNo: draft.periodNo,
          principal: draft.expectedPrincipal,
          interest: draft.expectedInterest,
          fee: draft.expectedFee,
          date: draft.expectedRepaymentDate,
        ),
    ]);
  }

  @override
  Future<void> updateSchedule(
    String scheduleId,
    InstallmentSchedulePatch patch,
  ) async {
    for (final entry in _schedules.entries) {
      final index = entry.value.indexWhere(
        (schedule) => schedule.id == scheduleId,
      );
      if (index == -1) continue;
      final current = entry.value[index];
      entry.value[index] = InstallmentSchedule(
        id: current.id,
        contractId: current.contractId,
        periodNo: current.periodNo,
        expectedRepaymentDate:
            patch.expectedRepaymentDate ?? current.expectedRepaymentDate,
        expectedPrincipal: patch.expectedPrincipal ?? current.expectedPrincipal,
        expectedInterest: patch.expectedInterest ?? current.expectedInterest,
        expectedFee: patch.expectedFee ?? current.expectedFee,
        status: patch.status ?? current.status,
        note: patch.note.applyTo(current.note),
        createdAt: current.createdAt,
      );
      return;
    }
  }

  @override
  Future<void> updateContractStatus(
    String contractId,
    InstallmentContractStatus status,
  ) async {
    final current = contracts[contractId]!;
    contracts[contractId] = InstallmentContract(
      id: current.id,
      liabilityAccountId: current.liabilityAccountId,
      sourceType: current.sourceType,
      disbursementAccountId: current.disbursementAccountId,
      disbursementTransactionId: current.disbursementTransactionId,
      principal: current.principal,
      totalPeriods: current.totalPeriods,
      borrowingDate: current.borrowingDate,
      firstRepaymentDate: current.firstRepaymentDate,
      lastRepaymentDate: current.lastRepaymentDate,
      repaymentMethod: current.repaymentMethod,
      interestRatePeriod: current.interestRatePeriod,
      interestRatePpm: current.interestRatePpm,
      interestAccrualMethod: current.interestAccrualMethod,
      totalFeeMinor: current.totalFeeMinor,
      status: status,
      note: current.note,
      createdAt: current.createdAt,
    );
  }

  @override
  Future<void> deleteContract(String contractId) async {
    contracts.remove(contractId);
    _schedules.remove(contractId);
  }
}

class _FakeRepaymentRepository implements RepaymentRepository {
  final repayments = <String, Repayment>{};
  final items = <String, List<RepaymentItem>>{};

  void putRepayment(Repayment repayment) {
    repayments[repayment.id] = repayment;
    items[repayment.id] = [...repayment.items];
  }

  @override
  Future<Repayment?> findRepayment(String repaymentId) async {
    return repayments[repaymentId];
  }

  @override
  Future<Repayment?> findByRootTransaction(String rootTransactionId) async {
    for (final repayment in repayments.values) {
      if (repayment.rootTransactionId == rootTransactionId) {
        return repayment;
      }
    }
    return null;
  }

  @override
  Future<List<Repayment>> listByTarget(
    RepaymentTargetType targetType,
    String targetId,
  ) async {
    return repayments.values
        .where((r) => r.targetType == targetType && r.targetId == targetId)
        .toList();
  }

  @override
  Future<List<RepaymentItem>> listItems(String repaymentId) async {
    return [...?items[repaymentId]];
  }

  @override
  Future<List<RepaymentItem>> listItemsByBillItem(String billItemId) async {
    return [
      for (final repaymentItems in items.values)
        for (final item in repaymentItems)
          if (item.billItemId == billItemId) item,
    ];
  }

  @override
  Future<void> saveRepayment(Repayment repayment) async {
    putRepayment(repayment);
  }

  @override
  Future<void> replaceRepaymentItems(
    String repaymentId,
    List<RepaymentItem> nextItems,
  ) async {
    final repayment = repayments[repaymentId];
    if (repayment != null) {
      repayment.replaceItems(nextItems);
    }
    items[repaymentId] = [...nextItems];
  }

  @override
  Future<void> deleteRepayment(String repaymentId) async {
    repayments.remove(repaymentId);
    items.remove(repaymentId);
  }
}

class _FakePostingService implements TransactionPostingAppService {
  final borrowingCommands = <CreateBorrowingCommand>[];

  @override
  Future<PostedTransactionResult> createBorrowing(
    CreateBorrowingCommand command,
  ) async {
    borrowingCommands.add(command);
    final id = 'tx-borrowing-${borrowingCommands.length}';
    return PostedTransactionResult(transactionId: id, rootTransactionId: id);
  }

  @override
  Future<PostedTransactionResult> createRepayment(
    CreateRepaymentCommand command,
  ) async {
    return const PostedTransactionResult(
      transactionId: 'tx-repay',
      rootTransactionId: 'tx-repay',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCorrectionService implements TransactionCorrectionAppService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUpdateService implements TransactionUpdateAppService {
  final ownershipCommands = <UpdateTransactionOwnershipCommand>[];

  @override
  Future<PostedTransactionResult> updateOwnership(
    UpdateTransactionOwnershipCommand command,
  ) async {
    ownershipCommands.add(command);
    return PostedTransactionResult(
      transactionId: command.transactionId,
      rootTransactionId: command.transactionId,
    );
  }

  @override
  Future<PostedTransactionResult> updateBasicInfo(
    UpdateTransactionBasicInfoCommand command,
  ) async {
    return PostedTransactionResult(
      transactionId: command.transactionId,
      rootTransactionId: command.transactionId,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransactionQueryService implements TransactionQueryService {
  @override
  Future<int> getDetailAmountSum({
    required Iterable<String> transactionIds,
    required TransactionDetailType detailType,
  }) async {
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
