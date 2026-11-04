import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'transaction_avatar_kind.dart';

import '../category/category_avatar.dart';
import '../icon/business_icon_bubble.dart';

/// Category artwork describes income/expense; fixed icons describe other events.
class TransactionAvatar extends StatelessWidget {
  const TransactionAvatar({
    required this.businessPurpose,
    required this.iconKey,
    super.key,
    this.size = 32,
    this.iconSize,
    this.hasMultipleCategories = false,
    this.preferCategoryArtwork = false,
    this.kind,
  });

  final BusinessPurpose businessPurpose;
  final String? iconKey;
  final double size;
  final double? iconSize;
  final bool hasMultipleCategories;
  final bool preferCategoryArtwork;
  final TransactionAvatarKind? kind;

  @override
  Widget build(BuildContext context) {
    if (kind case final kind?) {
      final icon = switch (kind) {
        TransactionAvatarKind.advanceCollection =>
          RemixIcons.money_cny_circle_line,
        TransactionAvatarKind.advanceSettlement => RemixIcons.check_double_line,
        TransactionAvatarKind.refund => RemixIcons.refund_line,
        TransactionAvatarKind.amortizationRecognition =>
          RemixIcons.calendar_check_line,
        TransactionAvatarKind.amortizationRefund => RemixIcons.refund_2_line,
        TransactionAvatarKind.amortizationTermination =>
          RemixIcons.stop_circle_line,
      };
      return BusinessIconBubble(
        size: size,
        child: Icon(icon, size: iconSize ?? size * 0.7),
      );
    }
    if (preferCategoryArtwork) {
      if (hasMultipleCategories) {
        return BusinessIconBubble(
          size: size,
          child: Icon(
            RemixIcons.layout_grid_line,
            size: iconSize ?? size * 0.7,
          ),
        );
      }
      if (iconKey != null) {
        return CategoryAvatar(iconKey: iconKey, size: size, iconSize: iconSize);
      }
    }

    final icon = switch (businessPurpose) {
      BusinessPurpose.dailyExpense ||
      BusinessPurpose.dailyIncome ||
      BusinessPurpose.advance =>
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
      BusinessPurpose.advanceCollection => RemixIcons.money_cny_circle_line,
      BusinessPurpose.advanceSettlement => RemixIcons.check_double_line,
    };
    if (icon == null) {
      return CategoryAvatar(iconKey: iconKey, size: size, iconSize: iconSize);
    }
    return BusinessIconBubble(
      size: size,
      child: Icon(icon, size: iconSize ?? size * 0.7),
    );
  }
}
