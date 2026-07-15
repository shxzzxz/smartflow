// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'installment_contract_edit_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( InstallmentContractReadModel contract,  int paidCount,  DateTime firstRepaymentDate,  DateTime lastRepaymentDate,  InstallmentRepaymentMethod method,  InterestRatePeriod ratePeriod,  InterestAccrualMethod accrualMethod,  List<InstallmentContractDraftRow> draft,  Set<int> manualPatchedPeriodNos,  bool submitting)?  loaded,TResult Function()?  notFound,required TResult orElse(),}) {final _that = this;
switch (_that) {
case InstallmentContractEditLoaded() when loaded != null:
return loaded(_that.contract,_that.paidCount,_that.firstRepaymentDate,_that.lastRepaymentDate,_that.method,_that.ratePeriod,_that.accrualMethod,_that.draft,_that.manualPatchedPeriodNos,_that.submitting);case InstallmentContractEditNotFound() when notFound != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( InstallmentContractReadModel contract,  int paidCount,  DateTime firstRepaymentDate,  DateTime lastRepaymentDate,  InstallmentRepaymentMethod method,  InterestRatePeriod ratePeriod,  InterestAccrualMethod accrualMethod,  List<InstallmentContractDraftRow> draft,  Set<int> manualPatchedPeriodNos,  bool submitting)  loaded,required TResult Function()  notFound,}) {final _that = this;
switch (_that) {
case InstallmentContractEditLoaded():
return loaded(_that.contract,_that.paidCount,_that.firstRepaymentDate,_that.lastRepaymentDate,_that.method,_that.ratePeriod,_that.accrualMethod,_that.draft,_that.manualPatchedPeriodNos,_that.submitting);case InstallmentContractEditNotFound():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( InstallmentContractReadModel contract,  int paidCount,  DateTime firstRepaymentDate,  DateTime lastRepaymentDate,  InstallmentRepaymentMethod method,  InterestRatePeriod ratePeriod,  InterestAccrualMethod accrualMethod,  List<InstallmentContractDraftRow> draft,  Set<int> manualPatchedPeriodNos,  bool submitting)?  loaded,TResult? Function()?  notFound,}) {final _that = this;
switch (_that) {
case InstallmentContractEditLoaded() when loaded != null:
return loaded(_that.contract,_that.paidCount,_that.firstRepaymentDate,_that.lastRepaymentDate,_that.method,_that.ratePeriod,_that.accrualMethod,_that.draft,_that.manualPatchedPeriodNos,_that.submitting);case InstallmentContractEditNotFound() when notFound != null:
return notFound();case _:
  return null;

}
}

}

/// @nodoc


class InstallmentContractEditLoaded implements InstallmentContractEditState {
  const InstallmentContractEditLoaded({required this.contract, required this.paidCount, required this.firstRepaymentDate, required this.lastRepaymentDate, required this.method, required this.ratePeriod, required this.accrualMethod, required final  List<InstallmentContractDraftRow> draft, final  Set<int> manualPatchedPeriodNos = const {}, this.submitting = false}): _draft = draft,_manualPatchedPeriodNos = manualPatchedPeriodNos;
  

 final  InstallmentContractReadModel contract;
 final  int paidCount;
 final  DateTime firstRepaymentDate;
 final  DateTime lastRepaymentDate;
 final  InstallmentRepaymentMethod method;
 final  InterestRatePeriod ratePeriod;
 final  InterestAccrualMethod accrualMethod;
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

/// Create a copy of InstallmentContractEditState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstallmentContractEditLoadedCopyWith<InstallmentContractEditLoaded> get copyWith => _$InstallmentContractEditLoadedCopyWithImpl<InstallmentContractEditLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstallmentContractEditLoaded&&(identical(other.contract, contract) || other.contract == contract)&&(identical(other.paidCount, paidCount) || other.paidCount == paidCount)&&(identical(other.firstRepaymentDate, firstRepaymentDate) || other.firstRepaymentDate == firstRepaymentDate)&&(identical(other.lastRepaymentDate, lastRepaymentDate) || other.lastRepaymentDate == lastRepaymentDate)&&(identical(other.method, method) || other.method == method)&&(identical(other.ratePeriod, ratePeriod) || other.ratePeriod == ratePeriod)&&(identical(other.accrualMethod, accrualMethod) || other.accrualMethod == accrualMethod)&&const DeepCollectionEquality().equals(other._draft, _draft)&&const DeepCollectionEquality().equals(other._manualPatchedPeriodNos, _manualPatchedPeriodNos)&&(identical(other.submitting, submitting) || other.submitting == submitting));
}


