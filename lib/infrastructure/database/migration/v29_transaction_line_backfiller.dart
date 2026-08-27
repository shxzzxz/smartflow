import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/entry.dart';
import 'package:smartflow/domain/ledger/entity/transaction_line.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:uuid/uuid.dart';

import 'transaction_line_migration_error.dart';

/// The immutable v28 snapshot consumed by the v29 converter.
///
/// This type deliberately describes the old database facts rather than the
/// current posting model. Its conversion rules are kept versioned below so
/// future domain posting changes cannot alter an existing migration.
final class V29TransactionSnapshot {
  const V29TransactionSnapshot({
    required this.transactionId,
    required this.businessPurpose,
    required this.primaryAmount,
    required this.reimbursementExpenseAccountId,
    required this.parentBusinessPurpose,
    required this.parentReimbursementExpenseAccountId,
    required this.entries,
    required this.legacyAmounts,
    required this.accountTypes,
    required this.systemAccountIds,
  });

  final String transactionId;
  final BusinessPurpose businessPurpose;
  final Money primaryAmount;
  final String? reimbursementExpenseAccountId;
  final BusinessPurpose? parentBusinessPurpose;
  final String? parentReimbursementExpenseAccountId;
  final List<Entry> entries;
  final Map<String, int> legacyAmounts;
  final Map<String, AccountType> accountTypes;
  final Map<SystemKey, String> systemAccountIds;
}

final class V29TransactionLineBackfill {
  const V29TransactionLineBackfill({
    required this.lines,
    this.primaryAmountCorrectionMinor,
  });

  final List<TransactionLine> lines;
  final int? primaryAmountCorrectionMinor;
}

/// Converts the v28 transaction shape to the v29 transaction-line shape.
///
/// This is a versioned migration snapshot. Do not replace its rules with calls
/// into the current domain posting engine: replay verification must remain
/// stable when the current domain evolves.
final class V29TransactionLineBackfiller {
  V29TransactionLineBackfiller({IdGenerator? idGenerator})
    : _idGenerator = idGenerator ?? _V29MigrationIdGenerator();

  final IdGenerator _idGenerator;

  V29TransactionLineBackfill convert(V29TransactionSnapshot snapshot) {
    final lines = _linesFor(snapshot);
    _verifyPostingReplay(snapshot: snapshot, lines: lines);
    final correction =
        snapshot.businessPurpose == BusinessPurpose.reimbursementClose
        ? (_legacy(snapshot, 'reimbursementCloseMain') +
                  _legacy(snapshot, 'reimbursementGapIncome') -
                  _legacy(snapshot, 'reimbursementGapExpense'))
              .minorUnits
        : null;
    return V29TransactionLineBackfill(
      lines: lines,
      primaryAmountCorrectionMinor: correction,
    );
  }

