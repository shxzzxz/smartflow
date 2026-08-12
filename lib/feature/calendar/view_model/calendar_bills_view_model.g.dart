// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_bills_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(calendarDayBillsViewModel)
final calendarDayBillsViewModelProvider = CalendarDayBillsViewModelFamily._();

final class CalendarDayBillsViewModelProvider
    extends
        $FunctionalProvider<
          CalendarBillsPageState,
          CalendarBillsPageState,
          CalendarBillsPageState
        >
    with $Provider<CalendarBillsPageState> {
  CalendarDayBillsViewModelProvider._({
    required CalendarDayBillsViewModelFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'calendarDayBillsViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$calendarDayBillsViewModelHash();

  @override
  String toString() {
    return r'calendarDayBillsViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<CalendarBillsPageState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CalendarBillsPageState create(Ref ref) {
    final argument = this.argument as DateTime;
    return calendarDayBillsViewModel(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarBillsPageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarBillsPageState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarDayBillsViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$calendarDayBillsViewModelHash() =>
    r'2bd185969bee9ac6b4dacc47a7e780bcc0c3ebed';

final class CalendarDayBillsViewModelFamily extends $Family
    with $FunctionalFamilyOverride<CalendarBillsPageState, DateTime> {
  CalendarDayBillsViewModelFamily._()
    : super(
        retry: null,
        name: r'calendarDayBillsViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CalendarDayBillsViewModelProvider call(DateTime date) =>
      CalendarDayBillsViewModelProvider._(argument: date, from: this);

  @override
  String toString() => r'calendarDayBillsViewModelProvider';
}

@ProviderFor(calendarMonthBillsViewModel)
final calendarMonthBillsViewModelProvider =
    CalendarMonthBillsViewModelFamily._();

final class CalendarMonthBillsViewModelProvider
    extends
        $FunctionalProvider<
          CalendarBillsPageState,
          CalendarBillsPageState,
          CalendarBillsPageState
        >
    with $Provider<CalendarBillsPageState> {
  CalendarMonthBillsViewModelProvider._({
    required CalendarMonthBillsViewModelFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'calendarMonthBillsViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$calendarMonthBillsViewModelHash();

  @override
  String toString() {
    return r'calendarMonthBillsViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<CalendarBillsPageState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CalendarBillsPageState create(Ref ref) {
    final argument = this.argument as DateTime;
    return calendarMonthBillsViewModel(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarBillsPageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarBillsPageState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarMonthBillsViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$calendarMonthBillsViewModelHash() =>
    r'905ec4db9b660a003ad818399230b09511b454d0';

final class CalendarMonthBillsViewModelFamily extends $Family
    with $FunctionalFamilyOverride<CalendarBillsPageState, DateTime> {
  CalendarMonthBillsViewModelFamily._()
    : super(
        retry: null,
        name: r'calendarMonthBillsViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CalendarMonthBillsViewModelProvider call(DateTime month) =>
      CalendarMonthBillsViewModelProvider._(argument: month, from: this);

  @override
  String toString() => r'calendarMonthBillsViewModelProvider';
}
