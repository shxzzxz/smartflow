import 'package:flutter/material.dart';

import '../icon/business_icon.dart';
import '../icon/business_icon_bubble.dart';

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({required this.iconKey, super.key, this.size = 32});

  final String? iconKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    return BusinessIconBubble(
      size: size,
      child: BusinessIcon(iconKey: iconKey, size: size * 0.7),
    );
  }
}
