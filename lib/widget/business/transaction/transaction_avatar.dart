import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';

import '../category/category_avatar.dart';
import '../icon/business_icon_bubble.dart';

/// Category artwork describes income/expense; fixed icons describe other events.
class TransactionAvatar extends StatelessWidget {
  const TransactionAvatar({
    required this.businessPurpose,
    required this.iconKey,
    super.key,
    this.size = 32,
    this.hasMultipleCategories = false,
  });

  final BusinessPurpose businessPurpose;
  final String? iconKey;
  final double size;
  final bool hasMultipleCategories;

  @override
  Widget build(BuildContext context) {
    final icon = switch (businessPurpose) {
      BusinessPurpose.dailyExpense ||
      BusinessPurpose.dailyIncome ||
      BusinessPurpose.reimbursementAdvance =>
        hasMultipleCategories ? RemixIcons.layout_grid_line : null,
      BusinessPurpose.transfer => RemixIcons.arrow_left_right_line,
      BusinessPurpose.lending => RemixIcons.logout_box_r_line,
      BusinessPurpose.borrowing => RemixIcons.hand_coin_line,
      BusinessPurpose.debtRepayment => RemixIcons.refund_2_line,
      BusinessPurpose.receivableCollection => RemixIcons.login_box_line,
      BusinessPurpose.badDebt => RemixIcons.close_circle_line,
      BusinessPurpose.debtRelief => RemixIcons.hand_heart_line,
      BusinessPurpose.openingBalance => RemixIcons.wallet_line,
      BusinessPurpose.balanceAdjustment => RemixIcons.scales_3_line,
      BusinessPurpose.refund => RemixIcons.refund_line,
      BusinessPurpose.reimbursementReceipt => RemixIcons.money_cny_circle_line,
      BusinessPurpose.reimbursementClose => RemixIcons.check_double_line,
    };
    if (icon == null) {
      return CategoryAvatar(iconKey: iconKey, size: size);
    }
    return BusinessIconBubble(
      size: size,
      child: Icon(icon, size: size * 0.7),
    );
  }
}
