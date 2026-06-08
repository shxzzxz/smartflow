// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction_detail_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TransactionDetailUiState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransactionDetailUiState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransactionDetailUiState()';
}


}

/// @nodoc
class $TransactionDetailUiStateCopyWith<$Res>  {
$TransactionDetailUiStateCopyWith(TransactionDetailUiState _, $Res Function(TransactionDetailUiState) __);
}


/// Adds pattern-matching-related methods to [TransactionDetailUiState].
extension TransactionDetailUiStatePatterns on TransactionDetailUiState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TransactionDetailLoaded value)?  loaded,TResult Function( TransactionDetailNotFound value)?  notFound,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TransactionDetailLoaded() when loaded != null:
return loaded(_that);case TransactionDetailNotFound() when notFound != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TransactionDetailLoaded value)  loaded,required TResult Function( TransactionDetailNotFound value)  notFound,}){
final _that = this;
switch (_that) {
case TransactionDetailLoaded():
return loaded(_that);case TransactionDetailNotFound():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TransactionDetailLoaded value)?  loaded,TResult? Function( TransactionDetailNotFound value)?  notFound,}){
final _that = this;
switch (_that) {
case TransactionDetailLoaded() when loaded != null:
return loaded(_that);case TransactionDetailNotFound() when notFound != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String transactionId,  TransactionDetail detail,  DetailBehaviorConfig behavior,  DetailHero hero,  String occurredAtText,  String createdAtText,  List<DetailAccountRow> accountRows,  DetailRefund? refund,  DetailReimbursement? reimbursement,  List<DetailSheetItem> historyItems,  bool showExcludeStats,  bool showExcludeBudget,  bool excludeStats,  bool excludeBudget,  List<DetailActionButton> actionButtons,  bool submitting,  String? noteText)?  loaded,TResult Function()?  notFound,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TransactionDetailLoaded() when loaded != null:
return loaded(_that.transactionId,_that.detail,_that.behavior,_that.hero,_that.occurredAtText,_that.createdAtText,_that.accountRows,_that.refund,_that.reimbursement,_that.historyItems,_that.showExcludeStats,_that.showExcludeBudget,_that.excludeStats,_that.excludeBudget,_that.actionButtons,_that.submitting,_that.noteText);case TransactionDetailNotFound() when notFound != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String transactionId,  TransactionDetail detail,  DetailBehaviorConfig behavior,  DetailHero hero,  String occurredAtText,  String createdAtText,  List<DetailAccountRow> accountRows,  DetailRefund? refund,  DetailReimbursement? reimbursement,  List<DetailSheetItem> historyItems,  bool showExcludeStats,  bool showExcludeBudget,  bool excludeStats,  bool excludeBudget,  List<DetailActionButton> actionButtons,  bool submitting,  String? noteText)  loaded,required TResult Function()  notFound,}) {final _that = this;
switch (_that) {
case TransactionDetailLoaded():
return loaded(_that.transactionId,_that.detail,_that.behavior,_that.hero,_that.occurredAtText,_that.createdAtText,_that.accountRows,_that.refund,_that.reimbursement,_that.historyItems,_that.showExcludeStats,_that.showExcludeBudget,_that.excludeStats,_that.excludeBudget,_that.actionButtons,_that.submitting,_that.noteText);case TransactionDetailNotFound():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String transactionId,  TransactionDetail detail,  DetailBehaviorConfig behavior,  DetailHero hero,  String occurredAtText,  String createdAtText,  List<DetailAccountRow> accountRows,  DetailRefund? refund,  DetailReimbursement? reimbursement,  List<DetailSheetItem> historyItems,  bool showExcludeStats,  bool showExcludeBudget,  bool excludeStats,  bool excludeBudget,  List<DetailActionButton> actionButtons,  bool submitting,  String? noteText)?  loaded,TResult? Function()?  notFound,}) {final _that = this;
switch (_that) {
case TransactionDetailLoaded() when loaded != null:
return loaded(_that.transactionId,_that.detail,_that.behavior,_that.hero,_that.occurredAtText,_that.createdAtText,_that.accountRows,_that.refund,_that.reimbursement,_that.historyItems,_that.showExcludeStats,_that.showExcludeBudget,_that.excludeStats,_that.excludeBudget,_that.actionButtons,_that.submitting,_that.noteText);case TransactionDetailNotFound() when notFound != null:
return notFound();case _:
  return null;

}
}

}

/// @nodoc


class TransactionDetailLoaded implements TransactionDetailUiState {
  const TransactionDetailLoaded({required this.transactionId, required this.detail, required this.behavior, required this.hero, required this.occurredAtText, required this.createdAtText, required final  List<DetailAccountRow> accountRows, required this.refund, required this.reimbursement, required final  List<DetailSheetItem> historyItems, required this.showExcludeStats, required this.showExcludeBudget, required this.excludeStats, required this.excludeBudget, required final  List<DetailActionButton> actionButtons, required this.submitting, this.noteText}): _accountRows = accountRows,_historyItems = historyItems,_actionButtons = actionButtons;


 final  String transactionId;
 final  TransactionDetail detail;
 final  DetailBehaviorConfig behavior;
 final  DetailHero hero;
 final  String occurredAtText;
 final  String createdAtText;
 final  List<DetailAccountRow> _accountRows;
 List<DetailAccountRow> get accountRows {
  if (_accountRows is EqualUnmodifiableListView) return _accountRows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_accountRows);
}

 final  DetailRefund? refund;
 final  DetailReimbursement? reimbursement;
 final  List<DetailSheetItem> _historyItems;
 List<DetailSheetItem> get historyItems {
  if (_historyItems is EqualUnmodifiableListView) return _historyItems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_historyItems);
}

 final  bool showExcludeStats;
 final  bool showExcludeBudget;
 final  bool excludeStats;
 final  bool excludeBudget;
 final  List<DetailActionButton> _actionButtons;
 List<DetailActionButton> get actionButtons {
  if (_actionButtons is EqualUnmodifiableListView) return _actionButtons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_actionButtons);
}

 final  bool submitting;
 final  String? noteText;

