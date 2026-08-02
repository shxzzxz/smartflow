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
    this.keywords = const [],
  }) : source = BusinessIconSource.remixIcon,
       assetPath = null;

  const BusinessIconSpec.svg({
    required this.iconKey,
    required this.assetPath,
    required this.color,
    required this.label,
    this.usage = BusinessIconUsage.account,
    this.keywords = const [],
  }) : source = BusinessIconSource.svgAsset,
       icon = null;

  final String iconKey;
  final BusinessIconSource source;
  final IconData? icon;
  final String? assetPath;
  final Color color;
  final String label;
  final BusinessIconUsage usage;
  final List<String> keywords;
}

class BusinessIcon extends StatelessWidget {
  const BusinessIcon({
    required this.iconKey,
    super.key,
    this.size = 24,
    this.color,
    this.usage = BusinessIconUsage.expenseCategory,
  });

  final String? iconKey;
  final double size;
  final Color? color;
  final BusinessIconUsage usage;

  @override
  Widget build(BuildContext context) {
    final spec = resolveBusinessIconSpec(iconKey, usage: usage);
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
    label: '人情社交-1',
  ),
  BusinessIconSpec.remix(
    iconKey: 'team-line',
    icon: RemixIcons.team_line,
    color: AppColors.categorySocial,
    label: '人情社交-2',
  ),
  BusinessIconSpec.remix(
    iconKey: 'home',
    icon: RemixIcons.home_5_line,
    color: AppColors.categoryHome,
    label: '家里-1',
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
    label: '电',
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
    iconKey: 'drinks-line',
    icon: RemixIcons.drinks_line,
    color: AppColors.categoryFood,
    label: '茶饮-1',
  ),
  BusinessIconSpec.remix(
    iconKey: 'cup-line',
    icon: RemixIcons.cup_line,
    color: AppColors.categoryFood,
    label: '咖啡',
  ),
  BusinessIconSpec.remix(
    iconKey: 'bowl-line',
    icon: RemixIcons.bowl_line,
    color: AppColors.categoryFood,
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
  BusinessIconSpec.svg(
    iconKey: 'fresh-food',
    assetPath: 'assets/icons/category/fresh_food.svg',
    color: AppColors.categorySeafood,
    label: '食材生鲜',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'vegetables',
    assetPath: 'assets/icons/category/vegetables.svg',
    color: AppColors.categorySeafood,
    label: '蔬菜',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'seasonings',
    assetPath: 'assets/icons/category/seasonings.svg',
    color: AppColors.categoryFood,
    label: '调味底料',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'teapot',
    assetPath: 'assets/icons/category/teapot.svg',
    color: AppColors.categoryFood,
    label: '茶饮-2',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'snacks',
    assetPath: 'assets/icons/category/snacks.svg',
    color: AppColors.categorySnack,
    label: '零食',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'group-dining',
    assetPath: 'assets/icons/category/group_dining.svg',
    color: AppColors.categoryDining,
    label: '聚餐',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'dining-with-friends',
    assetPath: 'assets/icons/category/dining_with_friends.svg',
    color: AppColors.categoryDining,
    label: '朋友聚餐',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'office-supplies',
    assetPath: 'assets/icons/category/office_supplies.svg',
    color: AppColors.categoryShopping,
    label: '办公用品',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'appliances',
    assetPath: 'assets/icons/category/appliances.svg',
    color: AppColors.categoryHome,
    label: '电器',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'home-illustration',
    assetPath: 'assets/icons/category/home.svg',
    color: AppColors.categoryHome,
    label: '家里-2',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'electricity-bill',
    assetPath: 'assets/icons/category/electricity_bill.svg',
    color: AppColors.categoryTransfer,
    label: '电费',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'gas-bill',
    assetPath: 'assets/icons/category/gas_bill.svg',
    color: AppColors.categoryTransfer,
    label: '燃气费',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'water-bill',
    assetPath: 'assets/icons/category/water_bill.svg',
    color: AppColors.categoryTransfer,
    label: '水费',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'internet',
    assetPath: 'assets/icons/category/internet.svg',
    color: AppColors.categoryTransfer,
    label: '网络代理',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'tobacco-alcohol',
    assetPath: 'assets/icons/category/tobacco_alcohol.svg',
    color: AppColors.categoryFood,
    label: '烟酒',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'entertainment',
    assetPath: 'assets/icons/category/entertainment.svg',
    color: AppColors.categoryGift,
    label: '游玩',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'elders',
    assetPath: 'assets/icons/category/elders.svg',
    color: AppColors.categorySocial,
    label: '长辈',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'ai-tools',
    assetPath: 'assets/icons/category/ai_tools.svg',
    color: AppColors.categoryGenericNeutral,
    label: 'AI 工具箱',
    usage: BusinessIconUsage.expenseCategory,
  ),
  BusinessIconSpec.svg(
    iconKey: 'haircut',
    assetPath: 'assets/icons/category/haircut.svg',
    color: AppColors.categoryShopping,
    label: '理发',
    usage: BusinessIconUsage.expenseCategory,
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
    label: '工资-1',
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
    label: '工资-2',
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
    iconKey: 'more-2-line',
    icon: RemixIcons.more_2_line,
    color: AppColors.categoryGenericIncome,
    label: '其他-2',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'more-line',
    icon: RemixIcons.more_line,
    color: AppColors.categoryGenericNeutral,
    label: '其他-1',
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
    iconKey: 'icbc',
    assetPath: 'assets/icons/account/icbc.svg',
    color: AppColors.categoryGenericNeutral,
    label: '中国工商银行',
  ),
  BusinessIconSpec.svg(
    iconKey: 'abc',
    assetPath: 'assets/icons/account/abc.svg',
    color: AppColors.categoryGenericNeutral,
    label: '中国农业银行',
  ),
  BusinessIconSpec.svg(
    iconKey: 'ccb',
    assetPath: 'assets/icons/account/ccb.svg',
    color: AppColors.categoryGenericNeutral,
    label: '中国建设银行',
  ),
  BusinessIconSpec.svg(
    iconKey: 'boc_debit_card',
    assetPath: 'assets/icons/account/boc_debit_card.svg',
    color: AppColors.categoryGenericNeutral,
    label: '中国银行',
  ),
  BusinessIconSpec.svg(
    iconKey: 'psbc',
    assetPath: 'assets/icons/account/psbc.svg',
    color: AppColors.categoryGenericNeutral,
    label: '中国邮政储蓄银行',
  ),
  BusinessIconSpec.svg(
    iconKey: 'china_development_bank',
    assetPath: 'assets/icons/account/china_development_bank.svg',
    color: AppColors.categoryGenericNeutral,
    label: '国家开发银行',
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
    iconKey: 'jiebei',
    assetPath: 'assets/icons/account/jiebei.svg',
    color: AppColors.categoryGenericNeutral,
    label: '借呗',
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
  BusinessIconSpec.remix(
    iconKey: 'dessert',
    icon: RemixIcons.cake_line,
    color: AppColors.categorySnack,
    label: '甜品',
  ),
  BusinessIconSpec.remix(
    iconKey: 'fruit',
    icon: RemixIcons.leaf_line,
    color: AppColors.categoryFood,
    label: '水果',
  ),
  BusinessIconSpec.remix(
    iconKey: 'kitchen',
    icon: RemixIcons.fridge_line,
    color: AppColors.categoryHome,
    label: '厨电',
  ),
  BusinessIconSpec.remix(
    iconKey: 'home-repair',
    icon: RemixIcons.tools_line,
    color: AppColors.categoryHome,
    label: '家居维修',
    keywords: ['维修'],
  ),
  BusinessIconSpec.remix(
    iconKey: 'home-appliance',
    icon: RemixIcons.lightbulb_flash_line,
    color: AppColors.categoryHome,
    label: '家电',
  ),
  BusinessIconSpec.remix(
    iconKey: 'home-network',
    icon: RemixIcons.home_wifi_line,
    color: AppColors.categoryHome,
    label: '家庭网络',
    keywords: ['宽带'],
  ),
  BusinessIconSpec.remix(
    iconKey: 'hotel',
    icon: RemixIcons.hotel_line,
    color: AppColors.categoryHome,
    label: '住宿',
  ),
  BusinessIconSpec.remix(
    iconKey: 'property-service',
    icon: RemixIcons.building_4_line,
    color: AppColors.categoryHome,
    label: '房产服务',
    keywords: ['物业'],
  ),
  BusinessIconSpec.remix(
    iconKey: 'subway',
    icon: RemixIcons.subway_line,
    color: AppColors.categoryTransport,
    label: '地铁',
  ),
  BusinessIconSpec.remix(
    iconKey: 'drive',
    icon: RemixIcons.car_line,
    color: AppColors.categoryTransport,
    label: '驾车',
  ),
  BusinessIconSpec.remix(
    iconKey: 'motorbike',
    icon: RemixIcons.motorbike_line,
    color: AppColors.categoryTransport,
    label: '摩托车',
  ),
  BusinessIconSpec.remix(
    iconKey: 'e-bike',
    icon: RemixIcons.e_bike_2_line,
    color: AppColors.categoryTransport,
    label: '电动车',
  ),
  BusinessIconSpec.remix(
    iconKey: 'cycling',
    icon: RemixIcons.riding_line,
    color: AppColors.categoryTransport,
    label: '骑行',
  ),
  BusinessIconSpec.remix(
    iconKey: 'fuel',
    icon: RemixIcons.gas_station_line,
    color: AppColors.categoryTaxi,
    label: '加油',
  ),
  BusinessIconSpec.remix(
    iconKey: 'parking',
    icon: RemixIcons.parking_box_line,
    color: AppColors.categoryTaxi,
    label: '停车',
  ),
  BusinessIconSpec.remix(
    iconKey: 'flight',
    icon: RemixIcons.flight_takeoff_line,
    color: AppColors.categoryTransport,
    label: '飞机',
  ),
  BusinessIconSpec.remix(
    iconKey: 'handbag',
    icon: RemixIcons.handbag_line,
    color: AppColors.categoryShopping,
    label: '箱包',
  ),
  BusinessIconSpec.remix(
    iconKey: 'shopping-cart',
    icon: RemixIcons.shopping_cart_2_line,
    color: AppColors.categoryShopping,
    label: '超市购物',
  ),
  BusinessIconSpec.remix(
    iconKey: 'computer',
    icon: RemixIcons.computer_line,
    color: AppColors.categoryShopping,
    label: '电脑数码',
  ),
  BusinessIconSpec.remix(
    iconKey: 'music',
    icon: RemixIcons.music_2_line,
    color: AppColors.categoryEntertainment,
    label: '音乐',
  ),
  BusinessIconSpec.remix(
    iconKey: 'camera',
    icon: RemixIcons.camera_line,
    color: AppColors.categoryEntertainment,
    label: '摄影',
  ),
  BusinessIconSpec.remix(
    iconKey: 'sport',
    icon: RemixIcons.basketball_line,
    color: AppColors.categoryEntertainment,
    label: '运动健身',
    keywords: ['健身'],
  ),
  BusinessIconSpec.remix(
    iconKey: 'education',
    icon: RemixIcons.graduation_cap_line,
    color: AppColors.categoryReading,
    label: '教育培训',
    keywords: ['培训'],
  ),
  BusinessIconSpec.remix(
    iconKey: 'medicine',
    icon: RemixIcons.medicine_bottle_line,
    color: AppColors.categoryMedical,
    label: '药品',
  ),
  BusinessIconSpec.remix(
    iconKey: 'capsule',
    icon: RemixIcons.capsule_line,
    color: AppColors.categoryMedical,
    label: '保健',
  ),
  BusinessIconSpec.remix(
    iconKey: 'doctor',
    icon: RemixIcons.stethoscope_line,
    color: AppColors.categoryMedical,
    label: '就医',
  ),
  BusinessIconSpec.remix(
    iconKey: 'wifi',
    icon: RemixIcons.wifi_line,
    color: AppColors.categoryGenericNeutral,
    label: '网络服务',
    keywords: ['宽带'],
  ),
  BusinessIconSpec.remix(
    iconKey: 'sim-card',
    icon: RemixIcons.sim_card_line,
    color: AppColors.categoryGenericNeutral,
    label: '话费流量',
  ),
  BusinessIconSpec.remix(
    iconKey: 'red-packet',
    icon: RemixIcons.red_packet_line,
    color: AppColors.categoryGift,
    label: '红包',
  ),
  BusinessIconSpec.remix(
    iconKey: 'gift-box',
    icon: RemixIcons.gift_2_line,
    color: AppColors.categoryGift,
    label: '礼品',
  ),
  BusinessIconSpec.remix(
    iconKey: 'refund-income',
    icon: RemixIcons.refund_2_line,
    color: AppColors.categoryGenericIncome,
    label: '退款收入',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'red-packet-income',
    icon: RemixIcons.red_packet_line,
    color: AppColors.categoryGift,
    label: '红包收入',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'coins-income',
    icon: RemixIcons.coins_line,
    color: AppColors.categorySalary,
    label: '劳务收入',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'rental-income',
    icon: RemixIcons.building_4_line,
    color: AppColors.categoryGenericIncome,
    label: '租金收入',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'sale-income',
    icon: RemixIcons.shopping_cart_2_line,
    color: AppColors.categoryGenericIncome,
    label: '销售收入',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'interest-income',
    icon: RemixIcons.money_cny_box_line,
    color: AppColors.categoryGenericIncome,
    label: '利息收入',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'exchange-income',
    icon: RemixIcons.exchange_dollar_line,
    color: AppColors.categoryGenericIncome,
    label: '汇兑收益',
    usage: BusinessIconUsage.incomeCategory,
  ),
  BusinessIconSpec.remix(
    iconKey: 'bank-card',
    icon: RemixIcons.bank_card_line,
    color: AppColors.categoryGenericNeutral,
    label: '银行卡',
    usage: BusinessIconUsage.account,
  ),
  BusinessIconSpec.remix(
    iconKey: 'credit-card',
    icon: RemixIcons.bank_card_2_line,
    color: AppColors.categoryGenericNeutral,
    label: '信用卡',
    usage: BusinessIconUsage.account,
  ),
  BusinessIconSpec.remix(
    iconKey: 'savings-account',
    icon: RemixIcons.safe_2_line,
    color: AppColors.categoryGenericNeutral,
    label: '储蓄账户',
    usage: BusinessIconUsage.account,
  ),
  BusinessIconSpec.remix(
    iconKey: 'cash-box',
    icon: RemixIcons.money_cny_box_line,
    color: AppColors.categoryGenericNeutral,
    label: '现金储备',
    usage: BusinessIconUsage.account,
  ),
  BusinessIconSpec.remix(
    iconKey: 'digital-wallet',
    icon: RemixIcons.wallet_3_line,
    color: AppColors.categoryGenericNeutral,
    label: '数字钱包',
    usage: BusinessIconUsage.account,
  ),
  BusinessIconSpec.remix(
    iconKey: 'bank-account',
    icon: RemixIcons.bank_line,
    color: AppColors.categoryGenericNeutral,
    label: '银行账户',
    usage: BusinessIconUsage.account,
  ),
  BusinessIconSpec.remix(
    iconKey: 'investment-account',
    icon: RemixIcons.stock_line,
    color: AppColors.categoryGenericNeutral,
    label: '投资账户',
    usage: BusinessIconUsage.account,
  ),
  BusinessIconSpec.remix(
    iconKey: 'securities-account',
    icon: RemixIcons.funds_line,
    color: AppColors.categoryGenericNeutral,
    label: '证券账户',
    usage: BusinessIconUsage.account,
  ),
  BusinessIconSpec.remix(
    iconKey: 'prepaid-card',
    icon: RemixIcons.coupon_2_line,
    color: AppColors.categoryGenericNeutral,
    label: '预付卡',
    usage: BusinessIconUsage.account,
  ),
  BusinessIconSpec.remix(
    iconKey: 'transfer-account',
    icon: RemixIcons.arrow_left_right_line,
    color: AppColors.categoryGenericNeutral,
    label: '转账账户',
    usage: BusinessIconUsage.account,
  ),
  BusinessIconSpec.remix(
    iconKey: 'receivable-account',
    icon: RemixIcons.hand_coin_line,
    color: AppColors.categoryGenericNeutral,
    label: '应收款',
    usage: BusinessIconUsage.account,
  ),
  BusinessIconSpec.remix(
    iconKey: 'loan-account',
    icon: RemixIcons.bank_line,
    color: AppColors.categoryGenericNeutral,
    label: '贷款账户',
    usage: BusinessIconUsage.account,
  ),
  BusinessIconSpec.remix(
    iconKey: 'mortgage-account',
    icon: RemixIcons.home_gear_line,
    color: AppColors.categoryGenericNeutral,
    label: '房贷账户',
    usage: BusinessIconUsage.account,
  ),
  BusinessIconSpec.remix(
    iconKey: 'car-loan-account',
    icon: RemixIcons.car_line,
    color: AppColors.categoryGenericNeutral,
    label: '车贷账户',
    usage: BusinessIconUsage.account,
    keywords: ['车贷'],
  ),
  BusinessIconSpec.remix(
    iconKey: 'cash-reserve',
    icon: RemixIcons.safe_2_line,
    color: AppColors.categoryGenericNeutral,
    label: '备用金',
    usage: BusinessIconUsage.account,
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

List<BusinessIconSpec> searchBusinessIconSpecs({
  required BusinessIconUsage usage,
  String query = '',
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final candidates = businessIconSpecsForUsage(usage);
  if (normalizedQuery.isEmpty) return candidates;

  return List.unmodifiable(
    candidates.where(
      (spec) =>
          spec.iconKey.toLowerCase().contains(normalizedQuery) ||
          spec.label.toLowerCase().contains(normalizedQuery) ||
          spec.keywords.any(
            (keyword) => keyword.toLowerCase().contains(normalizedQuery),
          ),
    ),
  );
}

const _systemFallbackIconSpec = BusinessIconSpec.remix(
  iconKey: 'fallback',
  icon: RemixIcons.remixicon_line,
  color: AppColors.categoryGenericNeutral,
  label: '图标',
  usage: BusinessIconUsage.system,
);

BusinessIconSpec resolveBusinessIconSpec(
  String? iconKey, {
  BusinessIconUsage usage = BusinessIconUsage.expenseCategory,
}) {
  final normalized = normalizeBusinessIconKey(iconKey);
  if (normalized != null && businessIconSpecsByKey.containsKey(normalized)) {
    return businessIconSpecsByKey[normalized]!;
  }
  return switch (usage) {
    BusinessIconUsage.account => businessIconSpecsByKey['bank-account']!,
    BusinessIconUsage.incomeCategory => businessIconSpecsByKey['more-2-line']!,
    BusinessIconUsage.expenseCategory => businessIconSpecsByKey['more-line']!,
    BusinessIconUsage.system => _systemFallbackIconSpec,
  };
}

String? normalizeBusinessIconKey(String? iconKey) {
  final trimmed = iconKey?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
