// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'log_viewer_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LogViewerViewModel)
final logViewerViewModelProvider = LogViewerViewModelProvider._();

final class LogViewerViewModelProvider
    extends $NotifierProvider<LogViewerViewModel, LogViewerState> {
  LogViewerViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logViewerViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logViewerViewModelHash();

  @$internal
  @override
  LogViewerViewModel create() => LogViewerViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LogViewerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LogViewerState>(value),
    );
  }
}

String _$logViewerViewModelHash() =>
    r'2c7e334a8a36d6406a041043cb6177d6d42b4ff0';

abstract class _$LogViewerViewModel extends $Notifier<LogViewerState> {
  LogViewerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<LogViewerState, LogViewerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LogViewerState, LogViewerState>,
              LogViewerState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(logEntries)
final logEntriesProvider = LogEntriesProvider._();

final class LogEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AppLogEntry>>,
          List<AppLogEntry>,
          FutureOr<List<AppLogEntry>>
        >
    with
        $FutureModifier<List<AppLogEntry>>,
        $FutureProvider<List<AppLogEntry>> {
  LogEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logEntriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logEntriesHash();

  @$internal
  @override
  $FutureProviderElement<List<AppLogEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AppLogEntry>> create(Ref ref) {
    return logEntries(ref);
  }
}

String _$logEntriesHash() => r'995696dc6f97304b6656c1cb905641d382af30eb';
