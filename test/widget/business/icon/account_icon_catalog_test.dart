import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const brandIcons = {
    'alipay': '支付宝',
    'wechat_pay': '微信支付',
    'douyin_change': '抖音零钱',
    'douyin_pay_later': '抖音月付',
    'fangxin_loan': '放心借',
    '360_jietiao': '360借条',
    'jd_jintiao': '京东金条',
    'xiaohongshu': '小红书',
  };
  const allBrandKeys = {
    'alipay',
    'wechat_pay',
    'icbc',
    'ccb',
    'cmb_credit_card',
    'boc_debit_card',
    'abc',
    'bocom',
    'psbc',
    'citic',
    'ceb',
    'cmbc',
    'cib',
    'spdb',
    'pab',
    'cgb',
    'huabei',
    'jiebei',
    'jd_baitiao',
    'jd',
    'meituan',
    'duxiaoman',
    'china_development_bank',
    'douyin_change',
    'douyin_pay_later',
    'fangxin_loan',
    '360_jietiao',
    'jd_jintiao',
    'xiaohongshu',
  };

  late BusinessIconRegistry registry;

  setUpAll(() async => registry = await BusinessIconRegistry.load(rootBundle));

  test('keeps brand icons in a removable group outside visual styles', () {
    final groups = registry.groupsFor(BusinessIconType.account);
    final styleGroups = groups
        .where((group) => group.kind == BusinessIconGroupKind.style)
        .toList();
    final brand = registry.groupFor(BusinessIconType.account, 'brand')!;

    expect(styleGroups, hasLength(3));
    expect(brand.kind, BusinessIconGroupKind.brand);
    expect(brand.icons.keys, containsAll(allBrandKeys));
    expect(brand.icons, hasLength(allBrandKeys.length));
    for (final group in styleGroups) {
      expect(
        group.icons.keys.toSet().intersection(allBrandKeys),
        isEmpty,
        reason: '${group.id} should not contain brand artwork',
      );
    }
  });

  test('requested account icons are registered in their intended groups', () {
    final styleGroups = registry
        .groupsFor(BusinessIconType.account)
        .where((group) => group.kind == BusinessIconGroupKind.style);
    for (final group in styleGroups) {
      final housingFund = group.icons['housing-fund'];
      expect(housingFund, isNotNull, reason: 'housing-fund in ${group.id}');
      expect(housingFund!.label, '公积金');
      expect(housingFund.usage, BusinessIconUsage.account);
    }

    final brand = registry.groupFor(BusinessIconType.account, 'brand')!;
    for (final entry in brandIcons.entries) {
      final icon = brand.icons[entry.key];
      expect(icon, isNotNull, reason: '${entry.key} missing in brand');
      expect(icon!.label, entry.value);
      expect(icon.ref.id, 'builtin:account:brand:${entry.key}');
    }
  });

  test('brand icons are searchable by their labels', () {
    for (final entry in brandIcons.entries) {
      final matches = registry.search(
        type: BusinessIconType.account,
        usage: BusinessIconUsage.account,
        query: entry.value,
      );

      expect(
        matches.map((icon) => icon.ref),
        contains(
          BusinessIconRef(
            origin: BusinessIconOrigin.builtin,
            type: BusinessIconType.account,
            groupId: 'brand',
            key: entry.key,
          ),
        ),
        reason: '${entry.value} should find ${entry.key}',
      );
    }
  });

  test('registered icon assets are bundled', () async {
    for (final group in registry.groupsFor(BusinessIconType.account)) {
      final keys = group.kind == BusinessIconGroupKind.brand
          ? allBrandKeys
          : const ['housing-fund'];
      for (final key in keys) {
        final icon = group.icons[key]!;
        final data = await rootBundle.load(icon.assetPath);
        final source = await rootBundle.loadString(icon.assetPath);

        expect(
          data.lengthInBytes,
          greaterThan(0),
          reason: '${icon.assetPath} should be bundled',
        );
        expect(
          source,
          contains('viewBox='),
          reason: '${icon.assetPath} should scale in browser previews',
        );
      }
    }
  });
}
