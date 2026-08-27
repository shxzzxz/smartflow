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

class AccountEndpointGroupView extends StatelessWidget {
  const AccountEndpointGroupView({
    required this.endpoints,
    super.key,
    this.style,
    this.iconSize = 14,
    this.maxVisibleIcons = 4,
  });

  final List<AccountEndpoint> endpoints;
  final TextStyle? style;
  final double iconSize;
  final int maxVisibleIcons;

  @override
  Widget build(BuildContext context) {
    if (endpoints.length <= 1) {
      return AccountEndpointView.compactTrailing(
        endpoint: endpoints.isEmpty
            ? const AccountEndpoint(label: '无账户', iconKey: null)
            : endpoints.single,
        style: style,
        iconSize: iconSize,
      );
    }

    final visible = endpoints.take(maxVisibleIcons).toList(growable: false);
    final hiddenCount = endpoints.length - visible.length;
    return Semantics(
      label: endpoints.map((endpoint) => endpoint.label).join('、'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (var index = 0; index < visible.length; index++) ...[
            if (index > 0) const SizedBox(width: AppSpacing.space4),
            Tooltip(
              message: visible[index].label,
              child: BusinessIcon(
                iconKey: visible[index].iconKey,
                size: iconSize,
                usage: BusinessIconUsage.account,
              ),
            ),
          ],
          if (hiddenCount > 0) ...[
            const SizedBox(width: AppSpacing.space4),
            Text('+$hiddenCount', style: style),
          ],
        ],
      ),
    );
  }
}
