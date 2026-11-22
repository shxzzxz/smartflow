// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_center_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NotificationCenterViewModel)
final notificationCenterViewModelProvider =
    NotificationCenterViewModelProvider._();

final class NotificationCenterViewModelProvider
    extends
        $NotifierProvider<
          NotificationCenterViewModel,
          AsyncValue<NotificationCenterViewState>
        > {
  NotificationCenterViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationCenterViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationCenterViewModelHash();

  @$internal
  @override
  NotificationCenterViewModel create() => NotificationCenterViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<NotificationCenterViewState> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<AsyncValue<NotificationCenterViewState>>(value),
    );
  }
}

String _$notificationCenterViewModelHash() =>
    r'762095f22e7d41f5ea3c067a223c57fcc428ddba';

abstract class _$NotificationCenterViewModel
    extends $Notifier<AsyncValue<NotificationCenterViewState>> {
  AsyncValue<NotificationCenterViewState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<NotificationCenterViewState>,
              AsyncValue<NotificationCenterViewState>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<NotificationCenterViewState>,
                AsyncValue<NotificationCenterViewState>
              >,
              AsyncValue<NotificationCenterViewState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
