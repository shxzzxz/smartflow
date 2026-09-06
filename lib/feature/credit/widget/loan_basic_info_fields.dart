import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../../widget/business/form/plain_transaction_fields.dart';

/// 本金和借款日；账户、放款与账单上下文由所在页面组合。
class LoanBasicInfoFields extends StatelessWidget {
  const LoanBasicInfoFields({
    required TextEditingController principalController,
    required this.borrowingDate,
    required ValueChanged<DateTime> onBorrowingDateChanged,
    this.onPrincipalChanged,
    super.key,
  }) : principalController = principalController,
       onBorrowingDateChanged = onBorrowingDateChanged,
       principal = null;

  const LoanBasicInfoFields.readOnly({
    required Money principal,
    required this.borrowingDate,
    super.key,
  }) : principal = principal,
       principalController = null,
       onBorrowingDateChanged = null,
       onPrincipalChanged = null;

  final TextEditingController? principalController;
  final Money? principal;
  final DateTime borrowingDate;
  final ValueChanged<DateTime>? onBorrowingDateChanged;
  final ValueChanged<String>? onPrincipalChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (principalController case final controller?)
        MoneyPlainFormRow(
          label: '本金',
          controller: controller,
          hintText: '请输入借款本金',
          validator: validatePositiveMoneyText,
          onChanged: onPrincipalChanged,
        )
      else
        AppPlainValueRow(label: '本金', value: principal!.format()),
      if (onBorrowingDateChanged case final onChanged?)
        DateTimePlainFormRow(
          label: '借款日期',
          dateTime: borrowingDate,
          value: formatDateLabel(borrowingDate),
          onTap: (onSelected) async {
            final date = await showAppDatePicker(
              context: context,
              initialDate: borrowingDate,
              title: '选择借款日期',
            );
            if (context.mounted && date != null) onSelected(date);
          },
          onChanged: (date) {
            if (date != null) onChanged(date);
          },
        )
      else
        AppPlainValueRow(label: '借款日期', value: formatDateLabel(borrowingDate)),
    ],
  );
}
