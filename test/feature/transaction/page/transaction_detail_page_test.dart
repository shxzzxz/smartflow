import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_form_section.dart';
import 'package:smartflow/design_system/widget/app_datetime_picker.dart';
import 'package:smartflow/design_system/widget/app_form_field.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/provider/tag_providers.dart';
import 'package:smartflow/feature/transaction/page/transaction_detail_page.dart';
import 'package:smartflow/feature/transaction/page/reimbursement_form_page.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';

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
          accountQueryServiceProvider.overrideWith(
            (ref) => _FakeAccountQueryService([
              _accounts['cash']!,
              _accounts['bank']!,
            ]),
          ),
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

  testWidgets('shows the transfer fee in transaction details', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionDetailProvider(
            'transfer',
          ).overrideWith((ref) => Stream.value(_transferDetail())),
          accountLookupProvider.overrideWith(
            (ref) => Stream.value(AccountLookup(_accounts)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const TransactionDetailPage(transactionId: 'transfer'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('手续费'), findsOneWidget);
    expect(find.text('3.00'), findsOneWidget);
  });

  testWidgets(
    'shows category and account breakdowns as compact rows above tags',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/transaction/tx-multi',
        routes: [
          GoRoute(
            path: '/transaction/:id',
            builder: (context, state) => TransactionDetailPage(
              transactionId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/transaction/:id/edit',
            builder: (context, state) => const Scaffold(body: Text('交易编辑页')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionDetailProvider(
              'tx-multi',
            ).overrideWith((ref) => Stream.value(_multiDetail())),
            accountLookupProvider.overrideWith(
              (ref) => Stream.value(AccountLookup(_accounts)),
            ),
            accountQueryServiceProvider.overrideWith(
              (ref) => _FakeAccountQueryService([
                _accounts['cash']!,
                _accounts['bank']!,
              ]),
            ),
            tagListProvider.overrideWithValue(const AsyncData([])),
            transactionTagIdsProvider(
              'tx-multi',
            ).overrideWithValue(const AsyncData({})),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final categoryCard = find.byKey(const ValueKey('detail-category-card'));
      expect(categoryCard, findsOneWidget);
      expect(
        find.descendant(of: categoryCard, matching: find.text('多分类')),
        findsOneWidget,
      );
      final heroIcon = tester.widget<BusinessIcon>(
        find.descendant(of: categoryCard, matching: find.byType(BusinessIcon)),
      );
      expect(resolveBusinessIconSpec(heroIcon.iconKey).iconKey, 'more-line');
      expect(find.text('分类构成'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('detail-allocation-card')),
          matching: find.text('午餐'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('detail-allocation-card')),
          matching: find.text('交通'),
        ),
        findsOneWidget,
      );
      expect(find.text('账户构成'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('detail-allocation-card')),
          matching: find.text('现金'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('detail-allocation-card')),
          matching: find.text('银行卡'),
        ),
        findsOneWidget,
      );
      expect(find.text('收支账户'), findsNothing);
      final detailList = tester.widget<ListView>(find.byType(ListView).first);
      final detailChildren =
          (detailList.childrenDelegate as SliverChildListDelegate).children;
      final allocationIndex = detailChildren.indexWhere(
        (child) => child.key == const ValueKey('detail-allocation-card'),
      );
      final tagIndex = detailChildren.indexWhere(
        (child) => child.key == const ValueKey('detail-tag-card'),
      );
      expect(allocationIndex, greaterThanOrEqualTo(0));
      expect(tagIndex, allocationIndex + 2);

      await tester.tap(
        find.byKey(const ValueKey('detail-allocation-row-category')),
      );
      await tester.pumpAndSettle();

      var sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('午餐')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('交通')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('60.00')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('40.00')),
        findsOneWidget,
      );
      await tester.tap(find.byType(ModalBarrier).last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('detail-allocation-row-account')),
      );
      await tester.pumpAndSettle();

      sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('现金')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('银行卡')),
        findsOneWidget,
      );
      await tester.tap(find.byType(ModalBarrier).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      expect(find.text('交易编辑页'), findsOneWidget);
    },
  );

  testWidgets('shows icons only when a breakdown has three items', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionDetailProvider(
            'tx-many',
          ).overrideWith((ref) => Stream.value(_multiDetail(many: true))),
          accountLookupProvider.overrideWith(
            (ref) => Stream.value(AccountLookup(_accounts)),
          ),
          tagListProvider.overrideWithValue(const AsyncData([])),
          transactionTagIdsProvider(
            'tx-many',
          ).overrideWithValue(const AsyncData({})),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const TransactionDetailPage(transactionId: 'tx-many'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final categoryRow = find.byKey(
      const ValueKey('detail-allocation-row-category'),
    );
    final accountRow = find.byKey(
      const ValueKey('detail-allocation-row-account'),
    );
    expect(
      find.descendant(of: categoryRow, matching: find.byType(BusinessIcon)),
      findsNWidgets(3),
    );
    expect(
      find.descendant(of: accountRow, matching: find.byType(BusinessIcon)),
      findsNWidgets(3),
    );
    expect(
      find.descendant(of: categoryRow, matching: find.text('午餐')),
      findsNothing,
    );
    expect(
      find.descendant(of: categoryRow, matching: find.text('交通')),
      findsNothing,
    );
    expect(
      find.descendant(of: categoryRow, matching: find.text('购物')),
      findsNothing,
    );
    expect(
      find.descendant(of: accountRow, matching: find.text('现金')),
      findsNothing,
    );
    expect(
      find.descendant(of: accountRow, matching: find.text('银行卡')),
      findsNothing,
    );
    expect(
      find.descendant(of: accountRow, matching: find.text('信用卡')),
      findsNothing,
    );

    await tester.tap(categoryRow);
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('午餐')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('交通')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('购物')),
      findsOneWidget,
    );
  });

  testWidgets('edits transaction tags from the detail tag row', (tester) async {
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
          tagListProvider.overrideWithValue(
            const AsyncData([
              TagView(id: 'tag-1', name: '工作', sortOrder: 0, usageCount: 1),
              TagView(id: 'tag-2', name: '旅行', sortOrder: 1, usageCount: 0),
            ]),
          ),
          transactionTagIdsProvider(
            'tx-1',
          ).overrideWithValue(const AsyncData({'tag-1'})),
          transactionUpdateAppServiceProvider.overrideWithValue(
            _FakeTransactionUpdateAppService(),
          ),
          transactionEditAppServiceProvider.overrideWithValue(editService),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const TransactionDetailPage(transactionId: 'tx-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, '工作'), findsOneWidget);
    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    expect(find.text('选择标签'), findsOneWidget);

    await tester.tap(find.text('旅行'));
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();

    expect(editService.expenseCommands.single.tagIds, {'tag-1', 'tag-2'});
    expect(find.text('标签已更新'), findsOneWidget);
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
          builder: (context, state) =>
              TransactionDetailPage(transactionId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/transaction/:id/reimbursement',
          builder: (context, state) => ReimbursementFormPage(
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
    final settlementCard = find.byKey(
      const ValueKey('reimbursement-settlement-allocations'),
    );
    expect(settlementCard, findsOneWidget);
    expect(
      find.descendant(of: settlementCard, matching: find.text('现金')),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: settlementCard, matching: find.byType(AppFormSection)),
      findsNothing,
    );

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
    await tester.pump();

    expect(tester.widget<Switch>(formSwitch).value, isTrue);
    expect(tester.widget<Text>(dateText).data, initialDateText);
  });
}

class _FakeAccountQueryService implements AccountQueryService {
  _FakeAccountQueryService(this._accounts);

  final List<Account> _accounts;

  @override
  Future<List<Account>> findAccounts(Set<AccountType> types) async {
    return _accounts;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final _accounts = <String, Account>{
  'cash': _account('cash', '现金', iconKey: 'cash'),
  'bank': _account('bank', '银行卡', iconKey: 'account'),
  'receivable': _account(
    'receivable',
    '报销应收',
    subtype: AccountSubtype.receivable,
    profileKey: 'ledger.reimbursement',
    iconKey: 'wallet',
  ),
  'food': _account('food', '午餐', type: AccountType.expense, iconKey: 'meal'),
  'travel': _account(
    'travel',
    '交通',
    type: AccountType.expense,
    iconKey: 'taxi',
  ),
  'shopping': _account(
    'shopping',
    '购物',
    type: AccountType.expense,
    iconKey: 'shopping-bag',
  ),
  'credit-card': _account(
    'credit-card',
    '信用卡',
    type: AccountType.liability,
    iconKey: 'credit-card',
  ),
};

TransactionReadModel _detail() {
  return TransactionReadModel.fromTransaction(
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
    lines: const [
      TransactionLine(
        id: 'category',
        transactionId: 'tx-1',
        lineNo: 1,
        role: TransactionRole.category,
        accountId: 'food',
        amount: Money(minorUnits: 10000),
      ),
      TransactionLine(
        id: 'settlement',
        transactionId: 'tx-1',
        lineNo: 2,
        role: TransactionRole.settlementOut,
        accountId: 'cash',
        amount: Money(minorUnits: 10000),
      ),
    ],
  );
}

TransactionReadModel _transferDetail() {
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'transfer',
      businessPurpose: BusinessPurpose.transfer,
      occurredAt: DateTime(2026, 1, 1, 8),
      primaryAmount: const Money(minorUnits: 2000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
    ),
    createdAt: DateTime(2026, 1, 1, 8, 1),
    lines: const [
      TransactionLine(
        id: 'transfer-out',
        transactionId: 'transfer',
        lineNo: 1,
        role: TransactionRole.settlementOut,
        accountId: 'cash',
        amount: Money(minorUnits: 2000),
      ),
      TransactionLine(
        id: 'transfer-in',
        transactionId: 'transfer',
        lineNo: 2,
        role: TransactionRole.settlementIn,
        accountId: 'bank',
        amount: Money(minorUnits: 2000),
      ),
      TransactionLine(
        id: 'transfer-fee',
        transactionId: 'transfer',
        lineNo: 3,
        role: TransactionRole.fee,
        amount: Money(minorUnits: 300),
      ),
    ],
  );
}

TransactionReadModel _multiDetail({bool many = false}) {
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: many ? 'tx-many' : 'tx-multi',
      businessPurpose: BusinessPurpose.dailyExpense,
      occurredAt: DateTime(2026, 1, 1, 8),
      primaryAmount: const Money(minorUnits: 10000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
    ),
    createdAt: DateTime(2026, 1, 1, 8, 1),
    lines: many
        ? const [
            TransactionLine(
              id: 'food-line',
              transactionId: 'tx-many',
              lineNo: 1,
              role: TransactionRole.category,
              accountId: 'food',
              amount: Money(minorUnits: 5000),
            ),
            TransactionLine(
              id: 'travel-line',
              transactionId: 'tx-many',
              lineNo: 2,
              role: TransactionRole.category,
              accountId: 'travel',
              amount: Money(minorUnits: 3000),
            ),
            TransactionLine(
              id: 'shopping-line',
              transactionId: 'tx-many',
              lineNo: 3,
              role: TransactionRole.category,
              accountId: 'shopping',
              amount: Money(minorUnits: 2000),
            ),
            TransactionLine(
              id: 'cash-line',
              transactionId: 'tx-many',
              lineNo: 4,
              role: TransactionRole.settlementOut,
              accountId: 'cash',
              amount: Money(minorUnits: 5000),
            ),
            TransactionLine(
              id: 'bank-line',
              transactionId: 'tx-many',
              lineNo: 5,
              role: TransactionRole.settlementOut,
              accountId: 'bank',
              amount: Money(minorUnits: 3000),
            ),
            TransactionLine(
              id: 'credit-card-line',
              transactionId: 'tx-many',
              lineNo: 6,
              role: TransactionRole.settlementOut,
              accountId: 'credit-card',
              amount: Money(minorUnits: 2000),
            ),
          ]
        : const [
            TransactionLine(
              id: 'food-line',
              transactionId: 'tx-multi',
              lineNo: 1,
              role: TransactionRole.category,
              accountId: 'food',
              amount: Money(minorUnits: 6000),
            ),
            TransactionLine(
              id: 'travel-line',
              transactionId: 'tx-multi',
              lineNo: 2,
              role: TransactionRole.category,
              accountId: 'travel',
              amount: Money(minorUnits: 4000),
            ),
            TransactionLine(
              id: 'cash-line',
              transactionId: 'tx-multi',
              lineNo: 3,
              role: TransactionRole.settlementOut,
              accountId: 'cash',
              amount: Money(minorUnits: 6000),
            ),
            TransactionLine(
              id: 'bank-line',
              transactionId: 'tx-multi',
              lineNo: 4,
              role: TransactionRole.settlementOut,
              accountId: 'bank',
              amount: Money(minorUnits: 4000),
            ),
          ],
  );
}

TransactionReadModel _reimbursementDetail() {
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'tx-reimbursement',
      businessPurpose: BusinessPurpose.reimbursementAdvance,
      occurredAt: DateTime(2026, 1, 1, 8),
      primaryAmount: const Money(minorUnits: 10000),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      lines: _reimbursementLines,
    ),
    createdAt: DateTime(2026, 1, 1, 8, 1),
    lines: _reimbursementLines,
  );
}

