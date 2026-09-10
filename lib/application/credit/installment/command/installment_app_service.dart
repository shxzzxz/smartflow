import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/installment/installment_lifecycle_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_origination_service.dart';
import 'package:smartflow/domain/credit/service/repayment/repayment_policy_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import 'installment_command.dart';
import '../../../../domain/credit/port/installment_repricing_repository.dart';
import '../../../../domain/credit/valobj/installment_plan_terms.dart';
import '../../../../domain/credit/port/installment_product_repository.dart';
import '../../../../domain/credit/valobj/installment_contract_terms.dart';
import 'installment_plan_service.dart';
import '../../../../domain/credit/service/installment/installment_plan_engine.dart';
import '../../../../domain/credit/valobj/installment_plan_change.dart';
import '../../settlement/settlement_app_service.dart';

abstract interface class InstallmentAppService {
  Future<CreateContractResult> createDisbursementContract(
    CreateDisbursementContractCommand command,
  );

  Future<void> updateContract(UpdateContractCommand command);

  /// 预览按候选条款重建待还尾部，返回确认所需的事实指纹。
  Future<ContractRecalculationPreview> previewContractRecalculation(
    PreviewContractRecalculationCommand command,
  );

  Future<void> skipSchedule(SkipInstallmentScheduleCommand command);

  Future<void> restoreSchedule(RestoreInstallmentScheduleCommand command);

  /// 删除合同：仅允许无提前还款且所有计划均未发生还款的合同。
  Future<void> deleteContract(DeleteContractCommand command);
}

class InstallmentAppServiceImpl implements InstallmentAppService {
  InstallmentAppServiceImpl({
    required InstallmentRepository repository,
    required BillRepository bills,
    required RepaymentRepository repayments,
    required CreditLedgerPort ledger,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    InstallmentPlanService? plans,
    InstallmentProductRepository? products,
    InstallmentRepricingRepository? repricings,
    InstallmentOriginationService origination =
        const InstallmentOriginationService(),
    InstallmentLifecycleService lifecycle = const InstallmentLifecycleService(),
    RepaymentPolicyService repaymentPolicy = const RepaymentPolicyService(),
  }) : _plans =
           plans ??
           InstallmentPlanService(
             installments: repository,
             repayments: repayments,
             bills: bills,
             runner: transactionRunner,
             idGenerator: idGenerator,
           ),
       _repricings = repricings,
       _products = products,
       _repository = repository,
       _bills = bills,
       _repayments = repayments,
       _ledger = ledger,
       _runner = transactionRunner,
       _idGenerator = idGenerator,
       _origination = origination,
       _lifecycle = lifecycle,
       _repaymentPolicy = repaymentPolicy,
       _repaymentSettlement = SettlementAppService(
         bills: bills,
         repayments: repayments,
         installments: repository,
       );

  final InstallmentPlanService _plans;
  final InstallmentRepository _repository;
  final InstallmentRepricingRepository? _repricings;
  final InstallmentProductRepository? _products;
  final BillRepository _bills;
  final RepaymentRepository _repayments;
  final CreditLedgerPort _ledger;
  final TransactionRunner _runner;
  final IdGenerator _idGenerator;
  final InstallmentOriginationService _origination;
  final InstallmentLifecycleService _lifecycle;
  final RepaymentPolicyService _repaymentPolicy;
  final SettlementAppService _repaymentSettlement;