/// Create a copy of TransactionDetailUiState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransactionDetailLoadedCopyWith<TransactionDetailLoaded> get copyWith => _$TransactionDetailLoadedCopyWithImpl<TransactionDetailLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransactionDetailLoaded&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.behavior, behavior) || other.behavior == behavior)&&(identical(other.hero, hero) || other.hero == hero)&&(identical(other.occurredAtText, occurredAtText) || other.occurredAtText == occurredAtText)&&(identical(other.createdAtText, createdAtText) || other.createdAtText == createdAtText)&&const DeepCollectionEquality().equals(other._accountRows, _accountRows)&&(identical(other.refund, refund) || other.refund == refund)&&(identical(other.reimbursement, reimbursement) || other.reimbursement == reimbursement)&&const DeepCollectionEquality().equals(other._historyItems, _historyItems)&&(identical(other.showExcludeStats, showExcludeStats) || other.showExcludeStats == showExcludeStats)&&(identical(other.showExcludeBudget, showExcludeBudget) || other.showExcludeBudget == showExcludeBudget)&&(identical(other.excludeStats, excludeStats) || other.excludeStats == excludeStats)&&(identical(other.excludeBudget, excludeBudget) || other.excludeBudget == excludeBudget)&&const DeepCollectionEquality().equals(other._actionButtons, _actionButtons)&&(identical(other.submitting, submitting) || other.submitting == submitting)&&(identical(other.noteText, noteText) || other.noteText == noteText));
}


@override
int get hashCode => Object.hash(runtimeType,transactionId,detail,behavior,hero,occurredAtText,createdAtText,const DeepCollectionEquality().hash(_accountRows),refund,reimbursement,const DeepCollectionEquality().hash(_historyItems),showExcludeStats,showExcludeBudget,excludeStats,excludeBudget,const DeepCollectionEquality().hash(_actionButtons),submitting,noteText);

@override
String toString() {
  return 'TransactionDetailUiState.loaded(transactionId: $transactionId, detail: $detail, behavior: $behavior, hero: $hero, occurredAtText: $occurredAtText, createdAtText: $createdAtText, accountRows: $accountRows, refund: $refund, reimbursement: $reimbursement, historyItems: $historyItems, showExcludeStats: $showExcludeStats, showExcludeBudget: $showExcludeBudget, excludeStats: $excludeStats, excludeBudget: $excludeBudget, actionButtons: $actionButtons, submitting: $submitting, noteText: $noteText)';
}


}

/// @nodoc
abstract mixin class $TransactionDetailLoadedCopyWith<$Res> implements $TransactionDetailUiStateCopyWith<$Res> {
  factory $TransactionDetailLoadedCopyWith(TransactionDetailLoaded value, $Res Function(TransactionDetailLoaded) _then) = _$TransactionDetailLoadedCopyWithImpl;
@useResult
$Res call({
 String transactionId, TransactionDetail detail, DetailBehaviorConfig behavior, DetailHero hero, String occurredAtText, String createdAtText, List<DetailAccountRow> accountRows, DetailRefund? refund, DetailReimbursement? reimbursement, List<DetailSheetItem> historyItems, bool showExcludeStats, bool showExcludeBudget, bool excludeStats, bool excludeBudget, List<DetailActionButton> actionButtons, bool submitting, String? noteText
});


$DetailBehaviorConfigCopyWith<$Res> get behavior;$DetailRefundCopyWith<$Res>? get refund;$DetailReimbursementCopyWith<$Res>? get reimbursement;

}
/// @nodoc
class _$TransactionDetailLoadedCopyWithImpl<$Res>
    implements $TransactionDetailLoadedCopyWith<$Res> {
  _$TransactionDetailLoadedCopyWithImpl(this._self, this._then);

  final TransactionDetailLoaded _self;
  final $Res Function(TransactionDetailLoaded) _then;

/// Create a copy of TransactionDetailUiState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? transactionId = null,Object? detail = null,Object? behavior = null,Object? hero = null,Object? occurredAtText = null,Object? createdAtText = null,Object? accountRows = null,Object? refund = freezed,Object? reimbursement = freezed,Object? historyItems = null,Object? showExcludeStats = null,Object? showExcludeBudget = null,Object? excludeStats = null,Object? excludeBudget = null,Object? actionButtons = null,Object? submitting = null,Object? noteText = freezed,}) {
  return _then(TransactionDetailLoaded(
transactionId: null == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as TransactionDetail,behavior: null == behavior ? _self.behavior : behavior // ignore: cast_nullable_to_non_nullable
as DetailBehaviorConfig,hero: null == hero ? _self.hero : hero // ignore: cast_nullable_to_non_nullable
as DetailHero,occurredAtText: null == occurredAtText ? _self.occurredAtText : occurredAtText // ignore: cast_nullable_to_non_nullable
as String,createdAtText: null == createdAtText ? _self.createdAtText : createdAtText // ignore: cast_nullable_to_non_nullable
as String,accountRows: null == accountRows ? _self._accountRows : accountRows // ignore: cast_nullable_to_non_nullable
as List<DetailAccountRow>,refund: freezed == refund ? _self.refund : refund // ignore: cast_nullable_to_non_nullable
as DetailRefund?,reimbursement: freezed == reimbursement ? _self.reimbursement : reimbursement // ignore: cast_nullable_to_non_nullable
as DetailReimbursement?,historyItems: null == historyItems ? _self._historyItems : historyItems // ignore: cast_nullable_to_non_nullable
as List<DetailSheetItem>,showExcludeStats: null == showExcludeStats ? _self.showExcludeStats : showExcludeStats // ignore: cast_nullable_to_non_nullable
as bool,showExcludeBudget: null == showExcludeBudget ? _self.showExcludeBudget : showExcludeBudget // ignore: cast_nullable_to_non_nullable
as bool,excludeStats: null == excludeStats ? _self.excludeStats : excludeStats // ignore: cast_nullable_to_non_nullable
as bool,excludeBudget: null == excludeBudget ? _self.excludeBudget : excludeBudget // ignore: cast_nullable_to_non_nullable
as bool,actionButtons: null == actionButtons ? _self._actionButtons : actionButtons // ignore: cast_nullable_to_non_nullable
as List<DetailActionButton>,submitting: null == submitting ? _self.submitting : submitting // ignore: cast_nullable_to_non_nullable
as bool,noteText: freezed == noteText ? _self.noteText : noteText // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of TransactionDetailUiState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetailBehaviorConfigCopyWith<$Res> get behavior {

  return $DetailBehaviorConfigCopyWith<$Res>(_self.behavior, (value) {
    return _then(_self.copyWith(behavior: value));
  });
}/// Create a copy of TransactionDetailUiState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetailRefundCopyWith<$Res>? get refund {
    if (_self.refund == null) {
    return null;
  }

  return $DetailRefundCopyWith<$Res>(_self.refund!, (value) {
    return _then(_self.copyWith(refund: value));
  });
}/// Create a copy of TransactionDetailUiState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetailReimbursementCopyWith<$Res>? get reimbursement {
    if (_self.reimbursement == null) {
    return null;
  }

  return $DetailReimbursementCopyWith<$Res>(_self.reimbursement!, (value) {
    return _then(_self.copyWith(reimbursement: value));
  });
}
}

