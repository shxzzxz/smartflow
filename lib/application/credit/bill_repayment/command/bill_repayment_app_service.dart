import 'package:smartflow/application/credit/repayment/command/repayment_command.dart';
import 'package:smartflow/application/credit/repayment/command/repayment_transaction_support.dart';
import 'package:smartflow/application/credit/repayment/repayment_amount_dto.dart';
import 'package:smartflow/application/credit/settlement/settlement_app_service.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/installment/installment_contract_origination_service.dart';
import 'package:smartflow/domain/credit/service/repayment/repayment_policy_service.dart'
    as domain_repayment;
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

/// 以账单为目标的还款能力，包括普通账单还款与账单分期。
abstract interface class BillRepaymentAppService {
  Future<CreateRepaymentResult> createBillRepayment(
    CreateBillRepaymentCommand command,
  );

  Future<BillRepaymentEditView?> loadBillRepaymentEditView(String repaymentId);

  Future<CreateRepaymentResult> editBillRepayment(
    EditBillRepaymentCommand command,
  );

  Future<CreateRepaymentResult> createBillConversionInstallmentRepayment(
    CreateBillConversionInstallmentRepaymentCommand command,
  );

  Future<void> editRepaymentTransaction(
    EditCreditRepaymentTransactionCommand command,
  );

  Future<void> deleteRepayment(DeleteCreditRepaymentCommand command);
}

class BillRepaymentAppServiceImpl implements BillRepaymentAppService {
  BillRepaymentAppServiceImpl({
    required BillRepository bills,
    required RepaymentRepository repayments,
    required InstallmentRepository installments,
    required CreditLedgerPort ledger,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    InstallmentContractOriginationService origination =
        const InstallmentContractOriginationService(),
    domain_repayment.RepaymentPolicyService repaymentPolicy =
        const domain_repayment.RepaymentPolicyService(),
    SettlementAppService? settlement,
  }) : _bills = bills,
       _repayments = repayments,
       _installments = installments,
       _transactionRunner = transactionRunner,
       _idGenerator = idGenerator,
       _origination = origination,
       _repaymentPolicy = repaymentPolicy,
       _transactions = RepaymentTransactionSupport(
         bills: bills,
         repayments: repayments,
         installments: installments,
         ledger: ledger,
       ),
       _settlement =
           settlement ??
           SettlementAppService(
             bills: bills,
             repayments: repayments,
             installments: installments,
           );

  final BillRepository _bills;
  final RepaymentRepository _repayments;
  final InstallmentRepository _installments;
  final TransactionRunner _transactionRunner;
  final IdGenerator _idGenerator;
  final InstallmentContractOriginationService _origination;
  final domain_repayment.RepaymentPolicyService _repaymentPolicy;
  final RepaymentTransactionSupport _transactions;
  final SettlementAppService _settlement;

  @override
  Future<CreateRepaymentResult> createBillRepayment(
    CreateBillRepaymentCommand command,
  ) async {
    final bill = await _requireBill(command.billId);
    final allocations = _domainAllocations(command.allocations);
    _repaymentPolicy.validateBillRepayment(
      bill: bill,
      allocations: allocations,
    );

    final repaymentId = _idGenerator.newId();
    final items = _items(
      repaymentId: repaymentId,
      allocations: command.allocations,
    );

    return _transactionRunner.run(() async {
      final total = _repaymentPolicy.total(allocations);
      final post = await _transactions.postIfNeeded(
        liabilityAccountId: bill.accountId,
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
        transactionId: post?.transactionId,
        repaymentDate: requireRepaymentDate(
          command.transactionInfo?.occurredAt ?? command.repaymentDate,
        ),
        items: items,
      )..validateAgainstLedgerTransaction(total);
      await _repayments.saveRepayment(repayment);
      await _settlement.refreshBillStatuses(bill, allocations);
      return CreateRepaymentResult(
        repaymentId: repaymentId,
        transactionId: post?.transactionId,
      );
    });
  }

