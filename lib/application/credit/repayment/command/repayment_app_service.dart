import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/application/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/debt/credit_debt_bucket_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_lifecycle_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';
import 'package:smartflow/domain/credit/service/installment/installment_prepayment_recalculator.dart';
import 'package:smartflow/domain/credit/service/installment/repayment_dates_strategy.dart';
import 'package:smartflow/domain/credit/service/repayment/repayment_policy_service.dart'
    as domain_repayment;
import 'package:smartflow/domain/credit/service/repayment/repayment_settlement_service.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import 'repayment_command.dart';

abstract interface class RepaymentAppService {
  Future<CreditLedgerPostedTransaction> createLiabilityRepayment(
    CreateLiabilityRepaymentCommand command,
  );

  Future<CreditLedgerPostedTransaction> correctLiabilityRepayment(
    CorrectLiabilityRepaymentCommand command,
  );

  Future<LiabilityRepaymentEditViewLoadResult> loadLiabilityRepaymentEditView(
    String transactionId,
  );

  Future<CreateRepaymentResult> createBillRepayment(
    CreateBillRepaymentCommand command,
  );

  Future<CreateRepaymentResult> createBillConversionInstallmentRepayment(
    CreateBillConversionInstallmentRepaymentCommand command,
  );

  Future<CreateRepaymentResult> createContractPrepaymentRepayment(
    CreateContractPrepaymentRepaymentCommand command,
  );

  Future<CreateRepaymentResult> createUnattributedRepayment(
    CreateUnattributedRepaymentCommand command,
  );

  Future<void> editRepaymentTransaction(
    EditCreditRepaymentTransactionCommand command,
  );

  Future<void> deleteRepayment(DeleteCreditRepaymentCommand command);
}

class RepaymentAppServiceImpl implements RepaymentAppService {
  RepaymentAppServiceImpl({
    required BillRepository bills,
    required RepaymentRepository repayments,
    required InstallmentRepository installments,
    required CreditLedgerPort ledger,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    InstallmentPlanEngine planEngine = const InstallmentPlanEngine(),
    CreditDebtBucketService debtBuckets = const CreditDebtBucketService(),
    InstallmentLifecycleService installmentLifecycle =
        const InstallmentLifecycleService(),
    domain_repayment.RepaymentPolicyService repaymentPolicy =
        const domain_repayment.RepaymentPolicyService(),
    InstallmentPrepaymentRecalculator prepaymentRecalculator =
        const InstallmentPrepaymentRecalculator(),
    RepaymentSettlementService? repaymentSettlement,
  }) : _bills = bills,
       _repayments = repayments,
       _installments = installments,
       _ledger = ledger,
       _transactionRunner = transactionRunner,
       _idGenerator = idGenerator,
       _planEngine = planEngine,
       _debtBuckets = debtBuckets,
       _installmentLifecycle = installmentLifecycle,
       _repaymentPolicy = repaymentPolicy,
       _repaymentSettlement =
           repaymentSettlement ??
           RepaymentSettlementService(
             bills: bills,
             repayments: repayments,
             installments: installments,
             lifecycle: installmentLifecycle,
             prepaymentRecalculator: prepaymentRecalculator,
           );

  final BillRepository _bills;
  final RepaymentRepository _repayments;
  final InstallmentRepository _installments;
  final CreditLedgerPort _ledger;
  final TransactionRunner _transactionRunner;
  final IdGenerator _idGenerator;
  final InstallmentPlanEngine _planEngine;
  final CreditDebtBucketService _debtBuckets;
  final InstallmentLifecycleService _installmentLifecycle;
  final domain_repayment.RepaymentPolicyService _repaymentPolicy;
  final RepaymentSettlementService _repaymentSettlement;

