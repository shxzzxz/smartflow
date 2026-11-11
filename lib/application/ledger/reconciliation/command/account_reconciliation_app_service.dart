import '../../../shared/transaction_runner.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../domain/ledger/port/account_repository.dart';
import '../../../../domain/ledger/valobj/ledger_error_code.dart';
import '../port/account_reconciliation_repository.dart';
import '../query/account_reconciliation_queries.dart';
import 'account_reconciliation_command.dart';

abstract interface class AccountReconciliationAppService {
  Future<void> confirm(ConfirmAccountReconciliationCommand command);
}

class AccountReconciliationAppServiceImpl
    implements AccountReconciliationAppService {
  const AccountReconciliationAppServiceImpl({
    required AccountRepository accounts,
    required AccountReconciliationRepository snapshots,
    required TransactionRunner transactionRunner,
  }) : _accounts = accounts,
       _snapshots = snapshots,
       _runner = transactionRunner;

  final AccountRepository _accounts;
  final AccountReconciliationRepository _snapshots;
  final TransactionRunner _runner;

  @override
  Future<void> confirm(ConfirmAccountReconciliationCommand command) {
    return _runner.run(() async {
      if (command.accountId.isEmpty ||
          command.untilInclusive.isBefore(command.from)) {
        throw BusinessException(LedgerErrorCode.reconciliationInvalidCommand);
      }
      if (await _accounts.findById(command.accountId) == null) {
        throw BusinessException(LedgerErrorCode.accountNotFound);
      }
      final query = AccountReconciliationQuery(
        accountId: command.accountId,
        from: command.from,
        untilInclusive: command.untilInclusive,
      );
      final currentDays = await _snapshots.findCurrentDays(query);
      await _snapshots.replaceSnapshots(
        query: query,
        currentDays: currentDays,
        confirmedAt: DateTime.now(),
      );
    });
  }
}
