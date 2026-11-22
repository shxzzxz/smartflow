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
        $AsyncNotifierProvider<
          NotificationCenterViewModel,
          NotificationCenterViewState
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
}

String _$notificationCenterViewModelHash() =>
    r'e04d867082ce75bf4392d15b166f280774185463';

abstract class _$NotificationCenterViewModel
    extends $AsyncNotifier<NotificationCenterViewState> {
  FutureOr<NotificationCenterViewState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<NotificationCenterViewState>,
              NotificationCenterViewState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<NotificationCenterViewState>,
                NotificationCenterViewState
              >,
              AsyncValue<NotificationCenterViewState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
