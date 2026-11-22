import 'package:flutter/material.dart';

import '../../../application/insurance/insurance_query_api.dart';

class MemberAvatarView extends StatelessWidget {
  const MemberAvatarView({
    required this.preset,
    super.key,
    this.size = 48,
    this.selected = false,
  });

  final MemberAvatarPreset preset;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: '${preset.label}头像',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(selected ? 3 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: selected ? Border.all(color: colors.primary, width: 2) : null,
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/insurance/member_avatar/${preset.name}.png',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}
