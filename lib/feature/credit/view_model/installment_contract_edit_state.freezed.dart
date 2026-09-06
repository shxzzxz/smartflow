// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'installment_contract_edit_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$InstallmentContractEditState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstallmentContractEditState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'InstallmentContractEditState()';
}


}

/// @nodoc
class $InstallmentContractEditStateCopyWith<$Res>  {
$InstallmentContractEditStateCopyWith(InstallmentContractEditState _, $Res Function(InstallmentContractEditState) __);
}


/// Adds pattern-matching-related methods to [InstallmentContractEditState].
extension InstallmentContractEditStatePatterns on InstallmentContractEditState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( InstallmentContractEditLoaded value)?  loaded,TResult Function( InstallmentContractEditNotFound value)?  notFound,required TResult orElse(),}){
final _that = this;
switch (_that) {
case InstallmentContractEditLoaded() when loaded != null:
return loaded(_that);case InstallmentContractEditNotFound() when notFound != null:
return notFound(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( InstallmentContractEditLoaded value)  loaded,required TResult Function( InstallmentContractEditNotFound value)  notFound,}){
final _that = this;
switch (_that) {
case InstallmentContractEditLoaded():
return loaded(_that);case InstallmentContractEditNotFound():
return notFound(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( InstallmentContractEditLoaded value)?  loaded,TResult? Function( InstallmentContractEditNotFound value)?  notFound,}){
final _that = this;
switch (_that) {
case InstallmentContractEditLoaded() when loaded != null:
return loaded(_that);case InstallmentContractEditNotFound() when notFound != null:
return notFound(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( InstallmentContractReadModel contract,  ContractMetrics? metrics,  List<InstallmentContractDraftRow> draft,  Set<int> manualPatchedPeriodNos,  bool submitting,  InstallmentTermsDraft stageDraft,  bool customRules,  bool stagePlanPreviewed)?  loaded,TResult Function()?  notFound,required TResult orElse(),}) {final _that = this;
switch (_that) {
case InstallmentContractEditLoaded() when loaded != null:
return loaded(_that.contract,_that.metrics,_that.draft,_that.manualPatchedPeriodNos,_that.submitting,_that.stageDraft,_that.customRules,_that.stagePlanPreviewed);case InstallmentContractEditNotFound() when notFound != null:
return notFound();case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( InstallmentContractReadModel contract,  ContractMetrics? metrics,  List<InstallmentContractDraftRow> draft,  Set<int> manualPatchedPeriodNos,  bool submitting,  InstallmentTermsDraft stageDraft,  bool customRules,  bool stagePlanPreviewed)  loaded,required TResult Function()  notFound,}) {final _that = this;
switch (_that) {
case InstallmentContractEditLoaded():
return loaded(_that.contract,_that.metrics,_that.draft,_that.manualPatchedPeriodNos,_that.submitting,_that.stageDraft,_that.customRules,_that.stagePlanPreviewed);case InstallmentContractEditNotFound():
return notFound();}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( InstallmentContractReadModel contract,  ContractMetrics? metrics,  List<InstallmentContractDraftRow> draft,  Set<int> manualPatchedPeriodNos,  bool submitting,  InstallmentTermsDraft stageDraft,  bool customRules,  bool stagePlanPreviewed)?  loaded,TResult? Function()?  notFound,}) {final _that = this;
switch (_that) {
case InstallmentContractEditLoaded() when loaded != null:
return loaded(_that.contract,_that.metrics,_that.draft,_that.manualPatchedPeriodNos,_that.submitting,_that.stageDraft,_that.customRules,_that.stagePlanPreviewed);case InstallmentContractEditNotFound() when notFound != null:
return notFound();case _:
  return null;

}
}

}

/// @nodoc


class InstallmentContractEditLoaded implements InstallmentContractEditState {
  const InstallmentContractEditLoaded({required this.contract, this.metrics, required  List<InstallmentContractDraftRow> draft,  Set<int> manualPatchedPeriodNos = const {}, this.submitting = false, required this.stageDraft, this.customRules = false, this.stagePlanPreviewed = false}): _draft = draft,_manualPatchedPeriodNos = manualPatchedPeriodNos;
  

 final  InstallmentContractReadModel contract;
 final  ContractMetrics? metrics;
 final  List<InstallmentContractDraftRow> _draft;
 List<InstallmentContractDraftRow> get draft {
  if (_draft is EqualUnmodifiableListView) return _draft;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_draft);
}

 final  Set<int> _manualPatchedPeriodNos;
@JsonKey() Set<int> get manualPatchedPeriodNos {
  if (_manualPatchedPeriodNos is EqualUnmodifiableSetView) return _manualPatchedPeriodNos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_manualPatchedPeriodNos);
}

