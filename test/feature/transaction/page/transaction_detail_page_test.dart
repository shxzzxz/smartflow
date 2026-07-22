import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_datetime_picker.dart';
import 'package:smartflow/design_system/widget/app_form_field.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/transaction/page/transaction_detail_page.dart';
import 'package:smartflow/feature/transaction/page/reimbursement_form_page.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  testWidgets('renders detail state and forwards inline edits', (tester) async {
    final update = _FakeTransactionUpdateAppService();
    final editService = _FakeTransactionEditAppService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionDetailProvider(
            'tx-1',
          ).overrideWith((ref) => Stream.value(_detail())),
          accountLookupProvider.overrideWith(
            (ref) => Stream.value(AccountLookup(_accounts)),
          ),
          accountsForSelectionPurposeProvider(
            AccountSelectionPurpose.settlement,
          ).overrideWith(
            (ref) => Stream.value([_accounts['cash']!, _accounts['bank']!]),
          ),
          accountsForSelectionPurposeProvider(
            AccountSelectionPurpose.reimbursementReceivable,
          ).overrideWith((ref) => Stream.value(const <Account>[])),
          transactionUpdateAppServiceProvider.overrideWithValue(update),
          transactionEditAppServiceProvider.overrideWithValue(editService),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const TransactionDetailPage(transactionId: 'tx-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('交易详情'), findsOneWidget);
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('退款'), findsOneWidget);
    expect(find.text('交易时间'), findsOneWidget);
    expect(find.text('入账时间'), findsOneWidget);

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('删除后交易及其账务记录将无法恢复。'), findsOneWidget);
    expect(find.textContaining('冲销记录'), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('点击添加备注'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新的备注');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(update.basicInfoCommands, hasLength(1));
    expect(update.basicInfoCommands.single.transactionId, 'tx-1');
    expect(find.text('备注已更新'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('现金'));
    await tester.pumpAndSettle();
    expect(find.text('选择收支账户'), findsOneWidget);

    await tester.tap(find.text('银行卡'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final command = editService.expenseCommands.single;
    expect(command.transactionId, 'tx-1');
    expect(command.paidFromAccountId, 'bank');
    expect(find.text('收支账户已更新'), findsOneWidget);
  });

  testWidgets('shows refund and reimbursement information together', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionDetailProvider(
            'tx-reimbursement',
          ).overrideWith((ref) => Stream.value(_combinedReimbursementDetail())),
          accountLookupProvider.overrideWith(
            (ref) => Stream.value(AccountLookup(_accounts)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const TransactionDetailPage(transactionId: 'tx-reimbursement'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('退款金额'), findsOneWidget);
    expect(find.text('报销详情'), findsOneWidget);
    expect(find.text('已收 40.00 / 应收 100.00'), findsOneWidget);
  });

  testWidgets('reimbursement date and close switch reset with the form', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/transaction/tx-reimbursement',
      routes: [
        GoRoute(
          path: '/transaction/:id',
          builder:
              (context, state) => TransactionDetailPage(
                transactionId: state.pathParameters['id']!,
              ),
        ),
        GoRoute(
          path: '/transaction/:id/reimbursement',
          builder:
              (context, state) => ReimbursementFormPage(
                advanceTransactionId: state.pathParameters['id']!,
              ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionDetailProvider(
            'tx-reimbursement',
          ).overrideWith((ref) => Stream.value(_reimbursementDetail())),
          accountLookupProvider.overrideWith(
            (ref) => Stream.value(AccountLookup(_accounts)),
          ),
          accountsForSelectionPurposeProvider.overrideWith(
            (ref, purpose) => Stream.value(switch (purpose) {
              AccountSelectionPurpose.settlement => [
                _accounts['cash']!,
                _accounts['bank']!,
              ],
              AccountSelectionPurpose.reimbursementReceivable => [
                _accounts['receivable']!,
              ],
              _ => const <Account>[],
            }),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('报销'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('应收：100'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AppControlledFormField<DateTime>,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AppControlledFormField<bool>,
      ),
      findsOneWidget,
    );
    final accountField = find.byWidgetPredicate(
      (widget) => widget is AppControlledFormField<String>,
    );
    final initialAccountValue =
        tester.state<FormFieldState<String>>(accountField).value;
    expect(initialAccountValue, 'cash');

    final formPage = find.byType(ReimbursementFormPage);
    final formSwitch = find.descendant(
      of: formPage,
      matching: find.byType(Switch),
    );
    final dateText = find.descendant(
      of: formPage,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            RegExp(
              r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$',
            ).hasMatch(widget.data ?? ''),
      ),
    );
    final initialDateText = tester.widget<Text>(dateText).data;

    await tester.tap(formSwitch);
    await tester.pump();
    await tester.tap(find.text('到账时间'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('下个月'));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AppDateTimePickerDialog),
        matching: find.text('1'),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(formSwitch).value, isFalse);
    expect(tester.widget<Text>(dateText).data, isNot(initialDateText));

    tester
        .state<FormState>(
          find.descendant(of: formPage, matching: find.byType(Form)),
        )
        .reset();
    expect(
      tester.state<FormFieldState<String>>(accountField).value,
      initialAccountValue,
    );
    await tester.pump();

    expect(tester.widget<Switch>(formSwitch).value, isTrue);
    expect(tester.widget<Text>(dateText).data, initialDateText);
  });
}

final _accounts = <String, Account>{
  'cash': _account('cash', '现金', iconKey: 'cash'),
  'bank': _account('bank', '银行卡', iconKey: 'account'),
  'receivable': _account('receivable', '报销应收', iconKey: 'wallet'),
  'food': _account('food', '午餐', type: AccountType.expense, iconKey: 'meal'),
};

TransactionDetail _detail() {
  return TransactionDetail(
    transaction: Transaction(
      id: 'tx-1',
      businessPurpose: BusinessPurpose.dailyExpense,
      occurredAt: DateTime(2026, 1, 1, 8),
      primaryAmount: const Money(minorUnits: 10000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
    ),
    createdAt: DateTime(2026, 1, 1, 8, 1),
    details: const [],
    entries: const [
      Entry(
        id: 'entry-cash',
        transactionId: 'tx-1',
        accountId: 'cash',
        direction: EntryDirection.credit,
        amount: Money(minorUnits: 10000),
      ),
      Entry(
        id: 'entry-food',
        transactionId: 'tx-1',
        accountId: 'food',
        direction: EntryDirection.debit,
        amount: Money(minorUnits: 10000),
      ),
    ],
  );
}

TransactionDetail _reimbursementDetail() {
  return TransactionDetail(
    transaction: Transaction(
      id: 'tx-reimbursement',
      businessPurpose: BusinessPurpose.reimbursementAdvance,
      occurredAt: DateTime(2026, 1, 1, 8),
      primaryAmount: const Money(minorUnits: 10000),
      reimbursementExpenseAccountId: 'food',
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
    ),
    createdAt: DateTime(2026, 1, 1, 8, 1),
    details: const [],
    entries: const [
      Entry(
        id: 'entry-cash-reimbursement',
        transactionId: 'tx-reimbursement',
        accountId: 'cash',
        direction: EntryDirection.credit,
        amount: Money(minorUnits: 10000),
      ),
      Entry(
        id: 'entry-receivable',
        transactionId: 'tx-reimbursement',
        accountId: 'receivable',
        direction: EntryDirection.debit,
        amount: Money(minorUnits: 10000),
      ),
    ],
    reimbursementSummary: const ReimbursementSummary(
      advanceAmount: Money(minorUnits: 10000),
      receivedAmount: Money(minorUnits: 0),
      outstanding: Money(minorUnits: 10000),
      isClosed: false,
    ),
  );
}

TransactionDetail _combinedReimbursementDetail() {
  final detail = _reimbursementDetail();
  return TransactionDetail(
    transaction: detail.transaction,
    createdAt: detail.createdAt,
    details: detail.details,
    entries: detail.entries,
    children: [
      TransactionListReadModel(
        id: 'refund',
        parentTransactionId: 'tx-reimbursement',
        businessPurpose: BusinessPurpose.refund,
        occurredAt: DateTime(2026, 1, 2, 8),
        primaryAmount: const Money(minorUnits: 2000),
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        entries: const [],
        details: const [],
      ),
      TransactionListReadModel(
        id: 'receipt',
        parentTransactionId: 'tx-reimbursement',
        businessPurpose: BusinessPurpose.reimbursementReceipt,
        occurredAt: DateTime(2026, 1, 3, 8),
        primaryAmount: const Money(minorUnits: 4000),
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        entries: const [],
        details: const [],
      ),
    ],
    refundedTotal: const Money(minorUnits: 2000),
    reimbursementSummary: const ReimbursementSummary(
      advanceAmount: Money(minorUnits: 10000),
      receivedAmount: Money(minorUnits: 4000),
      outstanding: Money(minorUnits: 4000),
      isClosed: false,
    ),
  );
}

Account _account(
  String id,
  String name, {
  AccountType type = AccountType.asset,
  String? iconKey,
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    iconKey: iconKey,
    balance: const Money(minorUnits: 0),
  );
}

class _FakeTransactionUpdateAppService implements TransactionUpdateAppService {
  final basicInfoCommands = <UpdateTransactionBasicInfoCommand>[];

  @override
  Future<PostedTransactionResult> updateBasicInfo(
    UpdateTransactionBasicInfoCommand command,
  ) async {
    basicInfoCommands.add(command);
    return const PostedTransactionResult(transactionId: 'tx-1');
  }

  @override
  Future<PostedTransactionResult> updateReportingFlag(
    UpdateTransactionReportingFlagCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> updateOwnership(
    UpdateTransactionOwnershipCommand command,
  ) {
    throw UnimplementedError();
  }
}

class _FakeTransactionEditAppService implements TransactionEditAppService {
  final expenseCommands = <EditExpenseCommand>[];

  @override
  Future<PostedTransactionResult> editExpense(
    EditExpenseCommand command,
  ) async {
    expenseCommands.add(command);
    return const PostedTransactionResult(transactionId: 'tx-2');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