  List<TransactionLine> _linesFor(V29TransactionSnapshot snapshot) {
    final builder = _V29LineBuilder(
      transactionId: snapshot.transactionId,
      businessPurpose: snapshot.businessPurpose,
      entries: snapshot.entries,
      accountTypes: snapshot.accountTypes,
      idGenerator: _idGenerator,
    );
    Money legacy(String detailType) =>
        Money(minorUnits: snapshot.legacyAmounts[detailType] ?? 0);
    final primaryAmount = snapshot.primaryAmount;

    switch (snapshot.businessPurpose) {
      case BusinessPurpose.dailyExpense:
        builder
          ..add(TransactionRole.category, primaryAmount, builder.onlyDebit())
          ..add(
            TransactionRole.settlementOut,
            primaryAmount,
            builder.onlyCredit(),
          );
      case BusinessPurpose.dailyIncome:
        builder
          ..add(TransactionRole.category, primaryAmount, builder.onlyCredit())
          ..add(
            TransactionRole.settlementIn,
            primaryAmount,
            builder.onlyDebit(),
          );
      case BusinessPurpose.transfer:
        builder
          ..add(
            TransactionRole.settlementOut,
            primaryAmount,
            builder.onlyCredit(),
          )
          ..add(
            TransactionRole.settlementIn,
            primaryAmount,
            builder.debitWhere(typeIsNot: AccountType.expense),
          );
        final fee = legacy('transferFee');
        if (fee.minorUnits > 0) {
          builder.add(TransactionRole.fee, fee, null);
        }
      case BusinessPurpose.refund:
        builder.add(
          TransactionRole.settlementIn,
          primaryAmount,
          builder.onlyDebit(),
        );
        if (snapshot.parentBusinessPurpose ==
            BusinessPurpose.reimbursementAdvance) {
          final accountId = snapshot.parentReimbursementExpenseAccountId;
          if (accountId == null) {
            throw _migrationError(
              snapshot,
              TransactionLineMigrationFailureReason
                  .missingReimbursementExpenseCategory,
            );
          }
          builder
            ..add(
              TransactionRole.reimbursementExpenseCategory,
              primaryAmount,
              accountId,
            )
            ..add(
              TransactionRole.receivable,
              primaryAmount,
              builder.onlyCredit(),
            );
        } else {
          builder.add(
            TransactionRole.refundOffset,
            primaryAmount,
            builder.onlyCredit(),
          );
        }
      case BusinessPurpose.reimbursementAdvance:
        final accountId = snapshot.reimbursementExpenseAccountId;
        if (accountId == null) {
          throw _migrationError(
            snapshot,
            TransactionLineMigrationFailureReason
                .missingReimbursementExpenseCategory,
          );
        }
        builder
          ..add(
            TransactionRole.reimbursementExpenseCategory,
            primaryAmount,
            accountId,
          )
          ..add(TransactionRole.receivable, primaryAmount, builder.onlyDebit())
          ..add(
            TransactionRole.settlementOut,
            primaryAmount,
            builder.onlyCredit(),
          );
      case BusinessPurpose.reimbursementReceipt:
        builder
          ..add(
            TransactionRole.settlementIn,
            primaryAmount,
            builder.onlyDebit(),
          )
          ..add(
            TransactionRole.receivable,
            primaryAmount,
            builder.onlyCredit(),
          );
      case BusinessPurpose.reimbursementClose:
        final outstanding = legacy('reimbursementCloseMain');
        final gapIncome = legacy('reimbursementGapIncome');
        final gapExpense = legacy('reimbursementGapExpense');
        final actual = outstanding + gapIncome - gapExpense;
        // v28 had no cash entry for a zero receipt, so its account is unknown.
        builder.add(
          TransactionRole.settlementIn,
          actual,
          actual.minorUnits > 0
              ? builder.debitWhere(typeIsNot: AccountType.expense)
              : snapshot.systemAccountIds[SystemKey.ghostAccount],
        );
        if (outstanding.minorUnits > 0) {
          builder.add(
            TransactionRole.receivable,
            outstanding,
            builder.creditWhere(typeIs: AccountType.asset),
          );
        }
        if (gapIncome.minorUnits > 0) {
          builder.add(TransactionRole.reimbursementGapIncome, gapIncome, null);
        }
        if (gapExpense.minorUnits > 0) {
          builder.add(
            TransactionRole.reimbursementGapExpense,
            gapExpense,
            builder.debitWhere(typeIs: AccountType.expense),
          );
        }
      case BusinessPurpose.debtRepayment:
        builder.add(
          TransactionRole.liability,
          legacy('repaymentPrincipal'),
          builder.debitWhere(typeIs: AccountType.liability),
        );
        for (final (role, detailType) in const [
          (TransactionRole.interest, 'repaymentInterest'),
          (TransactionRole.fee, 'repaymentFee'),
          (TransactionRole.discount, 'repaymentDiscount'),
        ]) {
          final amount = legacy(detailType);
          if (amount.minorUnits > 0) builder.add(role, amount, null);
        }
        builder.add(
          TransactionRole.settlementOut,
          primaryAmount,
          builder.creditWhere(typeIsNot: AccountType.income),
        );
      case BusinessPurpose.borrowing:
        builder
          ..add(TransactionRole.liability, primaryAmount, builder.onlyCredit())
          ..add(
            TransactionRole.settlementIn,
            primaryAmount,
            builder.onlyDebit(),
          );
      case BusinessPurpose.lending:
        builder
          ..add(TransactionRole.receivable, primaryAmount, builder.onlyDebit())
          ..add(
            TransactionRole.settlementOut,
            primaryAmount,
            builder.onlyCredit(),
          );
      case BusinessPurpose.receivableCollection:
        final interest = legacy('receivableCollectionInterest');
        builder.add(
          TransactionRole.receivable,
          legacy('receivableCollectionPrincipal'),
          builder.creditWhere(typeIs: AccountType.asset),
        );
        if (interest.minorUnits > 0) {
          builder.add(TransactionRole.interest, interest, null);
        }
        builder.add(
          TransactionRole.settlementIn,
          primaryAmount,
          builder.onlyDebit(),
        );
      case BusinessPurpose.badDebt:
        builder.add(
          TransactionRole.receivable,
          primaryAmount,
          builder.onlyCredit(),
        );
      case BusinessPurpose.debtRelief:
        builder.add(
          TransactionRole.liability,
          primaryAmount,
          builder.onlyDebit(),
        );
      case BusinessPurpose.openingBalance:
      case BusinessPurpose.balanceAdjustment:
        final target = builder.entryWhere(typeIsNot: AccountType.equity);
        builder.add(
          snapshot.businessPurpose == BusinessPurpose.openingBalance
              ? TransactionRole.openingBalance
              : TransactionRole.balanceAdjustment,
          Money(
            minorUnits: _balanceDeltaMinor(
              accountType: builder.typeOf(target.accountId),
              direction: target.direction,
              amountMinor: target.amount.minorUnits,
            ),
          ),
          target.accountId,
        );
    }
    return builder.lines;
  }

