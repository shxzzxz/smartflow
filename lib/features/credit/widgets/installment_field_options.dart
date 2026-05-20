import 'package:flutter/material.dart';

import '../../../domain/credit/enums/installment_enums.dart';

const List<DropdownMenuItem<InstallmentRepaymentMethod>>
    installmentRepaymentMethodItems = [
  DropdownMenuItem(
    value: InstallmentRepaymentMethod.equalInstallment,
    child: Text('等额本息'),
  ),
  DropdownMenuItem(
    value: InstallmentRepaymentMethod.equalPrincipal,
    child: Text('等额本金'),
  ),
  DropdownMenuItem(
    value: InstallmentRepaymentMethod.interestFirst,
    child: Text('先息后本'),
  ),
  DropdownMenuItem(
    value: InstallmentRepaymentMethod.flatFee,
    child: Text('一次性手续费'),
  ),
  DropdownMenuItem(
    value: InstallmentRepaymentMethod.custom,
    child: Text('自定义'),
  ),
];

const List<DropdownMenuItem<InterestRatePeriod>> interestRatePeriodItems = [
  DropdownMenuItem(value: InterestRatePeriod.annual, child: Text('年')),
  DropdownMenuItem(value: InterestRatePeriod.monthly, child: Text('月')),
  DropdownMenuItem(value: InterestRatePeriod.daily, child: Text('日')),
];

const List<DropdownMenuItem<InterestAccrualMethod>>
    interestAccrualMethodItems = [
  DropdownMenuItem(
    value: InterestAccrualMethod.daily,
    child: Text('按日计息'),
  ),
  DropdownMenuItem(
    value: InterestAccrualMethod.monthly,
    child: Text('按月计息'),
  ),
];
