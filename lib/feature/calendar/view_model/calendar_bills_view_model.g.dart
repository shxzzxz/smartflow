// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_bills_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CalendarDayBillsViewModel)
final calendarDayBillsViewModelProvider = CalendarDayBillsViewModelFamily._();

final class CalendarDayBillsViewModelProvider
    extends
        $NotifierProvider<CalendarDayBillsViewModel, CalendarBillsPageState> {
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
  CalendarDayBillsViewModel create() => CalendarDayBillsViewModel();

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
    r'53dbf6f16490789de1e1ee01e717831dc4a5b7f0';

final class CalendarDayBillsViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          CalendarDayBillsViewModel,
          CalendarBillsPageState,
          CalendarBillsPageState,
          CalendarBillsPageState,
          DateTime
        > {
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

abstract class _$CalendarDayBillsViewModel
    extends $Notifier<CalendarBillsPageState> {
  late final _$args = ref.$arg as DateTime;
  DateTime get date => _$args;

  CalendarBillsPageState build(DateTime date);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<CalendarBillsPageState, CalendarBillsPageState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CalendarBillsPageState, CalendarBillsPageState>,
              CalendarBillsPageState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(CalendarMonthBillsViewModel)
final calendarMonthBillsViewModelProvider =
    CalendarMonthBillsViewModelFamily._();

final class CalendarMonthBillsViewModelProvider
    extends
        $NotifierProvider<CalendarMonthBillsViewModel, CalendarBillsPageState> {
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
  CalendarMonthBillsViewModel create() => CalendarMonthBillsViewModel();

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
    r'001e96fb5ea8438e0a1a8064452a91c2e3664f75';

final class CalendarMonthBillsViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          CalendarMonthBillsViewModel,
          CalendarBillsPageState,
          CalendarBillsPageState,
          CalendarBillsPageState,
          DateTime
        > {
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

abstract class _$CalendarMonthBillsViewModel
    extends $Notifier<CalendarBillsPageState> {
  late final _$args = ref.$arg as DateTime;
  DateTime get month => _$args;

  CalendarBillsPageState build(DateTime month);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<CalendarBillsPageState, CalendarBillsPageState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CalendarBillsPageState, CalendarBillsPageState>,
              CalendarBillsPageState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
