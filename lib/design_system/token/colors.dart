import 'package:flutter/material.dart';

abstract final class AppColors {
  static const brand = Color(0xFF1677FF);
  static const brandDark = Color(0xFF9CCAFF);

  static const neutral10 = Color(0xFF101827);
  static const neutral20 = Color(0xFF3F4A5F);
  static const neutral90 = Color(0xFFE6EAF0);
  static const neutral95 = Color(0xFFFAFAFA);
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
}
