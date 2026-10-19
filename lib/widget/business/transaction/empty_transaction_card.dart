import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import 'package:smartflow/design_system/widget/app_empty_state.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';

class EmptyTransactionCard extends StatelessWidget {
  const EmptyTransactionCard({super.key, this.message = '本月暂无交易记录'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: AppEmptyState(
        layout: AppEmptyStateLayout.inline,
        icon: const Icon(RemixIcons.file_list_3_line),
        title: message,
      ),
    );
  }
}
