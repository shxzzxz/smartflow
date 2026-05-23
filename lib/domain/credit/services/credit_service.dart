import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../../accounting/accounting_api.dart'
    hide TransactionService, CreateRepaymentCommand, CorrectRepaymentCommand;
import '../../accounting/accounting_api.dart'
    as tx
    show TransactionService, CreateRepaymentCommand, CorrectRepaymentCommand;
import '../enums/installment_enums.dart';
import 'installment_service.dart';

/// 信贷域对外的通用入口。承载"非分期合同关联的普通还款"的创建、更正与编辑视图反解；
/// 内部委托账务核心写入，并强制走额度校验（debt − 未还分期本金）。
abstract interface class CreditService {
  Future<Result<CreatedTransactionResult>> createRepayment(
    CreateRepaymentCommand command,
  );

  Future<Result<CreatedTransactionResult>> correctRepayment(
    CorrectRepaymentCommand command,
  );

  /// 把已加载好的 detail 反解为编辑视图。非 DEBT_REPAYMENT 或结构异常时返回 null。
  /// 纯函数,无 IO;`accountsById` 由调用方(UI 层)从 accountsByIdProvider 提供,
  /// 用于把 entries 的 accountId 解析为 AccountType。
  RepaymentEditView? parseRepaymentEditView(
    TransactionDetail detail, {
    required Map<int, Account> accountsById,
  });
}

class CreateRepaymentCommand {
  const CreateRepaymentCommand({
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.principal,
    required this.occurredAt,
    this.interest,
    this.fee,
    this.discount,
    this.feeExpenseAccountId,
    this.interestExpenseAccountId,
    this.note,
  });

  final int liabilityAccountId;
  final int paidFromAccountId;
  final Money principal;
  final Money? interest;
  final Money? fee;
  final Money? discount;
  final int? feeExpenseAccountId;
  final int? interestExpenseAccountId;
  final DateTime occurredAt;
  final String? note;
}

/// 编辑命令。`liabilityAccountId` 必填且不允许改动——UI 携带原值用于额度校验。
/// `isExcludedFromStats/Budget` 不暴露：service 内部读原交易回填，避免编辑时改动统计口径。
class CorrectRepaymentCommand {
  const CorrectRepaymentCommand({
    required this.transactionId,
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.principal,
    required this.occurredAt,
    this.interest,
    this.fee,
    this.discount,
    this.feeExpenseAccountId,
    this.interestExpenseAccountId,
    this.note,
  });

  final int transactionId;
  final int liabilityAccountId;
  final int paidFromAccountId;
  final Money principal;
  final Money? interest;
  final Money? fee;
  final Money? discount;
  final int? feeExpenseAccountId;
  final int? interestExpenseAccountId;
  final DateTime occurredAt;
  final String? note;
}

/// 普通还款编辑视图。把交易 detail / entries 反解出的结构化字段提供给 UI，
/// 避免表单层自己从分录里凑账户与金额。
class RepaymentEditView {
  const RepaymentEditView({
    required this.principal,
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.occurredAt,
    this.interest,
    this.fee,
    this.discount,
    this.feeExpenseAccountId,
    this.note,
  });

  final Money principal;
  final Money? interest;
  final Money? fee;
  final Money? discount;
  final int liabilityAccountId;
  final int paidFromAccountId;
  final int? feeExpenseAccountId;
  final DateTime occurredAt;
  final String? note;
}

class CreditServiceImpl implements CreditService {
  CreditServiceImpl({
    required InstallmentService installmentService,
    required tx.TransactionService transactionService,
    required TransactionQueryService transactionQueryService,
    required AccountService accountService,
  }) : _installmentService = installmentService,
       _transactionService = transactionService,
       _transactionQueryService = transactionQueryService,
       _accountService = accountService;

  final InstallmentService _installmentService;
  final tx.TransactionService _transactionService;
  final TransactionQueryService _transactionQueryService;
  final AccountService _accountService;

  @override
  Future<Result<CreatedTransactionResult>> createRepayment(
    CreateRepaymentCommand command,
  ) async {
    final failure = await _validatePrincipal(
      liabilityAccountId: command.liabilityAccountId,
      principal: command.principal,
    );
    if (failure != null) return Result.failure(failure);

    return _transactionService.createRepayment(
      tx.CreateRepaymentCommand(
        principal: command.principal,
        interest: command.interest,
        fee: command.fee,
        discount: command.discount,
        liabilityAccountId: command.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        interestExpenseAccountId: command.interestExpenseAccountId,
        feeExpenseAccountId: command.feeExpenseAccountId,
        occurredAt: command.occurredAt,
        note: command.note,
      ),
    );
  }

  @override
  Future<Result<CreatedTransactionResult>> correctRepayment(
    CorrectRepaymentCommand command,
  ) async {
    final detail =
        await _transactionQueryService
            .watchTransactionDetail(command.transactionId)
            .first;
    if (detail == null) {
      return const Result.failure(
        Failure(
          code: 'credit_repayment_not_found',
          message: 'Repayment transaction does not exist.',
        ),
      );
    }
    if (detail.transaction.businessPurpose != BusinessPurpose.debtRepayment) {
      return const Result.failure(
        Failure(
          code: 'credit_correct_purpose_invalid',
          message:
              'CreditService.correctRepayment only handles DEBT_REPAYMENT.',
        ),
      );
    }

    final failure = await _validatePrincipal(
      liabilityAccountId: command.liabilityAccountId,
      principal: command.principal,
      editingTransactionDetail: detail,
    );
    if (failure != null) return Result.failure(failure);

    return _transactionService.correctRepayment(
      tx.CorrectRepaymentCommand(
        transactionId: command.transactionId,
        principal: command.principal,
        interest: command.interest,
        fee: command.fee,
        discount: command.discount,
        liabilityAccountId: command.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        interestExpenseAccountId: command.interestExpenseAccountId,
        feeExpenseAccountId: command.feeExpenseAccountId,
        occurredAt: command.occurredAt,
        note: command.note,
        // 回填原交易的统计/预算排除标记，信贷域的编辑命令不暴露这两个账务口径。
        isExcludedFromStats: detail.transaction.isExcludedFromStats,
        isExcludedFromBudget: detail.transaction.isExcludedFromBudget,
      ),
    );
  }

