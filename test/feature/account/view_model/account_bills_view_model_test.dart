// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/account/view_model/account_bills_view_model.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/account/view_model/account_views_provider.dart';
import 'package:smartflow/feature/credit/provider/bill_query_providers.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  test('allows historical generation for an active credit account', () async {
    final container = _container(_account(isArchived: false));
    final sub = container.listen(
      accountBillsViewModelProvider('card'),
      (_, _) {},
    );
    addTearDown(sub.close);

    await container.read(billSummariesByAccountProvider('card').future);
    await container.pump();
    await _flush();

    final state = container.read(accountBillsViewModelProvider('card'));
    expect(state, isA<AccountBillsPageLoaded>());
    expect((state as AccountBillsPageLoaded).canGenerateHistoricalBill, isTrue);
  });

  test(
    'disallows historical generation for an archived credit account',
    () async {
      final container = _container(_account(isArchived: true));
      final sub = container.listen(
        accountBillsViewModelProvider('card'),
        (_, _) {},
      );
      addTearDown(sub.close);

      await container.read(billSummariesByAccountProvider('card').future);
      await container.pump();
      await _flush();

      final state = container.read(accountBillsViewModelProvider('card'));
      expect(state, isA<AccountBillsPageLoaded>());
      expect(
        (state as AccountBillsPageLoaded).canGenerateHistoricalBill,
        isFalse,
      );
    },
  );
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

ProviderContainer _container(AccountView account) {
  final container = ProviderContainer(
    overrides: [
      accountViewProvider(
        'card',
      ).overrideWith((ref) => AsyncValue.data(account)),
      billSummariesByAccountProvider(
        'card',
      ).overrideWith((ref) async => const []),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

AccountView _account({required bool isArchived}) {
  return AccountView(
    id: 'card',
    name: '信用卡',
    kind: AccountProfileKind.credit,
    balance: Money.zero(),
    iconKey: 'card',
    isArchived: isArchived,
  );
}