  @override
  Future<BillRepaymentEditView?> loadBillRepaymentEditView(
    String repaymentId,
  ) async {
    final repayment = await _repayments.findRepayment(repaymentId);
    if (repayment == null || repayment.repaymentType != RepaymentType.bill) {
      return null;
    }
    String? paidFromAccountId;
    String? note;
    if (repayment.transactionId != null) {
      final detail = await _transactions.findRepaymentTransaction(
        repayment.transactionId!,
      );
      if (detail != null) {
        paidFromAccountId = _firstSettlementAccountId(detail);
        note = detail.note;
      }
    }
    return BillRepaymentEditView(
      repaymentId: repayment.id,
      billId: repayment.targetId,
      allocations: [
        for (final item in repayment.items)
          BillRepaymentEditAllocation(
            id: item.id,
            billItemId: item.billItemId,
            allocated: RepaymentAmountDto(
              principal: item.allocated.principal,
              interest: item.allocated.interest,
              fee: item.allocated.fee,
              discount: item.allocated.discount,
            ),
          ),
      ],
      hasTransaction: repayment.transactionId != null,
      transactionId: repayment.transactionId,
      paidFromAccountId: paidFromAccountId,
      occurredAt: repayment.repaymentDate,
      note: note,
    );
  }

  @override
  Future<CreateRepaymentResult> editBillRepayment(
    EditBillRepaymentCommand command,
  ) async {
    final repayment = await _repayments.findRepayment(command.repaymentId);
    if (repayment == null) {
      throw BusinessException(CreditErrorCode.repaymentNotFound);
    }
    if (repayment.repaymentType != RepaymentType.bill) {
      throw BusinessException(CreditErrorCode.repaymentNotEditable);
    }
    final bill = await _requireBill(repayment.targetId);
    final allocations = _domainAllocations(command.allocations);
    _repaymentPolicy.validateBillRepayment(
      bill: bill,
      allocations: allocations,
    );
    final oldAllocations = _repaymentPolicy.allocationsFromItems(
      repayment.items,
    );
    final items = _items(
      repaymentId: repayment.id,
      allocations: command.allocations,
    );
    final total = _repaymentPolicy.total(allocations);
    return _transactionRunner.run(() async {
      final transactionId = repayment.transactionId;
      if (transactionId != null) {
        final info = command.transactionInfo;
        if (info == null) {
          throw BusinessException(CreditErrorCode.repaymentInvalidCommand);
        }
        await _transactions.editRepayment(
          transactionId: transactionId,
          amount: total,
          liabilityAccountId: bill.accountId,
          paidFromAccountId: info.paidFromAccountId,
          occurredAt: info.occurredAt,
          note: info.note == null
              ? const Patch<String?>.clear()
              : Patch<String?>.set(info.note),
        );
      }
      repayment.replaceItems(items);
      final repaymentDate = transactionId == null
          ? command.repaymentDate
          : command.transactionInfo!.occurredAt;
      if (repaymentDate != null) {
        repayment.reviseRepaymentDate(repaymentDate);
      }
      repayment.validateAgainstLedgerTransaction(total);
      await _repayments.updateRepayment(repayment);
      await _settlement.refreshBillStatuses(bill, [
        ...oldAllocations,
        ...allocations,
      ]);
      return CreateRepaymentResult(
        repaymentId: repayment.id,
        transactionId: transactionId,
      );
    });
  }

  @override
  Future<CreateRepaymentResult> createBillConversionInstallmentRepayment(
    CreateBillConversionInstallmentRepaymentCommand command,
  ) async {
    final bill = await _requireBill(command.billId);
    final allocations = _domainAllocations(command.allocations);
    _repaymentPolicy.validateBillConversionInstallment(
      bill: bill,
      allocations: allocations,
      stageTerms: command.stageTerms,
    );

    final repaymentId = _idGenerator.newId();
    final items = _items(
      repaymentId: repaymentId,
      allocations: command.allocations,
    );

    return _transactionRunner.run(() async {
      final total = _repaymentPolicy.total(allocations);
      final contractId = _idGenerator.newId();
      final aggregate = _origination.originateBillConversion(
        contractId: contractId,
        name: command.contractName,
        bill: bill,
        sourceRepaymentId: repaymentId,
        principal: total.principal,
        borrowingDate: command.borrowingDate,
        stageTerms: InstallmentContractTerms(
          dayCount: command.stageTerms.dayCount,
          rounding: command.stageTerms.rounding,
          stages: [
            for (final stage in command.stageTerms.stages)
              InstallmentContractStage(
                id: _idGenerator.newId(),
                terms: stage.terms,
              ),
          ],
        ),
        note: command.note,
        createdAt: DateTime.now(),
        newScheduleId: _idGenerator.newId,
      );
      final repayment = Repayment(
        id: repaymentId,
        repaymentType: RepaymentType.installment,
        targetType: RepaymentTargetType.bill,
        targetId: bill.id,
        generatedContractId: contractId,
        repaymentDate: aggregate.contract.borrowingDate,
        items: items,
      );
      await _repayments.saveRepayment(repayment);
      await _settlement.refreshBillStatuses(bill, allocations);
      await _installments.insertAggregate(aggregate.contract);
      return CreateRepaymentResult(
        repaymentId: repaymentId,
        contractId: contractId,
      );
    });
  }

