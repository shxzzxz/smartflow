import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_page_header.dart';
import 'package:smartflow/feature/account/page/account_reconciliation_page.dart';
import 'package:smartflow/feature/account/view_model/account_reconciliation_view_model.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/feature/shared/view_model/action_guard.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  test('allows an empty expected balance but rejects invalid text', () {
    final account = _account();
    AccountReconciliationLoaded state({
      required String expectedBalanceText,
      required Money? expectedBalance,
    }) {
      return AccountReconciliationLoaded(
        account: account,
        from: DateTime(2026, 7, 1),
        untilInclusive: DateTime(2026, 7, 31),
        expectedBalanceText: expectedBalanceText,
        expectedBalance: expectedBalance,
        groups: const [],
        changedDayCount: 0,
        unconfirmedDayCount: 0,
        submitting: false,
      );
    }

    expect(
      state(expectedBalanceText: '', expectedBalance: null).canConfirm,
      isTrue,
    );
    expect(
      state(expectedBalanceText: '-', expectedBalance: null).canConfirm,
      isFalse,
    );
  });

  test(
    'confirm view model returns success with an injected selection',
    () async {
      final account = _account();
      final appService = _FakeReconciliationAppService();
      final state = AccountReconciliationLoaded(
        account: account,
        from: DateTime(2026, 7, 1),
        untilInclusive: DateTime(2026, 7, 31),
        expectedBalanceText: '100',
        expectedBalance: const Money(minorUnits: 10000),
        groups: const [],
        changedDayCount: 0,
        unconfirmedDayCount: 0,
        submitting: false,
      );
      final container = ProviderContainer(
        overrides: [
          accountReconciliationViewModelProvider(
            account.id,
          ).overrideWith(() => _FixedReconciliationViewModel(state)),
          accountReconciliationSelectionProvider(account.id).overrideWith(
            () => _FixedReconciliationSelection(
              AccountReconciliationSelectionState(
                from: state.from,
                untilInclusive: state.untilInclusive,
                expectedBalanceText: '100',
                submitting: false,
              ),
            ),
          ),
          accountReconciliationAppServiceProvider.overrideWithValue(appService),
        ],
      );
      addTearDown(container.dispose);

      final outcome = await container
          .read(accountReconciliationViewModelProvider(account.id).notifier)
          .confirm();

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(appService.commands, hasLength(1));
    },
  );

  testWidgets('confirms from the page header and shows daily warnings', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appService = _FakeReconciliationAppService();
    final account = _account();
    final router = GoRouter(
      initialLocation: '/account/${account.id}/reconcile',
      routes: [
        GoRoute(
          path: '/account/:id',
          builder: (context, state) => const Scaffold(body: Text('账户详情')),
        ),
        GoRoute(
          path: '/account/:id/reconcile',
          builder: (context, state) =>
              AccountReconciliationPage(accountId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    final state = AccountReconciliationLoaded(
      account: account,
      from: DateTime(2026, 7, 1),
      untilInclusive: DateTime(2026, 7, 31),
      expectedBalanceText: '',
      expectedBalance: const Money(minorUnits: 10000),
      groups: [
        TransactionDayGroup(
          date: DateTime(2026, 7, 31),
          rows: const [],
          incomeMinor: 0,
          expenseMinor: 0,
          closingBalance: const Money(minorUnits: 10000),
          closingBalanceLabel: '期望余额',
          warning: '该日原流水已删除',
        ),
        TransactionDayGroup(
          date: DateTime(2026, 7, 30),
          rows: const [],
          incomeMinor: 0,
          expenseMinor: 0,
          closingBalance: const Money(minorUnits: 10000),
          closingBalanceLabel: '期望余额',
          warning: '该日流水与上次确认时不同',
        ),
      ],
      changedDayCount: 2,
      unconfirmedDayCount: 0,
      submitting: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountReconciliationViewModelProvider(
            account.id,
          ).overrideWith(() => _FixedReconciliationViewModel(state)),
          accountReconciliationSelectionProvider(account.id).overrideWith(
            () => _FixedReconciliationSelection(
              AccountReconciliationSelectionState(
                from: state.from,
                untilInclusive: state.untilInclusive,
                expectedBalanceText: '',
                submitting: false,
              ),
            ),
          ),
          accountReconciliationAppServiceProvider.overrideWithValue(appService),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('账户对账'), findsOneWidget);
    expect(find.text(account.name), findsNothing);
    expect(find.text('期望余额'), findsOneWidget);
    expect(find.text('结束日期望余额'), findsOneWidget);
    expect(find.text('账户流水'), findsNothing);
    expect(
      tester.getTopLeft(find.text('2026.07.01 - 2026.07.31')).dx,
      closeTo(tester.getTopLeft(find.text('结束日期望余额')).dx, 0.5),
    );
    expect(find.textContaining('期望余额'), findsWidgets);
    expect(find.text('该日原流水已删除'), findsWidgets);
    expect(find.text('该日流水与上次确认时不同'), findsWidgets);

    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.widgetWithText(AppHeaderTextButton, '确认'));
    await tester.pumpAndSettle();

    expect(find.text('更新对账快照？'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, '确认'),
      ),
    );
    await tester.pumpAndSettle();

    expect(appService.commands, hasLength(1));
    expect(appService.commands.single.accountId, account.id);
    expect(appService.commands.single.from, DateTime(2026, 7, 1));
    expect(appService.commands.single.untilInclusive, DateTime(2026, 7, 31));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('对账快照已更新'), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/account/account',
    );
    expect(find.text('账户详情'), findsOneWidget);
    expect(find.text('账户对账'), findsNothing);
  });

  testWidgets('keeps header confirmation enabled without an expected balance', (
    tester,
  ) async {
    final account = _account();
    final state = AccountReconciliationLoaded(
      account: account,
      from: DateTime(2026, 7, 1),
      untilInclusive: DateTime(2026, 7, 31),
      expectedBalanceText: '',
      expectedBalance: null,
      groups: const [],
      changedDayCount: 0,
      unconfirmedDayCount: 0,
      submitting: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountReconciliationViewModelProvider(
            account.id,
          ).overrideWith(() => _FixedReconciliationViewModel(state)),
          accountReconciliationSelectionProvider(account.id).overrideWith(
            () => _FixedReconciliationSelection(
              AccountReconciliationSelectionState(
                from: state.from,
                untilInclusive: state.untilInclusive,
                expectedBalanceText: '',
                submitting: false,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: AccountReconciliationPage(accountId: account.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final headerButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byType(AppHeaderTextButton),
        matching: find.byType(TextButton),
      ),
    );
    expect(headerButton.onPressed, isNotNull);
  });
}

class _FixedReconciliationViewModel extends AccountReconciliationViewModel {
  _FixedReconciliationViewModel(this.fixedState);

  final AccountReconciliationPageState fixedState;

  @override
  AccountReconciliationPageState build(String accountId) => fixedState;

  @override
  Future<UiActionOutcome<void>> confirm() {
    return guardUiAction(Logger('test.reconciliation'), 'confirm', () async {
      final state = fixedState as AccountReconciliationLoaded;
      await ref
          .read(accountReconciliationAppServiceProvider)
          .confirm(
            ConfirmAccountReconciliationCommand(
              accountId: state.account.id,
              from: state.from,
              untilInclusive: state.untilInclusive,
            ),
          );
    });
  }
}

class _FixedReconciliationSelection extends AccountReconciliationSelection {
  _FixedReconciliationSelection(this.initialState);

  final AccountReconciliationSelectionState initialState;

  @override
  AccountReconciliationSelectionState build(String accountId) => initialState;
}

class _FakeReconciliationAppService implements AccountReconciliationAppService {
  final commands = <ConfirmAccountReconciliationCommand>[];

  @override
  Future<void> confirm(ConfirmAccountReconciliationCommand command) async {
    commands.add(command);
  }
}

AccountView _account() {
  return AccountView(
    id: 'account',
    name: '测试账户',
    kind: AccountProfileKind.fund,
    balance: Money.zero(),
    iconKey: AccountProfileKind.fund.iconKey,
    isArchived: false,
  );
}
