import 'package:smartflow/application/ledger/ledger_command_api.dart' as ledger;
import 'package:smartflow/application/ledger/ledger_query_api.dart'
    as ledger_query;
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/installment_schedule_generator.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

class RepaymentTransactionInfo {
  const RepaymentTransactionInfo({
    required this.paidFromAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String paidFromAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
  final String? note;
}

class BillRepaymentAllocation {
  const BillRepaymentAllocation({
    required this.billItemId,
    required this.allocated,
  });

  final String billItemId;
  final RepaymentAmountBreakdown allocated;
}

class CreateBillRepaymentCommand {
  const CreateBillRepaymentCommand({
    required this.billId,
    required this.allocations,
    this.transactionInfo,
    this.note,
  });

  final String billId;
  final List<BillRepaymentAllocation> allocations;
  final RepaymentTransactionInfo? transactionInfo;
  final String? note;
}

class CreateBillConversionInstallmentRepaymentCommand {
  const CreateBillConversionInstallmentRepaymentCommand({
    required this.billId,
    required this.allocations,
    required this.totalPeriods,
    required this.repaymentMethod,
    this.borrowingDate,
    this.firstRepaymentDate,
    this.lastRepaymentDate,
    this.interestRatePeriod,
    this.interestRatePpm,
    this.interestAccrualMethod = InterestAccrualMethod.daily,
    this.totalFeeMinor = 0,
    this.equalInstallmentOverrideMinor,
    this.note,
  });

  final String billId;
  final List<BillRepaymentAllocation> allocations;
  final int totalPeriods;
  final DateTime? borrowingDate;
  final DateTime? firstRepaymentDate;
  final DateTime? lastRepaymentDate;
  final InstallmentRepaymentMethod repaymentMethod;
  final InterestRatePeriod? interestRatePeriod;
  final int? interestRatePpm;
  final InterestAccrualMethod interestAccrualMethod;
  final int totalFeeMinor;
  final int? equalInstallmentOverrideMinor;
  final String? note;
}

class CreateExtraPrincipalRepaymentCommand {
  const CreateExtraPrincipalRepaymentCommand({
    required this.contractId,
    required this.principal,
    this.interest,
    this.fee,
    this.transactionInfo,
    this.note,
  });

  final String contractId;
  final Money principal;
  final Money? interest;
  final Money? fee;
  final RepaymentTransactionInfo? transactionInfo;
  final String? note;
}

class CreateEarlySettlementRepaymentCommand {
  const CreateEarlySettlementRepaymentCommand({
    required this.contractId,
    required this.principal,
    this.interest,
    this.fee,
    this.transactionInfo,
    this.note,
  });

  final String contractId;
  final Money principal;
  final Money? interest;
  final Money? fee;
  final RepaymentTransactionInfo? transactionInfo;
  final String? note;
}

class CreateUnattributedRepaymentCommand {
  const CreateUnattributedRepaymentCommand({
    required this.accountId,
    required this.amount,
    this.transactionInfo,
    this.note,
  });

  final String accountId;
  final Money amount;
  final RepaymentTransactionInfo? transactionInfo;
  final String? note;
}

class CreateRepaymentResult {
  const CreateRepaymentResult({
    required this.repaymentId,
    this.transactionId,
    this.rootTransactionId,
    this.contractId,
  });

  final String repaymentId;
  final String? transactionId;
  final String? rootTransactionId;
  final String? contractId;
}

abstract interface class RepaymentService {
  Future<CreateRepaymentResult> createBillRepayment(
    CreateBillRepaymentCommand command,
  );

  Future<CreateRepaymentResult> createBillConversionInstallmentRepayment(
    CreateBillConversionInstallmentRepaymentCommand command,
  );

  Future<CreateRepaymentResult> createExtraPrincipalRepayment(
    CreateExtraPrincipalRepaymentCommand command,
  );

  Future<CreateRepaymentResult> createEarlySettlementRepayment(
    CreateEarlySettlementRepaymentCommand command,
  );

  Future<CreateRepaymentResult> createUnattributedRepayment(
    CreateUnattributedRepaymentCommand command,
  );
}

class RepaymentServiceImpl implements RepaymentService {
  const RepaymentServiceImpl({
    required BillRepository bills,
    required RepaymentRepository repayments,
    required InstallmentRepository installments,
    required ledger_query.AccountQueryService accountQueryService,
    required ledger.TransactionPostingAppService postingService,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    InstallmentScheduleGenerator generator =
        const InstallmentScheduleGenerator(),
  }) : _bills = bills,
       _repayments = repayments,
       _installments = installments,
       _accountQueryService = accountQueryService,
       _postingService = postingService,
       _transactionRunner = transactionRunner,
       _idGenerator = idGenerator,
       _generator = generator;

  final BillRepository _bills;
  final RepaymentRepository _repayments;
  final InstallmentRepository _installments;
  final ledger_query.AccountQueryService _accountQueryService;
  final ledger.TransactionPostingAppService _postingService;
  final TransactionRunner _transactionRunner;
  final IdGenerator _idGenerator;
  final InstallmentScheduleGenerator _generator;

  @override
  Future<CreateRepaymentResult> createBillRepayment(
    CreateBillRepaymentCommand command,
  ) async {
    final bill = await _bills.findBill(command.billId);
    if (bill == null) {
      throw BusinessException(
        CreditErrorCode.billNotFound,
        message: 'Bill does not exist.',
      );
    }
    _validateBillRepaymentCommand(bill, command);

    final repaymentId = _idGenerator.newId();
    final items =
        command.allocations
            .map(
              (allocation) => RepaymentItem(
                id: _idGenerator.newId(),
                repaymentId: repaymentId,
                billItemId: allocation.billItemId,
                allocated: allocation.allocated,
              ),
            )
            .toList();

    return _transactionRunner.run(() async {
      final total = _total(command.allocations);
      final post = await _postLedgerTransactionIfNeeded(
        liabilityAccountId: bill.accountId,
        repaymentId: repaymentId,
        total: total,
        transactionInfo: command.transactionInfo,
        note: command.note,
        repaymentType: RepaymentType.bill,
      );
      final repayment = Repayment(
        id: repaymentId,
        repaymentType: RepaymentType.bill,
        targetType: RepaymentTargetType.bill,
        targetId: bill.id,
        rootTransactionId: post?.rootTransactionId,
        items: items,
      )..validateAgainstLedgerTransaction(total);
      await _repayments.saveRepayment(repayment);
      await _refreshBillStatuses(bill, command.allocations);
      return CreateRepaymentResult(
        repaymentId: repaymentId,
        transactionId: post?.transactionId,
        rootTransactionId: post?.rootTransactionId,
      );
    });
  }

  @override
  Future<CreateRepaymentResult> createBillConversionInstallmentRepayment(
    CreateBillConversionInstallmentRepaymentCommand command,
  ) async {
    final bill = await _bills.findBill(command.billId);
    if (bill == null) {
      throw BusinessException(
        CreditErrorCode.billNotFound,
        message: 'Bill does not exist.',
      );
    }
    _validateBillConversionInstallmentCommand(bill, command);

    final repaymentId = _idGenerator.newId();
    final items =
        command.allocations
            .map(
              (allocation) => RepaymentItem(
                id: _idGenerator.newId(),
                repaymentId: repaymentId,
                billItemId: allocation.billItemId,
                allocated: allocation.allocated,
              ),
            )
            .toList();

    return _transactionRunner.run(() async {
      final total = _total(command.allocations);
      final repayment = Repayment(
        id: repaymentId,
        repaymentType: RepaymentType.installment,
        targetType: RepaymentTargetType.bill,
        targetId: bill.id,
        items: items,
      );
      await _repayments.saveRepayment(repayment);
      await _refreshBillStatuses(bill, command.allocations);
      final contractId = await _createBillConversionContract(
        bill: bill,
        repaymentId: repaymentId,
        principal: total.principal,
        command: command,
      );
      return CreateRepaymentResult(
        repaymentId: repaymentId,
        contractId: contractId,
      );
    });
  }

  @override
  Future<CreateRepaymentResult> createExtraPrincipalRepayment(
    CreateExtraPrincipalRepaymentCommand command,
  ) async {
    final contract = await _installments.findContract(command.contractId);
    if (contract == null) {
      throw BusinessException(
        CreditErrorCode.contractNotFound,
        message: 'Installment contract does not exist.',
      );
    }
    _validateActiveContractRepayment(
      contract.status,
      principal: command.principal,
      interest: command.interest,
      fee: command.fee,
    );

    final repaymentId = _idGenerator.newId();
    final total = RepaymentAmountBreakdown(
      principal: command.principal,
      interest: command.interest ?? Money.zero(),
      fee: command.fee ?? Money.zero(),
      discount: Money.zero(),
    );

    return _transactionRunner.run(() async {
      final post = await _postLedgerTransactionIfNeeded(
        liabilityAccountId: contract.liabilityAccountId,
        repaymentId: repaymentId,
        total: total,
        transactionInfo: command.transactionInfo,
        note: command.note,
        repaymentType: RepaymentType.extraPrincipal,
      );
      final repayment = Repayment(
        id: repaymentId,
        repaymentType: RepaymentType.extraPrincipal,
        targetType: RepaymentTargetType.contract,
        targetId: contract.id,
        rootTransactionId: post?.rootTransactionId,
        items: [
          RepaymentItem(
            id: _idGenerator.newId(),
            repaymentId: repaymentId,
            allocated: total,
          ),
        ],
      )..validateAgainstLedgerTransaction(total);
      await _repayments.saveRepayment(repayment);
      await _recalculatePendingSchedules(contract.id);
      await _maybeMarkContractSettled(contract.id);
      return CreateRepaymentResult(
        repaymentId: repaymentId,
        transactionId: post?.transactionId,
        rootTransactionId: post?.rootTransactionId,
      );
    });
  }

  @override
  Future<CreateRepaymentResult> createEarlySettlementRepayment(
    CreateEarlySettlementRepaymentCommand command,
  ) async {
    final contract = await _installments.findContract(command.contractId);
    if (contract == null) {
      throw BusinessException(
        CreditErrorCode.contractNotFound,
        message: 'Installment contract does not exist.',
      );
    }
    _validateActiveContractRepayment(
      contract.status,
      principal: command.principal,
      interest: command.interest,
      fee: command.fee,
    );

    final repaymentId = _idGenerator.newId();
    final total = RepaymentAmountBreakdown(
      principal: command.principal,
      interest: command.interest ?? Money.zero(),
      fee: command.fee ?? Money.zero(),
      discount: Money.zero(),
    );

    return _transactionRunner.run(() async {
      final post = await _postLedgerTransactionIfNeeded(
        liabilityAccountId: contract.liabilityAccountId,
        repaymentId: repaymentId,
        total: total,
        transactionInfo: command.transactionInfo,
        note: command.note,
        repaymentType: RepaymentType.earlySettlement,
      );
      final repayment = Repayment(
        id: repaymentId,
        repaymentType: RepaymentType.earlySettlement,
        targetType: RepaymentTargetType.contract,
        targetId: contract.id,
        rootTransactionId: post?.rootTransactionId,
        items: [
          RepaymentItem(
            id: _idGenerator.newId(),
            repaymentId: repaymentId,
            allocated: total,
          ),
        ],
      )..validateAgainstLedgerTransaction(total);
      await _repayments.saveRepayment(repayment);
      await _skipPendingSchedules(contract.id);
      await _skipPendingBillItemsForContract(
        contract.id,
        contract.liabilityAccountId,
      );
      await _installments.updateContractStatus(
        contract.id,
        InstallmentContractStatus.closed,
      );
      return CreateRepaymentResult(
        repaymentId: repaymentId,
        transactionId: post?.transactionId,
        rootTransactionId: post?.rootTransactionId,
      );
    });
  }

  @override
  Future<CreateRepaymentResult> createUnattributedRepayment(
    CreateUnattributedRepaymentCommand command,
  ) async {
    final account = await _accountQueryService.findAccountById(
      command.accountId,
    );
    if (account == null) {
      throw BusinessException(
        CreditErrorCode.accountNotFound,
        message: 'Credit liability account does not exist.',
      );
    }
    if (command.amount.minorUnits <= 0) {
      throw BusinessException(CreditErrorCode.repaymentInvalidCommand);
    }

    final bucket = await _unattributedDebtBucket(command.accountId);
    if (command.amount.minorUnits > bucket.minorUnits) {
      throw BusinessException(CreditErrorCode.repaymentExceedsAvailable);
    }

    final repaymentId = _idGenerator.newId();
    final total = RepaymentAmountBreakdown(
      principal: command.amount,
      interest: Money.zero(),
      fee: Money.zero(),
      discount: Money.zero(),
    );

    return _transactionRunner.run(() async {
      final post = await _postLedgerTransactionIfNeeded(
        liabilityAccountId: command.accountId,
        repaymentId: repaymentId,
        total: total,
        transactionInfo: command.transactionInfo,
        note: command.note,
        repaymentType: RepaymentType.unattributed,
      );
      final repayment = Repayment(
        id: repaymentId,
        repaymentType: RepaymentType.unattributed,
        targetType: RepaymentTargetType.account,
        targetId: command.accountId,
        rootTransactionId: post?.rootTransactionId,
        items: [
          RepaymentItem(
            id: _idGenerator.newId(),
            repaymentId: repaymentId,
            allocated: total,
          ),
        ],
      )..validateAgainstLedgerTransaction(total);
      await _repayments.saveRepayment(repayment);
      return CreateRepaymentResult(
        repaymentId: repaymentId,
        transactionId: post?.transactionId,
        rootTransactionId: post?.rootTransactionId,
      );
    });
  }

  void _validateBillRepaymentCommand(
    Bill bill,
    CreateBillRepaymentCommand command,
  ) {
    if (bill.status == BillStatus.settled || command.allocations.isEmpty) {
      throw BusinessException(CreditErrorCode.billInvalidCommand);
    }

    final billItemsById = {for (final item in bill.items) item.id: item};
    final seen = <String>{};
    for (final allocation in command.allocations) {
      final item = billItemsById[allocation.billItemId];
      if (item == null || !seen.add(allocation.billItemId)) {
        throw BusinessException(CreditErrorCode.billInvalidCommand);
      }
      if (item.status == BillItemStatus.skipped) {
        throw BusinessException(CreditErrorCode.billInvalidCommand);
      }
      if (bill.status == BillStatus.open &&
          item.itemType != BillItemType.consumption) {
        throw BusinessException(CreditErrorCode.billInvalidCommand);
      }
      if (allocation.allocated.hasNegativePart) {
        throw BusinessException(CreditErrorCode.billInvalidCommand);
      }
    }

    if (_total(command.allocations).principal.minorUnits <= 0) {
      throw BusinessException(CreditErrorCode.billInvalidCommand);
    }
  }

  void _validateBillConversionInstallmentCommand(
    Bill bill,
    CreateBillConversionInstallmentRepaymentCommand command,
  ) {
    if (bill.status != BillStatus.billed || command.allocations.isEmpty) {
      throw BusinessException(CreditErrorCode.billInvalidCommand);
    }

    final billItemsById = {for (final item in bill.items) item.id: item};
    final seen = <String>{};
    for (final allocation in command.allocations) {
      final item = billItemsById[allocation.billItemId];
      if (item == null || !seen.add(allocation.billItemId)) {
        throw BusinessException(CreditErrorCode.billInvalidCommand);
      }
      if (item.itemType != BillItemType.consumption ||
          item.status != BillItemStatus.pending ||
          allocation.allocated.hasNegativePart ||
          allocation.allocated.interest.minorUnits != 0 ||
          allocation.allocated.fee.minorUnits != 0 ||
          allocation.allocated.discount.minorUnits != 0) {
        throw BusinessException(CreditErrorCode.billInvalidCommand);
      }
    }

    if (_total(command.allocations).principal.minorUnits <= 0) {
      throw BusinessException(CreditErrorCode.billInvalidCommand);
    }
    _requireValidInstallmentTerms(
      principal: _total(command.allocations).principal,
      totalPeriods: command.totalPeriods,
      firstRepaymentDate: command.firstRepaymentDate,
      lastRepaymentDate: command.lastRepaymentDate,
      interestRatePeriod: command.interestRatePeriod,
      interestRatePpm: command.interestRatePpm,
      totalFeeMinor: command.totalFeeMinor,
      equalInstallmentOverrideMinor: command.equalInstallmentOverrideMinor,
    );
  }

  void _validateActiveContractRepayment(
    InstallmentContractStatus status, {
    required Money principal,
    Money? interest,
    Money? fee,
  }) {
    if (status != InstallmentContractStatus.active) {
      throw BusinessException(
        CreditErrorCode.contractNotActive,
        message: 'Only active contracts allow contract-side repayment.',
      );
    }
    if (principal.minorUnits <= 0 ||
        (interest?.minorUnits ?? 0) < 0 ||
        (fee?.minorUnits ?? 0) < 0) {
      throw BusinessException(CreditErrorCode.repaymentInvalidCommand);
    }
  }

  void _requireValidInstallmentTerms({
    required Money principal,
    required int totalPeriods,
    required DateTime? firstRepaymentDate,
    required DateTime? lastRepaymentDate,
    required InterestRatePeriod? interestRatePeriod,
    required int? interestRatePpm,
    required int totalFeeMinor,
    required int? equalInstallmentOverrideMinor,
  }) {
    if (principal.minorUnits <= 0 ||
        totalPeriods <= 0 ||
        totalFeeMinor < 0 ||
        (equalInstallmentOverrideMinor ?? 0) < 0 ||
        (interestRatePpm ?? 0) < 0 ||
        (interestRatePeriod == null) != (interestRatePpm == null)) {
      throw BusinessException(CreditErrorCode.contractInvalidCommand);
    }
    if (firstRepaymentDate != null &&
        lastRepaymentDate != null &&
        totalPeriods > 1 &&
        !lastRepaymentDate.isAfter(firstRepaymentDate)) {
      throw BusinessException(CreditErrorCode.contractInvalidCommand);
    }
  }

  Future<String> _createBillConversionContract({
    required Bill bill,
    required String repaymentId,
    required Money principal,
    required CreateBillConversionInstallmentRepaymentCommand command,
  }) async {
    final borrowingDate = command.borrowingDate ?? _defaultBorrowingDate(bill);
    final firstDate =
        command.firstRepaymentDate ?? _addMonths(borrowingDate, 1);
    final lastDate =
        command.lastRepaymentDate ??
        _defaultLastDate(firstDate, command.totalPeriods);
    _requireValidInstallmentTerms(
      principal: principal,
      totalPeriods: command.totalPeriods,
      firstRepaymentDate: firstDate,
      lastRepaymentDate: lastDate,
      interestRatePeriod: command.interestRatePeriod,
      interestRatePpm: command.interestRatePpm,
      totalFeeMinor: command.totalFeeMinor,
      equalInstallmentOverrideMinor: command.equalInstallmentOverrideMinor,
    );
    final drafts = _generator.generate(
      principal: principal,
      borrowingDate: borrowingDate,
      firstRepaymentDate: firstDate,
      lastRepaymentDate: lastDate,
      totalPeriods: command.totalPeriods,
      method: command.repaymentMethod,
      accrualMethod: command.interestAccrualMethod,
      ratePeriod: command.interestRatePeriod,
      ratePpm: command.interestRatePpm,
      totalFeeMinor: command.totalFeeMinor,
      equalInstallmentOverrideMinor: command.equalInstallmentOverrideMinor,
    );
    final contractId = await _installments.insertContract(
      InstallmentContractDraft(
        liabilityAccountId: bill.accountId,
        sourceType: InstallmentSourceType.billConversion,
        sourceRepaymentId: repaymentId,
        principal: principal,
        totalPeriods: command.totalPeriods,
        borrowingDate: borrowingDate,
        firstRepaymentDate: firstDate,
        lastRepaymentDate: lastDate,
        repaymentMethod: command.repaymentMethod,
        interestRatePeriod: command.interestRatePeriod,
        interestRatePpm: command.interestRatePpm,
        interestAccrualMethod: command.interestAccrualMethod,
        totalFeeMinor: command.totalFeeMinor,
        status: InstallmentContractStatus.active,
        note: command.note,
      ),
    );
    await _installments.replaceSchedules(contractId, drafts);
    return contractId;
  }

  Future<ledger.PostedTransactionResult?> _postLedgerTransactionIfNeeded({
    required String liabilityAccountId,
    required String repaymentId,
    required RepaymentAmountBreakdown total,
    required RepaymentTransactionInfo? transactionInfo,
    required String? note,
    required RepaymentType repaymentType,
  }) {
    if (transactionInfo == null) return Future.value(null);
    return _postingService.createRepayment(
      ledger.CreateRepaymentCommand(
        principal: total.principal,
        interest: _positiveOrNull(total.interest),
        fee: _positiveOrNull(total.fee),
        discount: _positiveOrNull(total.discount),
        liabilityAccountId: liabilityAccountId,
        paidFromAccountId: transactionInfo.paidFromAccountId,
        occurredAt: transactionInfo.occurredAt,
        counterpartyName: transactionInfo.counterpartyName,
        note: transactionInfo.note ?? note,
        ownership: ledger.TransactionOwnership(
          ownerType: creditRepaymentOwnerType,
          ownerId: repaymentId,
          ownerRole: repaymentType.code,
        ),
      ),
    );
  }

  Future<void> _refreshBillStatuses(
    Bill bill,
    List<BillRepaymentAllocation> allocations,
  ) async {
    final touched =
        allocations.map((allocation) => allocation.billItemId).toSet();
    final nextItems = <BillItem>[];
    final paidScheduleIds = <String>{};
    for (final item in bill.items) {
      if (!touched.contains(item.id)) {
        nextItems.add(item);
        continue;
      }
      final allocated = await _repayments.listItemsByBillItem(item.id);
      final allocatedPrincipalMinor = allocated.fold<int>(
        0,
        (sum, allocation) => sum + allocation.allocated.principal.minorUnits,
      );
      final nextStatus =
          allocatedPrincipalMinor >= item.expectedPrincipal.minorUnits
              ? BillItemStatus.paid
              : BillItemStatus.pending;
      if (nextStatus == BillItemStatus.paid && item.scheduleId != null) {
        paidScheduleIds.add(item.scheduleId!);
      }
      nextItems.add(item.copyWith(status: nextStatus));
    }

    await _bills.upsertBillItems(bill.id, nextItems);
    await _refreshInstallmentStatuses(paidScheduleIds);
    await _bills.updateBill(
      bill.copyWith(status: _projectBillStatus(bill.status, nextItems)),
    );
  }

  Future<void> _refreshInstallmentStatuses(Set<String> paidScheduleIds) async {
    if (paidScheduleIds.isEmpty) return;
    final touchedContractIds = <String>{};
    for (final scheduleId in paidScheduleIds) {
      final schedule = await _installments.findSchedule(scheduleId);
      if (schedule == null) continue;
      if (schedule.status != InstallmentScheduleStatus.paid) {
        await _installments.updateSchedule(
          scheduleId,
          const InstallmentSchedulePatch(
            status: InstallmentScheduleStatus.paid,
          ),
        );
      }
      touchedContractIds.add(schedule.contractId);
    }

    for (final contractId in touchedContractIds) {
      final schedules = await _installments.listSchedules(contractId);
      if (schedules.isEmpty) continue;
      final allSettled = schedules.every(
        (schedule) =>
            schedule.status == InstallmentScheduleStatus.paid ||
            schedule.status == InstallmentScheduleStatus.skipped,
      );
      if (allSettled) {
        await _installments.updateContractStatus(
          contractId,
          InstallmentContractStatus.settled,
        );
      }
    }
  }

  Future<void> _recalculatePendingSchedules(String contractId) async {
    final contract = await _installments.findContract(contractId);
    if (contract == null) return;

    final schedules = await _installments.listSchedules(contractId);
    final paid =
        schedules
            .where((s) => s.status == InstallmentScheduleStatus.paid)
            .toList()
          ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    final pending =
        schedules
            .where((s) => s.status == InstallmentScheduleStatus.pending)
            .toList()
          ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    if (pending.isEmpty) return;

    final paidPrincipalMinor = paid.fold<int>(
      0,
      (acc, s) => acc + s.expectedPrincipal.minorUnits,
    );
    final extraPrincipalMinor = await _extraPrincipalSumMinor(contractId);
    final remainingMinor =
        contract.principal.minorUnits -
        paidPrincipalMinor -
        extraPrincipalMinor;
    if (remainingMinor < 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Remaining principal would be negative.',
      );
    }
    if (remainingMinor == 0) {
      for (final schedule in pending) {
        await _installments.updateSchedule(
          schedule.id,
          InstallmentSchedulePatch(
            expectedPrincipal: Money.zero(),
            expectedInterest: Money.zero(),
            expectedFee: Money.zero(),
            status: InstallmentScheduleStatus.skipped,
          ),
        );
      }
      return;
    }

    final paidFeeMinor = paid.fold<int>(
      0,
      (acc, s) => acc + s.expectedFee.minorUnits,
    );
    final remainingFeeMinor = contract.totalFeeMinor - paidFeeMinor;
    final anchorDate =
        paid.isEmpty ? contract.borrowingDate : paid.last.expectedRepaymentDate;
    final allocations = _generator.allocate(
      remainingPrincipal: Money(minorUnits: remainingMinor),
      anchorDate: anchorDate,
      pendingDates: [for (final p in pending) p.expectedRepaymentDate],
      method: contract.repaymentMethod,
      accrualMethod: contract.interestAccrualMethod,
      ratePeriod: contract.interestRatePeriod,
      ratePpm: contract.interestRatePpm,
      remainingFeeMinor: remainingFeeMinor < 0 ? 0 : remainingFeeMinor,
    );

    for (var i = 0; i < pending.length; i++) {
      final schedule = pending[i];
      final allocation = allocations[i];
      await _installments.updateSchedule(
        schedule.id,
        InstallmentSchedulePatch(
          expectedPrincipal: allocation.principal,
          expectedInterest: allocation.interest,
          expectedFee: allocation.fee,
        ),
      );
    }
  }

  Future<int> _extraPrincipalSumMinor(String contractId) async {
    final repayments = await _repayments.listByTarget(
      RepaymentTargetType.contract,
      contractId,
    );
    return repayments
        .where(
          (repayment) =>
              repayment.repaymentType == RepaymentType.extraPrincipal,
        )
        .fold<int>(
          0,
          (sum, repayment) =>
              sum + repayment.totalAllocated().principal.minorUnits,
        );
  }

  Future<void> _skipPendingSchedules(String contractId) async {
    final schedules = await _installments.listSchedules(contractId);
    for (final schedule in schedules) {
      if (schedule.status == InstallmentScheduleStatus.pending) {
        await _installments.updateSchedule(
          schedule.id,
          const InstallmentSchedulePatch(
            status: InstallmentScheduleStatus.skipped,
          ),
        );
      }
    }
  }

  Future<void> _skipPendingBillItemsForContract(
    String contractId,
    String liabilityAccountId,
  ) async {
    final bills = await _bills.listBillsByAccount(liabilityAccountId);
    for (final bill in bills) {
      var changed = false;
      final nextItems = <BillItem>[];
      for (final item in bill.items) {
        if (item.contractId == contractId &&
            item.status == BillItemStatus.pending) {
          changed = true;
          nextItems.add(item.copyWith(status: BillItemStatus.skipped));
        } else {
          nextItems.add(item);
        }
      }
      if (!changed) continue;
      await _bills.upsertBillItems(bill.id, nextItems);
      await _bills.updateBill(
        bill.copyWith(
          items: nextItems,
          status: _projectBillStatus(bill.status, nextItems),
        ),
      );
    }
  }

  Future<void> _maybeMarkContractSettled(String contractId) async {
    final schedules = await _installments.listSchedules(contractId);
    if (schedules.isEmpty) return;
    final allDone = schedules.every(
      (schedule) =>
          schedule.status == InstallmentScheduleStatus.paid ||
          schedule.status == InstallmentScheduleStatus.skipped,
    );
    if (allDone) {
      await _installments.updateContractStatus(
        contractId,
        InstallmentContractStatus.settled,
      );
    }
  }

  Future<Money> _unattributedDebtBucket(String accountId) async {
    final account = await _accountQueryService.findAccountById(accountId);
    if (account == null) {
      throw BusinessException(CreditErrorCode.accountNotFound);
    }
    final pendingContractPrincipal = (await _installments
            .listSchedulesByLiabilityAccount(accountId))
        .where(
          (schedule) => schedule.status == InstallmentScheduleStatus.pending,
        )
        .fold<int>(
          0,
          (sum, schedule) => sum + schedule.expectedPrincipal.minorUnits,
        );
    final pendingBilledConsumptionPrincipal = (await _bills.listBillsByAccount(
          accountId,
        ))
        .where((bill) => bill.status != BillStatus.open)
        .expand((bill) => bill.items)
        .where(
          (item) =>
              item.status == BillItemStatus.pending &&
              item.itemType == BillItemType.consumption,
        )
        .fold<int>(0, (sum, item) => sum + item.expectedPrincipal.minorUnits);
    return Money(
      minorUnits:
          account.balance.minorUnits -
          pendingContractPrincipal -
          pendingBilledConsumptionPrincipal,
    );
  }

  BillStatus _projectBillStatus(BillStatus current, List<BillItem> items) {
    if (current == BillStatus.open) return BillStatus.open;
    return items.any((item) => item.status == BillItemStatus.pending)
        ? BillStatus.billed
        : BillStatus.settled;
  }

  RepaymentAmountBreakdown _total(List<BillRepaymentAllocation> allocations) {
    return allocations.fold(
      RepaymentAmountBreakdown.zero,
      (sum, allocation) => sum + allocation.allocated,
    );
  }

  Money? _positiveOrNull(Money value) {
    return value.minorUnits > 0 ? value : null;
  }

  DateTime _defaultBorrowingDate(Bill bill) {
    final windowRepaymentDate = bill.window?.repaymentDate;
    if (windowRepaymentDate != null) return windowRepaymentDate;
    return bill.items
        .map((item) => item.repaymentDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  DateTime _defaultLastDate(DateTime firstRepaymentDate, int totalPeriods) {
    if (totalPeriods == 1) return firstRepaymentDate;
    return _addMonths(firstRepaymentDate, totalPeriods - 1);
  }

  DateTime _addMonths(DateTime date, int months) {
    return DateTime(date.year, date.month + months, date.day);
  }
}
