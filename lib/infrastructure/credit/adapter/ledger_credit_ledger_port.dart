import 'package:smartflow/application/ledger/ledger_command_api.dart'
    as ledger_command;
import 'package:smartflow/application/ledger/ledger_query_api.dart'
    as ledger_query;
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';

class LedgerCreditLedgerPort implements CreditLedgerPort {
  const LedgerCreditLedgerPort({
    required ledger_query.AccountQueryService accountQueryService,
    required ledger_command.TransactionPostingAppService postingService,
    required ledger_command.TransactionEditAppService editService,
    required ledger_command.TransactionUpdateAppService updateService,
    required ledger_query.TransactionQueryService transactionQueryService,
  }) : _accountQueryService = accountQueryService,
       _postingService = postingService,
       _editService = editService,
       _updateService = updateService,
       _transactionQueryService = transactionQueryService;

  final ledger_query.AccountQueryService _accountQueryService;
  final ledger_command.TransactionPostingAppService _postingService;
  final ledger_command.TransactionEditAppService _editService;
  final ledger_command.TransactionUpdateAppService _updateService;
  final ledger_query.TransactionQueryService _transactionQueryService;

  @override
  Future<CreditLedgerAccountSnapshot?> findAccount(String accountId) async {
    final account = await _accountQueryService.findAccountById(accountId);
    if (account == null) return null;
    return CreditLedgerAccountSnapshot(
      id: account.id,
      balance: account.balance,
      isArchived: account.isArchived,
    );
  }

  @override
  Future<CreditLedgerPostedTransaction> postRepayment(
    CreditLedgerPostRepaymentCommand command,
  ) async {
    final result = await _postingService.createRepayment(
      ledger_command.CreateRepaymentCommand(
        principal: command.amount.principal,
        interest: _positiveOrNull(command.amount.interest),
        fee: _positiveOrNull(command.amount.fee),
        discount: _positiveOrNull(command.amount.discount),
        liabilityAccountId: command.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        ownership: _ownership(command.ownership),
        tagIds: command.tagIds,
      ),
    );
    return _posted(result);
  }

  @override
  Future<CreditLedgerPostedTransaction> postBorrowing(
    CreditLedgerPostBorrowingCommand command,
  ) async {
    final result = await _postingService.createBorrowing(
      ledger_command.CreateBorrowingCommand(
        amount: command.amount,
        liabilityAccountId: command.liabilityAccountId,
        receiveAccountId: command.receiveAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        ownership: _ownership(command.ownership),
      ),
    );
    return _posted(result);
  }

  @override
  Future<CreditLedgerPostedTransaction> editRepayment(
    CreditLedgerEditRepaymentCommand command,
  ) async {
    final amount = command.amount;
    final result = await _editService.editRepayment(
      ledger_command.EditRepaymentCommand(
        transactionId: command.transactionId,
        principal: amount?.principal,
        interest:
            amount == null
                ? null
                : Patch<Money?>.set(_positiveOrNull(amount.interest)),
        fee:
            amount == null
                ? null
                : Patch<Money?>.set(_positiveOrNull(amount.fee)),
        discount:
            amount == null
                ? null
                : Patch<Money?>.set(_positiveOrNull(amount.discount)),
        liabilityAccountId: command.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        occurredAt: command.occurredAt,
        note: command.note,
        tagIds: command.tagIds,
      ),
    );
    return _posted(result);
  }

  @override
  Future<void> editBorrowing(CreditLedgerEditBorrowingCommand command) {
    return _editService.editBorrowing(
      ledger_command.EditBorrowingCommand(
        transactionId: command.transactionId,
        receiveAccountId: command.receiveAccountId,
        occurredAt: command.occurredAt,
      ),
    );
  }

  @override
  Future<void> updateBasicInfo(CreditLedgerUpdateBasicInfoCommand command) {
    return _updateService.updateBasicInfo(
      ledger_command.UpdateTransactionBasicInfoCommand(
        transactionId: command.transactionId,
        occurredAt: command.occurredAt,
        note: command.note,
      ),
    );
  }

  @override
  Future<void> updateOwnership({
    required String transactionId,
    required CreditLedgerOwnership ownership,
  }) {
    return _updateService.updateOwnership(
      ledger_command.UpdateTransactionOwnershipCommand(
        transactionId: transactionId,
        ownership: _ownership(ownership)!,
      ),
    );
  }

