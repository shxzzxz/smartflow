import 'package:drift/drift.dart' show Value, leftOuterJoin;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_balance_aggregate_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_entry_read_repository.dart';
import 'package:smartflow/data/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_posting_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_system_account_resolver.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_detail_read_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_read_repository.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/application/ledger/ledger_api.dart';
import 'package:smartflow/application/credit/credit_api.dart';
import 'package:smartflow/domain/ledger/ledger/poster.dart';
import 'package:smartflow/application/ledger/use_case/receipt_builder.dart';

import '../../../helper/test_app_database.dart';

void main() {
  group('InstallmentService integration', () {
    late AppDatabase database;
    late InstallmentService service;
    late int assetAccountId;
    late int liabilityAccountId;

    setUp(() async {
      database = createTestDatabase();
      final accountRepository = DriftAccountRepository(database);
      final postingRepository = DriftPostingRepository(database);
      final systemAccounts = DriftSystemAccountResolver(database);
      final queryService = TransactionQueryServiceImpl(
        transactionRead: DriftTransactionReadRepository(database),
        entryRead: DriftEntryReadRepository(database),
        detailRead: DriftTransactionDetailReadRepository(database),
        balanceAggregate: DriftBalanceAggregateRepository(database),
      );
      final transactionService = TransactionServiceImpl(
        poster: PosterImpl(postingRepository),
        receiptBuilder: ReceiptBuilder(
          accounts: accountRepository,
          query: queryService,
          systemAccounts: systemAccounts,
        ),
        accountRepository: accountRepository,
        transactionQueryService: queryService,
        postingRepository: postingRepository,
        transactionRunner: DriftTransactionRunner(database),
      );
      service = InstallmentServiceImpl(
        repository: DriftInstallmentRepository(database),
        transactionService: transactionService,
        transactionQueryService: queryService,
        transactionRunner: DriftTransactionRunner(database),
      );

      assetAccountId = await _insertAccount(
        database,
        name: '招行',
        type: AccountType.asset,
        subtype: AccountSubtype.bankCard,
        balanceMinor: 5000000,
      );
      liabilityAccountId = await _insertAccount(
        database,
        name: '借呗',
        type: AccountType.liability,
        subtype: AccountSubtype.loan,
      );
    });

    tearDown(() async {
      await database.close();
    });

    Future<int> createSimpleContract() async {
      final result = await service.createDisbursementContract(
        CreateDisbursementContractCommand(
          liabilityAccountId: liabilityAccountId,
          disbursementAccountId: assetAccountId,
          principal: const Money(minorUnits: 100000),
          totalPeriods: 1,
          borrowingDate: DateTime(2026, 5, 10),
          firstRepaymentDate: DateTime(2026, 6, 10),
          repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
        ),
      );
      return (result as Success<CreateContractResult>).value.contractId;
    }

    test('createDisbursementContract 写入 BORROWING + 合同 + 计划', () async {
      final result = await service.createDisbursementContract(
        CreateDisbursementContractCommand(
          liabilityAccountId: liabilityAccountId,
          disbursementAccountId: assetAccountId,
          principal: const Money(minorUnits: 1200000),
          totalPeriods: 12,
          borrowingDate: DateTime(2026, 5, 10),
          firstRepaymentDate: DateTime(2026, 6, 10),
          repaymentMethod: InstallmentRepaymentMethod.equalInstallment,
          interestRatePeriod: InterestRatePeriod.monthly,
          interestRatePpm: 5000,
        ),
      );
      expect(result, isA<Success<CreateContractResult>>());
      final contractId =
          (result as Success<CreateContractResult>).value.contractId;

      final contract = await service.findContract(contractId);
      expect(contract, isNotNull);
      expect(contract!.sourceType, InstallmentSourceType.disbursement);
      expect(contract.status, InstallmentContractStatus.active);
      expect(contract.disbursementTransactionId, isNotNull);
      await _expectOwnership(
        database,
        transactionId: contract.disbursementTransactionId!,
        ownerId: contractId,
        ownerRole: 'disbursement',
      );
      expect(contract.firstRepaymentDate, DateTime(2026, 6, 10));
      expect(contract.lastRepaymentDate, DateTime(2027, 5, 10));

      final schedules = await service.listSchedules(contractId);
      expect(schedules, hasLength(12));
      final principalSum = schedules.fold<int>(
        0,
        (acc, s) => acc + s.expectedPrincipal.minorUnits,
      );
      expect(principalSum, 1200000);

      expect(await _balanceOf(database, assetAccountId), 5000000 + 1200000);
      expect(await _balanceOf(database, liabilityAccountId), 1200000);
    });

    test('createBillConversionContract 不产生交易', () async {
      final result = await service.createBillConversionContract(
        CreateBillConversionContractCommand(
          liabilityAccountId: liabilityAccountId,
          principal: const Money(minorUnits: 500000),
          totalPeriods: 12,
          borrowingDate: DateTime(2026, 5, 9),
          firstRepaymentDate: DateTime(2026, 6, 9),
          repaymentMethod: InstallmentRepaymentMethod.flatFee,
          totalFeeMinor: 36000,
        ),
      );
      final contractId =
          (result as Success<CreateContractResult>).value.contractId;
      final contract = await service.findContract(contractId);
      expect(contract!.disbursementTransactionId, isNull);
      expect(contract.totalFeeMinor, 36000);
      expect(await _balanceOf(database, liabilityAccountId), 0);
      final schedules = await service.listSchedules(contractId);
      expect(schedules, hasLength(12));
      final feeSum = schedules.fold<int>(
        0,
        (acc, s) => acc + s.expectedFee.minorUnits,
      );
      expect(feeSum, 36000);
    });

    test('createScheduledRepayment 翻转期次状态并联动合同 settled', () async {
      final contractId = await createSimpleContract();
      final schedules = await service.listSchedules(contractId);
      final result = await service.createScheduledRepayment(
        CreateScheduledRepaymentCommand(
          contractId: contractId,
          scheduleId: schedules.single.id,
          principal: const Money(minorUnits: 100000),
          paidFromAccountId: assetAccountId,
          occurredAt: DateTime(2026, 7, 10),
        ),
      );
      expect(result, isA<Success>());
      final transactionId =
          (result as Success<CreatedTransactionResult>).value.transactionId;
      await _expectOwnership(
        database,
        transactionId: transactionId,
        ownerId: contractId,
        ownerRole: 'scheduled_repayment',
      );
      final updated = await service.listSchedules(contractId);
      expect(updated.single.status, InstallmentScheduleStatus.paid);
      final contract = await service.findContract(contractId);
      expect(contract!.status, InstallmentContractStatus.settled);
    });

    test('createPrincipalPrepayment 触发 PENDING 期次重算', () async {
      final result = await service.createDisbursementContract(
        CreateDisbursementContractCommand(
          liabilityAccountId: liabilityAccountId,
          disbursementAccountId: assetAccountId,
          principal: const Money(minorUnits: 1000000),
          totalPeriods: 10,
          borrowingDate: DateTime(2026, 5, 10),
          firstRepaymentDate: DateTime(2026, 6, 10),
          repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
        ),
      );
      final contractId =
          (result as Success<CreateContractResult>).value.contractId;

      final beforeDates =
          (await service.listSchedules(
            contractId,
          )).map((s) => s.expectedRepaymentDate).toList();

      final extra = await service.createPrincipalPrepayment(
        CreatePrincipalPrepaymentCommand(
          contractId: contractId,
          principal: const Money(minorUnits: 300000),
          paidFromAccountId: assetAccountId,
          occurredAt: DateTime(2026, 6, 1),
        ),
      );
      expect(extra, isA<Success>());
      final transactionId =
          (extra as Success<CreatedTransactionResult>).value.transactionId;
      await _expectOwnership(
        database,
        transactionId: transactionId,
        ownerId: contractId,
        ownerRole: 'extra_principal',
      );

      final schedules = await service.listSchedules(contractId);
      final pendingPrincipalSum = schedules
          .where((s) => s.status == InstallmentScheduleStatus.pending)
          .fold<int>(0, (acc, s) => acc + s.expectedPrincipal.minorUnits);
      expect(pendingPrincipalSum, 700000);

      // 提前还本后日期不能变。
      final afterDates = schedules.map((s) => s.expectedRepaymentDate).toList();
      expect(afterDates, beforeDates);
    });

    test('createPrincipalPrepayment 支持利息', () async {
      final contractResult = await service.createDisbursementContract(
        CreateDisbursementContractCommand(
          liabilityAccountId: liabilityAccountId,
          disbursementAccountId: assetAccountId,
          principal: const Money(minorUnits: 1000000),
          totalPeriods: 10,
          borrowingDate: DateTime(2026, 5, 10),
          firstRepaymentDate: DateTime(2026, 6, 10),
          repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
        ),
      );
      final contractId =
          (contractResult as Success<CreateContractResult>).value.contractId;

      final extra = await service.createPrincipalPrepayment(
        CreatePrincipalPrepaymentCommand(
          contractId: contractId,
          principal: const Money(minorUnits: 300000),
          interest: const Money(minorUnits: 1500),
          paidFromAccountId: assetAccountId,
          occurredAt: DateTime(2026, 6, 1),
        ),
      );
      expect(extra, isA<Success>());

      // 资产账户应扣减本金 + 利息
      final assetBalance = await _balanceOf(database, assetAccountId);
      expect(assetBalance, 5000000 + 1000000 - 300000 - 1500);
    });

    test('createEarlySettlement 剩余期次 skipped 且合同 closed', () async {
      final contractResult = await service.createDisbursementContract(
        CreateDisbursementContractCommand(
          liabilityAccountId: liabilityAccountId,
          disbursementAccountId: assetAccountId,
          principal: const Money(minorUnits: 1000000),
          totalPeriods: 10,
          borrowingDate: DateTime(2026, 5, 10),
          firstRepaymentDate: DateTime(2026, 6, 10),
          repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
        ),
      );
      final contractId =
          (contractResult as Success<CreateContractResult>).value.contractId;

      final settle = await service.createEarlySettlement(
        CreateEarlySettlementCommand(
          contractId: contractId,
          principal: const Money(minorUnits: 1000000),
          paidFromAccountId: assetAccountId,
          occurredAt: DateTime(2026, 7, 1),
        ),
      );
      expect(settle, isA<Success>());
      final transactionId =
          (settle as Success<CreatedTransactionResult>).value.transactionId;
      await _expectOwnership(
        database,
        transactionId: transactionId,
        ownerId: contractId,
        ownerRole: 'early_settlement',
      );
      final contract = await service.findContract(contractId);
      expect(contract!.status, InstallmentContractStatus.closed);
      final schedules = await service.listSchedules(contractId);
      for (final s in schedules) {
        expect(s.status, InstallmentScheduleStatus.skipped);
      }
    });

    test('revertRepayment(regular) 将 schedule 回退至 pending', () async {
      final contractId = await createSimpleContract();
      final schedules = await service.listSchedules(contractId);

      final repayResult = await service.createScheduledRepayment(
        CreateScheduledRepaymentCommand(
          contractId: contractId,
          scheduleId: schedules.single.id,
          principal: const Money(minorUnits: 100000),
          paidFromAccountId: assetAccountId,
          occurredAt: DateTime(2026, 7, 10),
        ),
      );
      final txId = (repayResult as Success).value.transactionId;

      final revert = await service.revertRepayment(
        RevertRepaymentCommand(transactionId: txId),
      );
      expect(revert, isA<Success>());

      final updated = await service.listSchedules(contractId);
      expect(updated.single.status, InstallmentScheduleStatus.pending);
      final contract = await service.findContract(contractId);
      expect(contract!.status, InstallmentContractStatus.active);
    });

    test(
      'revertRepayment(earlySettlement) 恢复期次为 pending 且合同回 active',
      () async {
        final contractResult = await service.createDisbursementContract(
          CreateDisbursementContractCommand(
            liabilityAccountId: liabilityAccountId,
            disbursementAccountId: assetAccountId,
            principal: const Money(minorUnits: 500000),
            totalPeriods: 5,
            borrowingDate: DateTime(2026, 5, 10),
            firstRepaymentDate: DateTime(2026, 6, 10),
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          ),
        );
        final contractId =
            (contractResult as Success<CreateContractResult>).value.contractId;
        final settle = await service.createEarlySettlement(
          CreateEarlySettlementCommand(
            contractId: contractId,
            principal: const Money(minorUnits: 500000),
            paidFromAccountId: assetAccountId,
            occurredAt: DateTime(2026, 7, 1),
          ),
        );
        final settleTxId = (settle as Success).value.transactionId;

        final revert = await service.revertRepayment(
          RevertRepaymentCommand(transactionId: settleTxId),
        );
        expect(revert, isA<Success>());
        final contract = await service.findContract(contractId);
        expect(contract!.status, InstallmentContractStatus.active);
        final schedules = await service.listSchedules(contractId);
        for (final s in schedules) {
          expect(s.status, InstallmentScheduleStatus.pending);
        }
      },
    );

    group('updateContract', () {
      test('调整末期还款日：仅末期日期变更，其它 pending 行日期不变', () async {
        final contractResult = await service.createDisbursementContract(
          CreateDisbursementContractCommand(
            liabilityAccountId: liabilityAccountId,
            disbursementAccountId: assetAccountId,
            principal: const Money(minorUnits: 1200000),
            totalPeriods: 12,
            borrowingDate: DateTime(2026, 5, 10),
            firstRepaymentDate: DateTime(2026, 6, 10),
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          ),
        );
        final contractId =
            (contractResult as Success<CreateContractResult>).value.contractId;

        final res = await service.updateContract(
          UpdateContractCommand(
            contractId: contractId,
            totalPeriods: 12,
            firstRepaymentDate: DateTime(2026, 6, 10),
            lastRepaymentDate: DateTime(2027, 6, 20), // 末期推后 10 天
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          ),
        );
        expect(res, isA<Success>());
        final schedules = await service.listSchedules(contractId);
        expect(schedules.last.expectedRepaymentDate, DateTime(2027, 6, 20));
        // 第 11 期保持原日期
        expect(schedules[10].expectedRepaymentDate, DateTime(2027, 4, 10));
      });

      test('paid 后修改首期还款日应失败', () async {
        final contractResult = await service.createDisbursementContract(
          CreateDisbursementContractCommand(
            liabilityAccountId: liabilityAccountId,
            disbursementAccountId: assetAccountId,
            principal: const Money(minorUnits: 600000),
            totalPeriods: 6,
            borrowingDate: DateTime(2026, 5, 10),
            firstRepaymentDate: DateTime(2026, 6, 10),
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          ),
        );
        final contractId =
            (contractResult as Success<CreateContractResult>).value.contractId;
        final schedules = await service.listSchedules(contractId);
        await service.createScheduledRepayment(
          CreateScheduledRepaymentCommand(
            contractId: contractId,
            scheduleId: schedules.first.id,
            principal: const Money(minorUnits: 100000),
            paidFromAccountId: assetAccountId,
            occurredAt: DateTime(2026, 6, 10),
          ),
        );

        final res = await service.updateContract(
          UpdateContractCommand(
            contractId: contractId,
            totalPeriods: 6,
            firstRepaymentDate: DateTime(2026, 7, 10), // 改了
            lastRepaymentDate: DateTime(2026, 12, 10),
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          ),
        );
        expect(res, isA<FailureResult>());
      });

      test('期数减少：超出的 pending 行被 skipped 清零', () async {
        final contractResult = await service.createDisbursementContract(
          CreateDisbursementContractCommand(
            liabilityAccountId: liabilityAccountId,
            disbursementAccountId: assetAccountId,
            principal: const Money(minorUnits: 600000),
            totalPeriods: 6,
            borrowingDate: DateTime(2026, 5, 10),
            firstRepaymentDate: DateTime(2026, 6, 10),
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          ),
        );
        final contractId =
            (contractResult as Success<CreateContractResult>).value.contractId;

        final res = await service.updateContract(
          UpdateContractCommand(
            contractId: contractId,
            totalPeriods: 3,
            firstRepaymentDate: DateTime(2026, 6, 10),
            lastRepaymentDate: DateTime(2026, 8, 10),
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          ),
        );
        expect(res, isA<Success>());

        final schedules = await service.listSchedules(contractId);
        final pending =
            schedules
                .where((s) => s.status == InstallmentScheduleStatus.pending)
                .toList();
        final skipped =
            schedules
                .where((s) => s.status == InstallmentScheduleStatus.skipped)
                .toList();
        expect(pending, hasLength(3));
        expect(skipped, hasLength(3));
        final principalSum = pending.fold<int>(
          0,
          (acc, s) => acc + s.expectedPrincipal.minorUnits,
        );
        expect(principalSum, 600000);
      });

      test('schedulePatches 覆盖 pending 行金额', () async {
        final contractResult = await service.createDisbursementContract(
          CreateDisbursementContractCommand(
            liabilityAccountId: liabilityAccountId,
            disbursementAccountId: assetAccountId,
            principal: const Money(minorUnits: 600000),
            totalPeriods: 6,
            borrowingDate: DateTime(2026, 5, 10),
            firstRepaymentDate: DateTime(2026, 6, 10),
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          ),
        );
        final contractId =
            (contractResult as Success<CreateContractResult>).value.contractId;

        await service.updateContract(
          UpdateContractCommand(
            contractId: contractId,
            totalPeriods: 6,
            firstRepaymentDate: DateTime(2026, 6, 10),
            lastRepaymentDate: DateTime(2026, 11, 10),
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
            schedulePatches: [
              const SchedulePendingPatch(
                periodNo: 3,
                expectedPrincipal: Money(minorUnits: 200000),
                expectedInterest: Money(minorUnits: 0),
                expectedFee: Money(minorUnits: 0),
              ),
            ],
          ),
        );
        final schedules = await service.listSchedules(contractId);
        expect(
          schedules
              .firstWhere((s) => s.periodNo == 3)
              .expectedPrincipal
              .minorUnits,
          200000,
        );
      });

      test('期数 < paidCount+1 失败', () async {
        final contractResult = await service.createDisbursementContract(
          CreateDisbursementContractCommand(
            liabilityAccountId: liabilityAccountId,
            disbursementAccountId: assetAccountId,
            principal: const Money(minorUnits: 600000),
            totalPeriods: 6,
            borrowingDate: DateTime(2026, 5, 10),
            firstRepaymentDate: DateTime(2026, 6, 10),
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          ),
        );
        final contractId =
            (contractResult as Success<CreateContractResult>).value.contractId;
        final schedules = await service.listSchedules(contractId);
        // 还掉前 2 期
        await service.createScheduledRepayment(
          CreateScheduledRepaymentCommand(
            contractId: contractId,
            scheduleId: schedules[0].id,
            principal: const Money(minorUnits: 100000),
            paidFromAccountId: assetAccountId,
            occurredAt: DateTime(2026, 6, 10),
          ),
        );
        await service.createScheduledRepayment(
          CreateScheduledRepaymentCommand(
            contractId: contractId,
            scheduleId: schedules[1].id,
            principal: const Money(minorUnits: 100000),
            paidFromAccountId: assetAccountId,
            occurredAt: DateTime(2026, 7, 10),
          ),
        );

        // 试图把期数改成 2（应失败，因为 paid=2，至少要 3）
        final res = await service.updateContract(
          UpdateContractCommand(
            contractId: contractId,
            totalPeriods: 2,
            firstRepaymentDate: DateTime(2026, 6, 10),
            lastRepaymentDate: DateTime(2026, 7, 10),
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          ),
        );
        expect(res, isA<FailureResult>());
      });

      test('只改 disbursementAccountId 不重算且联动放款交易', () async {
        final contractResult = await service.createDisbursementContract(
          CreateDisbursementContractCommand(
            liabilityAccountId: liabilityAccountId,
            disbursementAccountId: assetAccountId,
            principal: const Money(minorUnits: 600000),
            totalPeriods: 6,
            borrowingDate: DateTime(2026, 5, 10),
            firstRepaymentDate: DateTime(2026, 6, 10),
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          ),
        );
        final contractId =
            (contractResult as Success<CreateContractResult>).value.contractId;
        final disbursementTxId =
            (await service.findContract(
              contractId,
            ))!.disbursementTransactionId!;
        final beforeSchedules = await service.listSchedules(contractId);
        final beforeDates =
            beforeSchedules.map((s) => s.expectedRepaymentDate).toList();
        final beforePrincipals =
            beforeSchedules.map((s) => s.expectedPrincipal.minorUnits).toList();

        final newAssetId = await _insertAccount(
          database,
          name: '工行',
          type: AccountType.asset,
          subtype: AccountSubtype.bankCard,
          balanceMinor: 0,
        );

        final res = await service.updateContract(
          UpdateContractCommand(
            contractId: contractId,
            disbursementAccountId: newAssetId,
          ),
        );
        expect(res, isA<Success>());

        // 合同同步
        final contract = await service.findContract(contractId);
        expect(contract!.disbursementAccountId, newAssetId);

        // schedule 未被重算
        final afterSchedules = await service.listSchedules(contractId);
        expect(
          afterSchedules.map((s) => s.expectedRepaymentDate).toList(),
          beforeDates,
        );
        expect(
          afterSchedules.map((s) => s.expectedPrincipal.minorUnits).toList(),
          beforePrincipals,
        );

        // 放款交易的 settlement entry 切换到新账户
        expect(
          await _settlementAccountIdOf(database, disbursementTxId),
          newAssetId,
        );
      });

      test('改 borrowingDate 同时重算 schedule 并联动放款交易 occurredAt', () async {
        final contractResult = await service.createDisbursementContract(
          CreateDisbursementContractCommand(
            liabilityAccountId: liabilityAccountId,
            disbursementAccountId: assetAccountId,
            principal: const Money(minorUnits: 600000),
            totalPeriods: 6,
            borrowingDate: DateTime(2026, 5, 10),
            firstRepaymentDate: DateTime(2026, 6, 10),
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          ),
        );
        final contractId =
            (contractResult as Success<CreateContractResult>).value.contractId;
        final disbursementTxId =
            (await service.findContract(
              contractId,
            ))!.disbursementTransactionId!;

        final res = await service.updateContract(
          UpdateContractCommand(
            contractId: contractId,
            borrowingDate: DateTime(2026, 5, 15),
          ),
        );
        expect(res, isA<Success>());

        final contract = await service.findContract(contractId);
        expect(contract!.borrowingDate, DateTime(2026, 5, 15));

        // 放款交易 occurredAt 同步
        final tx = await _readTransaction(database, disbursementTxId);
        expect(tx.occurredAt, DateTime(2026, 5, 15));
      });

      test('Patch.set / clear 联动合同 note 与放款交易 note', () async {
        final contractResult = await service.createDisbursementContract(
          CreateDisbursementContractCommand(
            liabilityAccountId: liabilityAccountId,
            disbursementAccountId: assetAccountId,
            principal: const Money(minorUnits: 600000),
            totalPeriods: 6,
            borrowingDate: DateTime(2026, 5, 10),
            firstRepaymentDate: DateTime(2026, 6, 10),
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
            note: '原备注',
          ),
        );
        final contractId =
            (contractResult as Success<CreateContractResult>).value.contractId;
        final disbursementTxId =
            (await service.findContract(
              contractId,
            ))!.disbursementTransactionId!;

        await service.updateContract(
          UpdateContractCommand(
            contractId: contractId,
            note: const Patch.set('新备注'),
          ),
        );
        expect((await service.findContract(contractId))!.note, '新备注');
        expect(
          (await _readTransaction(database, disbursementTxId)).note,
          '新备注',
        );

        await service.updateContract(
          UpdateContractCommand(
            contractId: contractId,
            note: const Patch.clear(),
          ),
        );
        expect((await service.findContract(contractId))!.note, isNull);
        expect(
          (await _readTransaction(database, disbursementTxId)).note,
          isNull,
        );
      });

      test('Patch.clear 清除利率后重算 pending', () async {
        final contractResult = await service.createDisbursementContract(
          CreateDisbursementContractCommand(
            liabilityAccountId: liabilityAccountId,
            disbursementAccountId: assetAccountId,
            principal: const Money(minorUnits: 1200000),
            totalPeriods: 12,
            borrowingDate: DateTime(2026, 5, 10),
            firstRepaymentDate: DateTime(2026, 6, 10),
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
            interestRatePeriod: InterestRatePeriod.monthly,
            interestRatePpm: 5000,
          ),
        );
        final contractId =
            (contractResult as Success<CreateContractResult>).value.contractId;

        final res = await service.updateContract(
          UpdateContractCommand(
            contractId: contractId,
            interestRatePeriod: const Patch.clear(),
            interestRatePpm: const Patch.clear(),
          ),
        );
        expect(res, isA<Success>());

        final contract = await service.findContract(contractId);
        expect(contract!.interestRatePeriod, isNull);
        expect(contract.interestRatePpm, isNull);

        // 利率清空后 pending 行利息应归零
        final schedules = await service.listSchedules(contractId);
        final pendingInterest = schedules
            .where((s) => s.status == InstallmentScheduleStatus.pending)
            .fold<int>(0, (acc, s) => acc + s.expectedInterest.minorUnits);
        expect(pendingInterest, 0);
      });

      test('账单分期合同不允许传 disbursementAccountId', () async {
        final billResult = await service.createBillConversionContract(
          CreateBillConversionContractCommand(
            liabilityAccountId: liabilityAccountId,
            principal: const Money(minorUnits: 500000),
            totalPeriods: 5,
            borrowingDate: DateTime(2026, 5, 10),
            firstRepaymentDate: DateTime(2026, 6, 10),
            repaymentMethod: InstallmentRepaymentMethod.flatFee,
          ),
        );
        final contractId =
            (billResult as Success<CreateContractResult>).value.contractId;
        final res = await service.updateContract(
          UpdateContractCommand(
            contractId: contractId,
            disbursementAccountId: assetAccountId,
          ),
        );
        expect(res, isA<FailureResult>());
      });
    });

    group('editRepayment', () {
      test('改账户委托至放款源账户', () async {
        final contractId = await createSimpleContract();
        final schedules = await service.listSchedules(contractId);
        final repayResult = await service.createScheduledRepayment(
          CreateScheduledRepaymentCommand(
            contractId: contractId,
            scheduleId: schedules.single.id,
            principal: const Money(minorUnits: 100000),
            paidFromAccountId: assetAccountId,
            occurredAt: DateTime(2026, 7, 10),
          ),
        );
        final txId =
            (repayResult as Success<CreatedTransactionResult>)
                .value
                .transactionId;

        final newAssetId = await _insertAccount(
          database,
          name: '建行',
          type: AccountType.asset,
          subtype: AccountSubtype.bankCard,
          balanceMinor: 200000,
        );

        final res = await service.editRepayment(
          EditRepaymentCommand(
            transactionId: txId,
            paidFromAccountId: newAssetId,
          ),
        );
        expect(res, isA<Success>());
        expect(await _settlementAccountIdOf(database, txId), newAssetId);
      });

      test('改时间与备注委托至 transaction', () async {
        final contractId = await createSimpleContract();
        final schedules = await service.listSchedules(contractId);
        final repayResult = await service.createScheduledRepayment(
          CreateScheduledRepaymentCommand(
            contractId: contractId,
            scheduleId: schedules.single.id,
            principal: const Money(minorUnits: 100000),
            paidFromAccountId: assetAccountId,
            occurredAt: DateTime(2026, 7, 10),
            note: '初始',
          ),
        );
        final txId =
            (repayResult as Success<CreatedTransactionResult>)
                .value
                .transactionId;

        await service.editRepayment(
          EditRepaymentCommand(
            transactionId: txId,
            occurredAt: DateTime(2026, 7, 15),
            note: const Patch.set('改后'),
          ),
        );
        final tx = await _readTransaction(database, txId);
        expect(tx.occurredAt, DateTime(2026, 7, 15));
        expect(tx.note, '改后');

        await service.editRepayment(
          EditRepaymentCommand(transactionId: txId, note: const Patch.clear()),
        );
        expect((await _readTransaction(database, txId)).note, isNull);
      });

      test('非分期还款交易拒绝编辑', () async {
        // 用普通收入交易模拟一笔与分期无关的 transaction
        final accountRepository = DriftAccountRepository(database);
        final postingRepository = DriftPostingRepository(database);
        final systemAccounts = DriftSystemAccountResolver(database);
        final queryService = TransactionQueryServiceImpl(
          transactionRead: DriftTransactionReadRepository(database),
          entryRead: DriftEntryReadRepository(database),
          detailRead: DriftTransactionDetailReadRepository(database),
          balanceAggregate: DriftBalanceAggregateRepository(database),
        );
        final transactionService = TransactionServiceImpl(
          poster: PosterImpl(postingRepository),
          receiptBuilder: ReceiptBuilder(
            accounts: accountRepository,
            query: queryService,
            systemAccounts: systemAccounts,
          ),
          accountRepository: accountRepository,
          transactionQueryService: queryService,
          postingRepository: postingRepository,
          transactionRunner: DriftTransactionRunner(database),
        );
        final incomeAccountId = await _insertAccount(
          database,
          name: '工资',
          type: AccountType.income,
        );
        final incomeResult = await transactionService.createIncome(
          CreateIncomeCommand(
            amount: const Money(minorUnits: 100000),
            receiveAccountId: assetAccountId,
            incomeAccountId: incomeAccountId,
            occurredAt: DateTime(2026, 5, 1),
          ),
        );
        final txId =
            (incomeResult as Success<CreatedTransactionResult>)
                .value
                .transactionId;

        final res = await service.editRepayment(
          EditRepaymentCommand(
            transactionId: txId,
            occurredAt: DateTime(2026, 5, 2),
          ),
        );
        expect(res, isA<FailureResult>());
      });
    });
  });
}

