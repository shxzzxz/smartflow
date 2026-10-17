import 'package:flutter/material.dart';

import '../icon/business_icon.dart';
import '../icon/business_icon_bubble.dart';

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    required this.iconKey,
    super.key,
    this.size = 32,
    this.iconSize,
  });

  final String? iconKey;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return BusinessIconBubble(
      size: size,
      child: BusinessIcon(iconKey: iconKey, size: iconSize ?? size * 0.7),
    );
  }
}
