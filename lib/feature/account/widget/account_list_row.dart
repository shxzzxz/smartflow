import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../widget/business/finance/money_text.dart';
import '../../../widget/business/icon/business_icon.dart';
import '../../../widget/business/icon/business_icon_bubble.dart';
import '../view_model/account_view.dart';

class AccountListRow extends StatelessWidget {
  const AccountListRow({
    required this.account,
    required this.amountSemantic,
    required this.onTap,
    required this.trailing,
    super.key,
    this.hideBalance = false,
  });

  final AccountView account;
  final MoneySemantic amountSemantic;
  final VoidCallback onTap;
  final Widget trailing;
  final bool hideBalance;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    final supportingText = _creditDateText(account);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.space48 + AppSpacing.space8,
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.space8,
              top: AppSpacing.space4,
              bottom: AppSpacing.space4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BusinessIconBubble(
                  size: AppSpacing.space32,
                  child: BusinessIcon(
                    iconKey: account.iconKey,
                    size: AppSpacing.space28,
                    usage: BusinessIconUsage.account,
                  ),
                ),
                const SizedBox(width: AppSpacing.space14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyles.listTitle,
                      ),
                      if (supportingText.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.space2),
                        Text(
                          supportingText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyles.listSupporting.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.space12),
                AccountAmountText(
                  money: account.balance,
                  semantic: amountSemantic,
                  hidden: hideBalance,
                ),
                const SizedBox(width: AppSpacing.space4),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AccountAmountText extends StatelessWidget {
  const AccountAmountText({
    required this.money,
    required this.semantic,
    super.key,
    this.hidden = false,
    this.showSign = false,
  });

  final Money money;
  final MoneySemantic semantic;
  final bool hidden;
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.space48 * 2,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child:
            hidden
                ? Text('¥ ****', style: context.appTextStyles.amountList)
                : MoneyText(
                  money: money,
                  showSign: showSign,
                  semantic: semantic,
                  style: context.appTextStyles.amountList,
                ),
      ),
    );
  }
}

String _creditDateText(AccountView account) {
  final parts = <String>[];
  if (account.billingDay != null) {
    parts.add('出账日 ${account.billingDay}');
  }
  if (account.repaymentDay != null) {
    parts.add('还款日 ${account.repaymentDay}');
  }
  return parts.join('   ');
}