  void _verifyPostingReplay({
    required V29TransactionSnapshot snapshot,
    required List<TransactionLine> lines,
  }) {
    final replayed = _replayEntries(snapshot: snapshot, lines: lines);
    if (_sameEntries(replayed, snapshot.entries)) return;
    throw _migrationError(
      snapshot,
      TransactionLineMigrationFailureReason.postingReplayMismatch,
      detail:
          'replayed=${_describeEntries(replayed)} '
          'stored=${_describeEntries(snapshot.entries)} '
          'lines=${_describeLines(lines)}',
    );
  }

  List<Entry> _replayEntries({
    required V29TransactionSnapshot snapshot,
    required List<TransactionLine> lines,
  }) {
    final legs = <({String accountId, int signedMinor})>[];
    for (final line in lines) {
      if (line.amount.minorUnits == 0) continue;
      final accountId = _accountFor(snapshot, line);
      if (accountId == null) {
        throw _migrationError(
          snapshot,
          TransactionLineMigrationFailureReason.unexpectedEntryShape,
          detail: 'missing account for ${line.role.name}',
        );
      }
      final signedMinor = _roleAmountIsSigned(line.role)
          ? _signed(
              _directionForBalanceDelta(
                accountType: _accountType(snapshot, accountId),
                deltaMinor: line.amount.minorUnits,
              ),
              line.amount.minorUnits.abs(),
            )
          : switch (_entryDirectionFor(
              businessPurpose: snapshot.businessPurpose,
              role: line.role,
            )) {
              final direction? => _signed(direction, line.amount.minorUnits),
              null => null,
            };
      if (signedMinor != null) {
        legs.add((accountId: accountId, signedMinor: signedMinor));
      }
    }

    final imbalance = legs.fold(0, (sum, leg) => sum + leg.signedMinor);
    if (imbalance != 0) {
      final accountId = _balancingAccountId(snapshot, lines);
      legs.add((accountId: accountId, signedMinor: -imbalance));
    }

    final netByAccount = <String, int>{};
    final accountOrder = <String>[];
    for (final leg in legs) {
      if (!netByAccount.containsKey(leg.accountId)) {
        accountOrder.add(leg.accountId);
      }
      netByAccount[leg.accountId] =
          (netByAccount[leg.accountId] ?? 0) + leg.signedMinor;
    }
    return [
      for (final accountId in accountOrder)
        if (netByAccount[accountId] != 0)
          Entry(
            id: _idGenerator.newId(),
            transactionId: snapshot.transactionId,
            accountId: accountId,
            direction: netByAccount[accountId]! > 0
                ? EntryDirection.debit
                : EntryDirection.credit,
            amount: Money(minorUnits: netByAccount[accountId]!.abs()),
          ),
    ];
  }

  String? _accountFor(V29TransactionSnapshot snapshot, TransactionLine line) {
    if (_roleCarriesAccount(line.role)) return line.accountId;
    return snapshot.systemAccountIds[_systemKeyForRole(
      businessPurpose: snapshot.businessPurpose,
      role: line.role,
    )];
  }

  String _balancingAccountId(
    V29TransactionSnapshot snapshot,
    List<TransactionLine> lines,
  ) {
    final accountId = switch (snapshot.businessPurpose) {
      BusinessPurpose.transfer =>
        lines
            .where((line) => line.role == TransactionRole.settlementOut)
            .firstOrNull
            ?.accountId,
      BusinessPurpose.badDebt =>
        snapshot.systemAccountIds[SystemKey.badDebtExpense],
      BusinessPurpose.debtRelief =>
        snapshot.systemAccountIds[SystemKey.debtReliefIncome],
      BusinessPurpose.openingBalance || BusinessPurpose.balanceAdjustment =>
        snapshot.systemAccountIds[SystemKey.openingBalance],
      _ => null,
    };
    if (accountId == null) {
      throw _migrationError(
        snapshot,
        TransactionLineMigrationFailureReason.unexpectedEntryShape,
        detail: 'no balancing account',
      );
    }
    return accountId;
  }