  @override
  Future<void> editRepaymentTransaction(
    EditCreditRepaymentTransactionCommand command,
  ) {
    return _transactionRunner.run(() async {
      final repayment = await _transactions.requireRepayment(
        repaymentId: command.repaymentId,
        transactionId: command.transactionId,
        allowedTypes: const {RepaymentType.bill, RepaymentType.installment},
      );
      await _transactions.editTransaction(repayment, command);
    });
  }

  @override
  Future<void> deleteRepayment(DeleteCreditRepaymentCommand command) async {
    final repayment = await _transactions.requireRepayment(
      repaymentId: command.repaymentId,
      transactionId: command.transactionId,
      allowedTypes: const {RepaymentType.bill, RepaymentType.installment},
    );
    final transaction = await _transactions.loadParentTransaction(repayment);
    return _transactionRunner.run<void>(() async {
      await _transactions.deleteParentTransaction(transaction);
      switch (repayment.repaymentType) {
        case RepaymentType.bill:
          await _deleteBillRepayment(repayment);
        case RepaymentType.installment:
          await _deleteBillConversionInstallmentRepayment(repayment);
        case RepaymentType.prepayment || RepaymentType.unattributed:
          throw BusinessException(CreditErrorCode.repaymentNotEditable);
      }
    });
  }

  Future<Bill> _requireBill(String billId) async {
    final bill = await _bills.findBill(billId);
    if (bill == null) {
      throw BusinessException(
        CreditErrorCode.billNotFound,
        message: 'Bill does not exist.',
      );
    }
    return bill;
  }

  List<RepaymentItem> _items({
    required String repaymentId,
    required List<BillRepaymentAllocation> allocations,
  }) {
    return [
      for (final allocation in allocations)
        RepaymentItem(
          id: _idGenerator.newId(),
          repaymentId: repaymentId,
          billItemId: allocation.billItemId,
          allocated: repaymentAmountBreakdown(allocation.allocated),
        ),
    ];
  }

  List<domain_repayment.BillRepaymentAllocationDraft> _domainAllocations(
    List<BillRepaymentAllocation> allocations,
  ) {
    return [
      for (final allocation in allocations)
        domain_repayment.BillRepaymentAllocationDraft(
          billItemId: allocation.billItemId,
          allocated: repaymentAmountBreakdown(allocation.allocated),
        ),
    ];
  }

  Future<void> _deleteBillRepayment(Repayment repayment) async {
    final bill = await _requireBill(repayment.targetId);
    final allocations = _repaymentPolicy.allocationsFromItems(repayment.items);
    await _repayments.deleteRepayment(repayment.id);
    await _settlement.refreshBillStatuses(bill, allocations);
  }

  Future<void> _deleteBillConversionInstallmentRepayment(
    Repayment repayment,
  ) async {
    final bill = await _requireBill(repayment.targetId);
    final contract = await _findBillConversionContract(repayment, bill);
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
    await _settlement.refreshBillStatuses(bill, allocations);
    if (contract != null) {
      await _installments.deleteContract(contract.id);
    }
  }

  Future<InstallmentContract?> _findBillConversionContract(
    Repayment repayment,
    Bill bill,
  ) async {
    final generatedContractId = repayment.generatedContractId;
    if (generatedContractId != null) {
      final contract = await _installments.findContract(generatedContractId);
      if (contract?.installmentType == InstallmentType.billConversion &&
          contract?.sourceRefId == repayment.id) {
        return contract;
      }
      return null;
    }
    final contracts = await _installments.listContractsByLiabilityAccount(
      bill.accountId,
    );
    for (final contract in contracts) {
      if (contract.installmentType == InstallmentType.billConversion &&
          contract.sourceRefId == repayment.id) {
        return contract;
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
}