Future<int> _insertAccount(
  AppDatabase database, {
  required String name,
  required AccountType type,
  AccountSubtype? subtype,
  int balanceMinor = 0,
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          name: name,
          accountType: type,
          accountSubtype: Value(subtype),
          balanceMinor: Value(balanceMinor),
        ),
      );
}

Future<int> _balanceOf(AppDatabase database, int accountId) async {
  final row =
      await (database.select(database.accounts)
        ..where((a) => a.id.equals(accountId))).getSingle();
  return row.balanceMinor;
}

Future<void> _expectOwnership(
  AppDatabase database, {
  required int transactionId,
  required int ownerId,
  required String ownerRole,
}) async {
  final row =
      await (database.select(database.transactions)
        ..where((t) => t.id.equals(transactionId))).getSingle();
  expect(row.ownerType, 'installment');
  expect(row.ownerId, ownerId);
  expect(row.ownerRole, ownerRole);
}

Future<TransactionRow> _readTransaction(
  AppDatabase database,
  int transactionId,
) {
  return (database.select(database.transactions)
    ..where((t) => t.id.equals(transactionId))).getSingle();
}

/// 反查交易的"结算账户"对应 entry 的 accountId。
/// 约定：disbursement 与 repayment 的 settlement entry 都唯一指向一笔 asset 账户。
Future<int> _settlementAccountIdOf(
  AppDatabase database,
  int transactionId,
) async {
  final query = database.select(database.entries).join([
    leftOuterJoin(
      database.accounts,
      database.accounts.id.equalsExp(database.entries.accountId),
    ),
  ])..where(database.entries.transactionId.equals(transactionId));
  final rows = await query.get();
  for (final row in rows) {
    final account = row.readTableOrNull(database.accounts);
    if (account?.accountType == AccountType.asset) {
      return row.readTable(database.entries).accountId;
    }
  }
  fail('No settlement (asset) entry found for transaction $transactionId');
}