  @override
  Future<CreateContractResult> createDisbursementContract(
    CreateDisbursementContractCommand command,
  ) async {
    return _runner.run<CreateContractResult>(() async {
      final product = command.productId == null
          ? null
          : await _products?.find(command.productId!);
      if (command.productId != null && (product == null || product.archived)) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: '产品不存在或已归档，请重新选择',
        );
      }
      final inputTerms = command.stageTerms;
      final stageTerms = InstallmentContractTerms(
        dayCount: inputTerms.dayCount,
        rounding: inputTerms.rounding,
        tailDifference: inputTerms.tailDifference,
        stages: [
          for (final stage in inputTerms.stages)
            InstallmentContractStage(
              id: _idGenerator.newId(),
              terms: stage.terms,
            ),
        ],
      );
      final disbursementAccountId = command.disbursementAccountId;
      final borrowing = disbursementAccountId == null
          ? null
          : await _ledger.postBorrowing(
              CreditLedgerPostBorrowingCommand(
                amount: command.principal,
                liabilityAccountId: command.liabilityAccountId,
                occurredAt: command.borrowingDate,
                receiveAccountId: disbursementAccountId,
                counterpartyName: command.counterpartyName,
                note: command.note,
              ),
            );
      final now = DateTime.now();
      final contractId = _idGenerator.newId();
      final aggregate = _origination.originateDisbursement(
        contractId: contractId,
        liabilityAccountId: command.liabilityAccountId,
        disbursementAccountId: disbursementAccountId,
        disbursementTransactionId: borrowing?.transactionId,
        terms: InstallmentOriginationTerms(
          principal: command.principal,
          borrowingDate: command.borrowingDate,
          note: command.note,
          productId: product?.id,
          productName: product?.name,
          customRules: command.customRules,
          stageTerms: stageTerms,
        ),
        createdAt: now,
        newScheduleId: _idGenerator.newId,
      );
      await _repository.insertAggregate(
        aggregate.contract,
        aggregate.schedules,
      );
      if (borrowing != null) {
        await _ledger.updateOwnership(
          transactionId: borrowing.transactionId,
          ownership: _installmentOwnership(
            contractId,
            InstallmentOwnerRole.disbursement,
          ),
        );
      }
      return CreateContractResult(
        contractId: contractId,
        disbursementTransactionId: borrowing?.transactionId,
      );
    });
  }

  @override
  Future<void> updateContract(UpdateContractCommand command) =>
      _runner.run(() => _updateContract(command));

  Future<void> _updateContract(UpdateContractCommand command) async {
    final prepared = await _prepareContractUpdate(command);
    final contract = prepared.contract;
    final schedules = prepared.schedules;
    final terms = command.stageTerms;
    if (terms != null) {
      await _discardChangedRateCandidates(
        contract.id,
        prepared.previousTerms,
        terms,
      );
      await _reviseContractTerms(contract, command, terms);
    }
    contract.reviseDetails(
      name: command.name,
      borrowingDate: command.borrowingDate,
      note: command.note,
      disbursementAccountId: command.disbursementAccountId,
    );
    contract.reviseSchedules(
      schedules: schedules,
      revisions: [
        for (final patch in command.schedulePatches)
          InstallmentScheduleRevision(
            periodNo: patch.periodNo,
            expectedPrincipal: patch.expectedPrincipal,
            expectedInterest: patch.expectedInterest,
            expectedFee: patch.expectedFee,
            expectedRepaymentDate: patch.expectedRepaymentDate,
          ),
      ],
    );

    await _synchronizeBorrowing(contract, command);
    await _repository.saveAggregate(contract, schedules);
  }

  Future<
    ({
      InstallmentContract contract,
      List<InstallmentSchedule> schedules,
      InstallmentContractTerms previousTerms,
    })
  >
  _prepareContractUpdate(UpdateContractCommand command) async {
    var contract =
        await _repository.findContract(command.contractId) ??
        (throw BusinessException(CreditErrorCode.contractNotFound));
    contract.ensureEditable();
    var schedules = await _repository.listSchedules(command.contractId);
    final previousTerms = contract.stageTerms;
    final terms = command.stageTerms ?? previousTerms;
    terms.validateReplacementOf(previousTerms);
    if (command.regeneratePlan) {
      final token = command.planPreviewToken;
      if (token == null ||
          (command.borrowingDate != null &&
              command.borrowingDate != contract.borrowingDate)) {
        throw BusinessException(
          CreditErrorCode.contractPersistenceConflict,
          message: '请按当前借款日期重新预览计划后保存',
        );
      }
      await _plans.confirmChange(
        contract.id,
        RecalculateFromTerms(terms),
        token: token,
      );
      contract = (await _repository.findContract(command.contractId))!;
      schedules = await _repository.listSchedules(command.contractId);
    } else if (!terms.hasSameLayout(previousTerms)) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '阶段结构或期数已改变，请先按参数重算计划',
      );
    } else if (command.stageTerms != null || command.borrowingDate != null) {
      const InstallmentPlanEngine().generate(
        terms.planTerms(
          contract.principal,
          command.borrowingDate ?? contract.borrowingDate,
        ),
      );
    }
    return (
      contract: contract,
      schedules: schedules,
      previousTerms: previousTerms,
    );
  }

  Future<void> _discardChangedRateCandidates(
    String contractId,
    InstallmentContractTerms previousTerms,
    InstallmentContractTerms terms,
  ) async {
    final changedRateStages = <String>{};
    for (final previous in previousTerms.stages) {
      if (previous.terms is! AmortizingStage) continue;
      final old = previous.terms as AmortizingStage;
      final next = terms.stages
          .where((s) => s.id == previous.id)
          .firstOrNull
          ?.terms;
      if (next is! AmortizingStage ||
          next.floatingRate != old.floatingRate ||
          next.rate != old.rate) {
        changedRateStages.add(previous.id);
      }
    }
    await _repricings?.discardPending(contractId, changedRateStages);
  }

  Future<void> _reviseContractTerms(
    InstallmentContract contract,
    UpdateContractCommand command,
    InstallmentContractTerms terms,
  ) async {
    final product =
        command.productId == null || command.productId == contract.productId
        ? null
        : await _products?.find(command.productId!);
    if (command.productId != null &&
        command.productId != contract.productId &&
        (product == null || product.archived)) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '产品模板不存在或已归档',
      );
    }
    contract.reviseStageTerms(
      command.regeneratePlan ? contract.stageTerms : terms,
      customRules: command.customRules,
      productId: product?.id,
      productName: product?.name,
    );
  }

  Future<void> _synchronizeBorrowing(
    InstallmentContract contract,
    UpdateContractCommand command,
  ) async {
    if (contract.sourceType != InstallmentSourceType.disbursement) return;
    final txId = contract.disbursementTransactionId;
    if (txId == null) return;
    if (command.disbursementAccountId != null ||
        command.borrowingDate != null) {
      await _ledger.editBorrowing(
        CreditLedgerEditBorrowingCommand(
          transactionId: txId,
          receiveAccountId: command.disbursementAccountId,
          occurredAt: command.borrowingDate,
        ),
      );
    }
    if (command.note != null) {
      await _ledger.updateBasicInfo(
        CreditLedgerUpdateBasicInfoCommand(
          transactionId: txId,
          note: _nullableStringPatch(command.note),
        ),
      );
    }
  }

  @override
  Future<ContractRecalculationPreview> previewContractRecalculation(
    PreviewContractRecalculationCommand command,
  ) => _runner.run(() async {
    final contract = await _repository.findContract(command.contractId);
    if (contract == null) {
      throw BusinessException(CreditErrorCode.contractNotFound);
    }
    final preview = await _plans.previewChange(
      contract.id,
      RecalculateFromTerms(command.stageTerms ?? contract.stageTerms),
    );
    return ContractRecalculationPreview(
      token: preview.token,
      schedules: List.unmodifiable([
        for (final row in preview.change.rows)
          RecalculatedSchedulePreview(
            scheduleId: row.id,
            periodNo: row.periodNo,
            expectedRepaymentDate: row.date,
            expectedPrincipal: row.principal,
            expectedInterest: row.interest,
            expectedFee: row.fee,
          ),
      ]),
    );
  });

  @override
  Future<void> skipSchedule(SkipInstallmentScheduleCommand command) async {
    final aggregate = await _requireAggregate(command.contractId);
    final schedule = _ownedSchedule(aggregate.schedules, command.scheduleId);
    aggregate.contract.skipSchedule(schedule, schedules: aggregate.schedules);
    await _runner.run<void>(
      () => _repository.saveAggregate(aggregate.contract, aggregate.schedules),
    );
  }

  @override
  Future<void> restoreSchedule(
    RestoreInstallmentScheduleCommand command,
  ) async {
    final aggregate = await _requireAggregate(command.contractId);
    final schedule = _ownedSchedule(aggregate.schedules, command.scheduleId);
    aggregate.contract.restoreSchedule(
      schedule,
      schedules: aggregate.schedules,
    );
    await _runner.run<void>(
      () => _repository.saveAggregate(aggregate.contract, aggregate.schedules),
    );
  }

  Future<({InstallmentContract contract, List<InstallmentSchedule> schedules})>
  _requireAggregate(String contractId) async {
    final contract = await _repository.findContract(contractId);
    if (contract == null) {
      throw BusinessException(CreditErrorCode.contractNotFound);
    }
    final schedules = await _repository.listSchedules(contractId);
    return (contract: contract, schedules: schedules);
  }

  InstallmentSchedule _ownedSchedule(
    List<InstallmentSchedule> schedules,
    String scheduleId,
  ) {
    for (final schedule in schedules) {
      if (schedule.id == scheduleId) return schedule;
    }
    throw BusinessException(
      CreditErrorCode.scheduleNotFound,
      message: 'Schedule does not belong to the contract.',
    );
  }

  Patch<String?>? _nullableStringPatch(Patch<String>? patch) {
    return switch (patch) {
      null => null,
      PatchSet<String>(:final value) => Patch<String?>.set(value),
      PatchClear<String>() => const Patch<String?>.clear(),
    };
  }

  @override
  Future<void> deleteContract(DeleteContractCommand command) async {
    final contract = await _repository.findContract(command.contractId);
    if (contract == null) {
      throw BusinessException(
        CreditErrorCode.contractNotFound,
        message: 'Installment contract does not exist.',
      );
    }

    final repayments = await _repayments.listByTarget(
      RepaymentTargetType.contract,
      command.contractId,
    );
    final schedules = await _repository.listSchedules(command.contractId);
    _lifecycle.validateDelete(repayments: repayments, schedules: schedules);

    return _runner.run<void>(() async {
      final sourceRepaymentId = contract.sourceRepaymentId;
      if (sourceRepaymentId != null) {
        final sourceRepayment = await _repayments.findRepayment(
          sourceRepaymentId,
        );
        if (sourceRepayment != null) {
          final sourceBill = await _bills.findBill(sourceRepayment.targetId);
          if (sourceBill == null) {
            throw BusinessException(CreditErrorCode.billNotFound);
          }
          final allocations = _repaymentPolicy.allocationsFromItems(
            sourceRepayment.items,
          );
          await _repayments.deleteRepayment(sourceRepayment.id);
          await _repaymentSettlement.refreshBillStatuses(
            sourceBill,
            allocations,
          );
        }
      }
      final disbursementTransactionId = contract.disbursementTransactionId;
      if (disbursementTransactionId != null) {
        await _ledger.deleteTransaction(disbursementTransactionId);
      }
      await _removeContractBillItems(contract);
      await _repository.deleteContract(command.contractId);
    });
  }

  Future<void> _removeContractBillItems(InstallmentContract contract) async {
    final bills = await _bills.listBillsByAccount(contract.liabilityAccountId);
    for (final bill in bills) {
      final retained = [
        for (final item in bill.items)
          if (item.contractId != contract.id) item,
      ];
      if (retained.length == bill.items.length) continue;
      await _bills.replaceBillItems(bill.id, retained);
      if (bill.status == BillStatus.open) {
        bill.refreshOpenProjection(window: bill.window!, sourceItems: retained);
      } else {
        bill.synchronizeBilledItems(retained);
      }
      await _bills.updateBill(bill);
    }
  }

  CreditLedgerOwnership _installmentOwnership(
    String contractId,
    InstallmentOwnerRole role,
  ) {
    return CreditLedgerOwnership(
      ownerType: installmentOwnerType,
      ownerId: contractId,
      ownerRole: role.wireValue,
    );
  }
}