/// @nodoc


class TransactionDetailNotFound implements TransactionDetailUiState {
  const TransactionDetailNotFound();







@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransactionDetailNotFound);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransactionDetailUiState.notFound()';
}


}




/// @nodoc
mixin _$DetailBehaviorConfig {

 DetailEditPermission get canEditOccurredAt; DetailEditPermission get canEditNote; DetailEditPermission get canEditSettlementAccount; String? get bannerText; String? get editRoute;
/// Create a copy of DetailBehaviorConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetailBehaviorConfigCopyWith<DetailBehaviorConfig> get copyWith => _$DetailBehaviorConfigCopyWithImpl<DetailBehaviorConfig>(this as DetailBehaviorConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetailBehaviorConfig&&(identical(other.canEditOccurredAt, canEditOccurredAt) || other.canEditOccurredAt == canEditOccurredAt)&&(identical(other.canEditNote, canEditNote) || other.canEditNote == canEditNote)&&(identical(other.canEditSettlementAccount, canEditSettlementAccount) || other.canEditSettlementAccount == canEditSettlementAccount)&&(identical(other.bannerText, bannerText) || other.bannerText == bannerText)&&(identical(other.editRoute, editRoute) || other.editRoute == editRoute));
}


@override
int get hashCode => Object.hash(runtimeType,canEditOccurredAt,canEditNote,canEditSettlementAccount,bannerText,editRoute);

@override
String toString() {
  return 'DetailBehaviorConfig(canEditOccurredAt: $canEditOccurredAt, canEditNote: $canEditNote, canEditSettlementAccount: $canEditSettlementAccount, bannerText: $bannerText, editRoute: $editRoute)';
}


}

/// @nodoc
abstract mixin class $DetailBehaviorConfigCopyWith<$Res>  {
  factory $DetailBehaviorConfigCopyWith(DetailBehaviorConfig value, $Res Function(DetailBehaviorConfig) _then) = _$DetailBehaviorConfigCopyWithImpl;
@useResult
$Res call({
 DetailEditPermission canEditOccurredAt, DetailEditPermission canEditNote, DetailEditPermission canEditSettlementAccount, String? bannerText, String? editRoute
});


$DetailEditPermissionCopyWith<$Res> get canEditOccurredAt;$DetailEditPermissionCopyWith<$Res> get canEditNote;$DetailEditPermissionCopyWith<$Res> get canEditSettlementAccount;

}
/// @nodoc
class _$DetailBehaviorConfigCopyWithImpl<$Res>
    implements $DetailBehaviorConfigCopyWith<$Res> {
  _$DetailBehaviorConfigCopyWithImpl(this._self, this._then);

  final DetailBehaviorConfig _self;
  final $Res Function(DetailBehaviorConfig) _then;

/// Create a copy of DetailBehaviorConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? canEditOccurredAt = null,Object? canEditNote = null,Object? canEditSettlementAccount = null,Object? bannerText = freezed,Object? editRoute = freezed,}) {
  return _then(_self.copyWith(
canEditOccurredAt: null == canEditOccurredAt ? _self.canEditOccurredAt : canEditOccurredAt // ignore: cast_nullable_to_non_nullable
as DetailEditPermission,canEditNote: null == canEditNote ? _self.canEditNote : canEditNote // ignore: cast_nullable_to_non_nullable
as DetailEditPermission,canEditSettlementAccount: null == canEditSettlementAccount ? _self.canEditSettlementAccount : canEditSettlementAccount // ignore: cast_nullable_to_non_nullable
as DetailEditPermission,bannerText: freezed == bannerText ? _self.bannerText : bannerText // ignore: cast_nullable_to_non_nullable
as String?,editRoute: freezed == editRoute ? _self.editRoute : editRoute // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of DetailBehaviorConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetailEditPermissionCopyWith<$Res> get canEditOccurredAt {

  return $DetailEditPermissionCopyWith<$Res>(_self.canEditOccurredAt, (value) {
    return _then(_self.copyWith(canEditOccurredAt: value));
  });
}/// Create a copy of DetailBehaviorConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetailEditPermissionCopyWith<$Res> get canEditNote {

  return $DetailEditPermissionCopyWith<$Res>(_self.canEditNote, (value) {
    return _then(_self.copyWith(canEditNote: value));
  });
}/// Create a copy of DetailBehaviorConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetailEditPermissionCopyWith<$Res> get canEditSettlementAccount {

  return $DetailEditPermissionCopyWith<$Res>(_self.canEditSettlementAccount, (value) {
    return _then(_self.copyWith(canEditSettlementAccount: value));
  });
}
}


/// Adds pattern-matching-related methods to [DetailBehaviorConfig].
extension DetailBehaviorConfigPatterns on DetailBehaviorConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DetailBehaviorConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DetailBehaviorConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DetailBehaviorConfig value)  $default,){
final _that = this;
switch (_that) {
case _DetailBehaviorConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DetailBehaviorConfig value)?  $default,){
final _that = this;
switch (_that) {
case _DetailBehaviorConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DetailEditPermission canEditOccurredAt,  DetailEditPermission canEditNote,  DetailEditPermission canEditSettlementAccount,  String? bannerText,  String? editRoute)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DetailBehaviorConfig() when $default != null:
return $default(_that.canEditOccurredAt,_that.canEditNote,_that.canEditSettlementAccount,_that.bannerText,_that.editRoute);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DetailEditPermission canEditOccurredAt,  DetailEditPermission canEditNote,  DetailEditPermission canEditSettlementAccount,  String? bannerText,  String? editRoute)  $default,) {final _that = this;
switch (_that) {
case _DetailBehaviorConfig():
return $default(_that.canEditOccurredAt,_that.canEditNote,_that.canEditSettlementAccount,_that.bannerText,_that.editRoute);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DetailEditPermission canEditOccurredAt,  DetailEditPermission canEditNote,  DetailEditPermission canEditSettlementAccount,  String? bannerText,  String? editRoute)?  $default,) {final _that = this;
switch (_that) {
case _DetailBehaviorConfig() when $default != null:
return $default(_that.canEditOccurredAt,_that.canEditNote,_that.canEditSettlementAccount,_that.bannerText,_that.editRoute);case _:
  return null;

}
}

}

