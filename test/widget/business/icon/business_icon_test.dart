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
  late BusinessIconRegistry catalog;
  setUpAll(() async => catalog = await BusinessIconRegistry.load(rootBundle));

  test(
    'discovers actual style manifests and separates income and account choices',
    () {
      expect(catalog.groupsFor(BusinessIconType.account).map((s) => s.id), [
        'rounded-line',
        'soft-duotone',
        'color-shape',
        'brand',
      ]);
      expect(
        catalog
            .defaultGroupsFor(BusinessIconType.account)
            .map((group) => group.id),
        ['rounded-line', 'soft-duotone', 'color-shape'],
      );
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
      expect(catalog.resolve('alipay', type: BusinessIconType.account), isNull);
      expect(
        catalog
            .resolveLegacyKey('alipay', type: BusinessIconType.account)
            ?.ref
            .id,
        'builtin:account:brand:alipay',
      );
      expect(
        catalog
            .search(
              type: BusinessIconType.account,
              groupId: 'rounded-line',
              usage: BusinessIconUsage.account,
              query: '先享后付',
            )
            .single
            .iconKey,
        'buy-now-pay-later',
      );
      for (final group in catalog.defaultGroupsFor(BusinessIconType.account)) {
        expect(group.icons['buy-now-pay-later'], isNotNull);
      }
    },
  );

  test(
    'a new JSON entry is searchable without Dart registration; missing keys do not cross styles',
    () async {
      final fixture = await BusinessIconRegistry.load(_CatalogBundle());
      expect(
        fixture
            .search(
              type: BusinessIconType.account,
              groupId: 'first',
              usage: BusinessIconUsage.account,
              query: '新别名',
            )
            .single
            .iconKey,
        'new-key',
      );
      expect(
        fixture.resolveLegacyKey(
          'new-key',
          type: BusinessIconType.account,
          defaultGroupId: 'second',
        ),
        isNull,
      );
      expect(
        fixture.defaultGroupFor(BusinessIconType.account, 'removed-style')!.id,
        'first',
      );
      expect(
        fixture
            .resolveLegacyKey(
              'new-key',
              type: BusinessIconType.account,
              defaultGroupId: 'first',
            )!
            .assetPath,
        'assets/styles/account/first/icons/new-key.svg',
      );
    },
  );

  test('parses and serializes exact icon references', () {
    final ref = BusinessIconRef.tryParse(
      'builtin:account:soft-duotone:bank-card',
    );

    expect(
      ref,
      const BusinessIconRef(
        origin: BusinessIconOrigin.builtin,
        type: BusinessIconType.account,
        groupId: 'soft-duotone',
        key: 'bank-card',
      ),
    );
    expect(ref!.id, 'builtin:account:soft-duotone:bank-card');
    expect(BusinessIconRef.tryParse('bank-card'), isNull);
    expect(BusinessIconRef.tryParse('builtin:account:soft-duotone'), isNull);
  });

  test(
    'registry composes future user icon sources without changing UI API',
    () async {
      final fixture = await BusinessIconRegistry.loadFromSources([
        BundledBusinessIconSource(rootBundle),
        _MemoryUserIconSource(),
      ]);
      final ref = BusinessIconRef(
        origin: BusinessIconOrigin.user,
        type: BusinessIconType.account,
        groupId: 'rounded-line',
        key: 'custom-bank',
      );

      expect(
        fixture.resolve(ref.id, type: BusinessIconType.account),
        isNotNull,
      );
      expect(
        fixture.search(
          type: BusinessIconType.account,
          usage: BusinessIconUsage.account,
          groupId: 'rounded-line',
          origin: BusinessIconOrigin.user,
          query: '自定义',
        ),
        hasLength(1),
      );
      expect(
        fixture
            .defaultGroupsFor(BusinessIconType.account)
            .map((group) => group.identity),
        isNot(contains('user:account:rounded-line')),
      );
    },
  );

  test('category icon batch is available in every style and searchable', () {
    const expenseKeys = {
      'live-tip',
      'short-video',
      'streaming',
      'game-recharge',
      'digital-reading',
      'cloud-storage',
      'courier',
      'car-service',
      'traffic-fine',
      'moving',
      'visa',
      'luggage',
      'childcare',
      'elder-care',
      'dental',
      'optical',
      'mental-health',
      'pet-care',
      'online-course',
      'exam',
      'ktv',
      'live-show',
      'leisure',
      'lend-out',
    };
    const incomeKeys = {
      'pension',
      'subsidy',
      'scholarship',
      'insurance-claim',
      'creator-income',
      'briefcase',
      'borrow-in',
    };

    for (final group in catalog.defaultGroupsFor(BusinessIconType.category)) {
      expect(group.icons.keys, containsAll(expenseKeys));
      expect(group.icons.keys, containsAll(incomeKeys));
      for (final key in expenseKeys) {
        expect(group.icons[key]!.usage, BusinessIconUsage.expenseCategory);
      }
      for (final key in incomeKeys) {
        expect(group.icons[key]!.usage, BusinessIconUsage.incomeCategory);
      }
    }

    expect(
      catalog
          .search(
            type: BusinessIconType.category,
            usage: BusinessIconUsage.expenseCategory,
            query: '直播',
          )
          .map((icon) => icon.iconKey),
      contains('live-tip'),
    );
    expect(
      catalog
          .search(
            type: BusinessIconType.category,
            usage: BusinessIconUsage.expenseCategory,
            query: '游戏充值',
          )
          .map((icon) => icon.iconKey),
      contains('game-recharge'),
    );
    expect(
      catalog
          .search(
            type: BusinessIconType.category,
            usage: BusinessIconUsage.incomeCategory,
            query: '退休金',
          )
          .map((icon) => icon.iconKey),
      contains('pension'),
    );
    expect(
      catalog
          .search(
            type: BusinessIconType.category,
            usage: BusinessIconUsage.incomeCategory,
            query: '打赏收入',
          )
          .map((icon) => icon.iconKey),
      contains('creator-income'),
    );
  });

  test('new category icon assets are bundled in every style', () async {
    const keys = {
      'live-tip',
      'short-video',
      'streaming',
      'game-recharge',
      'digital-reading',
      'cloud-storage',
      'courier',
      'car-service',
      'traffic-fine',
      'moving',
      'visa',
      'luggage',
      'childcare',
      'elder-care',
      'dental',
      'optical',
      'mental-health',
      'pet-care',
      'online-course',
      'exam',
      'ktv',
      'live-show',
      'pension',
      'subsidy',
      'scholarship',
      'insurance-claim',
      'creator-income',
      'leisure',
      'briefcase',
      'lend-out',
      'borrow-in',
    };

    for (final group in catalog.defaultGroupsFor(BusinessIconType.category)) {
      for (final key in keys) {
        final icon = group.icons[key];
        expect(icon, isNotNull, reason: '$key is missing from ${group.id}');
        final data = await rootBundle.load(icon!.assetPath);
        expect(data.lengthInBytes, greaterThan(0), reason: icon.assetPath);
      }
    }
  });

  testWidgets('renders buy-now-pay-later in every account style', (
    tester,
  ) async {
    for (final group in catalog.defaultGroupsFor(BusinessIconType.account)) {
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessIconScope(
            registry: catalog,
            child: BusinessIcon(
              iconRef: 'builtin:account:${group.id}:buy-now-pay-later',
              usage: BusinessIconUsage.account,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_assetNames(tester), [
        'assets/styles/account/${group.id}/icons/buy-now-pay-later.svg',
      ]);
      expect(find.byIcon(RemixIcons.bank_line), findsNothing);
    }
  });

  testWidgets('renders multiple exact groups independently of defaults', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessIconScope(
          registry: catalog,
          child: const Row(
            children: [
              BusinessIcon(iconRef: 'builtin:category:soft-duotone:meal'),
              BusinessIcon(iconRef: 'builtin:category:color-shape:meal'),
              BusinessIcon(
                iconRef: 'builtin:account:soft-duotone:cash',
                usage: BusinessIconUsage.account,
              ),
            ],
          ),
        ),
      ),
    );

    expect(_assetNames(tester), [
      'assets/styles/category/soft-duotone/icons/meal.svg',
      'assets/styles/category/color-shape/icons/meal.svg',
      'assets/styles/account/soft-duotone/icons/cash.svg',
    ]);
  });

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
            registry: catalog,
            child: BusinessIcon(
              iconRef: 'builtin:category:rounded-line:meal',
              size: size,
            ),
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

  testWidgets('bare, unknown, empty and unfilled refs use generic fallback', (
    tester,
  ) async {
    final records = <LogRecord>[];
    final subscription = Logger.root.onRecord
        .where((record) => record.loggerName == 'widget.business.icon')
        .listen(records.add);
    addTearDown(subscription.cancel);
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessIconScope(
          registry: catalog,
          child: const Row(
            children: [
              BusinessIcon(iconRef: 'not-in-selected-style'),
              BusinessIcon(
                iconRef: 'unknown',
                usage: BusinessIconUsage.account,
              ),
              BusinessIcon(
                iconRef: null,
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
  });

  testWidgets(
    'primary tint follows dark theme while brand colors remain intact',
    (tester) async {
      final theme = AppTheme.dark();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: BusinessIconScope(
            registry: catalog,
            child: const Row(
              children: [
                BusinessIcon(iconRef: 'builtin:category:soft-duotone:meal'),
                BusinessIcon(
                  iconRef: 'builtin:account:brand:alipay',
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
    'account picker searches groups and returns the exact icon reference',
    (tester) async {
      String? selectedRef;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BusinessIconScope(
              registry: catalog,
              child: IconCatalogPicker(
                usage: BusinessIconUsage.account,
                selectedRef: null,
                onChanged: (ref) => selectedRef = ref,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '微信');
      await tester.pumpAndSettle();
      expect(find.textContaining('微信支付'), findsOneWidget);
      expect(_assetNames(tester), [
        'assets/styles/account/brand/icons/wechat_pay.svg',
      ]);
      await tester.tap(find.textContaining('微信支付'));
      expect(selectedRef, 'builtin:account:brand:wechat_pay');
    },
  );

  testWidgets('account picker switches groups before returning an icon', (
    tester,
  ) async {
    String? selectedRef;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BusinessIconScope(
            registry: catalog,
            child: IconCatalogPicker(
              usage: BusinessIconUsage.account,
              selectedRef: null,
              onChanged: (ref) => selectedRef = ref,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('business-icon-group-choice')),
      findsOneWidget,
    );
    expect(find.text('图标分组'), findsNothing);
    expect(
      tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .map((picture) => (picture.bytesLoader as SvgAssetLoader).assetName),
      everyElement(contains('/account/rounded-line/')),
    );

    await tester.tap(find.text('柔和双色'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .map((picture) => (picture.bytesLoader as SvgAssetLoader).assetName),
      everyElement(contains('/account/soft-duotone/')),
    );

    await tester.tap(find.text('现金'));
    expect(selectedRef, 'builtin:account:soft-duotone:cash');
  });
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
      final type = key.contains('/account/') ? 'account' : 'category';
      return jsonEncode({
        'groups': [
          {
            'id': 'first',
            'name': '一',
            'kind': 'style',
            'manifest': 'assets/styles/$type/first/manifest.json',
          },
          {
            'id': 'second',
            'name': '二',
            'kind': 'style',
            'manifest': 'assets/styles/$type/second/manifest.json',
          },
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

class _MemoryUserIconSource implements BusinessIconSource {
  @override
  Future<List<BusinessIconGroup>> load() async {
    final ref = BusinessIconRef(
      origin: BusinessIconOrigin.user,
      type: BusinessIconType.account,
      groupId: 'rounded-line',
      key: 'custom-bank',
    );
    return [
      BusinessIconGroup(
        origin: BusinessIconOrigin.user,
        type: BusinessIconType.account,
        id: 'rounded-line',
        name: '我的图标',
        kind: BusinessIconGroupKind.user,
        icons: {
          ref.key: BusinessIconSpec(
            ref: ref,
            label: '自定义银行',
            assetPath: 'memory://custom-bank.svg',
            usage: BusinessIconUsage.account,
            color: BusinessIconColor.original,
          ),
        },
      ),
    ];
  }
}
