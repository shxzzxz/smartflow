// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insurance_members_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InsuranceMembersViewModel)
final insuranceMembersViewModelProvider = InsuranceMembersViewModelProvider._();

final class InsuranceMembersViewModelProvider
    extends
        $AsyncNotifierProvider<
          InsuranceMembersViewModel,
          List<InsuranceMemberListItem>
        > {
  InsuranceMembersViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'insuranceMembersViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$insuranceMembersViewModelHash();

  @$internal
  @override
  InsuranceMembersViewModel create() => InsuranceMembersViewModel();
}

String _$insuranceMembersViewModelHash() =>
    r'9eaa9aad8d04ce0aa9bbadd7a2b4ae69d77dc868';

abstract class _$InsuranceMembersViewModel
    extends $AsyncNotifier<List<InsuranceMemberListItem>> {
  FutureOr<List<InsuranceMemberListItem>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<InsuranceMemberListItem>>,
              List<InsuranceMemberListItem>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<InsuranceMemberListItem>>,
                List<InsuranceMemberListItem>
              >,
              AsyncValue<List<InsuranceMemberListItem>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
