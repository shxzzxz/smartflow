import 'package:flutter/material.dart';

import 'package:smartflow/design_system/token/spacing.dart';

import '../icon/business_icon.dart';
import 'account_endpoint.dart';

class AccountEndpointView extends StatelessWidget {
  const AccountEndpointView({
    required this.endpoint,
    this.style,
    this.iconSize = 14,
    this.iconLabelSpacing = AppSpacing.space4,
    this.textAlign = TextAlign.right,
    this.mainAxisAlignment = MainAxisAlignment.end,
    super.key,
  });

  const AccountEndpointView.compactLeading({
    required this.endpoint,
    this.style,
    this.iconSize = 14,
    super.key,
  }) : iconLabelSpacing = AppSpacing.space2,
       textAlign = TextAlign.left,
       mainAxisAlignment = MainAxisAlignment.start;

  const AccountEndpointView.compactTrailing({
    required this.endpoint,
    this.style,
    this.iconSize = 14,
    super.key,
  }) : iconLabelSpacing = AppSpacing.space2,
       textAlign = TextAlign.right,
       mainAxisAlignment = MainAxisAlignment.end;

  final AccountEndpoint endpoint;
  final TextStyle? style;
  final double iconSize;
  final double iconLabelSpacing;
  final TextAlign textAlign;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: iconSize,
          child: Center(
            child: BusinessIcon(
              iconKey: endpoint.iconKey,
              size: iconSize,
              usage: BusinessIconUsage.account,
            ),
          ),
        ),
        SizedBox(width: iconLabelSpacing),
        Flexible(
          child: Text(
            endpoint.label,
            textAlign: textAlign,
            style: style,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
