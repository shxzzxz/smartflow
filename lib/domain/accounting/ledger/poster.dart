import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../enums/accounting_enums.dart';
import '../repositories/posting_repository.dart';
import 'ledger_rules.dart';
import 'posting_protocol.dart';

/// 过账执行器：ledger 子模块对内提供的写入入口。
/// 接收 PostTransactionCommand，校验 + 平账 + 委托 PostingRepository 落库。
abstract interface class Poster {
  Future<Result<PostTransactionResult>> post(PostTransactionCommand command);

  Future<Result<List<PostTransactionResult>>> postMutation({
    required List<TransactionStateUpdate> stateUpdates,
    required List<PostTransactionCommand> commands,
  });
}

class PosterImpl implements Poster {
  const PosterImpl(this._repository);

  final PostingRepository _repository;

  @override
  Future<Result<PostTransactionResult>> post(
    PostTransactionCommand command,
  ) async {
    try {
      final mutations = await _validateAndBuildMutations([command]);
      switch (mutations) {
        case FailureResult(:final failure):
          return Result.failure(failure);
        case Success(:final value):
          final result = await _repository.postTransaction(
            command: value.single.command,
            balanceDeltasMinor: value.single.balanceDeltasMinor,
          );
          return Result.success(result);
      }
    } on Object catch (error) {
      return Result.failure(
        Failure(
          code: 'posting_failed',
          message: 'Failed to post transaction.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<List<PostTransactionResult>>> postMutation({
    required List<TransactionStateUpdate> stateUpdates,
    required List<PostTransactionCommand> commands,
  }) async {
    try {
      final mutations = await _validateAndBuildMutations(commands);
      switch (mutations) {
        case FailureResult(:final failure):
          return Result.failure(failure);
        case Success(:final value):
          final result = await _repository.mutateTransactions(
            stateUpdates: stateUpdates,
            posts: value,
          );
          return Result.success(result);
      }
    } on Object catch (error) {
      return Result.failure(
        Failure(
          code: 'posting_mutation_failed',
          message: 'Failed to mutate transactions.',
          cause: error,
        ),
      );
    }
  }

  Future<Result<List<PostTransactionMutation>>> _validateAndBuildMutations(
    List<PostTransactionCommand> commands,
  ) async {
    final mutations = <PostTransactionMutation>[];
    for (final command in commands) {
      final failure = await _validate(command);
      if (failure != null) {
        return Result.failure(failure);
      }

      final accountIds =
          command.entries.map((entry) => entry.accountId).toSet();
      final accounts = await _repository.findAccountsByIds(accountIds);
      final accountsById = {
        for (final account in accounts) account.id: account,
      };

      for (final accountId in accountIds) {
        final account = accountsById[accountId];
        if (account == null) {
          return Result.failure(
            Failure(
              code: 'account_not_found',
              message: 'Account $accountId does not exist.',
            ),
          );
        }
        if (account.archivedAt != null) {
          return Result.failure(
            Failure(
              code: 'account_archived',
              message: 'Account $accountId is archived.',
            ),
          );
        }
        if (account.currencyCode != command.currencyCode) {
          return Result.failure(
            Failure(
              code: 'account_currency_mismatch',
              message:
                  'Account $accountId uses ${account.currencyCode}, '
                  'not ${command.currencyCode}.',
            ),
          );
        }
      }

      final deltas = <int, int>{};
      for (final entry in command.entries) {
        final account = accountsById[entry.accountId]!;
        deltas.update(
          entry.accountId,
          (value) =>
              value +
              balanceDeltaMinor(
                accountType: account.type,
                direction: entry.direction,
                amountMinor: entry.amount.minorUnits,
              ),
          ifAbsent:
              () => balanceDeltaMinor(
                accountType: account.type,
                direction: entry.direction,
                amountMinor: entry.amount.minorUnits,
              ),
        );
      }

      mutations.add(
        PostTransactionMutation(command: command, balanceDeltasMinor: deltas),
      );
    }
    return Result.success(mutations);
  }

  Future<Failure?> _validate(PostTransactionCommand command) async {
    if (command.details.isEmpty) {
      return const Failure(
        code: 'details_required',
        message: 'A transaction must have at least one detail.',
      );
    }
    if (command.entries.length < 2) {
      return const Failure(
        code: 'entries_required',
        message: 'A transaction must have at least two entries.',
      );
    }
    if (!moneyMatchesCurrency(command.primaryAmount, command.currencyCode)) {
      return const Failure(
        code: 'primary_amount_currency_mismatch',
        message: 'Primary amount currency does not match transaction currency.',
      );
    }
    final expectsNegativeDetailAndEntryAmounts =
        command.mutationKind == MutationKind.reversal;
    if ((!expectsNegativeDetailAndEntryAmounts &&
            command.primaryAmount.minorUnits <= 0) ||
        (expectsNegativeDetailAndEntryAmounts &&
            command.primaryAmount.minorUnits == 0)) {
      return const Failure(
        code: 'primary_amount_not_positive',
        message: 'Primary amount has an invalid sign.',
      );
    }

    final reversalFailure = _validateReversalState(command);
    if (reversalFailure != null) {
      return reversalFailure;
    }

    for (final detail in command.details) {
      if (!moneyMatchesCurrency(detail.amount, command.currencyCode)) {
        return const Failure(
          code: 'detail_currency_mismatch',
          message:
              'Detail amount currency does not match transaction currency.',
        );
      }
      if (!_amountSignIsValid(
        amountMinor: detail.amount.minorUnits,
        expectsNegative: expectsNegativeDetailAndEntryAmounts,
      )) {
        return Failure(
          code: 'detail_amount_sign_invalid',
          message:
              'Detail amount must be '
              '${expectsNegativeDetailAndEntryAmounts ? 'negative' : 'positive'}.',
        );
      }
      if (!detailTypeAllowedForPurpose(
        detailType: detail.type,
        businessPurpose: command.businessPurpose,
      )) {
        return Failure(
          code: 'detail_type_not_allowed',
          message:
              '${detail.type.name} is not allowed for '
              '${command.businessPurpose.name}.',
        );
      }
    }
    for (final entry in command.entries) {
      if (!moneyMatchesCurrency(entry.amount, command.currencyCode)) {
        return const Failure(
          code: 'entry_currency_mismatch',
          message: 'Entry amount currency does not match transaction currency.',
        );
      }
      if (!_amountSignIsValid(
        amountMinor: entry.amount.minorUnits,
        expectsNegative: expectsNegativeDetailAndEntryAmounts,
      )) {
        return Failure(
          code: 'entry_amount_sign_invalid',
          message:
              'Entry amount must be '
              '${expectsNegativeDetailAndEntryAmounts ? 'negative' : 'positive'}.',
        );
      }
    }
    if (!entriesAreBalanced(command.entries)) {
      return const Failure(
        code: 'entries_not_balanced',
        message: 'Debit and credit entries must be balanced.',
      );
    }

    return null;
  }

  Failure? _validateReversalState(PostTransactionCommand command) {
    if (command.mutationKind == MutationKind.reversal) {
      if (command.businessState != BusinessState.compensation) {
        return const Failure(
          code: 'reversal_state_invalid',
          message: 'Reversal transactions must be compensation records.',
        );
      }
      if (command.mutationReason == null) {
        return const Failure(
          code: 'reversal_reason_required',
          message: 'Reversal transactions must have a mutation reason.',
        );
      }
      if (command.mutationPreviousTransactionId == null) {
        return const Failure(
          code: 'reversal_previous_transaction_required',
          message:
              'Reversal transactions must reference the transaction being reversed.',
        );
      }
      return null;
    }

    if (command.businessState == BusinessState.compensation) {
      return const Failure(
        code: 'compensation_requires_reversal',
        message: 'Only reversal transactions can be compensation records.',
      );
    }
    if (command.mutationReason != null) {
      return const Failure(
        code: 'mutation_reason_requires_reversal',
        message: 'Mutation reason is only valid for reversal transactions.',
      );
    }

    return null;
  }

  bool _amountSignIsValid({
    required int amountMinor,
    required bool expectsNegative,
  }) {
    return expectsNegative ? amountMinor < 0 : amountMinor > 0;
  }
}
