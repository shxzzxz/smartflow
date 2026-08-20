// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_swipe_action.dart';
import 'package:smartflow/feature/account/page/account_bills_page.dart';
import 'package:smartflow/feature/account/page/account_detail_page.dart';
import 'package:smartflow/feature/account/view_model/account_detail_view_model.dart';
import 'package:smartflow/feature/account/view_model/account_transactions_view_model.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/account/view_model/account_views_provider.dart';
import 'package:smartflow/feature/credit/provider/bill_query_providers.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';
import 'package:smartflow/widget/business/transaction/transaction_row.dart';

void main() {
  testWidgets('shows receivable account actions', (tester) async {
    await tester.pumpWidget(
      _app(account: _account(kind: AccountProfileKind.receivable)),
    );

    expect(find.text('借出'), findsOneWidget);
    expect(find.text('收回'), findsOneWidget);
    expect(find.text('坏账'), findsOneWidget);
    expect(find.text('债务豁免'), findsNothing);
  });

  testWidgets('shows payable account actions', (tester) async {
    await tester.pumpWidget(
      _app(account: _account(kind: AccountProfileKind.payable)),
    );

    expect(find.text('借入'), findsOneWidget);
    expect(find.text('还款'), findsOneWidget);
    expect(find.text('债务豁免'), findsOneWidget);
    expect(find.text('坏账'), findsNothing);
  });

  testWidgets('hides new transaction actions for an archived account', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(account: _account(kind: AccountProfileKind.fund, isArchived: true)),
    );

    expect(find.text('记账'), findsNothing);
    expect(find.text('转账'), findsNothing);
    expect(find.byTooltip('编辑账户'), findsNothing);
    expect(find.byTooltip('归档账户'), findsNothing);
    expect(find.byTooltip('恢复账户'), findsOneWidget);
    expect(find.byTooltip('永久删除账户'), findsOneWidget);

    await tester.tap(find.byTooltip('永久删除账户'));
    await tester.pumpAndSettle();

    expect(find.text('永久删除账户？'), findsOneWidget);
    expect(find.text('账户仅在没有任何业务数据时才能删除。永久删除后无法恢复。'), findsOneWidget);
  });

  testWidgets('archives an account after confirmation', (tester) async {
    final account = _account(kind: AccountProfileKind.fund);
    final detailState = AccountDetailPageState.loaded(
      account: account,
      transactions: const AccountTransactionsState.loaded(
        groups: [],
        hasMore: false,
        isLoadingMore: false,
      ),
      contracts: const AccountContractsState.notApplicable(),
      bills: const AccountBillsState.notApplicable(),
      creditOverview: const AccountCreditOverviewState.notApplicable(),
    );
    final commandService = _FakeAccountAppService();
    final router = GoRouter(
      initialLocation: '/account/account',
      routes: [
        GoRoute(
          path: '/account',
          builder: (context, state) => const Scaffold(body: Text('账户列表')),
        ),
        GoRoute(
          path: '/account/:id',
          builder:
              (context, state) =>
                  AccountDetailPage(accountId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountAppServiceProvider.overrideWithValue(commandService),
          accountDetailViewModelProvider(
            account.id,
          ).overrideWith(() => _FixedAccountDetailViewModel(detailState)),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.byTooltip('归档账户'));
    await tester.pumpAndSettle();
    expect(find.text('归档账户？'), findsOneWidget);
    expect(find.text('归档后账户将不再用于新交易，历史数据会保留且可以恢复。'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '归档'));
    await tester.pumpAndSettle();

    expect(commandService.archiveCommands.single.id, account.id);
    expect(find.text('账户列表'), findsOneWidget);
  });

  testWidgets('shows bill view-all action without historical bill button', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        account: _account(kind: AccountProfileKind.credit),
        bills: [_bill(2026, 7), _bill(2026, 6)],
      ),
    );

    expect(find.text('合同未来欠款'), findsNothing);
    expect(find.text('生成历史账单'), findsNothing);
    expect(find.text('查看全部'), findsOneWidget);
    expect(find.text('2026年07月'), findsOneWidget);
    expect(find.text('2026年06月'), findsOneWidget);
  });

  testWidgets('hides historical bill action when the view model disallows it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(account: _account(kind: AccountProfileKind.fund)),
    );

    expect(find.text('生成历史账单'), findsNothing);
    expect(find.text('查看全部'), findsNothing);
  });

  testWidgets('does not calculate available credit before overview loads', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        account: AccountView(
          id: 'account',
          name: '测试账户',
          kind: AccountProfileKind.credit,
          balance: const Money(minorUnits: 20000),
          iconKey: AccountProfileKind.credit.iconKey,
          isArchived: false,
          creditLimit: const Money(minorUnits: 100000),
          billingDay: 5,
          repaymentDay: 25,
          billingDayToNext: true,
        ),
        creditOverview: const AccountCreditOverviewState.loading(),
      ),
    );

    expect(find.textContaining('800.00'), findsNothing);
  });

  testWidgets('opens the full bill list from the bill section header', (
    tester,
  ) async {
    final account = _account(kind: AccountProfileKind.credit);
    final detailState = AccountDetailPageState.loaded(
      account: account,
      transactions: const AccountTransactionsState.loaded(
        groups: [],
        hasMore: false,
        isLoadingMore: false,
      ),
      contracts: const AccountContractsState.loaded(contracts: []),
      bills: AccountBillsState.loaded(bills: [_bill(2026, 7), _bill(2026, 6)]),
      creditOverview: const AccountCreditOverviewState.notApplicable(),
    );
    final router = GoRouter(
      initialLocation: '/account/account',
      routes: [
        GoRoute(
          path: '/account/:id',
          builder:
              (context, state) =>
                  AccountDetailPage(accountId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/account/:id/bills',
          builder:
              (context, state) =>
                  AccountBillsPage(accountId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountDetailViewModelProvider(
            account.id,
          ).overrideWith(() => _FixedAccountDetailViewModel(detailState)),
          accountViewProvider(
            account.id,
          ).overrideWith((ref) => AsyncValue.data(account)),
          billSummariesByAccountProvider(account.id).overrideWith(
            (ref) async => [_bill(2026, 7), _bill(2026, 6), _bill(2026, 5)],
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('查看全部'));
    await tester.pumpAndSettle();

    expect(find.text('全部账单'), findsOneWidget);
    expect(find.text('2026年05月'), findsOneWidget);
  });

  testWidgets('keeps swipe-to-edit available in account transactions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final account = _account(kind: AccountProfileKind.fund);
    final detailState = AccountDetailPageState.loaded(
      account: account,
      transactions: AccountTransactionsState.loaded(
        groups: [
          TransactionDayGroup(
            date: DateTime(2026, 7, 14),
            rows: const [
              TransactionRowPresentation(
                transactionId: 'tx-1',
                iconKey: null,
                title: '测试交易',
                subtitle: '08:00',
                amountText: '-10.00',
                amountTone: FinanceTone.expense,
                accountFlow: TransactionAccountFlowPresentation(
                  fallbackLabel: '现金',
                ),
                badges: [],
                canQuickEdit: true,
              ),
            ],
            incomeMinor: 0,
            expenseMinor: 1000,
          ),
        ],
        hasMore: false,
        isLoadingMore: false,
      ),
      contracts: const AccountContractsState.notApplicable(),
      bills: const AccountBillsState.notApplicable(),
      creditOverview: const AccountCreditOverviewState.notApplicable(),
    );
    final router = GoRouter(
      initialLocation: '/account/account',
      routes: [
        GoRoute(
          path: '/account/:id',
          builder:
              (context, state) =>
                  AccountDetailPage(accountId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/transaction/:id/edit',
          builder: (context, state) => const Scaffold(body: Text('编辑交易')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountDetailViewModelProvider(
            account.id,
          ).overrideWith(() => _FixedAccountDetailViewModel(detailState)),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    expect(find.byType(AppSwipeAction), findsOneWidget);
    await tester.drag(find.byType(TransactionRow), const Offset(240, 0));
    await tester.pumpAndSettle();

    expect(find.text('编辑交易'), findsOneWidget);
  });
}

Widget _app({
  required AccountView account,
  List<BillSummaryReadModel> bills = const [],
  AccountCreditOverviewState creditOverview =
      const AccountCreditOverviewState.notApplicable(),
}) {
  final state = AccountDetailPageState.loaded(
    account: account,
    transactions: const AccountTransactionsState.loaded(
      groups: [],
      hasMore: false,
      isLoadingMore: false,
    ),
    contracts: const AccountContractsState.loaded(contracts: []),
    bills: AccountBillsState.loaded(bills: bills),
    creditOverview: creditOverview,
  );
  return ProviderScope(
    overrides: [
      accountDetailViewModelProvider(
        account.id,
      ).overrideWith(() => _FixedAccountDetailViewModel(state)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: AccountDetailPage(accountId: account.id),
    ),
  );
}

class _FixedAccountDetailViewModel extends AccountDetailViewModel {
  _FixedAccountDetailViewModel(this.fixedState);

  final AccountDetailPageState fixedState;

  @override
  AccountDetailPageState build(String accountId) => fixedState;

  @override
  void loadMoreTransactions() {}
}

class _FakeAccountAppService implements AccountAppService {
  final archiveCommands = <ArchiveAccountCommand>[];

  @override
  Future<Account> createAccount(CreateAccountCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<void> editAccount(EditAccountCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<void> archiveAccount(ArchiveAccountCommand command) async {
    archiveCommands.add(command);
  }

  @override
  Future<void> restoreAccount(RestoreAccountCommand command) async {}

  @override
  Future<void> deleteAccount(DeleteAccountCommand command) async {}
}

BillSummaryReadModel _bill(int year, int month) {
  return BillSummaryReadModel(
    id: 'bill-$year-$month',
    accountId: 'account',
    period: BillPeriod(year: year, month: month),
    status: BillStatus.billed,
    expectedPrincipal: Money.zero(),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    pendingPrincipal: Money.zero(),
    itemCount: 0,
    overdueItemCount: 0,
  );
}

AccountView _account({
  required AccountProfileKind kind,
  bool isArchived = false,
}) {
  return AccountView(
    id: 'account',
    name: '测试账户',
    kind: kind,
    balance: Money.zero(),
    iconKey: kind.iconKey,
    isArchived: isArchived,
    creditLimit:
        kind == AccountProfileKind.credit
            ? const Money(minorUnits: 100000)
            : null,
    billingDay: kind == AccountProfileKind.credit ? 5 : null,
    repaymentDay: kind == AccountProfileKind.credit ? 25 : null,
    billingDayToNext: kind == AccountProfileKind.credit ? true : null,
  );
}