  AccountType _accountType(V29TransactionSnapshot snapshot, String accountId) {
    final type = snapshot.accountTypes[accountId];
    if (type == null) {
      throw _migrationError(
        snapshot,
        TransactionLineMigrationFailureReason.unknownAccount,
        detail: accountId,
      );
    }
    return type;
  }

  TransactionLineMigrationError _migrationError(
    V29TransactionSnapshot snapshot,
    TransactionLineMigrationFailureReason reason, {
    String? detail,
  }) {
    return TransactionLineMigrationError(
      transactionId: snapshot.transactionId,
      reason: reason,
      businessPurpose: snapshot.businessPurpose.name,
      detail: detail,
    );
  }
}

final class _V29MigrationIdGenerator implements IdGenerator {
  const _V29MigrationIdGenerator();

  static const _uuid = Uuid();

  @override
  String newId() => _uuid.v7();
}

final class _V29LineBuilder {
  _V29LineBuilder({
    required this.transactionId,
    required this.businessPurpose,
    required this.entries,
    required this.accountTypes,
    required this.idGenerator,
  });

  final String transactionId;
  final BusinessPurpose businessPurpose;
  final List<Entry> entries;
  final Map<String, AccountType> accountTypes;
  final IdGenerator idGenerator;
  final lines = <TransactionLine>[];

  void add(TransactionRole role, Money amount, String? accountId) {
    if (_roleCarriesAccount(role) && accountId == null) {
      throw _shapeError('missing account for ${role.name}');
    }
    lines.add(
      TransactionLine(
        id: idGenerator.newId(),
        transactionId: transactionId,
        lineNo: lines.length + 1,
        role: role,
        accountId: _roleCarriesAccount(role) ? accountId : null,
        amount: amount,
      ),
    );
  }

  AccountType typeOf(String accountId) {
    final type = accountTypes[accountId];
    if (type == null) {
      throw TransactionLineMigrationError(
        transactionId: transactionId,
        reason: TransactionLineMigrationFailureReason.unknownAccount,
        businessPurpose: businessPurpose.name,
        detail: accountId,
      );
    }
    return type;
  }

  String onlyDebit() => _matching(EntryDirection.debit, null, null).accountId;

  String onlyCredit() => _matching(EntryDirection.credit, null, null).accountId;

  String debitWhere({AccountType? typeIs, AccountType? typeIsNot}) =>
      _matching(EntryDirection.debit, typeIs, typeIsNot).accountId;

  String creditWhere({AccountType? typeIs, AccountType? typeIsNot}) =>
      _matching(EntryDirection.credit, typeIs, typeIsNot).accountId;

  Entry entryWhere({AccountType? typeIs, AccountType? typeIsNot}) =>
      _matching(null, typeIs, typeIsNot);

  Entry _matching(
    EntryDirection? direction,
    AccountType? typeIs,
    AccountType? typeIsNot,
  ) {
    Entry? found;
    for (final entry in entries) {
      if (direction != null && entry.direction != direction) continue;
      final type = typeOf(entry.accountId);
      if (typeIs != null && type != typeIs) continue;
      if (typeIsNot != null && type == typeIsNot) continue;
      if (found != null) {
        throw _shapeError(
          _describeSelector(direction, typeIs, typeIsNot, 'ambiguous'),
        );
      }
      found = entry;
    }
    if (found == null) {
      throw _shapeError(_describeSelector(direction, typeIs, typeIsNot, 'no'));
    }
    return found;
  }

  String _describeSelector(
    EntryDirection? direction,
    AccountType? typeIs,
    AccountType? typeIsNot,
    String prefix,
  ) {
    return '$prefix ${direction?.name ?? 'entry'} '
        '(typeIs=${typeIs?.name}, typeIsNot=${typeIsNot?.name})';
  }

  TransactionLineMigrationError _shapeError(String detail) {
    return TransactionLineMigrationError(
      transactionId: transactionId,
      reason: TransactionLineMigrationFailureReason.unexpectedEntryShape,
      businessPurpose: businessPurpose.name,
      detail: detail,
    );
  }
}

Money _legacy(V29TransactionSnapshot snapshot, String detailType) =>
    Money(minorUnits: snapshot.legacyAmounts[detailType] ?? 0);

