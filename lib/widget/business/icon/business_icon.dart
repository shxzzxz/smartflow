import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:remixicon/remixicon.dart';

import 'package:smartflow/design_system/token/colors.dart';

enum BusinessIconSource { remixIcon, svgAsset }

enum BusinessIconUsage { expenseCategory, incomeCategory, system, account }

class BusinessIconSpec {
  const BusinessIconSpec.remix({
    required this.iconKey,
    required this.icon,
    required this.color,
    required this.label,
    this.usage = BusinessIconUsage.expenseCategory,
  }) : source = BusinessIconSource.remixIcon,
       assetPath = null;

  const BusinessIconSpec.svg({
    required this.iconKey,
    required this.assetPath,
    required this.color,
    required this.label,
    this.usage = BusinessIconUsage.account,
  }) : source = BusinessIconSource.svgAsset,
       icon = null;

  final String iconKey;
  final BusinessIconSource source;
  final IconData? icon;
  final String? assetPath;
  final Color color;
  final String label;
  final BusinessIconUsage usage;
}

class BusinessIcon extends StatelessWidget {
  const BusinessIcon({
    required this.iconKey,
    super.key,
    this.size = 24,
    this.color,
  });

  final String? iconKey;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final spec = resolveBusinessIconSpec(iconKey);
    return switch (spec.source) {
      BusinessIconSource.remixIcon => Icon(
        spec.icon,
        size: size,
        color:
            color ??
            IconTheme.of(context).color ??
            Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      BusinessIconSource.svgAsset => SvgPicture.asset(
        spec.assetPath!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter:
            color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      ),
    };
  }
}