TransactionReadModel _combinedReimbursementDetail() {
  final detail = _reimbursementDetail();
  return detail.copyWith(
    children: [
      TransactionReadModel(
        id: 'refund',
        parentTransactionId: detail.id,
        businessPurpose: BusinessPurpose.refund,
        occurredAt: DateTime(2026, 1, 2, 8),
        primaryAmount: const Money(minorUnits: 2000),
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        impactsByAccountId: const {},
      ),
      TransactionReadModel(
        id: 'receipt',
        parentTransactionId: detail.id,
        businessPurpose: BusinessPurpose.reimbursementReceipt,
        occurredAt: DateTime(2026, 1, 3, 8),
        primaryAmount: const Money(minorUnits: 4000),
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        impactsByAccountId: const {},
      ),
    ],
  );
}

Account _account(
  String id,
  String name, {
  AccountType type = AccountType.asset,
  AccountSubtype? subtype,
  String? profileKey,
  String? iconKey,
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    subtype:
        subtype ?? (type == AccountType.asset ? AccountSubtype.fund : null),
    profileKey:
        profileKey ?? (type == AccountType.asset ? 'ledger.fund' : null),
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

const _reimbursementLines = [
  TransactionLine(
    id: 'advance-category',
    transactionId: 'tx-reimbursement',
    lineNo: 1,
    role: TransactionRole.reimbursementExpenseCategory,
    accountId: 'food',
    amount: Money(minorUnits: 10000),
  ),
  TransactionLine(
    id: 'advance-out',
    transactionId: 'tx-reimbursement',
    lineNo: 2,
    role: TransactionRole.settlementOut,
    accountId: 'cash',
    amount: Money(minorUnits: 10000),
  ),
  TransactionLine(
    id: 'advance-receivable',
    transactionId: 'tx-reimbursement',
    lineNo: 3,
    role: TransactionRole.receivable,
    accountId: 'receivable',
    amount: Money(minorUnits: 10000),
  ),
];
