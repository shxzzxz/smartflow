/// 页面背景效果，使用稳定的文本值持久化。
enum AppBackgroundStyle {
  solid(storageValue: 'solid'),
  singleGlow(storageValue: 'single_glow'),
  multiGlow(storageValue: 'multi_glow');

  const AppBackgroundStyle({required this.storageValue});

  final String storageValue;

  static AppBackgroundStyle? fromStorageValue(String? value) => switch (value) {
    'solid' => solid,
    'single_glow' => singleGlow,
    'multi_glow' => multiGlow,
    _ => null,
  };
}

/// 用户选定的色值及背景参数，不依赖 Flutter 的 Color 或 ThemeData。
/// 色值 0 和渐变参数 -1 表示未覆盖，具体默认值由设计系统解析。
class AppAppearanceSettings {
  static const int useDefaultColor = 0;
  static const double useDefaultGradient = -1;

  const AppAppearanceSettings({
    this.primaryColor = useDefaultColor,
    this.backgroundSeedColor = useDefaultColor,
    this.incomeColor = useDefaultColor,
    this.expenseColor = useDefaultColor,
    this.backgroundStyle = AppBackgroundStyle.multiGlow,
    this.gradientDepth = useDefaultGradient,
    this.gradientRange = useDefaultGradient,
  }) : assert(
         primaryColor == useDefaultColor ||
             (primaryColor >= 0xFF000000 && primaryColor <= 0xFFFFFFFF),
       ),
       assert(
         backgroundSeedColor == useDefaultColor ||
             (backgroundSeedColor >= 0xFF000000 &&
                 backgroundSeedColor <= 0xFFFFFFFF),
       ),
       assert(
         incomeColor == useDefaultColor ||
             (incomeColor >= 0xFF000000 && incomeColor <= 0xFFFFFFFF),
       ),
       assert(
         expenseColor == useDefaultColor ||
             (expenseColor >= 0xFF000000 && expenseColor <= 0xFFFFFFFF),
       ),
       assert(
         gradientDepth == useDefaultGradient ||
             (gradientDepth >= 0 && gradientDepth <= 1),
       ),
       assert(
         gradientRange == useDefaultGradient ||
             (gradientRange >= 0 && gradientRange <= 1),
       );

  factory AppAppearanceSettings.fromJson(Map<String, dynamic> json) {
    const defaults = AppAppearanceSettings();
    int color(String key, int fallback) {
      final value = json[key];
      return value is int &&
              (value == useDefaultColor ||
                  (value >= 0xFF000000 && value <= 0xFFFFFFFF))
          ? value
          : fallback;
    }

    double fraction(String key, double fallback) {
      final value = json[key];
      if (value == useDefaultGradient) return useDefaultGradient;
      return value is num && value.isFinite
          ? value.toDouble().clamp(0, 1).toDouble()
          : fallback;
    }

    final primaryColor = color('primaryColor', defaults.primaryColor);
    final storedStyle = json['backgroundStyle'];
    return AppAppearanceSettings(
      primaryColor: primaryColor,
      // 旧配置没有独立背景基色，首次读取时承接原主题色。
      backgroundSeedColor: color(
        'backgroundSeedColor',
        json.containsKey('backgroundSeedColor')
            ? defaults.backgroundSeedColor
            : primaryColor,
      ),
      incomeColor: color('incomeColor', defaults.incomeColor),
      expenseColor: color('expenseColor', defaults.expenseColor),
      backgroundStyle:
          AppBackgroundStyle.fromStorageValue(
            storedStyle is String ? storedStyle : null,
          ) ??
          defaults.backgroundStyle,
      gradientDepth: fraction('gradientDepth', defaults.gradientDepth),
      gradientRange: fraction('gradientRange', defaults.gradientRange),
    );
  }

  final int primaryColor;
  final int backgroundSeedColor;
  final int incomeColor;
  final int expenseColor;
  final AppBackgroundStyle backgroundStyle;
  final double gradientDepth;
  final double gradientRange;

  AppAppearanceSettings copyWith({
    int? primaryColor,
    int? backgroundSeedColor,
    int? incomeColor,
    int? expenseColor,
    AppBackgroundStyle? backgroundStyle,
    double? gradientDepth,
    double? gradientRange,
  }) {
    return AppAppearanceSettings(
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundSeedColor: backgroundSeedColor ?? this.backgroundSeedColor,
      incomeColor: incomeColor ?? this.incomeColor,
      expenseColor: expenseColor ?? this.expenseColor,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      gradientDepth: gradientDepth ?? this.gradientDepth,
      gradientRange: gradientRange ?? this.gradientRange,
    );
  }

  Map<String, Object> toJson() => {
    'primaryColor': primaryColor,
    'backgroundSeedColor': backgroundSeedColor,
    'incomeColor': incomeColor,
    'expenseColor': expenseColor,
    'backgroundStyle': backgroundStyle.storageValue,
    'gradientDepth': gradientDepth,
    'gradientRange': gradientRange,
  };

  @override
  bool operator ==(Object other) =>
      other is AppAppearanceSettings &&
      primaryColor == other.primaryColor &&
      backgroundSeedColor == other.backgroundSeedColor &&
      incomeColor == other.incomeColor &&
      expenseColor == other.expenseColor &&
      backgroundStyle == other.backgroundStyle &&
      gradientDepth == other.gradientDepth &&
      gradientRange == other.gradientRange;

  @override
  int get hashCode => Object.hash(
    primaryColor,
    backgroundSeedColor,
    incomeColor,
    expenseColor,
    backgroundStyle,
    gradientDepth,
    gradientRange,
  );
}
