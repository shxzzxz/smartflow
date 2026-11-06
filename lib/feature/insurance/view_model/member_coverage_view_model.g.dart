// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_coverage_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MemberCoverageViewModel)
final memberCoverageViewModelProvider = MemberCoverageViewModelFamily._();

final class MemberCoverageViewModelProvider
    extends
        $AsyncNotifierProvider<
          MemberCoverageViewModel,
          MemberCoverageOverview?
        > {
  MemberCoverageViewModelProvider._({
    required MemberCoverageViewModelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'memberCoverageViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$memberCoverageViewModelHash();

  @override
  String toString() {
    return r'memberCoverageViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MemberCoverageViewModel create() => MemberCoverageViewModel();

  @override
  bool operator ==(Object other) {
    return other is MemberCoverageViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$memberCoverageViewModelHash() =>
    r'8e51577d7e0e2a4579a110c8085282cbc17cf296';

final class MemberCoverageViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          MemberCoverageViewModel,
          AsyncValue<MemberCoverageOverview?>,
          MemberCoverageOverview?,
          FutureOr<MemberCoverageOverview?>,
          String
        > {
  MemberCoverageViewModelFamily._()
    : super(
        retry: null,
        name: r'memberCoverageViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MemberCoverageViewModelProvider call(String insuredPersonId) =>
      MemberCoverageViewModelProvider._(argument: insuredPersonId, from: this);

  @override
  String toString() => r'memberCoverageViewModelProvider';
}

abstract class _$MemberCoverageViewModel
    extends $AsyncNotifier<MemberCoverageOverview?> {
  late final _$args = ref.$arg as String;
  String get insuredPersonId => _$args;

  FutureOr<MemberCoverageOverview?> build(String insuredPersonId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<MemberCoverageOverview?>,
              MemberCoverageOverview?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<MemberCoverageOverview?>,
                MemberCoverageOverview?
              >,
              AsyncValue<MemberCoverageOverview?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
