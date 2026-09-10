import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/icon/icon_catalog_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BusinessIconCatalog catalog;
  setUpAll(() async => catalog = await BusinessIconCatalog.load(rootBundle));

  test(
    'discovers actual style manifests and separates income and account choices',
    () {
      expect(catalog.stylesFor(BusinessIconType.account).map((s) => s.id), [
        'rounded-line',
        'soft-duotone',
        'color-shape',
      ]);
      expect(
        catalog
            .search(
              type: BusinessIconType.category,
              usage: BusinessIconUsage.incomeCategory,
            )
            .map((i) => i.iconKey),
        containsAll(['salary', 'interest-income', 'funds-line']),
      );
      expect(
        catalog
            .search(
              type: BusinessIconType.account,
              usage: BusinessIconUsage.account,
              query: '微信',
            )
            .single
            .iconKey,
        'wechat_pay',
      );
      expect(catalog.resolve('meal', type: BusinessIconType.account), isNull);
      expect(catalog.resolve('cash', type: BusinessIconType.category), isNull);
    },
  );

  test(
    'a new JSON entry is searchable without Dart registration; missing keys do not cross styles',
    () async {
      final fixture = await BusinessIconCatalog.load(_CatalogBundle());
      expect(
        fixture
            .search(
              type: BusinessIconType.account,
              style: 'first',
              usage: BusinessIconUsage.account,
              query: '新别名',
            )
            .single
            .iconKey,
        'new-key',
      );
      expect(
        fixture.resolve(
          'new-key',
          type: BusinessIconType.account,
          style: 'second',
        ),
        isNull,
      );
      expect(
        fixture.styleFor(BusinessIconType.account, 'removed-style')!.id,
        'first',
      );
      expect(
        fixture
            .resolve('new-key', type: BusinessIconType.account, style: 'first')!
            .assetPath,
        'assets/styles/account/first/icons/new-key.svg',
      );
    },
  );

  testWidgets(
    'switching category style leaves account style intact and keeps key identity',
    (tester) async {
      Widget app(String categoryStyle) => MaterialApp(
        home: BusinessIconScope(
          catalog: catalog,
          accountStyle: 'color-shape',
          categoryStyle: categoryStyle,
          child: const Row(
            children: [
              BusinessIcon(iconKey: 'meal'),
              BusinessIcon(iconKey: 'cash', usage: BusinessIconUsage.account),
            ],
          ),
        ),
      );
      await tester.pumpWidget(app('rounded-line'));
      expect(_assetNames(tester), [
        'assets/styles/category/rounded-line/icons/meal.svg',
        'assets/styles/account/color-shape/icons/cash.svg',
      ]);
      await tester.pumpWidget(app('soft-duotone'));
      expect(_assetNames(tester), [
        'assets/styles/category/soft-duotone/icons/meal.svg',
        'assets/styles/account/color-shape/icons/cash.svg',
      ]);
      expect(
        tester
            .widgetList<BusinessIcon>(find.byType(BusinessIcon))
            .map((i) => i.iconKey),
        ['meal', 'cash'],
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'logs SVG load failures once per failure and logs a later retry failure',
    (tester) async {
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord
          .where((record) => record.loggerName == 'widget.business.icon')
          .listen(records.add);
      addTearDown(subscription.cancel);
      final firstBundle = _FailingSvgBundle();
      Widget app(AssetBundle bundle, {double size = 24}) => MaterialApp(
        home: DefaultAssetBundle(
          bundle: bundle,
          child: BusinessIconScope(
            catalog: catalog,
            child: BusinessIcon(iconKey: 'meal', size: size),
          ),
        ),
      );

      await tester.pumpWidget(app(firstBundle));
      await tester.pumpAndSettle();
      expect(find.byIcon(RemixIcons.more_line), findsOneWidget);
      expect(records, hasLength(1));
      expect(records.single.level, Level.WARNING);
      expect(records.single.error, same(firstBundle.error));
      expect(records.single.stackTrace, same(firstBundle.stackTrace));
      expect(
        records.single.message,
        contains('assets/styles/category/rounded-line/icons/meal.svg'),
      );

      await tester.pumpWidget(app(firstBundle, size: 32));
      await tester.pumpAndSettle();
      expect(tester.widget<Icon>(find.byIcon(RemixIcons.more_line)).size, 32);
      expect(records, hasLength(1));

      final retryBundle = _FailingSvgBundle();
      await tester.pumpWidget(app(retryBundle));
      await tester.pumpAndSettle();
      expect(records, hasLength(2));
      expect(records.last.level, Level.WARNING);
      expect(records.last.error, same(retryBundle.error));
      expect(records.last.stackTrace, same(retryBundle.stackTrace));
    },
  );

  testWidgets(
    'unknown, empty and unfilled keys use generic fallback without old registry',
    (tester) async {
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord
          .where((record) => record.loggerName == 'widget.business.icon')
          .listen(records.add);
      addTearDown(subscription.cancel);
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessIconScope(
            catalog: catalog,
            child: const Row(
              children: [
                BusinessIcon(iconKey: 'not-in-selected-style'),
                BusinessIcon(
                  iconKey: 'unknown',
                  usage: BusinessIconUsage.account,
                ),
                BusinessIcon(
                  iconKey: null,
                  usage: BusinessIconUsage.incomeCategory,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byIcon(RemixIcons.more_line), findsOneWidget);
      expect(find.byIcon(RemixIcons.bank_line), findsOneWidget);
      expect(find.byIcon(RemixIcons.more_2_line), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
      expect(records, isEmpty);
    },
  );

  testWidgets(
    'primary tint follows dark theme while brand colors remain intact',
    (tester) async {
      final theme = AppTheme.dark();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: BusinessIconScope(
            catalog: catalog,
            accountStyle: 'soft-duotone',
            categoryStyle: 'soft-duotone',
            child: const Row(
              children: [
                BusinessIcon(iconKey: 'meal'),
                BusinessIcon(
                  iconKey: 'alipay',
                  usage: BusinessIconUsage.account,
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ),
      );
      final pictures = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .toList();
      expect(
        pictures.first.colorFilter,
        ColorFilter.mode(theme.colorScheme.primary, BlendMode.srcIn),
      );
      expect(pictures.last.colorFilter, isNull);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'account picker displays the selected account style and returns its JSON key',
    (tester) async {
      String? selectedKey;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BusinessIconScope(
              catalog: catalog,
              accountStyle: 'color-shape',
              categoryStyle: 'rounded-line',
              child: IconCatalogPicker(
                usage: BusinessIconUsage.account,
                selectedKey: null,
                onChanged: (key) => selectedKey = key,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '微信');
      await tester.pumpAndSettle();
      expect(find.text('微信支付'), findsOneWidget);
      expect(_assetNames(tester), [
        'assets/styles/account/color-shape/icons/wechat_pay.svg',
      ]);
      await tester.tap(find.text('微信支付'));
      expect(selectedKey, 'wechat_pay');
    },
  );
}

List<String> _assetNames(WidgetTester tester) => tester
    .widgetList<SvgPicture>(find.byType(SvgPicture))
    .map((picture) => (picture.bytesLoader as SvgAssetLoader).assetName)
    .toList();

class _CatalogBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'assets/styles/account/manifest.json' ||
        key == 'assets/styles/category/manifest.json') {
      return jsonEncode({
        'styles': [
          {'id': 'first', 'name': '一'},
          {'id': 'second', 'name': '二'},
        ],
      });
    }
    return jsonEncode({
      'icons': key.contains('/account/first/')
          ? [
              {
                'key': 'new-key',
                'label': '新图标',
                'keywords': ['新别名'],
              },
            ]
          : [],
    });
  }

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

class _FailingSvgBundle extends CachingAssetBundle {
  final error = FlutterError('Unable to load bundled SVG.');
  final stackTrace = StackTrace.current;

  @override
  Future<ByteData> load(String key) {
    // Isolate fallback logging from the SVG dependencies' unhandled async
    // cache futures; the loader forwards this error to the same errorBuilder.
    if (key.endsWith('.svg')) Error.throwWithStackTrace(error, stackTrace);
    return rootBundle.load(key);
  }
}
