import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/orchestration_command_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/provider/counterparty_providers.dart';
import 'package:smartflow/feature/shared/provider/tag_providers.dart';
import 'package:smartflow/feature/transaction/page/transaction_form_page.dart';
import 'package:smartflow/feature/transaction/view_model/transaction_form_view_model.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/widget/business/category/category_grid_picker.dart';
import 'package:smartflow/widget/business/transaction/transaction_amount_input.dart';
import '../../../helper/fake_counterparty_repository.dart';
import '../../../helper/sequential_id_generator.dart';

void main() {
  testWidgets('keeps transaction mode tabs at least 48dp tall', (tester) async {
    await _pumpTransactionForm(tester, _FakeTransactionPostingAppService());

    for (final label in const ['支出', '收入', '转账', '借入']) {
      final tab = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(tab).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('uses standardized account roles for borrowing', (tester) async {
    await _pumpTransactionForm(tester, _FakeTransactionPostingAppService());

    await tester.tap(find.text('借入'));
    await tester.pumpAndSettle();

    expect(find.text('负债账户'), findsOneWidget);
    expect(find.text('收款账户'), findsOneWidget);
    expect(find.text('借出账户'), findsNothing);
    expect(find.text('借入账户'), findsNothing);
  });

  testWidgets('renders on a common Android phone with accessibility text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpTransactionForm(
      tester,
      _FakeTransactionPostingAppService(),
      themeMode: ThemeMode.dark,
      textScaler: const TextScaler.linear(2),
    );

    expect(find.byType(TransactionAmountInput), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(TransactionFormPage))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.text('场景'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('app-choice-grid-relations')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('form validator blocks invalid daily expense submit', (
    tester,
  ) async {
    final fakeService = _FakeTransactionPostingAppService();
    await _pumpTransactionForm(tester, fakeService);

    await tester.tap(find.text('完成'));
    await tester.pump();

    expect(find.text('请输入有效金额'), findsOneWidget);
    expect(fakeService.commands, isEmpty);
  });

  testWidgets('submits the latest view-owned amount and note text', (
    tester,
  ) async {
    final fakeService = _FakeTransactionPostingAppService();
    await _pumpTransactionForm(tester, fakeService);

    await tester.tap(find.text('food'));
    await tester.tap(find.text('1'));
    await tester.pump();
    final noteField = find.byWidgetPredicate(
      (widget) => widget is TextField && !widget.readOnly,
    );
    await tester.enterText(noteField, '午餐');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    final command = fakeService.commands.single;
    expect(command.amount, const Money(minorUnits: 100));
    expect(command.note, '午餐');
  });

  testWidgets('uses the shared transaction amount input', (tester) async {
    await _pumpTransactionForm(tester, _FakeTransactionPostingAppService());

    expect(find.byType(TransactionAmountInput), findsOneWidget);
  });

  testWidgets('selects expense scenes and filters advance account profiles', (
    tester,
  ) async {
    await _pumpTransactionForm(
      tester,
      _FakeTransactionPostingAppService(),
      advanceReceivableAccounts: [
        _account('报销A', profileKey: AccountProfileKind.reimbursement.key),
        _account('应收B', profileKey: AccountProfileKind.receivable.key),
      ],
    );

    expect(find.text('再记'), findsNothing);
    await tester.tap(find.text('场景'));
    await tester.pumpAndSettle();

    expect(find.text('选择场景'), findsNothing);
    expect(find.text('普通支出'), findsOneWidget);
    expect(find.text('报销'), findsOneWidget);
    expect(find.text('代付'), findsOneWidget);
    expect(find.text('AA'), findsOneWidget);
    expect(find.text('报销（账户）'), findsOneWidget);
    expect(find.text('AA（账户）'), findsOneWidget);

    await tester.tap(find.text('报销'));
    await tester.pumpAndSettle();
    expect(find.text('不报销'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('advance-account-option')));
    await tester.pumpAndSettle();
    expect(find.text('选择报销账户'), findsOneWidget);
    expect(find.text('报销A'), findsOneWidget);
    expect(find.text('应收B'), findsNothing);

    Navigator.of(tester.element(find.text('选择报销账户'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('场景'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('代付'));
    await tester.pumpAndSettle();
    expect(find.text('不代付'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('advance-account-option')));
    await tester.pumpAndSettle();
    expect(find.text('选择垫付账户'), findsOneWidget);
    expect(find.text('报销A'), findsOneWidget);
    expect(find.text('应收B'), findsOneWidget);
  });

  testWidgets('shows all grouped scene grids from every transaction tab', (
    tester,
  ) async {
    await _pumpTransactionForm(tester, _FakeTransactionPostingAppService());

    const expectedItems = {
      'expense': ['普通支出', 'AA', '报销', '代付', 'AA（账户）', '报销（账户）'],
      'income': ['普通收入'],
      'transfer': ['转账'],
      'relations': ['借入', '借出'],
    };

    for (final tab in ['支出', '收入', '转账', '借入', '借出']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      await tester.tap(find.text('场景'));
      await tester.pumpAndSettle();

      expect(find.text('选择场景'), findsNothing);
      for (final entry in expectedItems.entries) {
        final group = find.byKey(
          ValueKey('app-choice-grid-group-${entry.key}'),
        );
        final grid = find.byKey(ValueKey('app-choice-grid-${entry.key}'));
        expect(group, findsOneWidget);
        expect(grid, findsOneWidget);
        expect(tester.widget(grid), isA<GridView>());
        for (final label in entry.value) {
          expect(
            find.descendant(of: grid, matching: find.text(label)),
            findsOneWidget,
          );
        }
      }

      final groupTops = [
        for (final id in expectedItems.keys)
          tester
              .getTopLeft(find.byKey(ValueKey('app-choice-grid-group-$id')))
              .dy,
      ];
      expect(
        groupTops,
        orderedEquals([...groupTops]..sort()),
        reason: '支出、收入、转账、往来应按顺序纵向排列',
      );

      Navigator.of(
        tester.element(find.byKey(const ValueKey('app-choice-grid-expense'))),
      ).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'switches modes and expense scenes from the grouped scene grids',
    (tester) async {
      await _pumpTransactionForm(
        tester,
        _FakeTransactionPostingAppService(),
        settlementAccounts: const [],
      );

      await tester.tap(find.text('场景'));
      await tester.pumpAndSettle();
      final incomeScene = _sceneItem('income', '普通收入');
      await tester.ensureVisible(incomeScene);
      await tester.tap(incomeScene);
      await tester.pumpAndSettle();
      expect(find.text('收入账户为空'), findsOneWidget);

      await tester.tap(find.text('场景'));
      await tester.pumpAndSettle();
      final borrowingScene = _sceneItem('relations', '借入');
      await tester.ensureVisible(borrowingScene);
      await tester.tap(borrowingScene);
      await tester.pumpAndSettle();
      expect(find.text('负债账户'), findsOneWidget);

      await tester.tap(find.text('场景'));
      await tester.pumpAndSettle();
      final aaScene = _sceneItem('expense', 'AA');
      await tester.ensureVisible(aaScene);
      await tester.tap(aaScene);
      await tester.pumpAndSettle();
      expect(find.text('不AA'), findsOneWidget);
    },
  );

  testWidgets('sets AA headcount from the advance account row', (tester) async {
    await _pumpTransactionForm(
      tester,
      _FakeTransactionPostingAppService(),
      advanceReceivableAccounts: [
        _account('应收A', profileKey: AccountProfileKind.receivable.key),
      ],
    );

    await tester.tap(find.text('场景'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AA'));
    await tester.pumpAndSettle();

    expect(find.text('不AA'), findsOneWidget);
    expect(find.text('2人'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('advance-account-option')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应收A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.tap(find.text('0'));
    await tester.tap(find.text('0'));
    await tester.pumpAndSettle();
    expect(find.text('按 2 人 AA：自承担 150.00，垫付 150.00'), findsOneWidget);
    expect(find.text('垫付金额'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('aa-people-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('aa-people-plus')));
    await tester.tap(find.byKey(const ValueKey('aa-people-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('3人'), findsOneWidget);
    expect(find.text('按 3 人 AA：自承担 100.00，垫付 200.00'), findsOneWidget);
  });

  testWidgets('switches category and account panes to inline allocation mode', (
    tester,
  ) async {
    await _pumpTransactionForm(tester, _FakeTransactionPostingAppService());

    await tester.tap(find.text('分项'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('expense-entry-allocated')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('expense-category-allocations')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('expense-settlement-allocations')),
      findsOneWidget,
    );
    expect(find.text('添加分类'), findsOneWidget);
    expect(find.text('添加账户'), findsOneWidget);
    expect(find.text('多分类'), findsOneWidget);
    expect(find.text('组合支付'), findsOneWidget);
    expect(find.text('分项'), findsOneWidget);
    expect(find.text('普通'), findsNothing);
    expect(
      find.byKey(const ValueKey('expense-primary-account-option')),
      findsNothing,
    );
    final categoryPane = tester.getRect(
      find.byKey(const ValueKey('expense-category-allocations')),
    );
    final accountPane = tester.getRect(
      find.byKey(const ValueKey('expense-settlement-allocations')),
    );
    expect(accountPane.top, greaterThan(categoryPane.bottom));
    expect(find.text('7'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('普通'), matching: find.byType(TextButton)),
      findsNothing,
    );
  });

  testWidgets('supports income category and account allocations', (
    tester,
  ) async {
    await _pumpTransactionForm(
      tester,
      _FakeTransactionPostingAppService(),
      settlementAccounts: [_account('bank'), _account('cash')],
      incomeTree: [
        CategoryNode(account: _category('salary', type: AccountType.income)),
        CategoryNode(account: _category('bonus', type: AccountType.income)),
      ],
    );

    await tester.tap(find.text('收入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('salary'));
    await tester.tap(find.text('分项'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('income-entry-allocated')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('income-category-allocations')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('income-settlement-allocations')),
      findsOneWidget,
    );
    expect(find.text('添加分类'), findsOneWidget);
    expect(find.text('添加收款账户'), findsOneWidget);
    expect(find.text('组合收款'), findsOneWidget);
  });

  testWidgets('shows allocation totals in each card header', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpTransactionForm(
      tester,
      _FakeTransactionPostingAppService(),
      textScaler: const TextScaler.linear(1.3),
    );

    await tester.tap(find.text('food'));
    await tester.tap(find.text('7'));
    await tester.tap(find.text('分项'));
    await tester.pumpAndSettle();

    final categoryCard = find.byKey(
      const ValueKey('expense-category-allocations'),
    );
    final settlementCard = find.byKey(
      const ValueKey('expense-settlement-allocations'),
    );

    _expectAllocationHeaderOrder(
      tester,
      card: categoryCard,
      title: '多分类',
      itemCount: '1项',
      status: '合计 7',
    );
    _expectAllocationHeaderOrder(
      tester,
      card: settlementCard,
      title: '组合支付',
      itemCount: '1项',
      status: '已匹配',
    );
  });

  testWidgets(
    'edits allocation amounts inline and switches each row directly',
    (tester) async {
      await _pumpTransactionForm(
        tester,
        _FakeTransactionPostingAppService(),
        settlementAccounts: [_account('cash'), _account('card')],
        expenseTree: [
          CategoryNode(account: _category('food')),
          CategoryNode(account: _category('drink')),
        ],
      );

      await tester.tap(find.text('food'));
      await tester.tap(find.text('7'));
      await tester.tap(find.text('分项'));
      await tester.pumpAndSettle();

      final categoryAmount = find.descendant(
        of: find.byKey(const ValueKey('allocation-amount-food')),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(categoryAmount, '70');
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.byKey(const ValueKey('allocation-option-food')));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryGridPicker), findsOneWidget);
      await tester.tap(find.text('drink'));
      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('allocation-option-drink')),
        findsOneWidget,
      );
      final switchedCategoryAmount = tester.widget<TextFormField>(
        find.descendant(
          of: find.byKey(const ValueKey('allocation-amount-drink')),
          matching: find.byType(TextFormField),
        ),
      );
      expect(switchedCategoryAmount.controller?.text, '70');
      expect(find.byType(AlertDialog), findsNothing);

      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final accountLabel = find.text('cash');
      await tester.dragUntilVisible(
        accountLabel,
        find.byType(ListView).first,
        const Offset(0, -100),
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -80));
      await tester.pumpAndSettle();
      await tester.tap(accountLabel);
      await tester.pumpAndSettle();
      expect(find.text('选择账户'), findsOneWidget);
      await tester.tap(find.text('card'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('allocation-option-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('expense-primary-account-option')),
        findsNothing,
      );
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('adds category and account rows before entering amounts', (
    tester,
  ) async {
    await _pumpTransactionForm(
      tester,
      _FakeTransactionPostingAppService(),
      settlementAccounts: [_account('cash'), _account('card')],
      expenseTree: [CategoryNode(account: _category('food'))],
    );

    await tester.tap(find.text('分项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加分类'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryGridPicker), findsOneWidget);
    await tester.tap(find.text('food'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();

    final categoryAmount = find.descendant(
      of: find.byKey(const ValueKey('allocation-amount-food')),
      matching: find.byType(TextFormField),
    );
    expect(tester.widget<TextFormField>(categoryAmount).controller?.text, '');
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(categoryAmount, '60');
    await tester.pump();

    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final addAccount = find.text('添加账户');
    await tester.dragUntilVisible(
      addAccount,
      find.byType(ListView).first,
      const Offset(0, -100),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(addAccount);
    await tester.pumpAndSettle();
    await tester.tap(find.text('card'));
    await tester.pumpAndSettle();

    final accountAmount = find.descendant(
      of: find.byKey(const ValueKey('allocation-amount-card')),
      matching: find.byType(TextFormField),
    );
    expect(tester.widget<TextFormField>(accountAmount).controller?.text, '');
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(accountAmount, '40');
    await tester.pump();
    expect(tester.widget<TextFormField>(accountAmount).controller?.text, '40');
  });

  testWidgets('keeps category full width and expense account on option row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpTransactionForm(tester, _FakeTransactionPostingAppService());

    expect(
      tester.getSize(find.byType(CategoryGridPicker)).width,
      greaterThan(300),
    );
    final dateText = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          RegExp(
            r'^(今天|\d{1,2}/\d{1,2}) \d{2}:\d{2}$',
          ).hasMatch(widget.data ?? ''),
    );
    expect(dateText, findsOneWidget);
    expect(find.text('cash'), findsOneWidget);
    expect(
      (tester.getCenter(find.text('cash')).dy - tester.getCenter(dateText).dy)
          .abs(),
      lessThan(8),
    );
  });

  testWidgets(
    'places a direct fee input below transfer accounts without overlapping the amount panel',
    (tester) async {
      // Pin this geometry assertion to the target phone viewport instead of the
      // default 800x600 test view.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpTransactionForm(tester, _FakeTransactionPostingAppService());

      expect(find.byKey(const ValueKey('transfer-fee-input')), findsNothing);

      await tester.tap(find.text('转账'));
      await tester.pumpAndSettle();

      final feeInput = find.byKey(const ValueKey('transfer-fee-input'));
      final toAccountTile = find.byKey(
        const ValueKey('transfer-to-account-tile'),
      );
      final amountInput = find.byType(TransactionAmountInput);

      expect(feeInput, findsOneWidget);
      expect(toAccountTile, findsOneWidget);
      expect(amountInput, findsOneWidget);
      expect(find.text('手续费'), findsOneWidget);
      expect(find.text('转出账户'), findsOneWidget);
      expect(find.text('转入账户'), findsOneWidget);
      expect(
        find.descendant(
          of: feeInput,
          matching: find.byIcon(RemixIcons.swap_box_line),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: feeInput, matching: find.text('0.00')),
        findsOneWidget,
      );
      expect(find.text('0.00（可选）'), findsNothing);
      final feeRect = tester.getRect(feeInput);
      final toAccountRect = tester.getRect(toAccountTile);
      final amountRect = tester.getRect(amountInput);
      expect(feeRect.top, greaterThanOrEqualTo(toAccountRect.bottom));
      expect(feeRect.bottom, lessThanOrEqualTo(amountRect.top));
      expect(
        find.descendant(of: feeInput, matching: find.text('¥')),
        findsNothing,
      );
    },
  );

  testWidgets('places the tag and allocation action above amount options', (
    tester,
  ) async {
    await _pumpTransactionForm(tester, _FakeTransactionPostingAppService());

    final dateText = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          RegExp(
            r'^(今天|\d{1,2}/\d{1,2}) \d{2}:\d{2}$',
          ).hasMatch(widget.data ?? ''),
    );
    expect(dateText, findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('标签')).dy,
      lessThan(tester.getTopLeft(dateText).dy),
    );
    expect(
      tester.getTopLeft(find.text('标签')).dy,
      lessThan(tester.getTopLeft(find.byType(TransactionAmountInput)).dy),
    );
    final actionRow = tester.getRect(
      find.byKey(const ValueKey('transaction-metadata-action-row')),
    );
    final entryMode = tester.getRect(
      find.byKey(const ValueKey('toggle-transaction-entry-mode')),
    );
    expect(actionRow.right - entryMode.right, lessThan(4));
  });

  testWidgets('keeps the tag row above amount for every transaction mode', (
    tester,
  ) async {
    await _pumpTransactionForm(tester, _FakeTransactionPostingAppService());

    for (final mode in const ['支出', '收入', '转账', '借入', '借出']) {
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();
      expect(find.text('标签'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('标签')).dy,
        lessThan(tester.getTopLeft(find.byType(TransactionAmountInput)).dy),
      );
    }
  });

  testWidgets('selects a counterparty to the left of tags', (tester) async {
    await _pumpTransactionForm(
      tester,
      _FakeTransactionPostingAppService(),
      counterparties: const [CounterpartyView(id: 'cp-ziroom', name: '自如')],
    );

    expect(find.text('对手方'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('对手方')).dx,
      lessThan(tester.getTopLeft(find.text('标签')).dx),
    );

    await tester.tap(
      find.byKey(const ValueKey('transaction-counterparty-action')),
    );
    await tester.pumpAndSettle();
    expect(find.text('选择对手方'), findsOneWidget);
    await tester.tap(find.text('自如'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, '自如'), findsOneWidget);
    expect(find.text('对手方'), findsNothing);
  });

  testWidgets('creates and submits a new counterparty', (tester) async {
    final fakeService = _FakeTransactionPostingAppService();
    await _pumpTransactionForm(tester, fakeService);

    await tester.tap(
      find.byKey(const ValueKey('transaction-counterparty-action')),
    );
    await tester.pumpAndSettle();
    final searchField = find.descendant(
      of: find.byKey(const ValueKey('counterparty-search-field')),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, '贝壳');
    await tester.pump();
    await tester.tap(find.text('创建对手方“贝壳”'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, '贝壳'), findsOneWidget);
    await tester.tap(find.text('food'));
    await tester.tap(find.text('1'));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(fakeService.commands.single.counterpartyId, isNotNull);
  });

  testWidgets('renders selected tags as badges that can be edited', (
    tester,
  ) async {
    await _pumpTransactionForm(
      tester,
      _FakeTransactionPostingAppService(),
      tags: const [
        TagView(id: 'tag-1', name: '工作', sortOrder: 0, usageCount: 1),
        TagView(id: 'tag-2', name: '旅行', sortOrder: 1, usageCount: 0),
      ],
    );

    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工作'));
    await tester.tap(find.text('旅行'));
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, '工作'), findsOneWidget);
    expect(find.widgetWithText(Chip, '旅行'), findsOneWidget);
    expect(find.text('工作、旅行'), findsNothing);

    await tester.tap(find.text('工作'));
    await tester.pumpAndSettle();
    expect(find.text('选择标签'), findsOneWidget);
  });

  testWidgets('new form renders while option queries are loading', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.settlement,
        ).overrideWithValue(const AsyncLoading<List<Account>>()),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.fund,
        ).overrideWithValue(const AsyncLoading<List<Account>>()),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.borrowingLiability,
        ).overrideWithValue(const AsyncLoading<List<Account>>()),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.advanceReceivable,
        ).overrideWithValue(const AsyncLoading<List<Account>>()),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.ordinaryReceivable,
        ).overrideWithValue(const AsyncLoading<List<Account>>()),
        categoryTreeProvider(
          AccountType.expense,
        ).overrideWithValue(const AsyncLoading<List<CategoryNode>>()),
        categoryTreeProvider(
          AccountType.income,
        ).overrideWithValue(const AsyncLoading<List<CategoryNode>>()),
        tagListProvider.overrideWithValue(const AsyncLoading<List<TagView>>()),
        counterpartyListProvider.overrideWithValue(
          const AsyncLoading<List<CounterpartyView>>(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TransactionFormPage()),
      ),
    );

    expect(find.byType(TransactionAmountInput), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'shows edit loading, initializes controllers, and preserves edited text',
    (tester) async {
      final details = StreamController<TransactionReadModel?>();
      addTearDown(details.close);
      final accounts = {'cash': _account('cash'), 'food': _category('food')};
      final container = ProviderContainer(
        overrides: [
          ..._editQueryOverrides(accounts),
          transactionDetailProvider(
            'tx-1',
          ).overrideWith((ref) => details.stream),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TransactionFormPage(editTransactionId: 'tx-1'),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      details.add(_transactionDetail('tx-1', note: '原始备注'));
      await tester.pumpAndSettle();

      var input = tester.widget<TransactionAmountInput>(
        find.byType(TransactionAmountInput),
      );
      expect(input.amountController.text, '12.34');
      expect(input.noteController.text, '原始备注');

      input.amountController.text = '99.99';
      input.noteController.text = '用户正在编辑';
      container
          .read(
            transactionFormViewModelProvider(
              editTransactionId: 'tx-1',
            ).notifier,
          )
          .setExcludeStats(true);
      await tester.pump();

      input = tester.widget<TransactionAmountInput>(
        find.byType(TransactionAmountInput),
      );
      expect(input.amountController.text, '99.99');
      expect(input.noteController.text, '用户正在编辑');
    },
  );

  testWidgets('does not reuse controllers between transaction ids', (
    tester,
  ) async {
    final accounts = {'cash': _account('cash'), 'food': _category('food')};
    final container = ProviderContainer(
      overrides: [
        ..._editQueryOverrides(accounts),
        transactionDetailProvider('tx-a').overrideWithValue(
          AsyncData(_transactionDetail('tx-a', note: '交易 A')),
        ),
        transactionDetailProvider('tx-b').overrideWithValue(
          AsyncData(
            _transactionDetail(
              'tx-b',
              amount: const Money(minorUnits: 5678),
              note: '交易 B',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    var activeId = 'tx-a';
    late StateSetter setPage;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setPage = setState;
              return TransactionFormPage(editTransactionId: activeId);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    var input = tester.widget<TransactionAmountInput>(
      find.byType(TransactionAmountInput),
    );
    input.amountController.text = '88.88';
    input.noteController.text = '交易 A 的临时修改';

    setPage(() => activeId = 'tx-b');
    await tester.pump();

    input = tester.widget<TransactionAmountInput>(
      find.byType(TransactionAmountInput),
    );
    expect(input.amountController.text, '56.78');
    expect(input.noteController.text, '交易 B');
  });
}

List<dynamic> _editQueryOverrides(Map<String, Account> accounts) {
  return [
    accountsForSelectionPurposeProvider(
      AccountSelectionPurpose.settlement,
    ).overrideWithValue(AsyncData([accounts['cash']!])),
    accountsForSelectionPurposeProvider(
      AccountSelectionPurpose.fund,
    ).overrideWithValue(const AsyncData(<Account>[])),
    accountsForSelectionPurposeProvider(
      AccountSelectionPurpose.borrowingLiability,
    ).overrideWithValue(const AsyncData(<Account>[])),
    accountsForSelectionPurposeProvider(
      AccountSelectionPurpose.advanceReceivable,
    ).overrideWithValue(const AsyncData(<Account>[])),
    accountsForSelectionPurposeProvider(
      AccountSelectionPurpose.ordinaryReceivable,
    ).overrideWithValue(const AsyncData(<Account>[])),
    categoryTreeProvider(
      AccountType.expense,
    ).overrideWithValue(AsyncData([CategoryNode(account: accounts['food']!)])),
    categoryTreeProvider(
      AccountType.income,
    ).overrideWithValue(const AsyncData(<CategoryNode>[])),
    accountsByIdProvider.overrideWithValue(AsyncData(accounts)),
    tagListProvider.overrideWithValue(const AsyncData(<TagView>[])),
    counterpartyListProvider.overrideWithValue(
      const AsyncData(<CounterpartyView>[]),
    ),
    transactionTagIdsProvider(
      'tx-1',
    ).overrideWithValue(const AsyncData(<String>{})),
    transactionTagIdsProvider(
      'tx-a',
    ).overrideWithValue(const AsyncData(<String>{})),
    transactionTagIdsProvider(
      'tx-b',
    ).overrideWithValue(const AsyncData(<String>{})),
  ];
}

Future<void> _pumpTransactionForm(
  WidgetTester tester,
  _FakeTransactionPostingAppService fakeService, {
  ThemeMode themeMode = ThemeMode.light,
  TextScaler textScaler = TextScaler.noScaling,
  List<TagView> tags = const [],
  List<CounterpartyView> counterparties = const [],
  List<Account>? settlementAccounts,
  List<Account> advanceReceivableAccounts = const [],
  List<CategoryNode>? expenseTree,
  List<CategoryNode>? incomeTree,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TextButton(
            key: const ValueKey('open-transaction-form'),
            onPressed: () => context.push('/form'),
            child: const Text('打开表单'),
          ),
        ),
      ),
      GoRoute(
        path: '/form',
        builder: (context, state) => const TransactionFormPage(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transactionPostingAppServiceProvider.overrideWithValue(fakeService),
        advanceOrchestrationAppServiceProvider.overrideWithValue(
          _FakeExpenseSceneOrchestrationAppService(fakeService),
        ),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.settlement,
        ).overrideWith(
          (ref) => Stream.value(settlementAccounts ?? [_account('cash')]),
        ),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.fund,
        ).overrideWith((ref) => Stream.value(const <Account>[])),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.borrowingLiability,
        ).overrideWith((ref) => Stream.value(const <Account>[])),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.advanceReceivable,
        ).overrideWith((ref) => Stream.value(advanceReceivableAccounts)),
        accountsForSelectionPurposeProvider(
          AccountSelectionPurpose.ordinaryReceivable,
        ).overrideWith((ref) => Stream.value(const <Account>[])),
        categoryTreeProvider(AccountType.expense).overrideWith(
          (ref) => Stream.value(
            expenseTree ?? [CategoryNode(account: _category('food'))],
          ),
        ),
        categoryTreeProvider(AccountType.income).overrideWith(
          (ref) => Stream.value(incomeTree ?? const <CategoryNode>[]),
        ),
        tagListProvider.overrideWith((ref) => Stream.value(tags)),
        counterpartyListProvider.overrideWith(
          (ref) => Stream.value(counterparties),
        ),
        counterpartyApplicationServiceProvider.overrideWithValue(
          CounterpartyApplicationService(
            repository: FakeCounterpartyRepository(counterparties),
            idGenerator: SequentialIdGenerator(prefix: 'cp'),
            transactionRunner: const _DirectTransactionRunner(),
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open-transaction-form')));
  await tester.pumpAndSettle();
}

class _DirectTransactionRunner implements TransactionRunner {
  const _DirectTransactionRunner();

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}

Account _account(String id, {String? profileKey}) {
  return Account(
    id: id,
    name: id,
    type: AccountType.asset,
    subtype: profileKey == null ? null : AccountSubtype.receivable,
    profileKey: profileKey,
    balance: const Money(minorUnits: 0),
  );
}

Account _category(String id, {AccountType type = AccountType.expense}) {
  return Account(
    id: id,
    name: id,
    type: type,
    balance: const Money(minorUnits: 0),
  );
}

Finder _sceneItem(String groupId, String label) {
  return find.descendant(
    of: find.byKey(ValueKey('app-choice-grid-$groupId')),
    matching: find.text(label),
  );
}

TransactionReadModel _transactionDetail(
  String id, {
  Money amount = const Money(minorUnits: 1234),
  String note = 'note',
}) {
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: id,
      businessPurpose: BusinessPurpose.dailyExpense,
      occurredAt: DateTime(2026, 1, 2, 8, 30),
      primaryAmount: amount,
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      note: note,
    ),
    createdAt: DateTime(2026, 1, 2, 8, 30),
    lines: [
      TransactionLine(
        id: '$id-category',
        transactionId: id,
        lineNo: 1,
        role: TransactionRole.category,
        accountId: 'food',
        amount: amount,
      ),
      TransactionLine(
        id: '$id-settlement',
        transactionId: id,
        lineNo: 2,
        role: TransactionRole.settlementOut,
        accountId: 'cash',
        amount: amount,
      ),
    ],
  );
}

void _expectAllocationHeaderOrder(
  WidgetTester tester, {
  required Finder card,
  required String title,
  required String itemCount,
  required String status,
}) {
  final titleCenter = tester.getCenter(
    find.descendant(of: card, matching: find.text(title)),
  );
  final countCenter = tester.getCenter(
    find.descendant(of: card, matching: find.text(itemCount)),
  );
  final statusCenter = tester.getCenter(
    find.descendant(of: card, matching: find.text(status)),
  );

  expect((countCenter.dy - titleCenter.dy).abs(), lessThan(4));
  expect((statusCenter.dy - titleCenter.dy).abs(), lessThan(4));
  expect(countCenter.dx, greaterThan(titleCenter.dx));
  expect(statusCenter.dx, greaterThan(countCenter.dx));
}

class _FakeTransactionPostingAppService
    implements TransactionPostingAppService {
  final commands = <CreateExpenseCommand>[];

  @override
  Future<PostedTransactionResult> createExpense(
    CreateExpenseCommand command,
  ) async {
    commands.add(command);
    return const PostedTransactionResult(transactionId: 'transaction-1');
  }

  @override
  Future<PostedTransactionResult> adjustBalance(AdjustBalanceCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> settleAdvance(
    CreateAdvanceSettlementCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createBorrowing(
    CreateBorrowingCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createIncome(CreateIncomeCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createOpeningBalance(
    CreateOpeningBalanceCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createRefund(CreateRefundCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createAdvance(CreateAdvanceCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createAdvanceCollection(
    CreateAdvanceCollectionCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createRepayment(
    CreateRepaymentCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PostedTransactionResult> createTransfer(
    CreateTransferCommand command,
  ) {
    throw UnimplementedError();
  }
}

class _FakeExpenseSceneOrchestrationAppService
    implements AdvanceOrchestrationAppService {
  const _FakeExpenseSceneOrchestrationAppService(this.posting);

  final _FakeTransactionPostingAppService posting;

  @override
  Future<String> createExpenseScene(
    CreateExpenseSceneWorkflowCommand command,
  ) async {
    if (command.target is! OrdinaryExpenseSceneTarget) {
      throw UnimplementedError('advance submission is not used in this test');
    }
    final result = await posting.createExpense(
      CreateExpenseCommand(
        amount: command.amount,
        categoryAllocations: command.categoryAllocations,
        settlementAllocations: command.settlementAllocations,
        occurredAt: command.occurredAt,
        postedAt: command.postedAt,
        counterpartyId: command.counterpartyId,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
        sourceKind: command.sourceKind,
        tagIds: command.tagIds,
      ),
    );
    return result.transactionId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
