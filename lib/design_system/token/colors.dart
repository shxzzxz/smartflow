import 'package:flutter/material.dart';

abstract final class AppColors {
  static const brand = Color(0xFF1677FF);
  static const brandDark = Color(0xFF9CCAFF);

  static const neutral10 = Color(0xFF101827);
  static const neutral20 = Color(0xFF3F4A5F);
  static const neutral90 = Color(0xFFE6EAF0);
  static const neutral95 = Color(0xFFF6F8FC);
  static const neutral99 = Color(0xFFFFFFFF);

  static const success = Color(0xFF19B35C);
  static const warning = Color(0xFFB26A00);
  static const danger = Color(0xFFFF3045);
  static const info = Color(0xFF1677FF);

  static const income = Color(0xFF00B85C);
  static const expense = Color(0xFFFF2B2B);
  static const transfer = Color(0xFF1677FF);
  static const asset = Color(0xFF1677FF);
  static const liability = Color(0xFF8E3B46);
  static const equity = Color(0xFF7862B8);

  // 类别强调色（用于 CategoryAvatar 等业务组件）。
  // 同色值不同语义即不同 token。
  static const categoryFood = Color(0xFF00B85C);
  static const categoryDining = Color(0xFF9254DE);
  static const categoryShopping = Color(0xFFFF4D4F);
  static const categoryTransport = Color(0xFF1890FF);
  static const categoryTaxi = Color(0xFFFF7A45);
  static const categoryReading = Color(0xFF1890FF);
  static const categoryEntertainment = Color(0xFFFFC53D);
  static const categorySalary = Color(0xFFFFA940);
  static const categoryLoan = Color(0xFF8E3B46);
  static const categoryTransfer = Color(0xFF1677FF);
  static const categoryHome = Color(0xFF8E54DE);
  static const categorySocial = Color(0xFF2F80ED);
  static const categorySnack = Color(0xFFBB4DE8);
  static const categorySeafood = Color(0xFFFF3045);
  static const categoryMedical = Color(0xFFFF3B4F);
  static const categoryGift = Color(0xFFFF9800);
  static const categoryGenericExpense = Color(0xFFFF4D4F);
  static const categoryGenericIncome = Color(0xFF00B85C);
  static const categoryGenericNeutral = Color(0xFF8C8C8C);

  // 系列图表色：亮/暗各 8 槽位，同一组色相分别对实际表面色取阶。
  // 顺序是色盲可分性校验的一部分，调整色值或顺序后必须重新校验。
  static const chart1 = Color(0xFF2A78D6);
  static const chart2 = Color(0xFFEB6834);
  static const chart3 = Color(0xFF1BAF7A);
  static const chart4 = Color(0xFFEDA100);
  static const chart5 = Color(0xFFE87BA4);
  static const chart6 = Color(0xFF008300);
  static const chart7 = Color(0xFF4A3AA7);
  static const chart8 = Color(0xFFE34948);
  static const chartOther = Color(0xFF8C929E);
  static const chart1Dark = Color(0xFF3987E5);
  static const chart2Dark = Color(0xFFD95926);
  static const chart3Dark = Color(0xFF199E70);
  static const chart4Dark = Color(0xFFC98500);
  static const chart5Dark = Color(0xFFD55181);
  static const chart6Dark = Color(0xFF008300);
  static const chart7Dark = Color(0xFF9085E9);
  static const chart8Dark = Color(0xFFE66767);
  static const chartOtherDark = Color(0xFF7A818C);
}
