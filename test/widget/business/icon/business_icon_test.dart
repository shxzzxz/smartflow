import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/icon/icon_catalog_picker.dart';

void main() {
  test(
    'provides a rich, searchable catalog for category and account pickers',
    () {
      final expenseIcons = businessIconSpecsForUsage(
        BusinessIconUsage.expenseCategory,
      );
      final incomeIcons = businessIconSpecsForUsage(
        BusinessIconUsage.incomeCategory,
      );
      final accountIcons = businessIconSpecsForUsage(BusinessIconUsage.account);

      expect(expenseIcons.length, greaterThanOrEqualTo(55));
      expect(incomeIcons.length, greaterThanOrEqualTo(15));
      expect(accountIcons.length, greaterThanOrEqualTo(32));
      expect(
        searchBusinessIconSpecs(
          usage: BusinessIconUsage.expenseCategory,
          query: '停车',
        ).map((spec) => spec.iconKey),
        contains('parking'),
      );
      expect(
        searchBusinessIconSpecs(
          usage: BusinessIconUsage.account,
          query: '车贷',
        ).map((spec) => spec.iconKey),
        contains('car-loan-account'),
      );
    },
  );

  test(
    'keeps icon keys unique and safely falls back for legacy unknown keys',
    () {
      final iconKeys = businessIconSpecs.map((spec) => spec.iconKey).toList();

      expect(iconKeys.toSet(), hasLength(iconKeys.length));
      expect(resolveBusinessIconSpec('parking').label, '停车');
      expect(
        resolveBusinessIconSpec('icbc').assetPath,
        'assets/icons/account/icbc.svg',
      );
      expect(
        resolveBusinessIconSpec('missing-legacy-icon').iconKey,
        'more-line',
      );
      expect(
        resolveBusinessIconSpec(
          'missing-legacy-icon',
          usage: BusinessIconUsage.account,
        ).iconKey,
        'bank-account',
      );
      expect(
        resolveBusinessIconSpec(
          'missing-legacy-icon',
          usage: BusinessIconUsage.incomeCategory,
        ).iconKey,
        'more-2-line',
      );
    },
  );

  testWidgets('loads every registered SVG account icon from the asset bundle', (
    tester,
  ) async {
    final svgAssets = businessIconSpecs
        .where((spec) => spec.source == BusinessIconSource.svgAsset)
        .map((spec) => spec.assetPath!);

    for (final assetPath in svgAssets) {
      await rootBundle.load(assetPath);
    }
  });

  testWidgets('filters the visible choices and returns the selected icon key', (
    tester,
  ) async {
    String? selectedKey;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IconCatalogPicker(
            usage: BusinessIconUsage.expenseCategory,
            selectedKey: null,
            onChanged: (iconKey) => selectedKey = iconKey,
          ),
        ),
      ),
    );

    await tester.enterText(_searchField(), '停车');
    await tester.pump();

    final parkingLabel = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == '停车',
    );
    expect(parkingLabel, findsOneWidget);
    await tester.tap(parkingLabel);

    expect(selectedKey, 'parking');
  });
}

Finder _searchField() {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == '搜索图标',
  );
}
