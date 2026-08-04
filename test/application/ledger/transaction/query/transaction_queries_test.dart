import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';

void main() {
  group('resolveCategoryAccountIds', () {
    test('expands and merges multiple semantic category selections', () {
      final accountsById = {
        'food': _account('food', AccountType.expense),
        'dining': _account('dining', AccountType.expense, parentId: 'food'),
        'groceries': _account(
          'groceries',
          AccountType.expense,
          parentId: 'food',
        ),
        'salary': _account('salary', AccountType.income),
      };

      final result = resolveCategoryAccountIds(const [
        CategorySelection.withDescendants('food'),
        CategorySelection.withDescendants('dining'),
        CategorySelection.ownOnly('food'),
        CategorySelection.withDescendants('salary'),
      ], accountsById);

      expect(result, {'food', 'dining', 'groceries', 'salary'});
    });

    test(
      'ignores archived and invalid categories without disabling filter',
      () {
        final accountsById = {
          'archived': _account(
            'archived',
            AccountType.expense,
            archivedAt: DateTime(2026),
          ),
          'cash': _account('cash', AccountType.asset),
        };

        final result = resolveCategoryAccountIds(const [
          CategorySelection.withDescendants('missing'),
          CategorySelection.withDescendants('archived'),
          CategorySelection.withDescendants('cash'),
        ], accountsById);

        expect(result, isEmpty);
      },
    );
  });
}

Account _account(
  String id,
  AccountType type, {
  String? parentId,
  DateTime? archivedAt,
}) {
  return Account(
    id: id,
    name: id,
    type: type,
    parentId: parentId,
    archivedAt: archivedAt,
    balance: Money.zero(),
  );
}