/// @nodoc


class _DetailBehaviorConfig implements DetailBehaviorConfig {
  const _DetailBehaviorConfig({required this.canEditOccurredAt, required this.canEditNote, required this.canEditSettlementAccount, this.bannerText, this.editRoute});


@override final  DetailEditPermission canEditOccurredAt;
@override final  DetailEditPermission canEditNote;
@override final  DetailEditPermission canEditSettlementAccount;
@override final  String? bannerText;
@override final  String? editRoute;

/// Create a copy of DetailBehaviorConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DetailBehaviorConfigCopyWith<_DetailBehaviorConfig> get copyWith => __$DetailBehaviorConfigCopyWithImpl<_DetailBehaviorConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DetailBehaviorConfig&&(identical(other.canEditOccurredAt, canEditOccurredAt) || other.canEditOccurredAt == canEditOccurredAt)&&(identical(other.canEditNote, canEditNote) || other.canEditNote == canEditNote)&&(identical(other.canEditSettlementAccount, canEditSettlementAccount) || other.canEditSettlementAccount == canEditSettlementAccount)&&(identical(other.bannerText, bannerText) || other.bannerText == bannerText)&&(identical(other.editRoute, editRoute) || other.editRoute == editRoute));
}


@override
int get hashCode => Object.hash(runtimeType,canEditOccurredAt,canEditNote,canEditSettlementAccount,bannerText,editRoute);

@override
String toString() {
  return 'DetailBehaviorConfig(canEditOccurredAt: $canEditOccurredAt, canEditNote: $canEditNote, canEditSettlementAccount: $canEditSettlementAccount, bannerText: $bannerText, editRoute: $editRoute)';
}


}

/// @nodoc
abstract mixin class _$DetailBehaviorConfigCopyWith<$Res> implements $DetailBehaviorConfigCopyWith<$Res> {
  factory _$DetailBehaviorConfigCopyWith(_DetailBehaviorConfig value, $Res Function(_DetailBehaviorConfig) _then) = __$DetailBehaviorConfigCopyWithImpl;
@override @useResult
$Res call({
 DetailEditPermission canEditOccurredAt, DetailEditPermission canEditNote, DetailEditPermission canEditSettlementAccount, String? bannerText, String? editRoute
});


@override $DetailEditPermissionCopyWith<$Res> get canEditOccurredAt;@override $DetailEditPermissionCopyWith<$Res> get canEditNote;@override $DetailEditPermissionCopyWith<$Res> get canEditSettlementAccount;

}
/// @nodoc
class __$DetailBehaviorConfigCopyWithImpl<$Res>
    implements _$DetailBehaviorConfigCopyWith<$Res> {
  __$DetailBehaviorConfigCopyWithImpl(this._self, this._then);

  final _DetailBehaviorConfig _self;
  final $Res Function(_DetailBehaviorConfig) _then;

/// Create a copy of DetailBehaviorConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? canEditOccurredAt = null,Object? canEditNote = null,Object? canEditSettlementAccount = null,Object? bannerText = freezed,Object? editRoute = freezed,}) {
  return _then(_DetailBehaviorConfig(
canEditOccurredAt: null == canEditOccurredAt ? _self.canEditOccurredAt : canEditOccurredAt // ignore: cast_nullable_to_non_nullable
as DetailEditPermission,canEditNote: null == canEditNote ? _self.canEditNote : canEditNote // ignore: cast_nullable_to_non_nullable
as DetailEditPermission,canEditSettlementAccount: null == canEditSettlementAccount ? _self.canEditSettlementAccount : canEditSettlementAccount // ignore: cast_nullable_to_non_nullable
as DetailEditPermission,bannerText: freezed == bannerText ? _self.bannerText : bannerText // ignore: cast_nullable_to_non_nullable
as String?,editRoute: freezed == editRoute ? _self.editRoute : editRoute // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of DetailBehaviorConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetailEditPermissionCopyWith<$Res> get canEditOccurredAt {

  return $DetailEditPermissionCopyWith<$Res>(_self.canEditOccurredAt, (value) {
    return _then(_self.copyWith(canEditOccurredAt: value));
  });
}/// Create a copy of DetailBehaviorConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetailEditPermissionCopyWith<$Res> get canEditNote {

  return $DetailEditPermissionCopyWith<$Res>(_self.canEditNote, (value) {
    return _then(_self.copyWith(canEditNote: value));
  });
}/// Create a copy of DetailBehaviorConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetailEditPermissionCopyWith<$Res> get canEditSettlementAccount {

  return $DetailEditPermissionCopyWith<$Res>(_self.canEditSettlementAccount, (value) {
    return _then(_self.copyWith(canEditSettlementAccount: value));
  });
}
}

/// @nodoc
mixin _$DetailAccountRow {

 String get label; String get accountId; AccountEndpoint get endpoint; DetailEditPermission get permission; AccountSelectionPurpose? get editPurpose;
/// Create a copy of DetailAccountRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetailAccountRowCopyWith<DetailAccountRow> get copyWith => _$DetailAccountRowCopyWithImpl<DetailAccountRow>(this as DetailAccountRow, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetailAccountRow&&(identical(other.label, label) || other.label == label)&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.endpoint, endpoint) || other.endpoint == endpoint)&&(identical(other.permission, permission) || other.permission == permission)&&(identical(other.editPurpose, editPurpose) || other.editPurpose == editPurpose));
}


@override
int get hashCode => Object.hash(runtimeType,label,accountId,endpoint,permission,editPurpose);

@override
String toString() {
  return 'DetailAccountRow(label: $label, accountId: $accountId, endpoint: $endpoint, permission: $permission, editPurpose: $editPurpose)';
}


}

