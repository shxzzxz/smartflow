/// 用户覆盖的玻璃参数；-1 表示沿用设计系统默认值。
class AppGlassSettings {
  static const double useDefault = -1;

  const AppGlassSettings({
    this.blurSigma = useDefault,
    this.backgroundOpacity = useDefault,
    this.saturation = useDefault,
    this.shadowOpacity = useDefault,
  }) : assert(blurSigma == useDefault || blurSigma >= 0),
       assert(
         backgroundOpacity == useDefault ||
             (backgroundOpacity >= 0 && backgroundOpacity <= 1),
       ),
       assert(saturation == useDefault || saturation >= 0),
       assert(
         shadowOpacity == useDefault ||
             (shadowOpacity >= 0 && shadowOpacity <= 1),
       );

  factory AppGlassSettings.fromJson(Object? json) {
    if (json is! Map) return const AppGlassSettings();
    double number(String key, {double maximum = double.infinity}) {
      final value = json[key];
      if (value == useDefault) return useDefault;
      return value is num && value.isFinite
          ? value.toDouble().clamp(0, maximum).toDouble()
          : useDefault;
    }

    return AppGlassSettings(
      blurSigma: number('blurSigma'),
      backgroundOpacity: number('backgroundOpacity', maximum: 1),
      saturation: number('saturation'),
      shadowOpacity: number('shadowOpacity', maximum: 1),
    );
  }

  final double blurSigma;
  final double backgroundOpacity;
  final double saturation;
  final double shadowOpacity;

  AppGlassSettings copyWith({
    double? blurSigma,
    double? backgroundOpacity,
    double? saturation,
    double? shadowOpacity,
  }) => AppGlassSettings(
    blurSigma: blurSigma ?? this.blurSigma,
    backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    saturation: saturation ?? this.saturation,
    shadowOpacity: shadowOpacity ?? this.shadowOpacity,
  );

  Map<String, Object> toJson() => {
    'blurSigma': blurSigma,
    'backgroundOpacity': backgroundOpacity,
    'saturation': saturation,
    'shadowOpacity': shadowOpacity,
  };

  @override
  bool operator ==(Object other) =>
      other is AppGlassSettings &&
      blurSigma == other.blurSigma &&
      backgroundOpacity == other.backgroundOpacity &&
      saturation == other.saturation &&
      shadowOpacity == other.shadowOpacity;

  @override
  int get hashCode =>
      Object.hash(blurSigma, backgroundOpacity, saturation, shadowOpacity);
}
