import 'package:remixicon/remixicon.dart';

import '../../../design_system/widget/app_page_header.dart';

class LoanCalculatorActionButton extends AppHeaderIconButton {
  const LoanCalculatorActionButton.compare({
    required super.onPressed,
    super.key,
  }) : super(icon: RemixIcons.scales_3_line, tooltip: '比较');

  const LoanCalculatorActionButton.change({required super.onPressed, super.key})
    : super(icon: RemixIcons.calendar_check_line, tooltip: '变更');
}
