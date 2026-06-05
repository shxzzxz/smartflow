// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CalendarViewModel)
final calendarViewModelProvider = CalendarViewModelProvider._();

final class CalendarViewModelProvider
    extends $NotifierProvider<CalendarViewModel, CalendarPageState> {
  CalendarViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarViewModelHash();

  @$internal
  @override
  CalendarViewModel create() => CalendarViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarPageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarPageState>(value),
    );
  }
}

String _$calendarViewModelHash() => r'8721c3854ad3545110720ae3fd883dea9e8cb8ca';

abstract class _$CalendarViewModel extends $Notifier<CalendarPageState> {
  CalendarPageState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<CalendarPageState, CalendarPageState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CalendarPageState, CalendarPageState>,
              CalendarPageState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
