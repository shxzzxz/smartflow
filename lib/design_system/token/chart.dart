abstract final class AppChartGeometry {
  static const double primaryPlotHeight = 180;
  static const double secondaryPlotHeight = 148;
  static const double donutPlotHeight = 176;
  static const double emptyStateHeight = 120;
  static const double barWidthMin = 1;
  static const double barWidthMax = 14;
  static const double barWidthRatio = .48;
  static const double groupedBarGap = 2;
  static const double lineWidth = 2;
  static const double lineDotRadius = 4;
  static const double lineDotStrokeWidth = 2;
  static const double gridLineWidth = 1;
  static const double gridLineOpacity = .45;
  static const double zeroLineOpacity = .9;
  static const double areaFillOpacity = .10;
  static const double hiddenLegendMarkerOpacity = .35;
  static const double hiddenLegendLabelOpacity = .55;
  static const double pieCenterRadius = 44;
  static const double pieSectionRadius = 36;
  static const double pieSelectedSectionBump = 4;
  static const double categoryMarkerRadius = 6;
  static const double categoryProgressHeight = 4;
  static const double leftAxisReservedWidth = 60;
  static const double leftAxisMinReservedWidth = 20;
  static const double leftAxisLabelGap = 6;
  static const double interactiveLegendReservedHeight = 36;
  static const double expandIconSize = 18;
  static const double chartCardHorizontalPadding = 16;
  static const double chartCardHeaderTopPadding = 12;
  static const double chartCardHeaderBottomPadding = 12;
  static const double chartCardHeaderToPlotGap = 8;
  static const double chartCardPlotBottomPadding = 8;
  static const double expandButtonVisualSize = 32;
  static const double expandButtonHitSize = 44;
  static const double legendItemHeight = 32;
  static const double bottomAxisBaseReservedHeight = 28;
  static const int cashflowAxisLabelLimit = 5;
  static const int trendAxisLabelLimit = 4;
  static const int weekdayAxisLabelLimit = 7;
}

abstract final class AppChartMotion {
  static const Duration switchDuration = Duration(milliseconds: 250);
}

/// 热力底色透明度区间。强度按 0..1 线性映射到 [minAlpha, maxAlpha]。
/// 上限保持在浅色区间，避免格子铺成实色块压掉格内文字。
abstract final class AppHeatScale {
  static const double minAlpha = .08;
  static const double maxAlpha = .42;

  static double alphaForIntensity(double intensity) {
    return minAlpha + (maxAlpha - minAlpha) * intensity.clamp(0.0, 1.0);
  }
}
