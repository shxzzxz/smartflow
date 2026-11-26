import '../../../helper/book_selection_override.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/analytics/analytics_command_api.dart';
import 'package:smartflow/feature/account/view_model/asset_views_provider.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/widget/app_form_section.dart';
import 'package:smartflow/design_system/widget/app_page_header.dart';
import 'package:smartflow/feature/account/page/account_form_page.dart';
import 'package:smartflow/feature/account/presentation/account_creation_presets.dart';
import 'package:smartflow/feature/account/view_model/account_form_view_model.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/account/view_model/account_views_provider.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import 'package:smartflow/widget/business/icon/icon_catalog_picker.dart';

void main() {
  testWidgets('keeps the edit header while the account is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._assetViewOverrides(),
          bookSelectionTestOverride,
          bookListTestOverride,
          accountViewProvider(
            'account-1',
          ).overrideWithValue(const AsyncLoading<AccountView?>()),
        ],
        child: const MaterialApp(home: AccountFormPage(accountId: 'account-1')),
      ),
    );
    expect(find.widgetWithText(AppPageHeader, '编辑账户'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows every account profile when creating an account', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._assetViewOverrides(),
          bookSelectionTestOverride,
          bookListTestOverride,
          assetViewAccountAppServiceProvider.overrideWith(
            (ref) => _FakeAssetViewAccountAppService(),
          ),
        ],
        child: const MaterialApp(home: AccountFormPage()),
      ),
    );

    for (final label in ['资金', '报销', '应收', '应付', '信用', '贷款', '预付', '预收']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('name validator blocks account submit', (tester) async {
    final service = _FakeAssetViewAccountAppService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._assetViewOverrides(),
          bookSelectionTestOverride,
          bookListTestOverride,
          assetViewAccountAppServiceProvider.overrideWith((ref) => service),
        ],
        child: const MaterialApp(home: AccountFormPage()),
      ),
    );

    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('请输入账户名称'), findsWidgets);
    expect(service.createCommands, isEmpty);
  });

  testWidgets('prefills a creation preset into the new account form', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        ..._assetViewOverrides(),
        bookSelectionTestOverride,
        bookListTestOverride,
        assetViewAccountAppServiceProvider.overrideWith(
          (ref) => _FakeAssetViewAccountAppService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final preset = accountCreationPresetForId('boc')!;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: AccountFormPage(creationPreset: preset)),
      ),
    );
    await tester.pumpAndSettle();

    final formState = container
        .read(accountFormViewModelProvider(null))
        .requireValue!;
    expect(formState.kind, AccountProfileKind.fund);
    expect(formState.iconKey, 'builtin:account:brand:boc_debit_card');
    expect(formState.groupId, 'builtin-account-group-funds');
    expect(_formTextFields(tester).first.controller!.text, '中国银行');
    expect(
      tester
          .widget<IconCatalogPicker>(find.byType(IconCatalogPicker))
          .selectedRef,
      'builtin:account:brand:boc_debit_card',
    );
  });

  testWidgets('shows built-in group names instead of internal ids', (
    tester,
  ) async {
    final preset = accountCreationPresetForId('prepaid-expense')!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._assetViewOverrides(),
          bookSelectionTestOverride,
          bookListTestOverride,
          assetViewAccountAppServiceProvider.overrideWith(
            (ref) => _FakeAssetViewAccountAppService(),
          ),
        ],
        child: MaterialApp(home: AccountFormPage(creationPreset: preset)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('builtin-account-group-prepaid-expense'), findsNothing);
    expect(find.text('预付'), findsNWidgets(2));
  });

  testWidgets('uses whitespace sections instead of field dividers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._assetViewOverrides(),
          bookSelectionTestOverride,
          bookListTestOverride,
          assetViewAccountAppServiceProvider.overrideWith(
            (ref) => _FakeAssetViewAccountAppService(),
          ),
        ],
        child: const MaterialApp(home: AccountFormPage()),
      ),
    );

    expect(find.byType(AppFormSection), findsAtLeastNWidgets(2));
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('shows billing and repayment days as separate credit fields', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._assetViewOverrides(),
          bookSelectionTestOverride,
          bookListTestOverride,
          assetViewAccountAppServiceProvider.overrideWith(
            (ref) => _FakeAssetViewAccountAppService(),
          ),
        ],
        child: const MaterialApp(home: AccountFormPage()),
      ),
    );

    expect(find.byType(BillingRepaymentDayPlainFields), findsNothing);

    await tester.tap(find.text('信用'));
    await tester.pump();

    expect(find.byType(BillingRepaymentDayPlainFields), findsOneWidget);
    expect(find.text('出账还款日'), findsNothing);
    expect(find.text('出账日'), findsOneWidget);
    expect(find.text('还款日'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BillingRepaymentDayPlainFields),
        matching: find.text('请选择'),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('saves an account immediately after edit data loads', (
    tester,
  ) async {
    final service = _FakeAssetViewAccountAppService();
    final account = AccountView(
      id: 'account-1',
      name: '工资卡',
      kind: AccountProfileKind.fund,
      balance: const Money(minorUnits: 123400),
      iconKey: AccountProfileKind.fund.iconKey,
      isArchived: false,
      note: '主账户',
    );
    final router = GoRouter(
      initialLocation: '/accounts/account-1/edit',
      routes: [
        GoRoute(
          path: '/accounts',
          builder: (context, state) => const Scaffold(body: Text('账户列表')),
          routes: [
            GoRoute(
              path: ':id/edit',
              builder: (context, state) =>
                  const AccountFormPage(accountId: 'account-1'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._assetViewOverrides(),
          bookSelectionTestOverride,
          bookListTestOverride,
          assetViewAccountAppServiceProvider.overrideWithValue(service),
          accountViewProvider(
            'account-1',
          ).overrideWithValue(AsyncValue.data(account)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(find.text('工资卡'), findsOneWidget);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(service.editCommands, hasLength(1));
    expect(service.editCommands.single.account.accountId, 'account-1');
    expect(service.editCommands.single.account.name, '工资卡');
    expect(
      service.editCommands.single.account.targetBalance,
      const Money(minorUnits: 123400),
    );
  });

  testWidgets('shows loading, error, and not-found edit states', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._assetViewOverrides(),
          bookSelectionTestOverride,
          bookListTestOverride,
          accountViewProvider(
            'loading',
          ).overrideWithValue(const AsyncLoading()),
        ],
        child: const MaterialApp(home: AccountFormPage(accountId: 'loading')),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('保存'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._assetViewOverrides(),
          bookSelectionTestOverride,
          bookListTestOverride,
          accountViewProvider('error').overrideWithValue(
            AsyncValue.error(StateError('boom'), StackTrace.empty),
          ),
        ],
        child: const MaterialApp(home: AccountFormPage(accountId: 'error')),
      ),
    );
    expect(find.textContaining('账户加载失败'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._assetViewOverrides(),
          bookSelectionTestOverride,
          bookListTestOverride,
          accountViewProvider(
            'missing',
          ).overrideWithValue(const AsyncData(null)),
        ],
        child: const MaterialApp(home: AccountFormPage(accountId: 'missing')),
      ),
    );
    expect(find.text('账户不存在'), findsOneWidget);
  });

  testWidgets('creates controllers from the loaded account snapshot', (
    tester,
  ) async {
    final account = AccountView(
      id: 'account-1',
      name: '工资卡',
      kind: AccountProfileKind.fund,
      balance: const Money(minorUnits: 123400),
      iconKey: AccountProfileKind.fund.iconKey,
      isArchived: false,
      note: '主账户',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._assetViewOverrides(),
          bookSelectionTestOverride,
          bookListTestOverride,
          accountViewProvider(
            'account-1',
          ).overrideWithValue(AsyncValue.data(account)),
        ],
        child: const MaterialApp(home: AccountFormPage(accountId: 'account-1')),
      ),
    );

    final textFields = _formTextFields(tester);
    expect(textFields.elementAt(0).controller!.text, '工资卡');
    expect(textFields.elementAt(1).controller!.text, '1234.00');
  });

  testWidgets('allows editing a negative current payable amount', (
    tester,
  ) async {
    final account = AccountView(
      id: 'account-1',
      name: '应付账户',
      kind: AccountProfileKind.payable,
      balance: const Money(minorUnits: -12300),
      iconKey: AccountProfileKind.payable.iconKey,
      isArchived: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._assetViewOverrides(),
          bookSelectionTestOverride,
          bookListTestOverride,
          accountViewProvider(
            'account-1',
          ).overrideWithValue(AsyncValue.data(account)),
        ],
        child: const MaterialApp(home: AccountFormPage(accountId: 'account-1')),
      ),
    );
    await tester.pump();

    final amountField = _formTextFields(tester).elementAt(1);
    expect(amountField.controller!.text, '-123.00');

    await tester.enterText(find.byWidget(amountField), '-123.0');
    await tester.pump();

    expect(amountField.controller!.text, '-123.0');
  });

  testWidgets('does not reuse controllers between account ids', (tester) async {
    final accountA = AccountView(
      id: 'account-a',
      name: '账户 A',
      kind: AccountProfileKind.fund,
      balance: const Money(minorUnits: 100),
      iconKey: AccountProfileKind.fund.iconKey,
      isArchived: false,
    );
    final accountB = AccountView(
      id: 'account-b',
      name: '账户 B',
      kind: AccountProfileKind.fund,
      balance: const Money(minorUnits: 200),
      iconKey: AccountProfileKind.fund.iconKey,
      isArchived: false,
    );
    final container = ProviderContainer(
      overrides: [
        ..._assetViewOverrides(),
        bookSelectionTestOverride,
        bookListTestOverride,
        accountViewProvider(
          'account-a',
        ).overrideWithValue(AsyncValue.data(accountA)),
        accountViewProvider(
          'account-b',
        ).overrideWithValue(AsyncValue.data(accountB)),
      ],
    );
    addTearDown(container.dispose);
    var activeId = 'account-a';
    late StateSetter setPage;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setPage = setState;
              return AccountFormPage(accountId: activeId);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byWidget(_formTextFields(tester).first),
      '账户 A 的临时修改',
    );

    setPage(() => activeId = 'account-b');
    await tester.pump();

    expect(_formTextFields(tester).first.controller!.text, '账户 B');
  });

  testWidgets('ViewModel changes do not overwrite edited text', (tester) async {
    final account = AccountView(
      id: 'account-1',
      name: '原始名称',
      kind: AccountProfileKind.fund,
      balance: const Money(minorUnits: 100),
      iconKey: AccountProfileKind.fund.iconKey,
      isArchived: false,
    );
    final container = ProviderContainer(
      overrides: [
        ..._assetViewOverrides(),
        bookSelectionTestOverride,
        bookListTestOverride,
        accountViewProvider(
          'account-1',
        ).overrideWithValue(AsyncValue.data(account)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AccountFormPage(accountId: 'account-1')),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byWidget(_formTextFields(tester).first),
      '用户正在编辑',
    );

    container
        .read(accountFormViewModelProvider('account-1').notifier)
        .setIconKey('another-account-icon');
    await tester.pump();

    expect(_formTextFields(tester).first.controller!.text, '用户正在编辑');
  });
}

List<TextField> _formTextFields(WidgetTester tester) {
  return tester
      .widgetList<TextField>(find.byType(TextField))
      .where((field) => field.controller != null)
      .toList();
}

final _formView = AssetView(
  id: AssetView.defaultId,
  name: AssetView.defaultName,
  accountIds: ['account-1', 'account-a', 'account-b'],
  groups: initialAssetViewGroups(),
);

dynamic _assetViewOverrides() => [
  assetViewsProvider.overrideWithValue(AsyncData([_formView])),
  selectedAssetViewProvider.overrideWithValue(AsyncData(_formView)),
];

class _FakeAssetViewAccountAppService implements AssetViewAccountAppService {
  final createCommands = <CreateAssetViewAccountCommand>[];
  final editCommands = <EditAssetViewAccountCommand>[];
  @override
  Future<String> createAccount(CreateAssetViewAccountCommand command) async {
    createCommands.add(command);
    return 'created';
  }

  @override
  Future<void> editAccount(EditAssetViewAccountCommand command) async {
    editCommands.add(command);
  }
}