@JsonKey() final  bool submitting;
 final  InstallmentTermsDraft stageDraft;
@JsonKey() final  bool customRules;
@JsonKey() final  bool stagePlanPreviewed;

/// Create a copy of InstallmentContractEditState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstallmentContractEditLoadedCopyWith<InstallmentContractEditLoaded> get copyWith => _$InstallmentContractEditLoadedCopyWithImpl<InstallmentContractEditLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstallmentContractEditLoaded&&(identical(other.contract, contract) || other.contract == contract)&&(identical(other.metrics, metrics) || other.metrics == metrics)&&const DeepCollectionEquality().equals(other._draft, _draft)&&const DeepCollectionEquality().equals(other._manualPatchedPeriodNos, _manualPatchedPeriodNos)&&(identical(other.submitting, submitting) || other.submitting == submitting)&&(identical(other.stageDraft, stageDraft) || other.stageDraft == stageDraft)&&(identical(other.customRules, customRules) || other.customRules == customRules)&&(identical(other.stagePlanPreviewed, stagePlanPreviewed) || other.stagePlanPreviewed == stagePlanPreviewed));
}


@override
int get hashCode => Object.hash(runtimeType,contract,metrics,const DeepCollectionEquality().hash(_draft),const DeepCollectionEquality().hash(_manualPatchedPeriodNos),submitting,stageDraft,customRules,stagePlanPreviewed);

@override
String toString() {
  return 'InstallmentContractEditState.loaded(contract: $contract, metrics: $metrics, draft: $draft, manualPatchedPeriodNos: $manualPatchedPeriodNos, submitting: $submitting, stageDraft: $stageDraft, customRules: $customRules, stagePlanPreviewed: $stagePlanPreviewed)';
}


}

/// @nodoc
abstract mixin class $InstallmentContractEditLoadedCopyWith<$Res> implements $InstallmentContractEditStateCopyWith<$Res> {
  factory $InstallmentContractEditLoadedCopyWith(InstallmentContractEditLoaded value, $Res Function(InstallmentContractEditLoaded) _then) = _$InstallmentContractEditLoadedCopyWithImpl;
@useResult
$Res call({
 InstallmentContractReadModel contract, ContractMetrics? metrics, List<InstallmentContractDraftRow> draft, Set<int> manualPatchedPeriodNos, bool submitting, InstallmentTermsDraft stageDraft, bool customRules, bool stagePlanPreviewed
});




}
/// @nodoc
class _$InstallmentContractEditLoadedCopyWithImpl<$Res>
    implements $InstallmentContractEditLoadedCopyWith<$Res> {
  _$InstallmentContractEditLoadedCopyWithImpl(this._self, this._then);

  final InstallmentContractEditLoaded _self;
  final $Res Function(InstallmentContractEditLoaded) _then;

/// Create a copy of InstallmentContractEditState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? contract = null,Object? metrics = freezed,Object? draft = null,Object? manualPatchedPeriodNos = null,Object? submitting = null,Object? stageDraft = null,Object? customRules = null,Object? stagePlanPreviewed = null,}) {
  return _then(InstallmentContractEditLoaded(
contract: null == contract ? _self.contract : contract // ignore: cast_nullable_to_non_nullable
as InstallmentContractReadModel,metrics: freezed == metrics ? _self.metrics : metrics // ignore: cast_nullable_to_non_nullable
as ContractMetrics?,draft: null == draft ? _self._draft : draft // ignore: cast_nullable_to_non_nullable
as List<InstallmentContractDraftRow>,manualPatchedPeriodNos: null == manualPatchedPeriodNos ? _self._manualPatchedPeriodNos : manualPatchedPeriodNos // ignore: cast_nullable_to_non_nullable
as Set<int>,submitting: null == submitting ? _self.submitting : submitting // ignore: cast_nullable_to_non_nullable
as bool,stageDraft: null == stageDraft ? _self.stageDraft : stageDraft // ignore: cast_nullable_to_non_nullable
as InstallmentTermsDraft,customRules: null == customRules ? _self.customRules : customRules // ignore: cast_nullable_to_non_nullable
as bool,stagePlanPreviewed: null == stagePlanPreviewed ? _self.stagePlanPreviewed : stagePlanPreviewed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class InstallmentContractEditNotFound implements InstallmentContractEditState {
  const InstallmentContractEditNotFound();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstallmentContractEditNotFound);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'InstallmentContractEditState.notFound()';
}


}




// dart format on
