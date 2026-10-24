// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'counterparty_management_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CounterpartyManagementViewModel)
final counterpartyManagementViewModelProvider =
    CounterpartyManagementViewModelProvider._();

final class CounterpartyManagementViewModelProvider
    extends $NotifierProvider<CounterpartyManagementViewModel, void> {
  CounterpartyManagementViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'counterpartyManagementViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$counterpartyManagementViewModelHash();

  @$internal
  @override
  CounterpartyManagementViewModel create() => CounterpartyManagementViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$counterpartyManagementViewModelHash() =>
    r'ff9c46bd7f39fa1ed778a28a52ec0e81b3fdebb1';

abstract class _$CounterpartyManagementViewModel extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
