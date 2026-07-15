// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/account/page/account_bills_page.dart';
import 'package:smartflow/feature/account/page/account_detail_page.dart';
import 'package:smartflow/feature/account/view_model/account_bills_view_model.dart';
import 'package:smartflow/feature/account/view_model/account_detail_view_model.dart';
import 'package:smartflow/feature/account/view_model/account_transactions_view_model.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';
import 'package:smartflow/widget/business/transaction/transaction_row.dart';

void main() {
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
          accountBillsViewModelProvider(account.id).overrideWith(
            (ref) => AccountBillsPageState.loaded(
              bills: [_bill(2026, 7), _bill(2026, 6), _bill(2026, 5)],
              canGenerateHistoricalBill: true,
            ),
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

    expect(find.byType(Dismissible), findsOneWidget);
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
    child: MaterialApp(home: AccountDetailPage(accountId: account.id)),
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

AccountView _account({required AccountProfileKind kind}) {
  return AccountView(
    id: 'account',
    name: '测试账户',
    kind: kind,
    balance: Money.zero(),
    iconKey: kind.iconKey,
    isArchived: false,
    creditLimit:
        kind == AccountProfileKind.credit
            ? const Money(minorUnits: 100000)
            : null,
    billingDay: kind == AccountProfileKind.credit ? 5 : null,
    repaymentDay: kind == AccountProfileKind.credit ? 25 : null,
    billingDayToNext: kind == AccountProfileKind.credit ? true : null,
  );
}
