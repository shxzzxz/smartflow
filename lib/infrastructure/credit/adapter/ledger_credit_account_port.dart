import 'package:smartflow/application/ledger/ledger_command_api.dart'
    as ledger_command;
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

class LedgerCreditAccountPort implements CreditAccountLedgerPort {
  const LedgerCreditAccountPort(this._accountAppService);

  final ledger_command.AccountAppService _accountAppService;

  @override
  Future<CreditLedgerAccountSnapshot> createLiabilityAccount(
    CreditLedgerCreateLiabilityAccountCommand command,
  ) async {
    final account = await _accountAppService.createAccount(
      ledger_command.CreateAccountCommand(
        name: command.name,
        type: ledger_command.AccountType.liability,
        openingBalance: command.openingBalance,
        profileKey: switch (command.kind) {
          CreditLiabilityAccountKind.credit => AccountProfileKind.credit.key,
          CreditLiabilityAccountKind.loan => AccountProfileKind.loan.key,
        },
        iconKey: command.iconKey,
        note: command.note,
        groupId: command.groupId,
        sortOrder: command.sortOrder,
        isHidden: command.isHidden,
      ),
    );
    return CreditLedgerAccountSnapshot(
      id: account.id,
      balance: account.balance,
      isArchived: account.isArchived,
    );
  }

  @override
  Future<void> editLiabilityAccount(
    CreditLedgerEditLiabilityAccountCommand command,
  ) {
    return _accountAppService.editAccount(
      ledger_command.EditAccountCommand(
        id: command.accountId,
        name: command.name,
        iconKey: command.iconKey,
        note: command.note,
        targetBalance: command.targetBalance,
      ),
    );
  }
}
