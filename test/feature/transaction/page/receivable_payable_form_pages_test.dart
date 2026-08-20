import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/transaction/page/receivable_payable_form_pages.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  testWidgets('collection confirms a negative receivable balance', (
    tester,
  ) async {
    final posting = _FakePostingService();
    final receivable = _account(
      'receivable',
      AccountSubtype.receivable,
      balance: Money.parse('100'),
    );
    final fund = _account('fund', AccountSubtype.fund);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('交易列表')),
        ),
        GoRoute(
          path: '/collection',
          builder:
              (context, state) => const ReceivableCollectionFormPage(
                receivableAccountId: 'receivable',
              ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountQueryServiceProvider.overrideWithValue(
            _FakeAccountQueryService(receivable),
          ),
          accountsForSelectionPurposeProvider(
            AccountSelectionPurpose.fund,
          ).overrideWith((ref) => Stream.value([fund])),
          accountsByIdProvider.overrideWithValue(
            AsyncData({'receivable': receivable, 'fund': fund}),
          ),
          transactionPostingAppServiceProvider.overrideWithValue(posting),
          transactionEditAppServiceProvider.overrideWithValue(
            _FakeEditService(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/collection');
    await tester.pumpAndSettle();

    expect(find.text('交易日期'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '150');

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('收回将超过当前应收'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(posting.collectionCommands, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '继续提交'));
    await tester.pumpAndSettle();

    expect(posting.collectionCommands, hasLength(1));
    expect(posting.collectionCommands.single.principal, Money.parse('150'));
    expect(find.text('交易列表'), findsOneWidget);
  });

  testWidgets('bad debt and debt relief expose editable transaction dates', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsByIdProvider.overrideWithValue(
            AsyncData({
              'receivable': _account('receivable', AccountSubtype.receivable),
            }),
          ),
        ],
        child: MaterialApp(
          home: const BadDebtFormPage(receivableAccountId: 'receivable'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('交易日期'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsByIdProvider.overrideWithValue(
            AsyncData({'payable': _account('payable', AccountSubtype.payable)}),
          ),
        ],
        child: MaterialApp(
          home: const DebtReliefFormPage(liabilityAccountId: 'payable'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('交易日期'), findsOneWidget);
  });
}

Account _account(
  String id,
  AccountSubtype subtype, {
  Money balance = const Money(minorUnits: 0),
}) => Account(
  id: id,
  name: id,
  type:
      subtype == AccountSubtype.fund || subtype == AccountSubtype.receivable
          ? AccountType.asset
          : AccountType.liability,
  subtype: subtype,
  balance: balance,
);

class _FakeAccountQueryService implements AccountQueryService {
  const _FakeAccountQueryService(this.account);

  final Account account;

  @override
  Future<Account?> findAccountById(String id) async =>
      id == account.id ? account : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePostingService
    implements
        TransactionPostingAppService,
        ReceivableTransactionPostingAppService {
  final collectionCommands = <CreateReceivableCollectionCommand>[];

  @override
  Future<PostedTransactionResult> createReceivableCollection(
    CreateReceivableCollectionCommand command,
  ) async {
    collectionCommands.add(command);
    return const PostedTransactionResult(transactionId: 'collection');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEditService
    implements TransactionEditAppService, ReceivableTransactionEditAppService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
