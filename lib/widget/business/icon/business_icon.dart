import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logging/logging.dart';
import 'package:remixicon/remixicon.dart';

import 'business_icon_scope.dart';

export 'business_icon_scope.dart';

final _logger = Logger('widget.business.icon');

class BusinessIcon extends StatefulWidget {
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
  State<BusinessIcon> createState() => _BusinessIconState();
}

class _BusinessIconState extends State<BusinessIcon> {
  (String, Object, StackTrace)? _lastLoggedFailure;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground =
        widget.color ?? IconTheme.of(context).color ?? colors.onSurfaceVariant;
    final spec = BusinessIconScope.of(
      context,
    ).resolve(widget.iconKey, widget.usage);
    Widget fallback() => Icon(
      switch (widget.usage) {
        BusinessIconUsage.account => RemixIcons.bank_line,
        BusinessIconUsage.incomeCategory => RemixIcons.more_2_line,
        BusinessIconUsage.expenseCategory => RemixIcons.more_line,
        BusinessIconUsage.system => RemixIcons.remixicon_line,
      },
      size: widget.size,
      color: foreground,
    );
    if (spec == null) return fallback();
    final tint = switch (spec.color) {
      BusinessIconColor.original => null,
      BusinessIconColor.foreground => foreground,
      BusinessIconColor.primary => widget.color ?? colors.primary,
    };
    return SvgPicture.asset(
      spec.assetPath,
      key: ValueKey(spec.assetPath),
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      colorFilter: tint == null
          ? null
          : ColorFilter.mode(tint, BlendMode.srcIn),
      errorBuilder: (context, error, stackTrace) {
        final failure = (spec.assetPath, error, stackTrace);
        if (_lastLoggedFailure != failure) {
          _lastLoggedFailure = failure;
          _logger.warning(
            'Failed to load business icon ${spec.assetPath}; using fallback.',
            error,
            stackTrace,
          );
        }
        return fallback();
      },
    );
  }
}
