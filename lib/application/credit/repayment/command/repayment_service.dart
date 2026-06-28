import 'package:smartflow/application/ledger/ledger_command_api.dart' as ledger;
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
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

class CreateRepaymentResult {
  const CreateRepaymentResult({
    required this.repaymentId,
    this.transactionId,
    this.rootTransactionId,
  });

  final String repaymentId;
  final String? transactionId;
  final String? rootTransactionId;
}

abstract interface class RepaymentService {
  Future<CreateRepaymentResult> createBillRepayment(
    CreateBillRepaymentCommand command,
  );
}

class RepaymentServiceImpl implements RepaymentService {
  const RepaymentServiceImpl({
    required BillRepository bills,
    required RepaymentRepository repayments,
    required InstallmentRepository installments,
    required ledger.TransactionPostingAppService postingService,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
  }) : _bills = bills,
       _repayments = repayments,
       _installments = installments,
       _postingService = postingService,
       _transactionRunner = transactionRunner,
       _idGenerator = idGenerator;

  final BillRepository _bills;
  final RepaymentRepository _repayments;
  final InstallmentRepository _installments;
  final ledger.TransactionPostingAppService _postingService;
  final TransactionRunner _transactionRunner;
  final IdGenerator _idGenerator;

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
        bill: bill,
        repaymentId: repaymentId,
        total: total,
        transactionInfo: command.transactionInfo,
        note: command.note,
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

  Future<ledger.PostedTransactionResult?> _postLedgerTransactionIfNeeded({
    required Bill bill,
    required String repaymentId,
    required RepaymentAmountBreakdown total,
    required RepaymentTransactionInfo? transactionInfo,
    required String? note,
  }) {
    if (transactionInfo == null) return Future.value(null);
    return _postingService.createRepayment(
      ledger.CreateRepaymentCommand(
        principal: total.principal,
        interest: _positiveOrNull(total.interest),
        fee: _positiveOrNull(total.fee),
        discount: _positiveOrNull(total.discount),
        liabilityAccountId: bill.accountId,
        paidFromAccountId: transactionInfo.paidFromAccountId,
        occurredAt: transactionInfo.occurredAt,
        counterpartyName: transactionInfo.counterpartyName,
        note: transactionInfo.note ?? note,
        ownership: ledger.TransactionOwnership(
          ownerType: creditRepaymentOwnerType,
          ownerId: repaymentId,
          ownerRole: RepaymentType.bill.code,
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
}
