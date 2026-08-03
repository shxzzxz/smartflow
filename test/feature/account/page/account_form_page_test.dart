import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/widget/app_form_section.dart';
import 'package:smartflow/feature/account/page/account_form_page.dart';
import 'package:smartflow/feature/account/view_model/account_form_view_model.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/account/view_model/account_views_provider.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  testWidgets('name validator blocks account submit', (tester) async {
    final service = _FakeAccountAppService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountAppServiceProvider.overrideWith((ref) => service)],
        child: const MaterialApp(home: AccountFormPage()),
      ),
    );

    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('请输入账户名称'), findsWidgets);
    expect(service.createCommands, isEmpty);
  });

  testWidgets('uses whitespace sections instead of field dividers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountAppServiceProvider.overrideWith(
            (ref) => _FakeAccountAppService(),
          ),
        ],
        child: const MaterialApp(home: AccountFormPage()),
      ),
    );

    expect(find.byType(AppFormSection), findsAtLeastNWidgets(3));
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('saves an account immediately after edit data loads', (
    tester,
  ) async {
    final service = _FakeAccountAppService();
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
              builder:
                  (context, state) =>
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
          accountAppServiceProvider.overrideWithValue(service),
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
    expect(service.editCommands.single.id, 'account-1');
    expect(service.editCommands.single.name, '工资卡');
    expect(
      service.editCommands.single.targetBalance,
      const Money(minorUnits: 123400),
    );
  });

  testWidgets('shows loading, error, and not-found edit states', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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

class _FakeAccountAppService implements AccountAppService {
  final createCommands = <CreateAccountCommand>[];
  final editCommands = <EditAccountCommand>[];

  @override
  Future<Account> createAccount(CreateAccountCommand command) async {
    createCommands.add(command);
    return Account(
      id: 'created',
      name: command.name,
      type: command.type,
      balance: const Money(minorUnits: 0),
    );
  }

  @override
  Future<void> editAccount(EditAccountCommand command) async {
    editCommands.add(command);
  }

  @override
  Future<void> archiveAccount(ArchiveAccountCommand command) async {}

  @override
  Future<void> restoreAccount(RestoreAccountCommand command) async {}
}