const _ruleAccountRoles = <TransactionRole>{
  TransactionRole.interest,
  TransactionRole.fee,
  TransactionRole.discount,
  TransactionRole.reimbursementGapIncome,
};

bool _roleCarriesAccount(TransactionRole role) =>
    !_ruleAccountRoles.contains(role);

bool _roleAmountIsSigned(TransactionRole role) =>
    role == TransactionRole.openingBalance ||
    role == TransactionRole.balanceAdjustment;

SystemKey? _systemKeyForRole({
  required BusinessPurpose businessPurpose,
  required TransactionRole role,
}) {
  return switch (role) {
    TransactionRole.fee => SystemKey.feeExpense,
    TransactionRole.discount => SystemKey.discountIncome,
    TransactionRole.interest =>
      businessPurpose == BusinessPurpose.debtRepayment
          ? SystemKey.interestExpense
          : SystemKey.interestIncome,
    TransactionRole.reimbursementGapIncome => SystemKey.reimbursementGapIncome,
    _ => null,
  };
}

EntryDirection? _entryDirectionFor({
  required BusinessPurpose businessPurpose,
  required TransactionRole role,
}) {
  return switch (role) {
    TransactionRole.settlementIn => EntryDirection.debit,
    TransactionRole.settlementOut => EntryDirection.credit,
    TransactionRole.refundOffset => EntryDirection.credit,
    TransactionRole.fee => EntryDirection.debit,
    TransactionRole.discount => EntryDirection.credit,
    TransactionRole.reimbursementGapIncome => EntryDirection.credit,
    TransactionRole.reimbursementGapExpense => EntryDirection.debit,
    TransactionRole.category =>
      businessPurpose == BusinessPurpose.dailyExpense
          ? EntryDirection.debit
          : EntryDirection.credit,
    TransactionRole.interest =>
      businessPurpose == BusinessPurpose.debtRepayment
          ? EntryDirection.debit
          : EntryDirection.credit,
    TransactionRole.receivable =>
      businessPurpose == BusinessPurpose.reimbursementAdvance ||
              businessPurpose == BusinessPurpose.lending
          ? EntryDirection.debit
          : EntryDirection.credit,
    TransactionRole.liability =>
      businessPurpose == BusinessPurpose.borrowing
          ? EntryDirection.credit
          : EntryDirection.debit,
    TransactionRole.reimbursementExpenseCategory => null,
    TransactionRole.openingBalance || TransactionRole.balanceAdjustment => null,
  };
}

EntryDirection _directionForBalanceDelta({
  required AccountType accountType,
  required int deltaMinor,
}) {
  final increasesOnDebit =
      accountType == AccountType.asset || accountType == AccountType.expense;
  final increase = deltaMinor > 0;
  if (increasesOnDebit) {
    return increase ? EntryDirection.debit : EntryDirection.credit;
  }
  return increase ? EntryDirection.credit : EntryDirection.debit;
}

int _balanceDeltaMinor({
  required AccountType accountType,
  required EntryDirection direction,
  required int amountMinor,
}) {
  final increasesOnDebit =
      accountType == AccountType.asset || accountType == AccountType.expense;
  if (increasesOnDebit) {
    return direction == EntryDirection.debit ? amountMinor : -amountMinor;
  }
  return direction == EntryDirection.credit ? amountMinor : -amountMinor;
}

int _signed(EntryDirection direction, int amountMinor) =>
    direction == EntryDirection.debit ? amountMinor : -amountMinor;

bool _sameEntries(Iterable<Entry> left, Iterable<Entry> right) {
  final leftShape = left.map(_entryShape).toList()..sort();
  final rightShape = right.map(_entryShape).toList()..sort();
  if (leftShape.length != rightShape.length) return false;
  for (var i = 0; i < leftShape.length; i++) {
    if (leftShape[i] != rightShape[i]) return false;
  }
  return true;
}

String _entryShape(Entry entry) =>
    '${entry.accountId}|${entry.direction.name}|${entry.amount.minorUnits}';

String _describeEntries(List<Entry> entries) {
  final shapes =
      entries
          .map(
            (entry) =>
                '${entry.accountId}:${entry.direction.name}:'
                '${entry.amount.minorUnits}',
          )
          .toList()
        ..sort();
  return shapes.join(',');
}

String _describeLines(List<TransactionLine> lines) => lines
    .map(
      (line) =>
          '${line.role.name}:${line.accountId ?? '-'}:${line.amount.minorUnits}',
    )
    .join(',');
