import 'package:flutter/material.dart';

import 'package:smartflow/design_system/token/spacing.dart';

import '../icon/business_icon.dart';
import 'account_endpoint.dart';

class AccountEndpointView extends StatelessWidget {
  const AccountEndpointView({
    required this.endpoint,
    this.style,
    this.iconSize = 14,
    this.textAlign = TextAlign.right,
    super.key,
  });

  final AccountEndpoint endpoint;
  final TextStyle? style;
  final double iconSize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: iconSize,
          child: Center(
            child: BusinessIcon(iconKey: endpoint.iconKey, size: iconSize),
          ),
        ),
        const SizedBox(width: AppSpacing.space4),
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
