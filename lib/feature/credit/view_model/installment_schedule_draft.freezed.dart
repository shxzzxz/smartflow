// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'installment_schedule_draft.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
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
  return _then(InstallmentContractDraftRow(
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
