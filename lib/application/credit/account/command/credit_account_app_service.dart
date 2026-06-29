import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';

class CreateCreditLiabilityAccountCommand {
  const CreateCreditLiabilityAccountCommand({
    required this.name,
    required this.kind,
    this.openingBalance = const Money(minorUnits: 0),
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.billingStartPeriod,
    this.billingDayToNext = true,
    this.iconKey,
    this.note,
    this.sortOrder = 0,
    this.isHidden = false,
  });

  final String name;
  final CreditLiabilityAccountKind kind;
  final Money openingBalance;
  final Money? creditLimit;
  final int? billingDay;
  final int? repaymentDay;
  final BillPeriod? billingStartPeriod;
  final bool billingDayToNext;
  final String? iconKey;
  final String? note;
  final int sortOrder;
  final bool isHidden;
}

class EditCreditLiabilityAccountCommand {
  const EditCreditLiabilityAccountCommand({
    required this.accountId,
    this.name,
    this.iconKey,
    this.note,
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.billingStartPeriod,
    this.billingDayToNext,
    this.targetBalance,
  });

  final String accountId;
  final String? name;
  final Patch<String>? iconKey;
  final Patch<String>? note;
  final Patch<Money>? creditLimit;
  final Patch<int>? billingDay;
  final Patch<int>? repaymentDay;
  final Patch<BillPeriod>? billingStartPeriod;
  final bool? billingDayToNext;
  final Money? targetBalance;
}

abstract interface class CreditAccountAppService {
  Future<Account> createAccount(CreateCreditLiabilityAccountCommand command);

  Future<void> editAccount(EditCreditLiabilityAccountCommand command);
}

class CreditAccountAppServiceImpl implements CreditAccountAppService {
  const CreditAccountAppServiceImpl({
    required AccountAppService accountAppService,
    required CreditAccountRepository creditAccounts,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    DateTime Function()? now,
  }) : _accountAppService = accountAppService,
       _creditAccounts = creditAccounts,
       _runner = transactionRunner,
       _idGenerator = idGenerator,
       _now = now ?? DateTime.now;

  final AccountAppService _accountAppService;
  final CreditAccountRepository _creditAccounts;
  final TransactionRunner _runner;
  final IdGenerator _idGenerator;
  final DateTime Function() _now;

  @override
  Future<Account> createAccount(CreateCreditLiabilityAccountCommand command) {
    final billingStartPeriod =
        command.kind == CreditLiabilityAccountKind.credit
            ? command.billingStartPeriod ?? BillPeriod.fromDate(_now())
            : null;

    return _runner.run<Account>(() async {
      final account = await _accountAppService.createAccount(
        CreateAccountCommand(
          name: command.name,
          type: AccountType.liability,
          openingBalance: command.openingBalance,
          profileKey: _profileKeyForKind(command.kind),
          iconKey: command.iconKey,
          note: command.note,
          sortOrder: command.sortOrder,
          isHidden: command.isHidden,
        ),
      );
      final extension = CreditLiabilityAccount(
        id: _idGenerator.newId(),
        accountId: account.id,
        kind: command.kind,
        creditLimit: command.creditLimit,
        billingDay: command.billingDay,
        repaymentDay: command.repaymentDay,
        billingStartPeriod: billingStartPeriod,
        billingDayToNext: command.billingDayToNext,
      );
      await _creditAccounts.insert(
        CreditLiabilityAccountDraft(
          id: extension.id,
          accountId: account.id,
          kind: extension.kind,
          creditLimit: extension.creditLimit,
          billingDay: extension.billingDay,
          repaymentDay: extension.repaymentDay,
          billingStartPeriod: extension.billingStartPeriod,
          billingDayToNext: extension.billingDayToNext,
        ),
      );
      return account;
    });
  }

  @override
  Future<void> editAccount(EditCreditLiabilityAccountCommand command) async {
    final current = await _creditAccounts.findByAccountId(command.accountId);
    if (current == null) {
      throw BusinessException(CreditErrorCode.accountNotFound);
    }
    final patch = CreditLiabilityAccountPatch(
      creditLimit: command.creditLimit,
      billingDay: command.billingDay,
      repaymentDay: command.repaymentDay,
      billingStartPeriod: command.billingStartPeriod,
      billingDayToNext: command.billingDayToNext,
    );
    current.updateParameters(patch);

    await _runner.run<void>(() async {
      await _accountAppService.editAccount(
        EditAccountCommand(
          id: command.accountId,
          name: command.name,
          iconKey: command.iconKey,
          note: command.note,
          targetBalance: command.targetBalance,
        ),
      );
      await _creditAccounts.update(
        command.accountId,
        CreditLiabilityAccountPersistencePatch(
          creditLimit: command.creditLimit,
          billingDay: command.billingDay,
          repaymentDay: command.repaymentDay,
          billingStartPeriod: command.billingStartPeriod,
          billingDayToNext: command.billingDayToNext,
        ),
      );
    });
  }
}

String _profileKeyForKind(CreditLiabilityAccountKind kind) {
  return switch (kind) {
    CreditLiabilityAccountKind.credit => 'credit.credit',
    CreditLiabilityAccountKind.loan => 'credit.loan',
  };
}