const businessIconSpecs = <BusinessIconSpec>[
  BusinessIconSpec.remix(
    iconKey: 'social',
    icon: RemixIcons.user_3_line,
    color: AppColors.categorySocial,
    label: '人情社交',
  ),
  BusinessIconSpec.remix(
    iconKey: 'team-line',
    icon: RemixIcons.team_line,
    color: AppColors.categorySocial,
    label: '人情社交',
  ),
  BusinessIconSpec.remix(
    iconKey: 'home',
    icon: RemixIcons.home_5_line,
    color: AppColors.categoryHome,
    label: '家里',
  ),
  BusinessIconSpec.remix(
    iconKey: 'home-office-line',
    icon: RemixIcons.home_office_line,
    color: AppColors.categoryHome,
    label: '房租',
  ),
  BusinessIconSpec.remix(
    iconKey: 'building-2-line',
    icon: RemixIcons.building_2_line,
    color: AppColors.categoryHome,
    label: '物业',
  ),
  BusinessIconSpec.remix(
    iconKey: 'flashlight-line',
    icon: RemixIcons.flashlight_line,
    color: AppColors.categoryTransfer,
    label: '水电燃',
  ),
  BusinessIconSpec.remix(
    iconKey: 'meal',
    icon: RemixIcons.restaurant_2_line,
    color: AppColors.categoryDining,
    label: '食品餐饮',
  ),
  BusinessIconSpec.remix(
    iconKey: 'service-bell-line',
    icon: RemixIcons.service_bell_line,
    color: AppColors.categoryDining,
    label: '请客吃饭',
  ),
  BusinessIconSpec.remix(
    iconKey: 'shopping',
    icon: RemixIcons.shopping_bag_3_line,
    color: AppColors.categoryShopping,
    label: '购物消费',
  ),
  BusinessIconSpec.remix(
    iconKey: 't-shirt-line',
    icon: RemixIcons.t_shirt_line,
    color: AppColors.categoryShopping,
    label: '衣物',
  ),
  BusinessIconSpec.remix(
    iconKey: 'coffee',
    icon: RemixIcons.cup_line,
    color: AppColors.categoryFood,
    label: '咖啡',
  ),
  BusinessIconSpec.remix(
    iconKey: 'drinks-line',
    icon: RemixIcons.drinks_line,
    color: AppColors.categoryFood,
    label: '茶饮',
  ),
  BusinessIconSpec.remix(
    iconKey: 'cup-line',
    icon: RemixIcons.cup_line,
    color: AppColors.categoryFood,
    label: '早餐',
  ),
  BusinessIconSpec.remix(
    iconKey: 'bowl-line',
    icon: RemixIcons.bowl_line,
    color: AppColors.categoryFood,
    label: '午餐',
  ),
  BusinessIconSpec.remix(
    iconKey: 'breakfast',
    icon: RemixIcons.bowl_line,
    color: AppColors.categoryGift,
    label: '早餐',
  ),
  BusinessIconSpec.remix(
    iconKey: 'lunch',
    icon: RemixIcons.briefcase_4_line,
    color: AppColors.categoryGift,
    label: '午餐',
  ),
  BusinessIconSpec.remix(
    iconKey: 'dinner',
    icon: RemixIcons.restaurant_line,
    color: AppColors.categoryGift,
    label: '晚餐',
  ),
  BusinessIconSpec.remix(
    iconKey: 'drink',
    icon: RemixIcons.goblet_line,
    color: AppColors.categoryTransfer,
    label: '饮料酒水',
  ),
  BusinessIconSpec.remix(
    iconKey: 'snack',
    icon: RemixIcons.cake_3_line,
    color: AppColors.categorySnack,
    label: '休闲零食',
  ),
  BusinessIconSpec.remix(
    iconKey: 'seafood',
    icon: RemixIcons.gitlab_line,
    color: AppColors.categorySeafood,
    label: '生鲜食品',
  ),
  BusinessIconSpec.svg(
    iconKey: 'cabbage',
    assetPath: 'assets/icons/category/cabbage.svg',
    color: AppColors.categorySeafood,
    label: '食材生鲜',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'seasoning',
    icon: RemixIcons.archive_line,
    color: AppColors.categoryHome,
    label: '粮油调味',
  ),
  BusinessIconSpec.svg(
    iconKey: 'rice',
    assetPath: 'assets/icons/category/rice.svg',
    color: AppColors.categoryHome,
    label: '粮油调味',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'metro',
    icon: RemixIcons.train_line,
    color: AppColors.categoryTransport,
    label: '通勤',
  ),
  BusinessIconSpec.remix(
    iconKey: 'traffic-light-line',
    icon: RemixIcons.traffic_light_line,
    color: AppColors.categoryTransport,
    label: '出行交通',
  ),
  BusinessIconSpec.remix(
    iconKey: 'bus-2-line',
    icon: RemixIcons.bus_2_line,
    color: AppColors.categoryTransport,
    label: '公交',
  ),
  BusinessIconSpec.remix(
    iconKey: 'taxi',
    icon: RemixIcons.taxi_line,
    color: AppColors.categoryTaxi,
    label: '打车',
  ),
  BusinessIconSpec.remix(
    iconKey: 'gift',
    icon: RemixIcons.gift_line,
    color: AppColors.categoryGift,
    label: '礼物',
  ),
  BusinessIconSpec.remix(
    iconKey: 'hand-heart-line',
    icon: RemixIcons.hand_heart_line,
    color: AppColors.categoryGift,
    label: '慈善捐助',
  ),
  BusinessIconSpec.remix(
    iconKey: 'health',
    icon: RemixIcons.heart_pulse_line,
    color: AppColors.categoryMedical,
    label: '医疗',
  ),
  BusinessIconSpec.remix(
    iconKey: 'phone',
    icon: RemixIcons.smartphone_line,
    color: AppColors.categoryGenericNeutral,
    label: '通讯',
  ),
  BusinessIconSpec.remix(
    iconKey: 'send-plane-line',
    icon: RemixIcons.send_plane_line,
    color: AppColors.categoryGenericNeutral,
    label: '通讯',
  ),
  BusinessIconSpec.remix(
    iconKey: 'book',
    icon: RemixIcons.book_open_line,
    color: AppColors.categoryReading,
    label: '书籍',
  ),
  BusinessIconSpec.remix(
    iconKey: 'movie',
    icon: RemixIcons.film_line,
    color: AppColors.categoryEntertainment,
    label: '娱乐',
  ),
  BusinessIconSpec.remix(
    iconKey: 'gamepad-line',
    icon: RemixIcons.gamepad_line,
    color: AppColors.categoryEntertainment,
    label: '休闲娱乐',
  ),
  BusinessIconSpec.remix(
    iconKey: 'dice-5-line',
    icon: RemixIcons.dice_5_line,
    color: AppColors.categoryEntertainment,
    label: '棋牌桌游',
  ),
  BusinessIconSpec.remix(
    iconKey: 'salary',
    icon: RemixIcons.briefcase_4_line,
    color: AppColors.categorySalary,
    label: '工资',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'briefcase-line',
    icon: RemixIcons.briefcase_line,
    color: AppColors.categorySalary,
    label: '工作',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'wallet-3-line',
    icon: RemixIcons.wallet_3_line,
    color: AppColors.categorySalary,
    label: '工资',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'wallet-line',
    icon: RemixIcons.wallet_line,
    color: AppColors.categoryGenericNeutral,
    label: '余额',
    usage: BusinessIconUsage.system,
  ),
  BusinessIconSpec.remix(
    iconKey: 'trophy-line',
    icon: RemixIcons.trophy_line,
    color: AppColors.categoryGift,
    label: '奖金',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'rest-time-line',
    icon: RemixIcons.rest_time_line,
    color: AppColors.categoryGenericIncome,
    label: '兼职',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'funds-line',
    icon: RemixIcons.funds_line,
    color: AppColors.categoryTransfer,
    label: '投资',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'loan',
    icon: RemixIcons.bank_line,
    color: AppColors.categoryLoan,
    label: '借贷',
    usage: BusinessIconUsage.system,
  ),
  BusinessIconSpec.remix(
    iconKey: 'money-cny-circle-line',
    icon: RemixIcons.money_cny_circle_line,
    color: AppColors.categoryLoan,
    label: '利息',
    usage: BusinessIconUsage.system,
  ),
  BusinessIconSpec.remix(
    iconKey: 'hand-coin-line',
    icon: RemixIcons.hand_coin_line,
    color: AppColors.categoryLoan,
    label: '借入',
    usage: BusinessIconUsage.system,
  ),
  BusinessIconSpec.remix(
    iconKey: 'logout-box-r-line',
    icon: RemixIcons.logout_box_r_line,
    color: AppColors.categoryLoan,
    label: '借出',
    usage: BusinessIconUsage.system,
  ),
  BusinessIconSpec.remix(
    iconKey: 'currency-line',
    icon: RemixIcons.currency_line,
    color: AppColors.categoryGenericIncome,
    label: '报销',
    usage: BusinessIconUsage.system,
  ),
  BusinessIconSpec.remix(
    iconKey: 'coupon-3-line',
    icon: RemixIcons.coupon_3_line,
    color: AppColors.categoryGenericIncome,
    label: '优惠',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'transfer',
    icon: RemixIcons.arrow_left_right_line,
    color: AppColors.categoryTransfer,
    label: '转账',
    usage: BusinessIconUsage.system,
  ),
  BusinessIconSpec.remix(
    iconKey: 'swap-box-line',
    icon: RemixIcons.swap_box_line,
    color: AppColors.categoryTransfer,
    label: '手续费',
    usage: BusinessIconUsage.system,
  ),
  BusinessIconSpec.remix(
    iconKey: 'expense',
    icon: RemixIcons.price_tag_3_line,
    color: AppColors.categoryGenericExpense,
    label: '通用支出',
  ),
  BusinessIconSpec.remix(
    iconKey: 'income',
    icon: RemixIcons.price_tag_3_line,
    color: AppColors.categoryGenericIncome,
    label: '通用收入',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'more-2-line',
    icon: RemixIcons.more_2_line,
    color: AppColors.categoryGenericIncome,
    label: '其他',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'category',
    icon: RemixIcons.price_tag_3_line,
    color: AppColors.categoryGenericNeutral,
    label: '其他',
  ),
  BusinessIconSpec.remix(
    iconKey: 'more-line',
    icon: RemixIcons.more_line,
    color: AppColors.categoryGenericNeutral,
    label: '其他',
  ),
  BusinessIconSpec.svg(
    iconKey: 'account',
    assetPath: 'assets/icons/account/account.svg',
    color: AppColors.categoryGenericNeutral,
    label: '账户',
  ),
  BusinessIconSpec.svg(
    iconKey: 'alipay',
    assetPath: 'assets/icons/account/alipay.svg',
    color: AppColors.categoryGenericNeutral,
    label: '支付宝',
  ),
  BusinessIconSpec.svg(
    iconKey: 'wechat_pay',
    assetPath: 'assets/icons/account/wechat_pay.svg',
    color: AppColors.categoryGenericNeutral,
    label: '微信支付',
  ),
  BusinessIconSpec.svg(
    iconKey: 'cmb_credit_card',
    assetPath: 'assets/icons/account/cmb_credit_card.svg',
    color: AppColors.categoryGenericNeutral,
    label: '招商银行',
  ),
  BusinessIconSpec.svg(
    iconKey: 'boc_debit_card',
    assetPath: 'assets/icons/account/boc_debit_card.svg',
    color: AppColors.categoryGenericNeutral,
    label: '中国银行',
  ),
  BusinessIconSpec.svg(
    iconKey: 'cash',
    assetPath: 'assets/icons/account/cash.svg',
    color: AppColors.categoryGenericNeutral,
    label: '现金',
  ),
  BusinessIconSpec.svg(
    iconKey: 'huabei',
    assetPath: 'assets/icons/account/huabei.svg',
    color: AppColors.categoryGenericNeutral,
    label: '花呗',
  ),
  BusinessIconSpec.svg(
    iconKey: 'loan_in',
    assetPath: 'assets/icons/account/loan_in.svg',
    color: AppColors.categoryGenericNeutral,
    label: '借入',
  ),
  BusinessIconSpec.svg(
    iconKey: 'loan_out',
    assetPath: 'assets/icons/account/loan_out.svg',
    color: AppColors.categoryGenericNeutral,
    label: '借出',
  ),
  BusinessIconSpec.svg(
    iconKey: 'reimburse',
    assetPath: 'assets/icons/account/reimburse.svg',
    color: AppColors.categoryGenericNeutral,
    label: '报销',
  ),
];

final Map<String, BusinessIconSpec> businessIconSpecsByKey = Map.unmodifiable({
  for (final spec in businessIconSpecs) spec.iconKey: spec,
});

List<BusinessIconSpec> businessIconSpecsForUsage(BusinessIconUsage usage) {
  return List.unmodifiable(
    businessIconSpecs.where((spec) => spec.usage == usage),
  );
}

const _fallbackIconSpec = BusinessIconSpec.remix(
  iconKey: 'fallback',
  icon: RemixIcons.remixicon_line,
  color: AppColors.categoryGenericNeutral,
  label: '图标',
  usage: BusinessIconUsage.system,
);

BusinessIconSpec resolveBusinessIconSpec(String? iconKey) {
  final normalized = normalizeBusinessIconKey(iconKey);
  if (normalized != null && businessIconSpecsByKey.containsKey(normalized)) {
    return businessIconSpecsByKey[normalized]!;
  }
  return _fallbackIconSpec;
}

String? normalizeBusinessIconKey(String? iconKey) {
  final trimmed = iconKey?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