  @override
  RepaymentEditView? parseRepaymentEditView(
    TransactionDetail detail, {
    required Map<int, Account> accountsById,
  }) {
    if (detail.transaction.businessPurpose != BusinessPurpose.debtRepayment) {
      return null;
    }

    Money? principal;
    Money? interest;
    Money? fee;
    Money? discount;
    for (final line in detail.details) {
      switch (line.type) {
        case TransactionDetailType.repaymentPrincipal:
          principal = line.amount;
        case TransactionDetailType.repaymentInterest:
          interest = line.amount;
        case TransactionDetailType.repaymentFee:
          fee = line.amount;
        case TransactionDetailType.repaymentDiscount:
          discount = line.amount;
        default:
          break;
      }
    }
    if (principal == null) return null;

    final liabilityAccountId = _firstAccountId(
      detail,
      accountsById: accountsById,
      accountType: AccountType.liability,
      direction: EntryDirection.debit,
    );
    final paidFromAccountId = _firstSettlementAccountId(
      detail,
      accountsById: accountsById,
    );
    if (liabilityAccountId == null || paidFromAccountId == null) return null;

    return RepaymentEditView(
      principal: principal,
      interest: (interest?.minorUnits ?? 0) > 0 ? interest : null,
      fee: (fee?.minorUnits ?? 0) > 0 ? fee : null,
      discount: (discount?.minorUnits ?? 0) > 0 ? discount : null,
      feeExpenseAccountId:
          fee != null && fee.minorUnits > 0
              ? _expenseAccountIdByAmount(
                detail,
                accountsById: accountsById,
                amount: fee,
              )
              : null,
      liabilityAccountId: liabilityAccountId,
      paidFromAccountId: paidFromAccountId,
      occurredAt: detail.transaction.occurredAt,
      note: detail.transaction.note,
    );
  }

  /// 额度规则：principal ≤ |liabilityAccount.balance| − 未还分期本金合计。
  /// 编辑模式（[editingTransactionDetail] 非空）：
  ///   - 若原交易挂在分期合同上（owner_type=installment），跳过校验（分期通路自管金额）。
  ///   - 否则把原交易的 REPAYMENT_PRINCIPAL 加回到 debt，避免"原地编辑同金额"被自己挤掉。
  Future<Failure?> _validatePrincipal({
    required int liabilityAccountId,
    required Money principal,
    TransactionDetail? editingTransactionDetail,
  }) async {
    if (principal.minorUnits <= 0) return null;

    if (editingTransactionDetail != null &&
        editingTransactionDetail.transaction.ownership?.ownerType ==
            installmentOwnerType) {
      return null;
    }

    final account = await _accountService.findAccountById(liabilityAccountId);
    if (account == null) return null;

    var oldPrincipalMinor = 0;
    if (editingTransactionDetail != null) {
      for (final d in editingTransactionDetail.details) {
        if (d.type == TransactionDetailType.repaymentPrincipal) {
          oldPrincipalMinor += d.amount.minorUnits;
        }
      }
    }

    final debtMinor = account.balance.minorUnits + oldPrincipalMinor;
    final unpaidMinor = await _installmentService
        .unpaidInstallmentPrincipalMinor(liabilityAccountId);
    final availableMinor = debtMinor - unpaidMinor;

    if (principal.minorUnits > availableMinor) {
      final clamped = availableMinor < 0 ? 0 : availableMinor;
      final available = Money(
        minorUnits: clamped,
        currency: account.currencyCode,
      );
      return Failure(
        code: 'repayment_principal_exceeds_available',
        message:
            '本金超过可还额度（${available.format(withCurrency: true)}），剩余请通过分期合同还款',
      );
    }
    return null;
  }

  int? _firstAccountId(
    TransactionDetail detail, {
    required Map<int, Account> accountsById,
    required AccountType accountType,
    required EntryDirection direction,
  }) {
    for (final entry in detail.entries) {
      if (accountsById[entry.accountId]?.type == accountType &&
          entry.direction == direction) {
        return entry.accountId;
      }
    }
    return null;
  }

  int? _firstSettlementAccountId(
    TransactionDetail detail, {
    required Map<int, Account> accountsById,
  }) {
    for (final entry in detail.entries) {
      if (entry.direction != EntryDirection.credit) continue;
      final type = accountsById[entry.accountId]?.type;
      if (type == AccountType.asset || type == AccountType.liability) {
        return entry.accountId;
      }
    }
    return null;
  }

  int? _expenseAccountIdByAmount(
    TransactionDetail detail, {
    required Map<int, Account> accountsById,
    required Money amount,
  }) {
    for (final entry in detail.entries) {
      if (accountsById[entry.accountId]?.type == AccountType.expense &&
          entry.direction == EntryDirection.debit &&
          entry.amount == amount) {
        return entry.accountId;
      }
    }
    return null;
  }
}