@override
int get hashCode => Object.hash(runtimeType,contract,paidCount,firstRepaymentDate,lastRepaymentDate,method,ratePeriod,accrualMethod,const DeepCollectionEquality().hash(_draft),const DeepCollectionEquality().hash(_manualPatchedPeriodNos),submitting);

@override
String toString() {
  return 'InstallmentContractEditState.loaded(contract: $contract, paidCount: $paidCount, firstRepaymentDate: $firstRepaymentDate, lastRepaymentDate: $lastRepaymentDate, method: $method, ratePeriod: $ratePeriod, accrualMethod: $accrualMethod, draft: $draft, manualPatchedPeriodNos: $manualPatchedPeriodNos, submitting: $submitting)';
}


}

/// @nodoc
abstract mixin class $InstallmentContractEditLoadedCopyWith<$Res> implements $InstallmentContractEditStateCopyWith<$Res> {
  factory $InstallmentContractEditLoadedCopyWith(InstallmentContractEditLoaded value, $Res Function(InstallmentContractEditLoaded) _then) = _$InstallmentContractEditLoadedCopyWithImpl;
@useResult
$Res call({
 InstallmentContractReadModel contract, int paidCount, DateTime firstRepaymentDate, DateTime lastRepaymentDate, InstallmentRepaymentMethod method, InterestRatePeriod ratePeriod, InterestAccrualMethod accrualMethod, List<InstallmentContractDraftRow> draft, Set<int> manualPatchedPeriodNos, bool submitting
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
@pragma('vm:prefer-inline') $Res call({Object? contract = null,Object? paidCount = null,Object? firstRepaymentDate = null,Object? lastRepaymentDate = null,Object? method = null,Object? ratePeriod = null,Object? accrualMethod = null,Object? draft = null,Object? manualPatchedPeriodNos = null,Object? submitting = null,}) {
  return _then(InstallmentContractEditLoaded(
contract: null == contract ? _self.contract : contract // ignore: cast_nullable_to_non_nullable
as InstallmentContractReadModel,paidCount: null == paidCount ? _self.paidCount : paidCount // ignore: cast_nullable_to_non_nullable
as int,firstRepaymentDate: null == firstRepaymentDate ? _self.firstRepaymentDate : firstRepaymentDate // ignore: cast_nullable_to_non_nullable
as DateTime,lastRepaymentDate: null == lastRepaymentDate ? _self.lastRepaymentDate : lastRepaymentDate // ignore: cast_nullable_to_non_nullable
as DateTime,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as InstallmentRepaymentMethod,ratePeriod: null == ratePeriod ? _self.ratePeriod : ratePeriod // ignore: cast_nullable_to_non_nullable
as InterestRatePeriod,accrualMethod: null == accrualMethod ? _self.accrualMethod : accrualMethod // ignore: cast_nullable_to_non_nullable
as InterestAccrualMethod,draft: null == draft ? _self._draft : draft // ignore: cast_nullable_to_non_nullable
as List<InstallmentContractDraftRow>,manualPatchedPeriodNos: null == manualPatchedPeriodNos ? _self._manualPatchedPeriodNos : manualPatchedPeriodNos // ignore: cast_nullable_to_non_nullable
as Set<int>,submitting: null == submitting ? _self.submitting : submitting // ignore: cast_nullable_to_non_nullable
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




/// @nodoc
mixin _$InstallmentContractDraftRow {

 int get periodNo; DateTime get date; Money get principal; Money get interest; Money get fee; InstallmentScheduleStatus get status; String? get scheduleId;
/// Create a copy of InstallmentContractDraftRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstallmentContractDraftRowCopyWith<InstallmentContractDraftRow> get copyWith => _$InstallmentContractDraftRowCopyWithImpl<InstallmentContractDraftRow>(this as InstallmentContractDraftRow, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstallmentContractDraftRow&&(identical(other.periodNo, periodNo) || other.periodNo == periodNo)&&(identical(other.date, date) || other.date == date)&&(identical(other.principal, principal) || other.principal == principal)&&(identical(other.interest, interest) || other.interest == interest)&&(identical(other.fee, fee) || other.fee == fee)&&(identical(other.status, status) || other.status == status)&&(identical(other.scheduleId, scheduleId) || other.scheduleId == scheduleId));
}


@override
int get hashCode => Object.hash(runtimeType,periodNo,date,principal,interest,fee,status,scheduleId);

@override
String toString() {
  return 'InstallmentContractDraftRow(periodNo: $periodNo, date: $date, principal: $principal, interest: $interest, fee: $fee, status: $status, scheduleId: $scheduleId)';
}


}

/// @nodoc
abstract mixin class $InstallmentContractDraftRowCopyWith<$Res>  {
  factory $InstallmentContractDraftRowCopyWith(InstallmentContractDraftRow value, $Res Function(InstallmentContractDraftRow) _then) = _$InstallmentContractDraftRowCopyWithImpl;
@useResult
$Res call({
 int periodNo, DateTime date, Money principal, Money interest, Money fee, InstallmentScheduleStatus status, String? scheduleId
});




}
/// @nodoc
class _$InstallmentContractDraftRowCopyWithImpl<$Res>
    implements $InstallmentContractDraftRowCopyWith<$Res> {
  _$InstallmentContractDraftRowCopyWithImpl(this._self, this._then);

  final InstallmentContractDraftRow _self;
  final $Res Function(InstallmentContractDraftRow) _then;

/// Create a copy of InstallmentContractDraftRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? periodNo = null,Object? date = null,Object? principal = null,Object? interest = null,Object? fee = null,Object? status = null,Object? scheduleId = freezed,}) {
  return _then(_self.copyWith(
periodNo: null == periodNo ? _self.periodNo : periodNo // ignore: cast_nullable_to_non_nullable
as int,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,principal: null == principal ? _self.principal : principal // ignore: cast_nullable_to_non_nullable
as Money,interest: null == interest ? _self.interest : interest // ignore: cast_nullable_to_non_nullable
as Money,fee: null == fee ? _self.fee : fee // ignore: cast_nullable_to_non_nullable
as Money,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as InstallmentScheduleStatus,scheduleId: freezed == scheduleId ? _self.scheduleId : scheduleId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [InstallmentContractDraftRow].
extension InstallmentContractDraftRowPatterns on InstallmentContractDraftRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InstallmentContractDraftRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InstallmentContractDraftRow() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InstallmentContractDraftRow value)  $default,){
final _that = this;
switch (_that) {
case _InstallmentContractDraftRow():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InstallmentContractDraftRow value)?  $default,){
final _that = this;
switch (_that) {
case _InstallmentContractDraftRow() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int periodNo,  DateTime date,  Money principal,  Money interest,  Money fee,  InstallmentScheduleStatus status,  String? scheduleId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InstallmentContractDraftRow() when $default != null:
return $default(_that.periodNo,_that.date,_that.principal,_that.interest,_that.fee,_that.status,_that.scheduleId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int periodNo,  DateTime date,  Money principal,  Money interest,  Money fee,  InstallmentScheduleStatus status,  String? scheduleId)  $default,) {final _that = this;
switch (_that) {
case _InstallmentContractDraftRow():
return $default(_that.periodNo,_that.date,_that.principal,_that.interest,_that.fee,_that.status,_that.scheduleId);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int periodNo,  DateTime date,  Money principal,  Money interest,  Money fee,  InstallmentScheduleStatus status,  String? scheduleId)?  $default,) {final _that = this;
switch (_that) {
case _InstallmentContractDraftRow() when $default != null:
return $default(_that.periodNo,_that.date,_that.principal,_that.interest,_that.fee,_that.status,_that.scheduleId);case _:
  return null;

}
}

}

/// @nodoc


class _InstallmentContractDraftRow extends InstallmentContractDraftRow {
  const _InstallmentContractDraftRow({required this.periodNo, required this.date, required this.principal, required this.interest, required this.fee, required this.status, this.scheduleId}): super._();
  

@override final  int periodNo;
@override final  DateTime date;
@override final  Money principal;
@override final  Money interest;
@override final  Money fee;
@override final  InstallmentScheduleStatus status;
@override final  String? scheduleId;

/// Create a copy of InstallmentContractDraftRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstallmentContractDraftRowCopyWith<_InstallmentContractDraftRow> get copyWith => __$InstallmentContractDraftRowCopyWithImpl<_InstallmentContractDraftRow>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InstallmentContractDraftRow&&(identical(other.periodNo, periodNo) || other.periodNo == periodNo)&&(identical(other.date, date) || other.date == date)&&(identical(other.principal, principal) || other.principal == principal)&&(identical(other.interest, interest) || other.interest == interest)&&(identical(other.fee, fee) || other.fee == fee)&&(identical(other.status, status) || other.status == status)&&(identical(other.scheduleId, scheduleId) || other.scheduleId == scheduleId));
}


@override
int get hashCode => Object.hash(runtimeType,periodNo,date,principal,interest,fee,status,scheduleId);

@override
String toString() {
  return 'InstallmentContractDraftRow(periodNo: $periodNo, date: $date, principal: $principal, interest: $interest, fee: $fee, status: $status, scheduleId: $scheduleId)';
}


}

/// @nodoc
abstract mixin class _$InstallmentContractDraftRowCopyWith<$Res> implements $InstallmentContractDraftRowCopyWith<$Res> {
  factory _$InstallmentContractDraftRowCopyWith(_InstallmentContractDraftRow value, $Res Function(_InstallmentContractDraftRow) _then) = __$InstallmentContractDraftRowCopyWithImpl;
@override @useResult
$Res call({
 int periodNo, DateTime date, Money principal, Money interest, Money fee, InstallmentScheduleStatus status, String? scheduleId
});




}
/// @nodoc
class __$InstallmentContractDraftRowCopyWithImpl<$Res>
    implements _$InstallmentContractDraftRowCopyWith<$Res> {
  __$InstallmentContractDraftRowCopyWithImpl(this._self, this._then);

  final _InstallmentContractDraftRow _self;
  final $Res Function(_InstallmentContractDraftRow) _then;

/// Create a copy of InstallmentContractDraftRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? periodNo = null,Object? date = null,Object? principal = null,Object? interest = null,Object? fee = null,Object? status = null,Object? scheduleId = freezed,}) {
  return _then(_InstallmentContractDraftRow(
periodNo: null == periodNo ? _self.periodNo : periodNo // ignore: cast_nullable_to_non_nullable
as int,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,principal: null == principal ? _self.principal : principal // ignore: cast_nullable_to_non_nullable
as Money,interest: null == interest ? _self.interest : interest // ignore: cast_nullable_to_non_nullable
as Money,fee: null == fee ? _self.fee : fee // ignore: cast_nullable_to_non_nullable
as Money,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as InstallmentScheduleStatus,scheduleId: freezed == scheduleId ? _self.scheduleId : scheduleId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
