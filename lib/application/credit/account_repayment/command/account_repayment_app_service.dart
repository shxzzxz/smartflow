import 'package:smartflow/application/credit/repayment/command/repayment_command.dart';
import 'package:smartflow/application/credit/repayment/command/repayment_transaction_support.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/debt/credit_debt_bucket_service.dart';
import 'package:smartflow/domain/credit/service/repayment/repayment_policy_service.dart'
    as domain_repayment;
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

/// 以信用账户为目标的账户级还款能力。
abstract interface class AccountRepaymentAppService {
  Future<CreateRepaymentResult> createAccountRepayment(
    CreateUnattributedRepaymentCommand command,
  );

  Future<void> editRepaymentTransaction(
    EditCreditRepaymentTransactionCommand command,
  );

  Future<void> deleteRepayment(DeleteCreditRepaymentCommand command);
}

class AccountRepaymentAppServiceImpl implements AccountRepaymentAppService {
  AccountRepaymentAppServiceImpl({
    required BillRepository bills,
    required RepaymentRepository repayments,
    required InstallmentRepository installments,
    required CreditLedgerPort ledger,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    CreditDebtBucketService debtBuckets = const CreditDebtBucketService(),
    domain_repayment.RepaymentPolicyService repaymentPolicy =
        const domain_repayment.RepaymentPolicyService(),
  }) : _bills = bills,
       _repayments = repayments,
       _installments = installments,
       _ledger = ledger,
       _transactionRunner = transactionRunner,
       _idGenerator = idGenerator,
       _debtBuckets = debtBuckets,
       _repaymentPolicy = repaymentPolicy,
       _transactions = RepaymentTransactionSupport(
         bills: bills,
         repayments: repayments,
         installments: installments,
         ledger: ledger,
       );

  final BillRepository _bills;
  final RepaymentRepository _repayments;
  final InstallmentRepository _installments;
  final CreditLedgerPort _ledger;
  final TransactionRunner _transactionRunner;
  final IdGenerator _idGenerator;
  final CreditDebtBucketService _debtBuckets;
  final domain_repayment.RepaymentPolicyService _repaymentPolicy;
  final RepaymentTransactionSupport _transactions;

  @override
  Future<CreateRepaymentResult> createAccountRepayment(
    CreateUnattributedRepaymentCommand command,
  ) async {
    final account = await _ledger.findAccount(command.accountId);
    if (account == null) {
      throw BusinessException(
        CreditErrorCode.accountNotFound,
        message: 'Credit liability account does not exist.',
      );
    }
    final total = repaymentAmountBreakdown(command.amount);
    final bucket = await _unattributedDebtBucket(command.accountId);
    _repaymentPolicy.validateUnattributedRepayment(
      total: total,
      availableDebt: bucket,
    );
    final repaymentId = _idGenerator.newId();

    return _transactionRunner.run(() async {
      final post = await _transactions.post(
        liabilityAccountId: command.accountId,
        repaymentId: repaymentId,
        total: total,
        transactionInfo: command.transactionInfo,
        note: command.note,
      );
      final repayment = Repayment(
        id: repaymentId,
        repaymentType: RepaymentType.unattributed,
        targetType: RepaymentTargetType.account,
        targetId: command.accountId,
        transactionId: post.transactionId,
        repaymentDate: command.transactionInfo.occurredAt,
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
        transactionId: post.transactionId,
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
        allowedTypes: const {RepaymentType.unattributed},
      );
      await _transactions.editTransaction(repayment, command);
    });
  }

  @override
  Future<void> deleteRepayment(DeleteCreditRepaymentCommand command) async {
    final repayment = await _transactions.requireRepayment(
      repaymentId: command.repaymentId,
      transactionId: command.transactionId,
      allowedTypes: const {RepaymentType.unattributed},
    );
    final transaction = await _transactions.loadParentTransaction(repayment);
    return _transactionRunner.run<void>(() async {
      await _transactions.deleteParentTransaction(transaction);
      await _repayments.deleteRepayment(repayment.id);
    });
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
}
