import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/widget/business/account/account_picker_sheet.dart';

void main() {
  testWidgets('平铺列表可返回选中的账户', (tester) async {
    String? selectedId;
    final accounts = [
      _account('cash', '现金', AccountProfileKind.fund),
      _account('credit', '信用卡', AccountProfileKind.credit),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  selectedId = await showAccountPickerSheet(
                    context: context,
                    accounts: accounts,
                    selectedId: 'cash',
                  );
                },
                child: const Text('打开账户选择'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开账户选择'));
    await tester.pumpAndSettle();

    expect(find.text('选择账户'), findsNothing);
    expect(find.text('列表'), findsOneWidget);
    expect(find.byIcon(RemixIcons.list_unordered), findsOneWidget);
    final sheetLeft = tester.getTopLeft(find.byType(AccountPickerSheet)).dx;
    final toggleLeft = tester
        .getTopLeft(find.byKey(const ValueKey('account-picker-layout-toggle')))
        .dx;
    expect(toggleLeft - sheetLeft, lessThanOrEqualTo(20));

    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();

    expect(find.text('分组'), findsOneWidget);
    expect(find.byIcon(RemixIcons.layout_left_line), findsOneWidget);
    expect(
      find.byKey(const ValueKey('account-picker-grouped-layout')),
      findsOneWidget,
    );

    await tester.tap(find.text('分组'));
    await tester.pumpAndSettle();

    expect(find.text('列表'), findsOneWidget);
    expect(find.byIcon(RemixIcons.list_unordered), findsOneWidget);

    await tester.tap(find.text('信用卡'));
    await tester.pumpAndSettle();

    expect(selectedId, 'credit');
    expect(find.text('选择账户'), findsNothing);
  });

  testWidgets('分组导航按账户画像筛选账户', (tester) async {
    final accounts = [
      _account('cash', '现金', AccountProfileKind.fund),
      _account('bank', '工资卡', AccountProfileKind.fund),
      _account('friend', '朋友欠款', AccountProfileKind.receivable),
      _account('credit', '信用卡', AccountProfileKind.credit),
    ];

    await tester.pumpWidget(
      _testApp(
        AccountPickerSheet(
          accounts: accounts,
          selectedId: 'bank',
          onAccountTap: (_) {},
        ),
      ),
    );

    expect(find.text('现金'), findsOneWidget);
    expect(find.text('朋友欠款'), findsOneWidget);
    expect(find.text('信用卡'), findsOneWidget);

    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();

    expect(find.text('资金账户'), findsOneWidget);
    expect(find.text('应收账户'), findsOneWidget);
    expect(find.text('信用账户'), findsOneWidget);
    expect(find.text('现金'), findsOneWidget);
    expect(find.text('工资卡'), findsOneWidget);
    expect(find.text('朋友欠款'), findsNothing);
    expect(find.text('信用卡'), findsNothing);
    expect(
      tester
          .getRect(
            find.byKey(const ValueKey('account-picker-group-navigation')),
          )
          .right,
      lessThan(
        tester
            .getRect(
              find.byKey(const ValueKey('account-picker-grouped-account-list')),
            )
            .left,
      ),
    );

    await tester.tap(find.text('应收账户'));
    await tester.pumpAndSettle();

    expect(find.text('朋友欠款'), findsOneWidget);
    expect(find.text('现金'), findsNothing);
    expect(find.text('工资卡'), findsNothing);
  });

  testWidgets('未识别画像归入其他账户', (tester) async {
    final accounts = [
      _account('cash', '现金', AccountProfileKind.fund),
      _accountWithoutProfile('legacy', '历史账户'),
    ];

    await tester.pumpWidget(
      _testApp(
        AccountPickerSheet(
          accounts: accounts,
          selectedId: null,
          onAccountTap: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('其他账户'));
    await tester.pumpAndSettle();

    expect(find.text('历史账户'), findsOneWidget);
    expect(find.text('现金'), findsNothing);
  });

  testWidgets('可选账户在两种布局中都保留无账户入口', (tester) async {
    final accounts = [
      _account('cash', '现金', AccountProfileKind.fund),
      _account('credit', '信用卡', AccountProfileKind.credit),
    ];

    await tester.pumpWidget(
      _testApp(
        AccountPickerSheet(
          accounts: accounts,
          selectedId: null,
          noneLabel: '无',
          onNoneTap: () {},
          onAccountTap: (_) {},
        ),
      ),
    );

    expect(find.text('无'), findsOneWidget);
    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();
    expect(find.text('无'), findsOneWidget);
  });

  testWidgets('窄屏和大字号下保持可用且无布局溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(
        AccountPickerSheet(
          accounts: [
            for (final profile in AccountProfileKind.values)
              _account(profile.key, profile.label, profile),
          ],
          selectedId: AccountProfileKind.credit.key,
          onAccountTap: (_) {},
        ),
        textScaler: const TextScaler.linear(1.4),
      ),
    );
    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('信用账户'), findsWidgets);
  });
}

Widget _testApp(Widget child, {TextScaler? textScaler}) {
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) {
      final mediaQuery = MediaQuery.of(context);
      return MediaQuery(
        data: textScaler == null
            ? mediaQuery
            : mediaQuery.copyWith(textScaler: textScaler),
        child: child!,
      );
    },
    home: Scaffold(body: child),
  );
}

Account _account(String id, String name, AccountProfileKind profile) {
  return Account(
    id: id,
    name: name,
    type: profile.accountType,
    subtype: profile.accountSubtype,
    profileKey: profile.key,
    balance: const Money(minorUnits: 0),
  );
}

Account _accountWithoutProfile(String id, String name) {
  return Account(
    id: id,
    name: name,
    type: AccountType.asset,
    balance: const Money(minorUnits: 0),
  );
}