  @override
  Future<void> deleteTransaction(String transactionId) {
    return _editService.deleteTransaction(
      ledger_command.DeleteTransactionCommand(transactionId: transactionId),
    );
  }

  @override
  Future<CreditLedgerTransactionSnapshot?> findParentTransaction(
    String transactionId,
  ) async {
    final detail = await _transactionQueryService.findParentTransactionDetail(
      transactionId,
    );
    if (detail == null) return null;
    return CreditLedgerTransactionSnapshot(
      transactionId: detail.transaction.id,
      occurredAt: detail.transaction.occurredAt,
      paidFromAccountId: _paidFromAccountId(detail),
    );
  }

  @override
  Future<CreditLedgerRepaymentSnapshot?> findRepaymentTransaction(
    String transactionId,
  ) async {
    final detail = await _transactionQueryService.findTransactionDetail(
      transactionId,
    );
    if (detail == null) return null;

    final accountKinds = <String, CreditLedgerAccountKind>{};
    for (final entry in detail.entries) {
      accountKinds[entry.accountId] = await _accountKind(entry.accountId);
    }

    return CreditLedgerRepaymentSnapshot(
      transactionId: detail.transaction.id,
      isDebtRepayment:
          detail.transaction.businessPurpose ==
          ledger_query.BusinessPurpose.debtRepayment,
      occurredAt: detail.transaction.occurredAt,
      ownerType: detail.transaction.ownership?.ownerType,
      note: detail.transaction.note,
      details: [
        for (final line in detail.details)
          if (_repaymentDetailType(line.type) != null)
            CreditLedgerRepaymentDetail(
              type: _repaymentDetailType(line.type)!,
              amount: line.amount,
            ),
      ],
      entries: [
        for (final entry in detail.entries)
          CreditLedgerRepaymentEntry(
            accountId: entry.accountId,
            accountKind:
                accountKinds[entry.accountId] ?? CreditLedgerAccountKind.other,
            direction: switch (entry.direction) {
              ledger_query.EntryDirection.debit =>
                CreditLedgerEntryDirection.debit,
              ledger_query.EntryDirection.credit =>
                CreditLedgerEntryDirection.credit,
            },
          ),
      ],
    );
  }

  CreditLedgerPostedTransaction _posted(
    ledger_command.PostedTransactionResult result,
  ) {
    return CreditLedgerPostedTransaction(transactionId: result.transactionId);
  }

  ledger_command.TransactionOwnership? _ownership(
    CreditLedgerOwnership? ownership,
  ) {
    if (ownership == null) return null;
    return ledger_command.TransactionOwnership(
      ownerType: ownership.ownerType,
      ownerId: ownership.ownerId,
      ownerRole: ownership.ownerRole,
    );
  }

  Future<CreditLedgerAccountKind> _accountKind(String accountId) async {
    final account = await _accountQueryService.findAccountById(accountId);
    if (account == null) return CreditLedgerAccountKind.other;
    return switch (account.type) {
      ledger_query.AccountType.asset => CreditLedgerAccountKind.asset,
      ledger_query.AccountType.liability => CreditLedgerAccountKind.liability,
      ledger_query.AccountType.equity ||
      ledger_query.AccountType.income ||
      ledger_query.AccountType.expense => CreditLedgerAccountKind.other,
    };
  }

  CreditLedgerRepaymentDetailType? _repaymentDetailType(
    ledger_query.TransactionDetailType type,
  ) {
    return switch (type) {
      ledger_query.TransactionDetailType.repaymentPrincipal =>
        CreditLedgerRepaymentDetailType.principal,
      ledger_query.TransactionDetailType.repaymentInterest =>
        CreditLedgerRepaymentDetailType.interest,
      ledger_query.TransactionDetailType.repaymentFee =>
        CreditLedgerRepaymentDetailType.fee,
      ledger_query.TransactionDetailType.repaymentDiscount =>
        CreditLedgerRepaymentDetailType.discount,
      _ => null,
    };
  }

  Money? _positiveOrNull(Money value) {
    return value.minorUnits > 0 ? value : null;
  }

  String? _paidFromAccountId(ledger_query.TransactionDetail detail) {
    final paidAmount = detail.transaction.primaryAmount;
    for (final entry in detail.entries.reversed) {
      if (entry.direction == ledger_query.EntryDirection.credit &&
          entry.amount == paidAmount) {
        return entry.accountId;
      }
    }
    return null;
  }
}