/// @nodoc
abstract mixin class $DetailAccountRowCopyWith<$Res>  {
  factory $DetailAccountRowCopyWith(DetailAccountRow value, $Res Function(DetailAccountRow) _then) = _$DetailAccountRowCopyWithImpl;
@useResult
$Res call({
 String label, String accountId, AccountEndpoint endpoint, DetailEditPermission permission, AccountSelectionPurpose? editPurpose
});


$DetailEditPermissionCopyWith<$Res> get permission;

}
/// @nodoc
class _$DetailAccountRowCopyWithImpl<$Res>
    implements $DetailAccountRowCopyWith<$Res> {
  _$DetailAccountRowCopyWithImpl(this._self, this._then);

  final DetailAccountRow _self;
  final $Res Function(DetailAccountRow) _then;

/// Create a copy of DetailAccountRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? accountId = null,Object? endpoint = null,Object? permission = null,Object? editPurpose = freezed,}) {
  return _then(_self.copyWith(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,endpoint: null == endpoint ? _self.endpoint : endpoint // ignore: cast_nullable_to_non_nullable
as AccountEndpoint,permission: null == permission ? _self.permission : permission // ignore: cast_nullable_to_non_nullable
as DetailEditPermission,editPurpose: freezed == editPurpose ? _self.editPurpose : editPurpose // ignore: cast_nullable_to_non_nullable
as AccountSelectionPurpose?,
  ));
}
/// Create a copy of DetailAccountRow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetailEditPermissionCopyWith<$Res> get permission {

  return $DetailEditPermissionCopyWith<$Res>(_self.permission, (value) {
    return _then(_self.copyWith(permission: value));
  });
}
}


/// Adds pattern-matching-related methods to [DetailAccountRow].
extension DetailAccountRowPatterns on DetailAccountRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DetailAccountRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DetailAccountRow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DetailAccountRow value)  $default,){
final _that = this;
switch (_that) {
case _DetailAccountRow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DetailAccountRow value)?  $default,){
final _that = this;
switch (_that) {
case _DetailAccountRow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String label,  String accountId,  AccountEndpoint endpoint,  DetailEditPermission permission,  AccountSelectionPurpose? editPurpose)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DetailAccountRow() when $default != null:
return $default(_that.label,_that.accountId,_that.endpoint,_that.permission,_that.editPurpose);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String label,  String accountId,  AccountEndpoint endpoint,  DetailEditPermission permission,  AccountSelectionPurpose? editPurpose)  $default,) {final _that = this;
switch (_that) {
case _DetailAccountRow():
return $default(_that.label,_that.accountId,_that.endpoint,_that.permission,_that.editPurpose);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String label,  String accountId,  AccountEndpoint endpoint,  DetailEditPermission permission,  AccountSelectionPurpose? editPurpose)?  $default,) {final _that = this;
switch (_that) {
case _DetailAccountRow() when $default != null:
return $default(_that.label,_that.accountId,_that.endpoint,_that.permission,_that.editPurpose);case _:
  return null;

}
}

}

/// @nodoc


class _DetailAccountRow implements DetailAccountRow {
  const _DetailAccountRow({required this.label, required this.accountId, required this.endpoint, required this.permission, this.editPurpose});


@override final  String label;
@override final  String accountId;
@override final  AccountEndpoint endpoint;
@override final  DetailEditPermission permission;
@override final  AccountSelectionPurpose? editPurpose;

/// Create a copy of DetailAccountRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DetailAccountRowCopyWith<_DetailAccountRow> get copyWith => __$DetailAccountRowCopyWithImpl<_DetailAccountRow>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DetailAccountRow&&(identical(other.label, label) || other.label == label)&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.endpoint, endpoint) || other.endpoint == endpoint)&&(identical(other.permission, permission) || other.permission == permission)&&(identical(other.editPurpose, editPurpose) || other.editPurpose == editPurpose));
}


@override
int get hashCode => Object.hash(runtimeType,label,accountId,endpoint,permission,editPurpose);

@override
String toString() {
  return 'DetailAccountRow(label: $label, accountId: $accountId, endpoint: $endpoint, permission: $permission, editPurpose: $editPurpose)';
}


}

/// @nodoc
abstract mixin class _$DetailAccountRowCopyWith<$Res> implements $DetailAccountRowCopyWith<$Res> {
  factory _$DetailAccountRowCopyWith(_DetailAccountRow value, $Res Function(_DetailAccountRow) _then) = __$DetailAccountRowCopyWithImpl;
@override @useResult
$Res call({
 String label, String accountId, AccountEndpoint endpoint, DetailEditPermission permission, AccountSelectionPurpose? editPurpose
});


@override $DetailEditPermissionCopyWith<$Res> get permission;

}
/// @nodoc
class __$DetailAccountRowCopyWithImpl<$Res>
    implements _$DetailAccountRowCopyWith<$Res> {
  __$DetailAccountRowCopyWithImpl(this._self, this._then);

  final _DetailAccountRow _self;
  final $Res Function(_DetailAccountRow) _then;

/// Create a copy of DetailAccountRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? accountId = null,Object? endpoint = null,Object? permission = null,Object? editPurpose = freezed,}) {
  return _then(_DetailAccountRow(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,endpoint: null == endpoint ? _self.endpoint : endpoint // ignore: cast_nullable_to_non_nullable
as AccountEndpoint,permission: null == permission ? _self.permission : permission // ignore: cast_nullable_to_non_nullable
as DetailEditPermission,editPurpose: freezed == editPurpose ? _self.editPurpose : editPurpose // ignore: cast_nullable_to_non_nullable
as AccountSelectionPurpose?,
  ));
}

/// Create a copy of DetailAccountRow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetailEditPermissionCopyWith<$Res> get permission {

  return $DetailEditPermissionCopyWith<$Res>(_self.permission, (value) {
    return _then(_self.copyWith(permission: value));
  });
}
}

/// @nodoc
mixin _$DetailEditPermission {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetailEditPermission);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DetailEditPermission()';
}


}

/// @nodoc
class $DetailEditPermissionCopyWith<$Res>  {
$DetailEditPermissionCopyWith(DetailEditPermission _, $Res Function(DetailEditPermission) __);
}