  @override
  Future<CreditLedgerPostedTransaction> createLiabilityRepayment(
    CreateLiabilityRepaymentCommand command,
  ) async {
    await _validateLiabilityRepaymentPrincipal(
      liabilityAccountId: command.liabilityAccountId,
      principal: command.principal,
    );

    return _ledger.postRepayment(
      CreditLedgerPostRepaymentCommand(
        liabilityAccountId: command.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        occurredAt: command.occurredAt,
        amount: RepaymentAmountBreakdown(
          principal: command.principal,
          interest: command.interest ?? Money.zero(),
          fee: command.fee ?? Money.zero(),
          discount: command.discount ?? Money.zero(),
        ),
        note: command.note,
      ),
    );
  }

  @override
  Future<CreditLedgerPostedTransaction> correctLiabilityRepayment(
    CorrectLiabilityRepaymentCommand command,
  ) async {
    final snapshot = await _ledger.findRepaymentTransaction(
      command.transactionId,
    );
    if (snapshot == null) {
      throw BusinessException(
        CreditErrorCode.repaymentNotFound,
        message: 'Repayment transaction does not exist.',
      );
    }
    if (!snapshot.isDebtRepayment) {
      throw BusinessException(
        CreditErrorCode.repaymentNotEditable,
        message:
            'RepaymentAppService.correctLiabilityRepayment only handles DEBT_REPAYMENT.',
      );
    }

    await _validateLiabilityRepaymentPrincipal(
      liabilityAccountId: command.liabilityAccountId,
      principal: command.principal,
      editingRepaymentSnapshot: snapshot,
    );

    return _ledger.correctRepayment(
      CreditLedgerCorrectRepaymentCommand(
        transactionId: command.transactionId,
        amount: RepaymentAmountBreakdown(
          principal: command.principal,
          interest: command.interest ?? Money.zero(),
          fee: command.fee ?? Money.zero(),
          discount: command.discount ?? Money.zero(),
        ),
        liabilityAccountId: command.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        occurredAt: command.occurredAt,
        note:
            command.note == null
                ? const Patch<String?>.clear()
                : Patch<String?>.set(command.note),
      ),
    );
  }

