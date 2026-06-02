import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const fontFamily = 'HarmonyOS Sans SC';

  static const fontFamilyFallback = <String>[
    'HarmonyOS Sans',
    'Roboto',
    'Noto Sans CJK SC',
    'Microsoft YaHei',
  ];

  static const double fontSizeXs = 12;
  static const double fontSizeSm = 14;
  static const double fontSizeMd = 15;
  static const double fontSizeLgCompact = 18;
  static const double fontSizeLg = 20;
  static const double fontSizeXl = 22;
  static const double fontSize2xl = 24;

  static const double fontSizeTiny = 10;
  static const double fontSizeCompact = 11;
  static const double fontSizeMicro = 8;

  static const titleWeight = FontWeight.w600;
  static const bodyWeight = FontWeight.w400;
  static const emphasisWeight = FontWeight.w500;
  static const strongWeight = FontWeight.w700;
}