/// Adds pattern-matching-related methods to [DetailEditPermission].
extension DetailEditPermissionPatterns on DetailEditPermission {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( DetailEditAllowed value)?  allowed,TResult Function( DetailEditDenied value)?  denied,required TResult orElse(),}){
final _that = this;
switch (_that) {
case DetailEditAllowed() when allowed != null:
return allowed(_that);case DetailEditDenied() when denied != null:
return denied(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( DetailEditAllowed value)  allowed,required TResult Function( DetailEditDenied value)  denied,}){
final _that = this;
switch (_that) {
case DetailEditAllowed():
return allowed(_that);case DetailEditDenied():
return denied(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( DetailEditAllowed value)?  allowed,TResult? Function( DetailEditDenied value)?  denied,}){
final _that = this;
switch (_that) {
case DetailEditAllowed() when allowed != null:
return allowed(_that);case DetailEditDenied() when denied != null:
return denied(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  allowed,TResult Function( String reason)?  denied,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DetailEditAllowed() when allowed != null:
return allowed();case DetailEditDenied() when denied != null:
return denied(_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  allowed,required TResult Function( String reason)  denied,}) {final _that = this;
switch (_that) {
case DetailEditAllowed():
return allowed();case DetailEditDenied():
return denied(_that.reason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  allowed,TResult? Function( String reason)?  denied,}) {final _that = this;
switch (_that) {
case DetailEditAllowed() when allowed != null:
return allowed();case DetailEditDenied() when denied != null:
return denied(_that.reason);case _:
  return null;

}
}

}

/// @nodoc


class DetailEditAllowed implements DetailEditPermission {
  const DetailEditAllowed();







@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetailEditAllowed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DetailEditPermission.allowed()';
}


}




/// @nodoc


class DetailEditDenied implements DetailEditPermission {
  const DetailEditDenied({required this.reason});


 final  String reason;

/// Create a copy of DetailEditPermission
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetailEditDeniedCopyWith<DetailEditDenied> get copyWith => _$DetailEditDeniedCopyWithImpl<DetailEditDenied>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetailEditDenied&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'DetailEditPermission.denied(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $DetailEditDeniedCopyWith<$Res> implements $DetailEditPermissionCopyWith<$Res> {
  factory $DetailEditDeniedCopyWith(DetailEditDenied value, $Res Function(DetailEditDenied) _then) = _$DetailEditDeniedCopyWithImpl;
@useResult
$Res call({
 String reason
});




}
/// @nodoc
class _$DetailEditDeniedCopyWithImpl<$Res>
    implements $DetailEditDeniedCopyWith<$Res> {
  _$DetailEditDeniedCopyWithImpl(this._self, this._then);

  final DetailEditDenied _self;
  final $Res Function(DetailEditDenied) _then;

/// Create a copy of DetailEditPermission
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(DetailEditDenied(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$DetailRefund {

 bool get hasRefund; List<DetailSheetItem> get items; Money? get refundedTotal;
/// Create a copy of DetailRefund
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetailRefundCopyWith<DetailRefund> get copyWith => _$DetailRefundCopyWithImpl<DetailRefund>(this as DetailRefund, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetailRefund&&(identical(other.hasRefund, hasRefund) || other.hasRefund == hasRefund)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.refundedTotal, refundedTotal) || other.refundedTotal == refundedTotal));
}


@override
int get hashCode => Object.hash(runtimeType,hasRefund,const DeepCollectionEquality().hash(items),refundedTotal);

@override
String toString() {
  return 'DetailRefund(hasRefund: $hasRefund, items: $items, refundedTotal: $refundedTotal)';
}


}

/// @nodoc
abstract mixin class $DetailRefundCopyWith<$Res>  {
  factory $DetailRefundCopyWith(DetailRefund value, $Res Function(DetailRefund) _then) = _$DetailRefundCopyWithImpl;
@useResult
$Res call({
 bool hasRefund, List<DetailSheetItem> items, Money? refundedTotal
});




}
/// @nodoc
class _$DetailRefundCopyWithImpl<$Res>
    implements $DetailRefundCopyWith<$Res> {
  _$DetailRefundCopyWithImpl(this._self, this._then);

  final DetailRefund _self;
  final $Res Function(DetailRefund) _then;

/// Create a copy of DetailRefund
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hasRefund = null,Object? items = null,Object? refundedTotal = freezed,}) {
  return _then(_self.copyWith(
hasRefund: null == hasRefund ? _self.hasRefund : hasRefund // ignore: cast_nullable_to_non_nullable
as bool,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<DetailSheetItem>,refundedTotal: freezed == refundedTotal ? _self.refundedTotal : refundedTotal // ignore: cast_nullable_to_non_nullable
as Money?,
  ));
}

}


/// Adds pattern-matching-related methods to [DetailRefund].
extension DetailRefundPatterns on DetailRefund {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DetailRefund value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DetailRefund() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DetailRefund value)  $default,){
final _that = this;
switch (_that) {
case _DetailRefund():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DetailRefund value)?  $default,){
final _that = this;
switch (_that) {
case _DetailRefund() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool hasRefund,  List<DetailSheetItem> items,  Money? refundedTotal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DetailRefund() when $default != null:
return $default(_that.hasRefund,_that.items,_that.refundedTotal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool hasRefund,  List<DetailSheetItem> items,  Money? refundedTotal)  $default,) {final _that = this;
switch (_that) {
case _DetailRefund():
return $default(_that.hasRefund,_that.items,_that.refundedTotal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool hasRefund,  List<DetailSheetItem> items,  Money? refundedTotal)?  $default,) {final _that = this;
switch (_that) {
case _DetailRefund() when $default != null:
return $default(_that.hasRefund,_that.items,_that.refundedTotal);case _:
  return null;

}
}

}

/// @nodoc


class _DetailRefund implements DetailRefund {
  const _DetailRefund({required this.hasRefund, required final  List<DetailSheetItem> items, this.refundedTotal}): _items = items;


@override final  bool hasRefund;
 final  List<DetailSheetItem> _items;
@override List<DetailSheetItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  Money? refundedTotal;

/// Create a copy of DetailRefund
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DetailRefundCopyWith<_DetailRefund> get copyWith => __$DetailRefundCopyWithImpl<_DetailRefund>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DetailRefund&&(identical(other.hasRefund, hasRefund) || other.hasRefund == hasRefund)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.refundedTotal, refundedTotal) || other.refundedTotal == refundedTotal));
}


@override
int get hashCode => Object.hash(runtimeType,hasRefund,const DeepCollectionEquality().hash(_items),refundedTotal);

@override
String toString() {
  return 'DetailRefund(hasRefund: $hasRefund, items: $items, refundedTotal: $refundedTotal)';
}


}