  @override
  Future<LiabilityRepaymentEditViewLoadResult> loadLiabilityRepaymentEditView(
    String transactionId,
  ) async {
    final snapshot = await _ledger.findRepaymentTransaction(transactionId);
    if (snapshot == null) {
      return const LiabilityRepaymentEditViewLoadResult.notFound();
    }
    if (!snapshot.isDebtRepayment) {
      return const LiabilityRepaymentEditViewLoadResult.notEditable();
    }

    Money? principal;
    Money? interest;
    Money? fee;
    Money? discount;
    for (final line in snapshot.details) {
      switch (line.type) {
        case CreditLedgerRepaymentDetailType.principal:
          principal = line.amount;
        case CreditLedgerRepaymentDetailType.interest:
          interest = line.amount;
        case CreditLedgerRepaymentDetailType.fee:
          fee = line.amount;
        case CreditLedgerRepaymentDetailType.discount:
          discount = line.amount;
      }
    }
    if (principal == null) {
      return const LiabilityRepaymentEditViewLoadResult.notEditable();
    }

    final liabilityAccountId = _firstAccountId(
      snapshot,
      accountKind: CreditLedgerAccountKind.liability,
      direction: CreditLedgerEntryDirection.debit,
    );
    final paidFromAccountId = _firstSettlementAccountId(snapshot);
    if (liabilityAccountId == null || paidFromAccountId == null) {
      return const LiabilityRepaymentEditViewLoadResult.notEditable();
    }

    return LiabilityRepaymentEditViewLoadResult.loaded(
      LiabilityRepaymentEditView(
        principal: principal,
        interest: (interest?.minorUnits ?? 0) > 0 ? interest : null,
        fee: (fee?.minorUnits ?? 0) > 0 ? fee : null,
        discount: (discount?.minorUnits ?? 0) > 0 ? discount : null,
        liabilityAccountId: liabilityAccountId,
        paidFromAccountId: paidFromAccountId,
        occurredAt: snapshot.occurredAt,
        note: snapshot.note,
      ),
    );
  }

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
    final allocations = _domainAllocations(command.allocations);
    _repaymentPolicy.validateBillRepayment(
      bill: bill,
      allocations: allocations,
    );

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
      final total = _repaymentPolicy.total(allocations);
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
      await _repaymentSettlement.refreshBillStatuses(bill, allocations);
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
    final allocations = _domainAllocations(command.allocations);
    _repaymentPolicy.validateBillConversionInstallment(
      bill: bill,
      allocations: allocations,
      totalPeriods: command.totalPeriods,
      firstRepaymentDate: command.firstRepaymentDate,
      lastRepaymentDate: command.lastRepaymentDate,
      interestRatePeriod: command.interestRatePeriod,
      interestRatePpm: command.interestRatePpm,
      totalFeeMinor: command.totalFeeMinor,
      equalInstallmentOverrideMinor: command.equalInstallmentOverrideMinor,
    );

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
      final total = _repaymentPolicy.total(allocations);
      final repayment = Repayment(
        id: repaymentId,
        repaymentType: RepaymentType.installment,
        targetType: RepaymentTargetType.bill,
        targetId: bill.id,
        items: items,
      );
      await _repayments.saveRepayment(repayment);
      await _repaymentSettlement.refreshBillStatuses(bill, allocations);
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
  Future<CreateRepaymentResult> createContractPrepaymentRepayment(
    CreateContractPrepaymentRepaymentCommand command,
  ) async {
    final contract = await _installments.findContract(command.contractId);
    if (contract == null) {
      throw BusinessException(
        CreditErrorCode.contractNotFound,
        message: 'Installment contract does not exist.',
      );
    }
    final repaymentId = _idGenerator.newId();
    final total = RepaymentAmountBreakdown(
      principal: command.principal,
      interest: command.interest ?? Money.zero(),
      fee: command.fee ?? Money.zero(),
      discount: command.discount ?? Money.zero(),
    );
    _repaymentPolicy.validateActiveContractRepayment(
      contract: contract,
      total: total,
    );

    return _transactionRunner.run(() async {
      final post = await _postLedgerTransactionIfNeeded(
        liabilityAccountId: contract.liabilityAccountId,
        repaymentId: repaymentId,
        total: total,
        transactionInfo: command.transactionInfo,
        note: command.note,
        repaymentType: RepaymentType.prepayment,
      );
      final repayment = Repayment(
        id: repaymentId,
        repaymentType: RepaymentType.prepayment,
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
      await _repaymentSettlement.recalculatePendingSchedulesAfter(
        contract.id,
        command.transactionInfo?.occurredAt ?? DateTime.now(),
      );
      await _repaymentSettlement.refreshContractStatus(contract.id);
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
    final account = await _ledger.findAccount(command.accountId);
    if (account == null) {
      throw BusinessException(
        CreditErrorCode.accountNotFound,
        message: 'Credit liability account does not exist.',
      );
    }
    final total = RepaymentAmountBreakdown(
      principal: command.amount,
      interest: command.interest ?? Money.zero(),
      fee: command.fee ?? Money.zero(),
      discount: command.discount ?? Money.zero(),
    );
    final bucket = await _unattributedDebtBucket(command.accountId);
    _repaymentPolicy.validateUnattributedRepayment(
      total: total,
      availableDebt: bucket,
    );

    final repaymentId = _idGenerator.newId();

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

  @override
  Future<void> editRepaymentTransaction(
    EditCreditRepaymentTransactionCommand command,
  ) async {
    final repayment = await _findRepaymentForCommand(
      repaymentId: command.repaymentId,
      rootTransactionId: command.rootTransactionId,
    );
    final rootTransactionId = repayment.rootTransactionId;
    if (rootTransactionId == null) {
      throw BusinessException(CreditErrorCode.repaymentNotEditable);
    }
    final detail = await _currentParentTransactionDetail(rootTransactionId);
    final currentTransactionId = detail.transactionId;

    if (command.paidFromAccountId == null) {
      await _ledger.updateBasicInfo(
        CreditLedgerUpdateBasicInfoCommand(
          transactionId: currentTransactionId,
          occurredAt: command.occurredAt,
          note: command.note,
        ),
      );
      return;
    }

    final liabilityAccountId = await _liabilityAccountIdForRepayment(repayment);
    await _ledger.correctRepayment(
      CreditLedgerCorrectRepaymentCommand(
        transactionId: currentTransactionId,
        amount: repayment.totalAllocated(),
        liabilityAccountId: liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        occurredAt: command.occurredAt ?? detail.occurredAt,
        note: command.note,
      ),
    );
  }

  @override
  Future<void> deleteRepayment(DeleteCreditRepaymentCommand command) async {
    final repayment = await _findRepaymentForCommand(
      repaymentId: command.repaymentId,
      rootTransactionId: command.rootTransactionId,
    );

    CreditLedgerTransactionSnapshot? transactionDetail;
    if (repayment.rootTransactionId != null) {
      transactionDetail = await _currentParentTransactionDetail(
        repayment.rootTransactionId!,
      );
    }

    return _transactionRunner.run<void>(() async {
      if (transactionDetail != null) {
        await _ledger.deleteTransaction(transactionDetail.transactionId);
      }
      switch (repayment.repaymentType) {
        case RepaymentType.bill:
          await _deleteBillRepayment(repayment);
        case RepaymentType.installment:
          await _deleteBillConversionInstallmentRepayment(repayment);
        case RepaymentType.prepayment:
          await _deleteContractPrepaymentRepayment(
            repayment,
            occurredAt:
                transactionDetail?.occurredAt ??
                repayment.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0),
          );
        case RepaymentType.unattributed:
          await _repayments.deleteRepayment(repayment.id);
      }
    });
  }

  Future<Repayment> _findRepaymentForCommand({
    required String? repaymentId,
    required String? rootTransactionId,
  }) async {
    if ((repaymentId == null) == (rootTransactionId == null)) {
      throw BusinessException(CreditErrorCode.repaymentInvalidCommand);
    }
    final repayment =
        repaymentId != null
            ? await _repayments.findRepayment(repaymentId)
            : await _repayments.findByRootTransaction(rootTransactionId!);
    if (repayment == null) {
      throw BusinessException(CreditErrorCode.repaymentNotFound);
    }
    return repayment;
  }

  Future<void> _deleteBillRepayment(Repayment repayment) async {
    final bill = await _bills.findBill(repayment.targetId);
    if (bill == null) {
      throw BusinessException(CreditErrorCode.billNotFound);
    }
    final allocations = _repaymentPolicy.allocationsFromItems(repayment.items);
    await _repayments.deleteRepayment(repayment.id);
    await _repaymentSettlement.refreshBillStatuses(bill, allocations);
  }

  Future<void> _deleteBillConversionInstallmentRepayment(
    Repayment repayment,
  ) async {
    final bill = await _bills.findBill(repayment.targetId);
    if (bill == null) {
      throw BusinessException(CreditErrorCode.billNotFound);
    }
    final contract = await _findBillConversionContract(repayment.id, bill);
    if (contract != null) {
      final contractRepayments = await _repayments.listByTarget(
        RepaymentTargetType.contract,
        contract.id,
      );
      if (contractRepayments.isNotEmpty) {
        throw BusinessException(
          CreditErrorCode.repaymentNotEditable,
          message:
              'Bill conversion contract has repayments. Delete them first.',
        );
      }
    }

    final allocations = _repaymentPolicy.allocationsFromItems(repayment.items);
    await _repayments.deleteRepayment(repayment.id);
    await _repaymentSettlement.refreshBillStatuses(bill, allocations);
    if (contract != null) {
      await _installments.deleteContract(contract.id);
    }
  }

  Future<void> _deleteContractPrepaymentRepayment(
    Repayment repayment, {
    required DateTime occurredAt,
  }) async {
    final contract = await _installments.findContract(repayment.targetId);
    if (contract == null) {
      throw BusinessException(CreditErrorCode.contractNotFound);
    }
    await _repayments.deleteRepayment(repayment.id);
    await _repaymentSettlement.recalculatePendingSchedulesAfter(
      contract.id,
      occurredAt,
    );
    await _repaymentSettlement.refreshContractStatus(contract.id);
  }

  Future<InstallmentContract?> _findBillConversionContract(
    String sourceRepaymentId,
    Bill bill,
  ) async {
    final contracts = await _installments.listContractsByLiabilityAccount(
      bill.accountId,
    );
    for (final contract in contracts) {
      if (contract.sourceType == InstallmentSourceType.billConversion &&
          contract.sourceRepaymentId == sourceRepaymentId) {
        return contract;
      }
    }
    return null;
  }

  Future<CreditLedgerTransactionSnapshot> _currentParentTransactionDetail(
    String rootTransactionId,
  ) async {
    final detail = await _ledger.findCurrentParentTransactionByRoot(
      rootTransactionId,
    );
    if (detail == null) {
      throw BusinessException(
        CreditErrorCode.repaymentNotFound,
        message: 'Current repayment transaction does not exist.',
      );
    }
    return detail;
  }

  Future<String> _liabilityAccountIdForRepayment(Repayment repayment) async {
    switch (repayment.targetType) {
      case RepaymentTargetType.account:
        return repayment.targetId;
      case RepaymentTargetType.bill:
        final bill = await _bills.findBill(repayment.targetId);
        if (bill == null) throw BusinessException(CreditErrorCode.billNotFound);
        return bill.accountId;
      case RepaymentTargetType.contract:
        final contract = await _installments.findContract(repayment.targetId);
        if (contract == null) {
          throw BusinessException(CreditErrorCode.contractNotFound);
        }
        return contract.liabilityAccountId;
    }
  }

  List<domain_repayment.BillRepaymentAllocationDraft> _domainAllocations(
    List<BillRepaymentAllocation> allocations,
  ) {
    return [
      for (final allocation in allocations)
        domain_repayment.BillRepaymentAllocationDraft(
          billItemId: allocation.billItemId,
          allocated: allocation.allocated,
        ),
    ];
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
        _installmentLifecycle.defaultLastDate(firstDate, command.totalPeriods);
    _repaymentPolicy.validateInstallmentTerms(
      principal: principal,
      totalPeriods: command.totalPeriods,
      firstRepaymentDate: firstDate,
      lastRepaymentDate: lastDate,
      interestRatePeriod: command.interestRatePeriod,
      interestRatePpm: command.interestRatePpm,
      totalFeeMinor: command.totalFeeMinor,
      equalInstallmentOverrideMinor: command.equalInstallmentOverrideMinor,
    );
    final entries = _planEngine.generate(
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
    final now = DateTime.now();
    final contractId = _idGenerator.newId();
    final contract = InstallmentContract(
      id: contractId,
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
      createdAt: now,
    );
    await _installments.saveContract(contract);
    await _installments.replaceSchedules(
      contractId,
      _installmentLifecycle.schedulesFromEntries(
        contractId: contractId,
        entries: entries,
        createdAt: now,
        newId: _idGenerator.newId,
      ),
    );
    return contractId;
  }

  Future<CreditLedgerPostedTransaction?> _postLedgerTransactionIfNeeded({
    required String liabilityAccountId,
    required String repaymentId,
    required RepaymentAmountBreakdown total,
    required RepaymentTransactionInfo? transactionInfo,
    required String? note,
    required RepaymentType repaymentType,
  }) {
    if (transactionInfo == null) return Future.value(null);
    return _ledger.postRepayment(
      CreditLedgerPostRepaymentCommand(
        amount: total,
        liabilityAccountId: liabilityAccountId,
        paidFromAccountId: transactionInfo.paidFromAccountId,
        occurredAt: transactionInfo.occurredAt,
        counterpartyName: transactionInfo.counterpartyName,
        note: transactionInfo.note ?? note,
        ownership: CreditLedgerOwnership(
          ownerType: creditRepaymentOwnerType,
          ownerId: repaymentId,
          ownerRole: repaymentType.code,
        ),
      ),
    );
  }

  Future<Money> _unattributedDebtBucket(String accountId) async {
    final account = await _ledger.findAccount(accountId);
    if (account == null) {
      throw BusinessException(CreditErrorCode.accountNotFound);
    }
    final buckets = await _debtBuckets.bucketsForAccount(
      accountId: accountId,
      liabilityBalance: account.balance,
      bills: _bills,
      installments: _installments,
      repayments: _repayments,
    );
    return buckets.unattributedDebt;
  }

  /// 额度规则：principal ≤ |liabilityAccount.balance| − 未还分期本金合计。
  ///
  /// 编辑模式：
  /// - 若原交易挂在分期合同上（owner_type=installment），跳过校验（分期通路自管金额）。
  /// - 否则把原交易的 REPAYMENT_PRINCIPAL 加回到 debt，避免原地编辑同金额被自己挤掉。
  Future<void> _validateLiabilityRepaymentPrincipal({
    required String liabilityAccountId,
    required Money principal,
    CreditLedgerRepaymentSnapshot? editingRepaymentSnapshot,
  }) async {
    if (principal.minorUnits <= 0) return;

    if (editingRepaymentSnapshot?.ownerType == installmentOwnerType) {
      return;
    }

    final account = await _ledger.findAccount(liabilityAccountId);
    if (account == null) return;

    var oldPrincipalMinor = 0;
    if (editingRepaymentSnapshot != null) {
      for (final detail in editingRepaymentSnapshot.details) {
        if (detail.type == CreditLedgerRepaymentDetailType.principal) {
          oldPrincipalMinor += detail.amount.minorUnits;
        }
      }
    }

    final debtMinor = account.balance.minorUnits + oldPrincipalMinor;
    final unpaidMinor = await _unpaidInstallmentPrincipalMinor(
      liabilityAccountId,
    );
    final availableMinor = debtMinor - unpaidMinor;

    if (principal.minorUnits > availableMinor) {
      final clamped = availableMinor < 0 ? 0 : availableMinor;
      final available = Money(minorUnits: clamped);
      throw BusinessException(
        CreditErrorCode.repaymentExceedsAvailable,
        message: '本金超过可还额度（${available.format()}），剩余请通过分期合同还款',
      );
    }
  }

  Future<int> _unpaidInstallmentPrincipalMinor(
    String liabilityAccountId,
  ) async {
    final contracts = await _installments.listContractsByLiabilityAccount(
      liabilityAccountId,
    );
    var sum = 0;
    for (final contract in contracts) {
      if (contract.status != InstallmentContractStatus.active) continue;
      final schedules = await _installments.listSchedules(contract.id);
      sum += schedules
          .where(
            (schedule) => schedule.status == InstallmentScheduleStatus.pending,
          )
          .fold<int>(
            0,
            (total, schedule) => total + schedule.expectedPrincipal.minorUnits,
          );
    }
    return sum;
  }

  String? _firstAccountId(
    CreditLedgerRepaymentSnapshot snapshot, {
    required CreditLedgerAccountKind accountKind,
    required CreditLedgerEntryDirection direction,
  }) {
    for (final entry in snapshot.entries) {
      if (entry.accountKind == accountKind && entry.direction == direction) {
        return entry.accountId;
      }
    }
    return null;
  }

  String? _firstSettlementAccountId(CreditLedgerRepaymentSnapshot snapshot) {
    for (final entry in snapshot.entries) {
      if (entry.direction != CreditLedgerEntryDirection.credit) continue;
      final kind = entry.accountKind;
      if (kind == CreditLedgerAccountKind.asset ||
          kind == CreditLedgerAccountKind.liability) {
        return entry.accountId;
      }
    }
    return null;
  }

  DateTime _defaultBorrowingDate(Bill bill) {
    final windowRepaymentDate = bill.window?.repaymentDate;
    if (windowRepaymentDate != null) return windowRepaymentDate;
    return bill.items
        .map((item) => item.repaymentDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  DateTime _addMonths(DateTime date, int months) {
    return IntervalRepaymentDates(
      firstDate: date,
      count: months + 1,
    ).getDates().last;
  }
}