/// @nodoc
abstract mixin class _$DetailRefundCopyWith<$Res> implements $DetailRefundCopyWith<$Res> {
  factory _$DetailRefundCopyWith(_DetailRefund value, $Res Function(_DetailRefund) _then) = __$DetailRefundCopyWithImpl;
@override @useResult
$Res call({
 bool hasRefund, List<DetailSheetItem> items, Money? refundedTotal
});




}
/// @nodoc
class __$DetailRefundCopyWithImpl<$Res>
    implements _$DetailRefundCopyWith<$Res> {
  __$DetailRefundCopyWithImpl(this._self, this._then);

  final _DetailRefund _self;
  final $Res Function(_DetailRefund) _then;

/// Create a copy of DetailRefund
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hasRefund = null,Object? items = null,Object? refundedTotal = freezed,}) {
  return _then(_DetailRefund(
hasRefund: null == hasRefund ? _self.hasRefund : hasRefund // ignore: cast_nullable_to_non_nullable
as bool,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<DetailSheetItem>,refundedTotal: freezed == refundedTotal ? _self.refundedTotal : refundedTotal // ignore: cast_nullable_to_non_nullable
as Money?,
  ));
}


}

/// @nodoc
mixin _$DetailReimbursement {

 String get summaryText; bool get hasActivity; bool get isClosed; List<DetailSheetItem> get items; Money? get outstanding;
/// Create a copy of DetailReimbursement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetailReimbursementCopyWith<DetailReimbursement> get copyWith => _$DetailReimbursementCopyWithImpl<DetailReimbursement>(this as DetailReimbursement, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetailReimbursement&&(identical(other.summaryText, summaryText) || other.summaryText == summaryText)&&(identical(other.hasActivity, hasActivity) || other.hasActivity == hasActivity)&&(identical(other.isClosed, isClosed) || other.isClosed == isClosed)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.outstanding, outstanding) || other.outstanding == outstanding));
}


@override
int get hashCode => Object.hash(runtimeType,summaryText,hasActivity,isClosed,const DeepCollectionEquality().hash(items),outstanding);

@override
String toString() {
  return 'DetailReimbursement(summaryText: $summaryText, hasActivity: $hasActivity, isClosed: $isClosed, items: $items, outstanding: $outstanding)';
}


}

/// @nodoc
abstract mixin class $DetailReimbursementCopyWith<$Res>  {
  factory $DetailReimbursementCopyWith(DetailReimbursement value, $Res Function(DetailReimbursement) _then) = _$DetailReimbursementCopyWithImpl;
@useResult
$Res call({
 String summaryText, bool hasActivity, bool isClosed, List<DetailSheetItem> items, Money? outstanding
});




}
/// @nodoc
class _$DetailReimbursementCopyWithImpl<$Res>
    implements $DetailReimbursementCopyWith<$Res> {
  _$DetailReimbursementCopyWithImpl(this._self, this._then);

  final DetailReimbursement _self;
  final $Res Function(DetailReimbursement) _then;

/// Create a copy of DetailReimbursement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? summaryText = null,Object? hasActivity = null,Object? isClosed = null,Object? items = null,Object? outstanding = freezed,}) {
  return _then(_self.copyWith(
summaryText: null == summaryText ? _self.summaryText : summaryText // ignore: cast_nullable_to_non_nullable
as String,hasActivity: null == hasActivity ? _self.hasActivity : hasActivity // ignore: cast_nullable_to_non_nullable
as bool,isClosed: null == isClosed ? _self.isClosed : isClosed // ignore: cast_nullable_to_non_nullable
as bool,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<DetailSheetItem>,outstanding: freezed == outstanding ? _self.outstanding : outstanding // ignore: cast_nullable_to_non_nullable
as Money?,
  ));
}

}


/// Adds pattern-matching-related methods to [DetailReimbursement].
extension DetailReimbursementPatterns on DetailReimbursement {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DetailReimbursement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DetailReimbursement() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DetailReimbursement value)  $default,){
final _that = this;
switch (_that) {
case _DetailReimbursement():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DetailReimbursement value)?  $default,){
final _that = this;
switch (_that) {
case _DetailReimbursement() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String summaryText,  bool hasActivity,  bool isClosed,  List<DetailSheetItem> items,  Money? outstanding)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DetailReimbursement() when $default != null:
return $default(_that.summaryText,_that.hasActivity,_that.isClosed,_that.items,_that.outstanding);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String summaryText,  bool hasActivity,  bool isClosed,  List<DetailSheetItem> items,  Money? outstanding)  $default,) {final _that = this;
switch (_that) {
case _DetailReimbursement():
return $default(_that.summaryText,_that.hasActivity,_that.isClosed,_that.items,_that.outstanding);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String summaryText,  bool hasActivity,  bool isClosed,  List<DetailSheetItem> items,  Money? outstanding)?  $default,) {final _that = this;
switch (_that) {
case _DetailReimbursement() when $default != null:
return $default(_that.summaryText,_that.hasActivity,_that.isClosed,_that.items,_that.outstanding);case _:
  return null;

}
}

}

/// @nodoc


class _DetailReimbursement implements DetailReimbursement {
  const _DetailReimbursement({required this.summaryText, required this.hasActivity, required this.isClosed, required final  List<DetailSheetItem> items, this.outstanding}): _items = items;


@override final  String summaryText;
@override final  bool hasActivity;
@override final  bool isClosed;
 final  List<DetailSheetItem> _items;
@override List<DetailSheetItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  Money? outstanding;

/// Create a copy of DetailReimbursement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DetailReimbursementCopyWith<_DetailReimbursement> get copyWith => __$DetailReimbursementCopyWithImpl<_DetailReimbursement>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DetailReimbursement&&(identical(other.summaryText, summaryText) || other.summaryText == summaryText)&&(identical(other.hasActivity, hasActivity) || other.hasActivity == hasActivity)&&(identical(other.isClosed, isClosed) || other.isClosed == isClosed)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.outstanding, outstanding) || other.outstanding == outstanding));
}


@override
int get hashCode => Object.hash(runtimeType,summaryText,hasActivity,isClosed,const DeepCollectionEquality().hash(_items),outstanding);

@override
String toString() {
  return 'DetailReimbursement(summaryText: $summaryText, hasActivity: $hasActivity, isClosed: $isClosed, items: $items, outstanding: $outstanding)';
}


}

/// @nodoc
abstract mixin class _$DetailReimbursementCopyWith<$Res> implements $DetailReimbursementCopyWith<$Res> {
  factory _$DetailReimbursementCopyWith(_DetailReimbursement value, $Res Function(_DetailReimbursement) _then) = __$DetailReimbursementCopyWithImpl;
@override @useResult
$Res call({
 String summaryText, bool hasActivity, bool isClosed, List<DetailSheetItem> items, Money? outstanding
});




}
/// @nodoc
class __$DetailReimbursementCopyWithImpl<$Res>
    implements _$DetailReimbursementCopyWith<$Res> {
  __$DetailReimbursementCopyWithImpl(this._self, this._then);

  final _DetailReimbursement _self;
  final $Res Function(_DetailReimbursement) _then;

/// Create a copy of DetailReimbursement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? summaryText = null,Object? hasActivity = null,Object? isClosed = null,Object? items = null,Object? outstanding = freezed,}) {
  return _then(_DetailReimbursement(
summaryText: null == summaryText ? _self.summaryText : summaryText // ignore: cast_nullable_to_non_nullable
as String,hasActivity: null == hasActivity ? _self.hasActivity : hasActivity // ignore: cast_nullable_to_non_nullable
as bool,isClosed: null == isClosed ? _self.isClosed : isClosed // ignore: cast_nullable_to_non_nullable
as bool,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<DetailSheetItem>,outstanding: freezed == outstanding ? _self.outstanding : outstanding // ignore: cast_nullable_to_non_nullable
as Money?,
  ));
}


}

/// @nodoc
mixin _$DetailActionButton {

 DetailActionKind get kind; String get label; bool get primary; bool get enabled; String? get route; String? get deniedReason;
/// Create a copy of DetailActionButton
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetailActionButtonCopyWith<DetailActionButton> get copyWith => _$DetailActionButtonCopyWithImpl<DetailActionButton>(this as DetailActionButton, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetailActionButton&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.label, label) || other.label == label)&&(identical(other.primary, primary) || other.primary == primary)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.route, route) || other.route == route)&&(identical(other.deniedReason, deniedReason) || other.deniedReason == deniedReason));
}


@override
int get hashCode => Object.hash(runtimeType,kind,label,primary,enabled,route,deniedReason);

@override
String toString() {
  return 'DetailActionButton(kind: $kind, label: $label, primary: $primary, enabled: $enabled, route: $route, deniedReason: $deniedReason)';
}


}

/// @nodoc
abstract mixin class $DetailActionButtonCopyWith<$Res>  {
  factory $DetailActionButtonCopyWith(DetailActionButton value, $Res Function(DetailActionButton) _then) = _$DetailActionButtonCopyWithImpl;
@useResult
$Res call({
 DetailActionKind kind, String label, bool primary, bool enabled, String? route, String? deniedReason
});




}
/// @nodoc
class _$DetailActionButtonCopyWithImpl<$Res>
    implements $DetailActionButtonCopyWith<$Res> {
  _$DetailActionButtonCopyWithImpl(this._self, this._then);

  final DetailActionButton _self;
  final $Res Function(DetailActionButton) _then;

/// Create a copy of DetailActionButton
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? label = null,Object? primary = null,Object? enabled = null,Object? route = freezed,Object? deniedReason = freezed,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as DetailActionKind,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,primary: null == primary ? _self.primary : primary // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,route: freezed == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String?,deniedReason: freezed == deniedReason ? _self.deniedReason : deniedReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DetailActionButton].
extension DetailActionButtonPatterns on DetailActionButton {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DetailActionButton value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DetailActionButton() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DetailActionButton value)  $default,){
final _that = this;
switch (_that) {
case _DetailActionButton():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DetailActionButton value)?  $default,){
final _that = this;
switch (_that) {
case _DetailActionButton() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DetailActionKind kind,  String label,  bool primary,  bool enabled,  String? route,  String? deniedReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DetailActionButton() when $default != null:
return $default(_that.kind,_that.label,_that.primary,_that.enabled,_that.route,_that.deniedReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DetailActionKind kind,  String label,  bool primary,  bool enabled,  String? route,  String? deniedReason)  $default,) {final _that = this;
switch (_that) {
case _DetailActionButton():
return $default(_that.kind,_that.label,_that.primary,_that.enabled,_that.route,_that.deniedReason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DetailActionKind kind,  String label,  bool primary,  bool enabled,  String? route,  String? deniedReason)?  $default,) {final _that = this;
switch (_that) {
case _DetailActionButton() when $default != null:
return $default(_that.kind,_that.label,_that.primary,_that.enabled,_that.route,_that.deniedReason);case _:
  return null;

}
}

}

/// @nodoc


class _DetailActionButton implements DetailActionButton {
  const _DetailActionButton({required this.kind, required this.label, required this.primary, required this.enabled, this.route, this.deniedReason});


@override final  DetailActionKind kind;
@override final  String label;
@override final  bool primary;
@override final  bool enabled;
@override final  String? route;
@override final  String? deniedReason;

/// Create a copy of DetailActionButton
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DetailActionButtonCopyWith<_DetailActionButton> get copyWith => __$DetailActionButtonCopyWithImpl<_DetailActionButton>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DetailActionButton&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.label, label) || other.label == label)&&(identical(other.primary, primary) || other.primary == primary)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.route, route) || other.route == route)&&(identical(other.deniedReason, deniedReason) || other.deniedReason == deniedReason));
}


@override
int get hashCode => Object.hash(runtimeType,kind,label,primary,enabled,route,deniedReason);

@override
String toString() {
  return 'DetailActionButton(kind: $kind, label: $label, primary: $primary, enabled: $enabled, route: $route, deniedReason: $deniedReason)';
}


}

/// @nodoc
abstract mixin class _$DetailActionButtonCopyWith<$Res> implements $DetailActionButtonCopyWith<$Res> {
  factory _$DetailActionButtonCopyWith(_DetailActionButton value, $Res Function(_DetailActionButton) _then) = __$DetailActionButtonCopyWithImpl;
@override @useResult
$Res call({
 DetailActionKind kind, String label, bool primary, bool enabled, String? route, String? deniedReason
});




}
/// @nodoc
class __$DetailActionButtonCopyWithImpl<$Res>
    implements _$DetailActionButtonCopyWith<$Res> {
  __$DetailActionButtonCopyWithImpl(this._self, this._then);

  final _DetailActionButton _self;
  final $Res Function(_DetailActionButton) _then;

/// Create a copy of DetailActionButton
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? label = null,Object? primary = null,Object? enabled = null,Object? route = freezed,Object? deniedReason = freezed,}) {
  return _then(_DetailActionButton(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as DetailActionKind,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,primary: null == primary ? _self.primary : primary // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,route: freezed == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String?,deniedReason: freezed == deniedReason ? _self.deniedReason : deniedReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
