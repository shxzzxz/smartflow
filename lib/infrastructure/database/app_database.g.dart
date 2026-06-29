// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts
    with TableInfo<$AccountsTable, AccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AccountType, String> accountType =
      GeneratedColumn<String>(
        'account_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AccountType>($AccountsTable.$converteraccountType);
  @override
  late final GeneratedColumnWithTypeConverter<AccountSubtype?, String>
  accountSubtype = GeneratedColumn<String>(
    'account_subtype',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<AccountSubtype?>($AccountsTable.$converteraccountSubtypen);
  static const VerificationMeta _accountProfileKeyMeta = const VerificationMeta(
    'accountProfileKey',
  );
  @override
  late final GeneratedColumn<String> accountProfileKey =
      GeneratedColumn<String>(
        'account_profile_key',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _balanceMinorMeta = const VerificationMeta(
    'balanceMinor',
  );
  @override
  late final GeneratedColumn<int> balanceMinor = GeneratedColumn<int>(
    'balance_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta(
    'iconKey',
  );
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creditLimitMinorMeta = const VerificationMeta(
    'creditLimitMinor',
  );
  @override
  late final GeneratedColumn<int> creditLimitMinor = GeneratedColumn<int>(
    'credit_limit_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _billingDayMeta = const VerificationMeta(
    'billingDay',
  );
  @override
  late final GeneratedColumn<int> billingDay = GeneratedColumn<int>(
    'billing_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repaymentDayMeta = const VerificationMeta(
    'repaymentDay',
  );
  @override
  late final GeneratedColumn<int> repaymentDay = GeneratedColumn<int>(
    'repayment_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isHiddenMeta = const VerificationMeta(
    'isHidden',
  );
  @override
  late final GeneratedColumn<bool> isHidden = GeneratedColumn<bool>(
    'is_hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SystemKey?, String> systemKey =
      GeneratedColumn<String>(
        'system_key',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<SystemKey?>($AccountsTable.$convertersystemKeyn);
  @override
  late final GeneratedColumnWithTypeConverter<AccountSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(AccountSource.user.name),
      ).withConverter<AccountSource>($AccountsTable.$convertersource);
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    accountType,
    accountSubtype,
    accountProfileKey,
    parentId,
    balanceMinor,
    iconKey,
    note,
    creditLimitMinor,
    billingDay,
    repaymentDay,
    sortOrder,
    isHidden,
    archivedAt,
    systemKey,
    source,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('account_profile_key')) {
      context.handle(
        _accountProfileKeyMeta,
        accountProfileKey.isAcceptableOrUnknown(
          data['account_profile_key']!,
          _accountProfileKeyMeta,
        ),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('balance_minor')) {
      context.handle(
        _balanceMinorMeta,
        balanceMinor.isAcceptableOrUnknown(
          data['balance_minor']!,
          _balanceMinorMeta,
        ),
      );
    }
    if (data.containsKey('icon_key')) {
      context.handle(
        _iconKeyMeta,
        iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('credit_limit_minor')) {
      context.handle(
        _creditLimitMinorMeta,
        creditLimitMinor.isAcceptableOrUnknown(
          data['credit_limit_minor']!,
          _creditLimitMinorMeta,
        ),
      );
    }
    if (data.containsKey('billing_day')) {
      context.handle(
        _billingDayMeta,
        billingDay.isAcceptableOrUnknown(data['billing_day']!, _billingDayMeta),
      );
    }
    if (data.containsKey('repayment_day')) {
      context.handle(
        _repaymentDayMeta,
        repaymentDay.isAcceptableOrUnknown(
          data['repayment_day']!,
          _repaymentDayMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_hidden')) {
      context.handle(
        _isHiddenMeta,
        isHidden.isAcceptableOrUnknown(data['is_hidden']!, _isHiddenMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      accountType: $AccountsTable.$converteraccountType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}account_type'],
        )!,
      ),
      accountSubtype: $AccountsTable.$converteraccountSubtypen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}account_subtype'],
        ),
      ),
      accountProfileKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_profile_key'],
      ),
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      balanceMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}balance_minor'],
          )!,
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      creditLimitMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credit_limit_minor'],
      ),
      billingDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}billing_day'],
      ),
      repaymentDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repayment_day'],
      ),
      sortOrder:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sort_order'],
          )!,
      isHidden:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_hidden'],
          )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      systemKey: $AccountsTable.$convertersystemKeyn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}system_key'],
        ),
      ),
      source: $AccountsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      version:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}version'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AccountType, String, String> $converteraccountType =
      const EnumNameConverter<AccountType>(AccountType.values);
  static JsonTypeConverter2<AccountSubtype, String, String>
  $converteraccountSubtype = const EnumNameConverter<AccountSubtype>(
    AccountSubtype.values,
  );
  static JsonTypeConverter2<AccountSubtype?, String?, String?>
  $converteraccountSubtypen = JsonTypeConverter2.asNullable(
    $converteraccountSubtype,
  );
  static JsonTypeConverter2<SystemKey, String, String> $convertersystemKey =
      const EnumNameConverter<SystemKey>(SystemKey.values);
  static JsonTypeConverter2<SystemKey?, String?, String?> $convertersystemKeyn =
      JsonTypeConverter2.asNullable($convertersystemKey);
  static JsonTypeConverter2<AccountSource, String, String> $convertersource =
      const EnumNameConverter<AccountSource>(AccountSource.values);
}

class AccountRow extends DataClass implements Insertable<AccountRow> {
  final String id;
  final String name;
  final AccountType accountType;
  final AccountSubtype? accountSubtype;
  final String? accountProfileKey;
  final String? parentId;
  final int balanceMinor;
  final String? iconKey;
  final String? note;
  final int? creditLimitMinor;
  final int? billingDay;
  final int? repaymentDay;
  final int sortOrder;
  final bool isHidden;
  final DateTime? archivedAt;
  final SystemKey? systemKey;
  final AccountSource source;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AccountRow({
    required this.id,
    required this.name,
    required this.accountType,
    this.accountSubtype,
    this.accountProfileKey,
    this.parentId,
    required this.balanceMinor,
    this.iconKey,
    this.note,
    this.creditLimitMinor,
    this.billingDay,
    this.repaymentDay,
    required this.sortOrder,
    required this.isHidden,
    this.archivedAt,
    this.systemKey,
    required this.source,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    {
      map['account_type'] = Variable<String>(
        $AccountsTable.$converteraccountType.toSql(accountType),
      );
    }
    if (!nullToAbsent || accountSubtype != null) {
      map['account_subtype'] = Variable<String>(
        $AccountsTable.$converteraccountSubtypen.toSql(accountSubtype),
      );
    }
    if (!nullToAbsent || accountProfileKey != null) {
      map['account_profile_key'] = Variable<String>(accountProfileKey);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['balance_minor'] = Variable<int>(balanceMinor);
    if (!nullToAbsent || iconKey != null) {
      map['icon_key'] = Variable<String>(iconKey);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || creditLimitMinor != null) {
      map['credit_limit_minor'] = Variable<int>(creditLimitMinor);
    }
    if (!nullToAbsent || billingDay != null) {
      map['billing_day'] = Variable<int>(billingDay);
    }
    if (!nullToAbsent || repaymentDay != null) {
      map['repayment_day'] = Variable<int>(repaymentDay);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_hidden'] = Variable<bool>(isHidden);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || systemKey != null) {
      map['system_key'] = Variable<String>(
        $AccountsTable.$convertersystemKeyn.toSql(systemKey),
      );
    }
    {
      map['source'] = Variable<String>(
        $AccountsTable.$convertersource.toSql(source),
      );
    }
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      name: Value(name),
      accountType: Value(accountType),
      accountSubtype:
          accountSubtype == null && nullToAbsent
              ? const Value.absent()
              : Value(accountSubtype),
      accountProfileKey:
          accountProfileKey == null && nullToAbsent
              ? const Value.absent()
              : Value(accountProfileKey),
      parentId:
          parentId == null && nullToAbsent
              ? const Value.absent()
              : Value(parentId),
      balanceMinor: Value(balanceMinor),
      iconKey:
          iconKey == null && nullToAbsent
              ? const Value.absent()
              : Value(iconKey),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      creditLimitMinor:
          creditLimitMinor == null && nullToAbsent
              ? const Value.absent()
              : Value(creditLimitMinor),
      billingDay:
          billingDay == null && nullToAbsent
              ? const Value.absent()
              : Value(billingDay),
      repaymentDay:
          repaymentDay == null && nullToAbsent
              ? const Value.absent()
              : Value(repaymentDay),
      sortOrder: Value(sortOrder),
      isHidden: Value(isHidden),
      archivedAt:
          archivedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(archivedAt),
      systemKey:
          systemKey == null && nullToAbsent
              ? const Value.absent()
              : Value(systemKey),
      source: Value(source),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      accountType: $AccountsTable.$converteraccountType.fromJson(
        serializer.fromJson<String>(json['accountType']),
      ),
      accountSubtype: $AccountsTable.$converteraccountSubtypen.fromJson(
        serializer.fromJson<String?>(json['accountSubtype']),
      ),
      accountProfileKey: serializer.fromJson<String?>(
        json['accountProfileKey'],
      ),
      parentId: serializer.fromJson<String?>(json['parentId']),
      balanceMinor: serializer.fromJson<int>(json['balanceMinor']),
      iconKey: serializer.fromJson<String?>(json['iconKey']),
      note: serializer.fromJson<String?>(json['note']),
      creditLimitMinor: serializer.fromJson<int?>(json['creditLimitMinor']),
      billingDay: serializer.fromJson<int?>(json['billingDay']),
      repaymentDay: serializer.fromJson<int?>(json['repaymentDay']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isHidden: serializer.fromJson<bool>(json['isHidden']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      systemKey: $AccountsTable.$convertersystemKeyn.fromJson(
        serializer.fromJson<String?>(json['systemKey']),
      ),
      source: $AccountsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'accountType': serializer.toJson<String>(
        $AccountsTable.$converteraccountType.toJson(accountType),
      ),
      'accountSubtype': serializer.toJson<String?>(
        $AccountsTable.$converteraccountSubtypen.toJson(accountSubtype),
      ),
      'accountProfileKey': serializer.toJson<String?>(accountProfileKey),
      'parentId': serializer.toJson<String?>(parentId),
      'balanceMinor': serializer.toJson<int>(balanceMinor),
      'iconKey': serializer.toJson<String?>(iconKey),
      'note': serializer.toJson<String?>(note),
      'creditLimitMinor': serializer.toJson<int?>(creditLimitMinor),
      'billingDay': serializer.toJson<int?>(billingDay),
      'repaymentDay': serializer.toJson<int?>(repaymentDay),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isHidden': serializer.toJson<bool>(isHidden),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'systemKey': serializer.toJson<String?>(
        $AccountsTable.$convertersystemKeyn.toJson(systemKey),
      ),
      'source': serializer.toJson<String>(
        $AccountsTable.$convertersource.toJson(source),
      ),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AccountRow copyWith({
    String? id,
    String? name,
    AccountType? accountType,
    Value<AccountSubtype?> accountSubtype = const Value.absent(),
    Value<String?> accountProfileKey = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
    int? balanceMinor,
    Value<String?> iconKey = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<int?> creditLimitMinor = const Value.absent(),
    Value<int?> billingDay = const Value.absent(),
    Value<int?> repaymentDay = const Value.absent(),
    int? sortOrder,
    bool? isHidden,
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<SystemKey?> systemKey = const Value.absent(),
    AccountSource? source,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AccountRow(
    id: id ?? this.id,
    name: name ?? this.name,
    accountType: accountType ?? this.accountType,
    accountSubtype:
        accountSubtype.present ? accountSubtype.value : this.accountSubtype,
    accountProfileKey:
        accountProfileKey.present
            ? accountProfileKey.value
            : this.accountProfileKey,
    parentId: parentId.present ? parentId.value : this.parentId,
    balanceMinor: balanceMinor ?? this.balanceMinor,
    iconKey: iconKey.present ? iconKey.value : this.iconKey,
    note: note.present ? note.value : this.note,
    creditLimitMinor:
        creditLimitMinor.present
            ? creditLimitMinor.value
            : this.creditLimitMinor,
    billingDay: billingDay.present ? billingDay.value : this.billingDay,
    repaymentDay: repaymentDay.present ? repaymentDay.value : this.repaymentDay,
    sortOrder: sortOrder ?? this.sortOrder,
    isHidden: isHidden ?? this.isHidden,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    systemKey: systemKey.present ? systemKey.value : this.systemKey,
    source: source ?? this.source,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AccountRow copyWithCompanion(AccountsCompanion data) {
    return AccountRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      accountType:
          data.accountType.present ? data.accountType.value : this.accountType,
      accountSubtype:
          data.accountSubtype.present
              ? data.accountSubtype.value
              : this.accountSubtype,
      accountProfileKey:
          data.accountProfileKey.present
              ? data.accountProfileKey.value
              : this.accountProfileKey,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      balanceMinor:
          data.balanceMinor.present
              ? data.balanceMinor.value
              : this.balanceMinor,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      note: data.note.present ? data.note.value : this.note,
      creditLimitMinor:
          data.creditLimitMinor.present
              ? data.creditLimitMinor.value
              : this.creditLimitMinor,
      billingDay:
          data.billingDay.present ? data.billingDay.value : this.billingDay,
      repaymentDay:
          data.repaymentDay.present
              ? data.repaymentDay.value
              : this.repaymentDay,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isHidden: data.isHidden.present ? data.isHidden.value : this.isHidden,
      archivedAt:
          data.archivedAt.present ? data.archivedAt.value : this.archivedAt,
      systemKey: data.systemKey.present ? data.systemKey.value : this.systemKey,
      source: data.source.present ? data.source.value : this.source,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('accountType: $accountType, ')
          ..write('accountSubtype: $accountSubtype, ')
          ..write('accountProfileKey: $accountProfileKey, ')
          ..write('parentId: $parentId, ')
          ..write('balanceMinor: $balanceMinor, ')
          ..write('iconKey: $iconKey, ')
          ..write('note: $note, ')
          ..write('creditLimitMinor: $creditLimitMinor, ')
          ..write('billingDay: $billingDay, ')
          ..write('repaymentDay: $repaymentDay, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isHidden: $isHidden, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('systemKey: $systemKey, ')
          ..write('source: $source, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    accountType,
    accountSubtype,
    accountProfileKey,
    parentId,
    balanceMinor,
    iconKey,
    note,
    creditLimitMinor,
    billingDay,
    repaymentDay,
    sortOrder,
    isHidden,
    archivedAt,
    systemKey,
    source,
    version,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.accountType == this.accountType &&
          other.accountSubtype == this.accountSubtype &&
          other.accountProfileKey == this.accountProfileKey &&
          other.parentId == this.parentId &&
          other.balanceMinor == this.balanceMinor &&
          other.iconKey == this.iconKey &&
          other.note == this.note &&
          other.creditLimitMinor == this.creditLimitMinor &&
          other.billingDay == this.billingDay &&
          other.repaymentDay == this.repaymentDay &&
          other.sortOrder == this.sortOrder &&
          other.isHidden == this.isHidden &&
          other.archivedAt == this.archivedAt &&
          other.systemKey == this.systemKey &&
          other.source == this.source &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AccountsCompanion extends UpdateCompanion<AccountRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<AccountType> accountType;
  final Value<AccountSubtype?> accountSubtype;
  final Value<String?> accountProfileKey;
  final Value<String?> parentId;
  final Value<int> balanceMinor;
  final Value<String?> iconKey;
  final Value<String?> note;
  final Value<int?> creditLimitMinor;
  final Value<int?> billingDay;
  final Value<int?> repaymentDay;
  final Value<int> sortOrder;
  final Value<bool> isHidden;
  final Value<DateTime?> archivedAt;
  final Value<SystemKey?> systemKey;
  final Value<AccountSource> source;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.accountType = const Value.absent(),
    this.accountSubtype = const Value.absent(),
    this.accountProfileKey = const Value.absent(),
    this.parentId = const Value.absent(),
    this.balanceMinor = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.note = const Value.absent(),
    this.creditLimitMinor = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.repaymentDay = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.systemKey = const Value.absent(),
    this.source = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required String name,
    required AccountType accountType,
    this.accountSubtype = const Value.absent(),
    this.accountProfileKey = const Value.absent(),
    this.parentId = const Value.absent(),
    this.balanceMinor = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.note = const Value.absent(),
    this.creditLimitMinor = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.repaymentDay = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.systemKey = const Value.absent(),
    this.source = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       accountType = Value(accountType);
  static Insertable<AccountRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? accountType,
    Expression<String>? accountSubtype,
    Expression<String>? accountProfileKey,
    Expression<String>? parentId,
    Expression<int>? balanceMinor,
    Expression<String>? iconKey,
    Expression<String>? note,
    Expression<int>? creditLimitMinor,
    Expression<int>? billingDay,
    Expression<int>? repaymentDay,
    Expression<int>? sortOrder,
    Expression<bool>? isHidden,
    Expression<DateTime>? archivedAt,
    Expression<String>? systemKey,
    Expression<String>? source,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (accountType != null) 'account_type': accountType,
      if (accountSubtype != null) 'account_subtype': accountSubtype,
      if (accountProfileKey != null) 'account_profile_key': accountProfileKey,
      if (parentId != null) 'parent_id': parentId,
      if (balanceMinor != null) 'balance_minor': balanceMinor,
      if (iconKey != null) 'icon_key': iconKey,
      if (note != null) 'note': note,
      if (creditLimitMinor != null) 'credit_limit_minor': creditLimitMinor,
      if (billingDay != null) 'billing_day': billingDay,
      if (repaymentDay != null) 'repayment_day': repaymentDay,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isHidden != null) 'is_hidden': isHidden,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (systemKey != null) 'system_key': systemKey,
      if (source != null) 'source': source,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<AccountType>? accountType,
    Value<AccountSubtype?>? accountSubtype,
    Value<String?>? accountProfileKey,
    Value<String?>? parentId,
    Value<int>? balanceMinor,
    Value<String?>? iconKey,
    Value<String?>? note,
    Value<int?>? creditLimitMinor,
    Value<int?>? billingDay,
    Value<int?>? repaymentDay,
    Value<int>? sortOrder,
    Value<bool>? isHidden,
    Value<DateTime?>? archivedAt,
    Value<SystemKey?>? systemKey,
    Value<AccountSource>? source,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      accountSubtype: accountSubtype ?? this.accountSubtype,
      accountProfileKey: accountProfileKey ?? this.accountProfileKey,
      parentId: parentId ?? this.parentId,
      balanceMinor: balanceMinor ?? this.balanceMinor,
      iconKey: iconKey ?? this.iconKey,
      note: note ?? this.note,
      creditLimitMinor: creditLimitMinor ?? this.creditLimitMinor,
      billingDay: billingDay ?? this.billingDay,
      repaymentDay: repaymentDay ?? this.repaymentDay,
      sortOrder: sortOrder ?? this.sortOrder,
      isHidden: isHidden ?? this.isHidden,
      archivedAt: archivedAt ?? this.archivedAt,
      systemKey: systemKey ?? this.systemKey,
      source: source ?? this.source,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (accountType.present) {
      map['account_type'] = Variable<String>(
        $AccountsTable.$converteraccountType.toSql(accountType.value),
      );
    }
    if (accountSubtype.present) {
      map['account_subtype'] = Variable<String>(
        $AccountsTable.$converteraccountSubtypen.toSql(accountSubtype.value),
      );
    }
    if (accountProfileKey.present) {
      map['account_profile_key'] = Variable<String>(accountProfileKey.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (balanceMinor.present) {
      map['balance_minor'] = Variable<int>(balanceMinor.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (creditLimitMinor.present) {
      map['credit_limit_minor'] = Variable<int>(creditLimitMinor.value);
    }
    if (billingDay.present) {
      map['billing_day'] = Variable<int>(billingDay.value);
    }
    if (repaymentDay.present) {
      map['repayment_day'] = Variable<int>(repaymentDay.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isHidden.present) {
      map['is_hidden'] = Variable<bool>(isHidden.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (systemKey.present) {
      map['system_key'] = Variable<String>(
        $AccountsTable.$convertersystemKeyn.toSql(systemKey.value),
      );
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $AccountsTable.$convertersource.toSql(source.value),
      );
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('accountType: $accountType, ')
          ..write('accountSubtype: $accountSubtype, ')
          ..write('accountProfileKey: $accountProfileKey, ')
          ..write('parentId: $parentId, ')
          ..write('balanceMinor: $balanceMinor, ')
          ..write('iconKey: $iconKey, ')
          ..write('note: $note, ')
          ..write('creditLimitMinor: $creditLimitMinor, ')
          ..write('billingDay: $billingDay, ')
          ..write('repaymentDay: $repaymentDay, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isHidden: $isHidden, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('systemKey: $systemKey, ')
          ..write('source: $source, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppMetadataTable extends AppMetadata
    with TableInfo<$AppMetadataTable, AppMetadataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppMetadataRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetadataRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetadataRow(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      value:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}value'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $AppMetadataTable createAlias(String alias) {
    return $AppMetadataTable(attachedDatabase, alias);
  }
}

class AppMetadataRow extends DataClass implements Insertable<AppMetadataRow> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const AppMetadataRow({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppMetadataCompanion toCompanion(bool nullToAbsent) {
    return AppMetadataCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppMetadataRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetadataRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppMetadataRow copyWith({String? key, String? value, DateTime? updatedAt}) =>
      AppMetadataRow(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppMetadataRow copyWithCompanion(AppMetadataCompanion data) {
    return AppMetadataRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetadataRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppMetadataCompanion extends UpdateCompanion<AppMetadataRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetadataCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppMetadataRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, TransactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootTransactionIdMeta = const VerificationMeta(
    'rootTransactionId',
  );
  @override
  late final GeneratedColumn<String> rootTransactionId =
      GeneratedColumn<String>(
        'root_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  late final GeneratedColumnWithTypeConverter<BusinessPurpose, String>
  businessPurpose = GeneratedColumn<String>(
    'business_purpose',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<BusinessPurpose>(
    $TransactionsTable.$converterbusinessPurpose,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _primaryAmountMinorMeta =
      const VerificationMeta('primaryAmountMinor');
  @override
  late final GeneratedColumn<int> primaryAmountMinor = GeneratedColumn<int>(
    'primary_amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _counterpartyNameMeta = const VerificationMeta(
    'counterpartyName',
  );
  @override
  late final GeneratedColumn<String> counterpartyName = GeneratedColumn<String>(
    'counterparty_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentTransactionIdMeta =
      const VerificationMeta('parentTransactionId');
  @override
  late final GeneratedColumn<String> parentTransactionId =
      GeneratedColumn<String>(
        'parent_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _reimbursementExpenseAccountIdMeta =
      const VerificationMeta('reimbursementExpenseAccountId');
  @override
  late final GeneratedColumn<String> reimbursementExpenseAccountId =
      GeneratedColumn<String>(
        'reimbursement_expense_account_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  late final GeneratedColumnWithTypeConverter<MutationKind, String>
  mutationKind = GeneratedColumn<String>(
    'mutation_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<MutationKind>($TransactionsTable.$convertermutationKind);
  static const VerificationMeta _mutationPreviousTransactionIdMeta =
      const VerificationMeta('mutationPreviousTransactionId');
  @override
  late final GeneratedColumn<String> mutationPreviousTransactionId =
      GeneratedColumn<String>(
        'mutation_previous_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  late final GeneratedColumnWithTypeConverter<MutationReason?, String>
  mutationReason = GeneratedColumn<String>(
    'mutation_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<MutationReason?>(
    $TransactionsTable.$convertermutationReasonn,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BusinessState, String>
  businessState = GeneratedColumn<String>(
    'business_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<BusinessState>($TransactionsTable.$converterbusinessState);
  static const VerificationMeta _isExcludedFromStatsMeta =
      const VerificationMeta('isExcludedFromStats');
  @override
  late final GeneratedColumn<bool> isExcludedFromStats = GeneratedColumn<bool>(
    'is_excluded_from_stats',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_excluded_from_stats" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isExcludedFromBudgetMeta =
      const VerificationMeta('isExcludedFromBudget');
  @override
  late final GeneratedColumn<bool> isExcludedFromBudget = GeneratedColumn<bool>(
    'is_excluded_from_budget',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_excluded_from_budget" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<SourceKind, String> sourceKind =
      GeneratedColumn<String>(
        'source_kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SourceKind>($TransactionsTable.$convertersourceKind);
  static const VerificationMeta _ownerTypeMeta = const VerificationMeta(
    'ownerType',
  );
  @override
  late final GeneratedColumn<String> ownerType = GeneratedColumn<String>(
    'owner_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerRoleMeta = const VerificationMeta(
    'ownerRole',
  );
  @override
  late final GeneratedColumn<String> ownerRole = GeneratedColumn<String>(
    'owner_role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    rootTransactionId,
    businessPurpose,
    occurredAt,
    primaryAmountMinor,
    counterpartyName,
    note,
    parentTransactionId,
    reimbursementExpenseAccountId,
    mutationKind,
    mutationPreviousTransactionId,
    mutationReason,
    businessState,
    isExcludedFromStats,
    isExcludedFromBudget,
    sourceKind,
    ownerType,
    ownerId,
    ownerRole,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('root_transaction_id')) {
      context.handle(
        _rootTransactionIdMeta,
        rootTransactionId.isAcceptableOrUnknown(
          data['root_transaction_id']!,
          _rootTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('primary_amount_minor')) {
      context.handle(
        _primaryAmountMinorMeta,
        primaryAmountMinor.isAcceptableOrUnknown(
          data['primary_amount_minor']!,
          _primaryAmountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_primaryAmountMinorMeta);
    }
    if (data.containsKey('counterparty_name')) {
      context.handle(
        _counterpartyNameMeta,
        counterpartyName.isAcceptableOrUnknown(
          data['counterparty_name']!,
          _counterpartyNameMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('parent_transaction_id')) {
      context.handle(
        _parentTransactionIdMeta,
        parentTransactionId.isAcceptableOrUnknown(
          data['parent_transaction_id']!,
          _parentTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('reimbursement_expense_account_id')) {
      context.handle(
        _reimbursementExpenseAccountIdMeta,
        reimbursementExpenseAccountId.isAcceptableOrUnknown(
          data['reimbursement_expense_account_id']!,
          _reimbursementExpenseAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('mutation_previous_transaction_id')) {
      context.handle(
        _mutationPreviousTransactionIdMeta,
        mutationPreviousTransactionId.isAcceptableOrUnknown(
          data['mutation_previous_transaction_id']!,
          _mutationPreviousTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('is_excluded_from_stats')) {
      context.handle(
        _isExcludedFromStatsMeta,
        isExcludedFromStats.isAcceptableOrUnknown(
          data['is_excluded_from_stats']!,
          _isExcludedFromStatsMeta,
        ),
      );
    }
    if (data.containsKey('is_excluded_from_budget')) {
      context.handle(
        _isExcludedFromBudgetMeta,
        isExcludedFromBudget.isAcceptableOrUnknown(
          data['is_excluded_from_budget']!,
          _isExcludedFromBudgetMeta,
        ),
      );
    }
    if (data.containsKey('owner_type')) {
      context.handle(
        _ownerTypeMeta,
        ownerType.isAcceptableOrUnknown(data['owner_type']!, _ownerTypeMeta),
      );
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('owner_role')) {
      context.handle(
        _ownerRoleMeta,
        ownerRole.isAcceptableOrUnknown(data['owner_role']!, _ownerRoleMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      rootTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_transaction_id'],
      ),
      businessPurpose: $TransactionsTable.$converterbusinessPurpose.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}business_purpose'],
        )!,
      ),
      occurredAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}occurred_at'],
          )!,
      primaryAmountMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}primary_amount_minor'],
          )!,
      counterpartyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counterparty_name'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      parentTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_transaction_id'],
      ),
      reimbursementExpenseAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reimbursement_expense_account_id'],
      ),
      mutationKind: $TransactionsTable.$convertermutationKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}mutation_kind'],
        )!,
      ),
      mutationPreviousTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_previous_transaction_id'],
      ),
      mutationReason: $TransactionsTable.$convertermutationReasonn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}mutation_reason'],
        ),
      ),
      businessState: $TransactionsTable.$converterbusinessState.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}business_state'],
        )!,
      ),
      isExcludedFromStats:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_excluded_from_stats'],
          )!,
      isExcludedFromBudget:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_excluded_from_budget'],
          )!,
      sourceKind: $TransactionsTable.$convertersourceKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source_kind'],
        )!,
      ),
      ownerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_type'],
      ),
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      ),
      ownerRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_role'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<BusinessPurpose, String, String>
  $converterbusinessPurpose = const EnumNameConverter<BusinessPurpose>(
    BusinessPurpose.values,
  );
  static JsonTypeConverter2<MutationKind, String, String>
  $convertermutationKind = const EnumNameConverter<MutationKind>(
    MutationKind.values,
  );
  static JsonTypeConverter2<MutationReason, String, String>
  $convertermutationReason = const EnumNameConverter<MutationReason>(
    MutationReason.values,
  );
  static JsonTypeConverter2<MutationReason?, String?, String?>
  $convertermutationReasonn = JsonTypeConverter2.asNullable(
    $convertermutationReason,
  );
  static JsonTypeConverter2<BusinessState, String, String>
  $converterbusinessState = const EnumNameConverter<BusinessState>(
    BusinessState.values,
  );
  static JsonTypeConverter2<SourceKind, String, String> $convertersourceKind =
      const EnumNameConverter<SourceKind>(SourceKind.values);
}

class TransactionRow extends DataClass implements Insertable<TransactionRow> {
  final String id;
  final String? rootTransactionId;
  final BusinessPurpose businessPurpose;
  final DateTime occurredAt;
  final int primaryAmountMinor;
  final String? counterpartyName;
  final String? note;
  final String? parentTransactionId;
  final String? reimbursementExpenseAccountId;
  final MutationKind mutationKind;
  final String? mutationPreviousTransactionId;
  final MutationReason? mutationReason;
  final BusinessState businessState;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final SourceKind sourceKind;
  final String? ownerType;
  final String? ownerId;
  final String? ownerRole;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TransactionRow({
    required this.id,
    this.rootTransactionId,
    required this.businessPurpose,
    required this.occurredAt,
    required this.primaryAmountMinor,
    this.counterpartyName,
    this.note,
    this.parentTransactionId,
    this.reimbursementExpenseAccountId,
    required this.mutationKind,
    this.mutationPreviousTransactionId,
    this.mutationReason,
    required this.businessState,
    required this.isExcludedFromStats,
    required this.isExcludedFromBudget,
    required this.sourceKind,
    this.ownerType,
    this.ownerId,
    this.ownerRole,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || rootTransactionId != null) {
      map['root_transaction_id'] = Variable<String>(rootTransactionId);
    }
    {
      map['business_purpose'] = Variable<String>(
        $TransactionsTable.$converterbusinessPurpose.toSql(businessPurpose),
      );
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['primary_amount_minor'] = Variable<int>(primaryAmountMinor);
    if (!nullToAbsent || counterpartyName != null) {
      map['counterparty_name'] = Variable<String>(counterpartyName);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || parentTransactionId != null) {
      map['parent_transaction_id'] = Variable<String>(parentTransactionId);
    }
    if (!nullToAbsent || reimbursementExpenseAccountId != null) {
      map['reimbursement_expense_account_id'] = Variable<String>(
        reimbursementExpenseAccountId,
      );
    }
    {
      map['mutation_kind'] = Variable<String>(
        $TransactionsTable.$convertermutationKind.toSql(mutationKind),
      );
    }
    if (!nullToAbsent || mutationPreviousTransactionId != null) {
      map['mutation_previous_transaction_id'] = Variable<String>(
        mutationPreviousTransactionId,
      );
    }
    if (!nullToAbsent || mutationReason != null) {
      map['mutation_reason'] = Variable<String>(
        $TransactionsTable.$convertermutationReasonn.toSql(mutationReason),
      );
    }
    {
      map['business_state'] = Variable<String>(
        $TransactionsTable.$converterbusinessState.toSql(businessState),
      );
    }
    map['is_excluded_from_stats'] = Variable<bool>(isExcludedFromStats);
    map['is_excluded_from_budget'] = Variable<bool>(isExcludedFromBudget);
    {
      map['source_kind'] = Variable<String>(
        $TransactionsTable.$convertersourceKind.toSql(sourceKind),
      );
    }
    if (!nullToAbsent || ownerType != null) {
      map['owner_type'] = Variable<String>(ownerType);
    }
    if (!nullToAbsent || ownerId != null) {
      map['owner_id'] = Variable<String>(ownerId);
    }
    if (!nullToAbsent || ownerRole != null) {
      map['owner_role'] = Variable<String>(ownerRole);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      rootTransactionId:
          rootTransactionId == null && nullToAbsent
              ? const Value.absent()
              : Value(rootTransactionId),
      businessPurpose: Value(businessPurpose),
      occurredAt: Value(occurredAt),
      primaryAmountMinor: Value(primaryAmountMinor),
      counterpartyName:
          counterpartyName == null && nullToAbsent
              ? const Value.absent()
              : Value(counterpartyName),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      parentTransactionId:
          parentTransactionId == null && nullToAbsent
              ? const Value.absent()
              : Value(parentTransactionId),
      reimbursementExpenseAccountId:
          reimbursementExpenseAccountId == null && nullToAbsent
              ? const Value.absent()
              : Value(reimbursementExpenseAccountId),
      mutationKind: Value(mutationKind),
      mutationPreviousTransactionId:
          mutationPreviousTransactionId == null && nullToAbsent
              ? const Value.absent()
              : Value(mutationPreviousTransactionId),
      mutationReason:
          mutationReason == null && nullToAbsent
              ? const Value.absent()
              : Value(mutationReason),
      businessState: Value(businessState),
      isExcludedFromStats: Value(isExcludedFromStats),
      isExcludedFromBudget: Value(isExcludedFromBudget),
      sourceKind: Value(sourceKind),
      ownerType:
          ownerType == null && nullToAbsent
              ? const Value.absent()
              : Value(ownerType),
      ownerId:
          ownerId == null && nullToAbsent
              ? const Value.absent()
              : Value(ownerId),
      ownerRole:
          ownerRole == null && nullToAbsent
              ? const Value.absent()
              : Value(ownerRole),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TransactionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionRow(
      id: serializer.fromJson<String>(json['id']),
      rootTransactionId: serializer.fromJson<String?>(
        json['rootTransactionId'],
      ),
      businessPurpose: $TransactionsTable.$converterbusinessPurpose.fromJson(
        serializer.fromJson<String>(json['businessPurpose']),
      ),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      primaryAmountMinor: serializer.fromJson<int>(json['primaryAmountMinor']),
      counterpartyName: serializer.fromJson<String?>(json['counterpartyName']),
      note: serializer.fromJson<String?>(json['note']),
      parentTransactionId: serializer.fromJson<String?>(
        json['parentTransactionId'],
      ),
      reimbursementExpenseAccountId: serializer.fromJson<String?>(
        json['reimbursementExpenseAccountId'],
      ),
      mutationKind: $TransactionsTable.$convertermutationKind.fromJson(
        serializer.fromJson<String>(json['mutationKind']),
      ),
      mutationPreviousTransactionId: serializer.fromJson<String?>(
        json['mutationPreviousTransactionId'],
      ),
      mutationReason: $TransactionsTable.$convertermutationReasonn.fromJson(
        serializer.fromJson<String?>(json['mutationReason']),
      ),
      businessState: $TransactionsTable.$converterbusinessState.fromJson(
        serializer.fromJson<String>(json['businessState']),
      ),
      isExcludedFromStats: serializer.fromJson<bool>(
        json['isExcludedFromStats'],
      ),
      isExcludedFromBudget: serializer.fromJson<bool>(
        json['isExcludedFromBudget'],
      ),
      sourceKind: $TransactionsTable.$convertersourceKind.fromJson(
        serializer.fromJson<String>(json['sourceKind']),
      ),
      ownerType: serializer.fromJson<String?>(json['ownerType']),
      ownerId: serializer.fromJson<String?>(json['ownerId']),
      ownerRole: serializer.fromJson<String?>(json['ownerRole']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'rootTransactionId': serializer.toJson<String?>(rootTransactionId),
      'businessPurpose': serializer.toJson<String>(
        $TransactionsTable.$converterbusinessPurpose.toJson(businessPurpose),
      ),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'primaryAmountMinor': serializer.toJson<int>(primaryAmountMinor),
      'counterpartyName': serializer.toJson<String?>(counterpartyName),
      'note': serializer.toJson<String?>(note),
      'parentTransactionId': serializer.toJson<String?>(parentTransactionId),
      'reimbursementExpenseAccountId': serializer.toJson<String?>(
        reimbursementExpenseAccountId,
      ),
      'mutationKind': serializer.toJson<String>(
        $TransactionsTable.$convertermutationKind.toJson(mutationKind),
      ),
      'mutationPreviousTransactionId': serializer.toJson<String?>(
        mutationPreviousTransactionId,
      ),
      'mutationReason': serializer.toJson<String?>(
        $TransactionsTable.$convertermutationReasonn.toJson(mutationReason),
      ),
      'businessState': serializer.toJson<String>(
        $TransactionsTable.$converterbusinessState.toJson(businessState),
      ),
      'isExcludedFromStats': serializer.toJson<bool>(isExcludedFromStats),
      'isExcludedFromBudget': serializer.toJson<bool>(isExcludedFromBudget),
      'sourceKind': serializer.toJson<String>(
        $TransactionsTable.$convertersourceKind.toJson(sourceKind),
      ),
      'ownerType': serializer.toJson<String?>(ownerType),
      'ownerId': serializer.toJson<String?>(ownerId),
      'ownerRole': serializer.toJson<String?>(ownerRole),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TransactionRow copyWith({
    String? id,
    Value<String?> rootTransactionId = const Value.absent(),
    BusinessPurpose? businessPurpose,
    DateTime? occurredAt,
    int? primaryAmountMinor,
    Value<String?> counterpartyName = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> parentTransactionId = const Value.absent(),
    Value<String?> reimbursementExpenseAccountId = const Value.absent(),
    MutationKind? mutationKind,
    Value<String?> mutationPreviousTransactionId = const Value.absent(),
    Value<MutationReason?> mutationReason = const Value.absent(),
    BusinessState? businessState,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
    SourceKind? sourceKind,
    Value<String?> ownerType = const Value.absent(),
    Value<String?> ownerId = const Value.absent(),
    Value<String?> ownerRole = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TransactionRow(
    id: id ?? this.id,
    rootTransactionId:
        rootTransactionId.present
            ? rootTransactionId.value
            : this.rootTransactionId,
    businessPurpose: businessPurpose ?? this.businessPurpose,
    occurredAt: occurredAt ?? this.occurredAt,
    primaryAmountMinor: primaryAmountMinor ?? this.primaryAmountMinor,
    counterpartyName:
        counterpartyName.present
            ? counterpartyName.value
            : this.counterpartyName,
    note: note.present ? note.value : this.note,
    parentTransactionId:
        parentTransactionId.present
            ? parentTransactionId.value
            : this.parentTransactionId,
    reimbursementExpenseAccountId:
        reimbursementExpenseAccountId.present
            ? reimbursementExpenseAccountId.value
            : this.reimbursementExpenseAccountId,
    mutationKind: mutationKind ?? this.mutationKind,
    mutationPreviousTransactionId:
        mutationPreviousTransactionId.present
            ? mutationPreviousTransactionId.value
            : this.mutationPreviousTransactionId,
    mutationReason:
        mutationReason.present ? mutationReason.value : this.mutationReason,
    businessState: businessState ?? this.businessState,
    isExcludedFromStats: isExcludedFromStats ?? this.isExcludedFromStats,
    isExcludedFromBudget: isExcludedFromBudget ?? this.isExcludedFromBudget,
    sourceKind: sourceKind ?? this.sourceKind,
    ownerType: ownerType.present ? ownerType.value : this.ownerType,
    ownerId: ownerId.present ? ownerId.value : this.ownerId,
    ownerRole: ownerRole.present ? ownerRole.value : this.ownerRole,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TransactionRow copyWithCompanion(TransactionsCompanion data) {
    return TransactionRow(
      id: data.id.present ? data.id.value : this.id,
      rootTransactionId:
          data.rootTransactionId.present
              ? data.rootTransactionId.value
              : this.rootTransactionId,
      businessPurpose:
          data.businessPurpose.present
              ? data.businessPurpose.value
              : this.businessPurpose,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      primaryAmountMinor:
          data.primaryAmountMinor.present
              ? data.primaryAmountMinor.value
              : this.primaryAmountMinor,
      counterpartyName:
          data.counterpartyName.present
              ? data.counterpartyName.value
              : this.counterpartyName,
      note: data.note.present ? data.note.value : this.note,
      parentTransactionId:
          data.parentTransactionId.present
              ? data.parentTransactionId.value
              : this.parentTransactionId,
      reimbursementExpenseAccountId:
          data.reimbursementExpenseAccountId.present
              ? data.reimbursementExpenseAccountId.value
              : this.reimbursementExpenseAccountId,
      mutationKind:
          data.mutationKind.present
              ? data.mutationKind.value
              : this.mutationKind,
      mutationPreviousTransactionId:
          data.mutationPreviousTransactionId.present
              ? data.mutationPreviousTransactionId.value
              : this.mutationPreviousTransactionId,
      mutationReason:
          data.mutationReason.present
              ? data.mutationReason.value
              : this.mutationReason,
      businessState:
          data.businessState.present
              ? data.businessState.value
              : this.businessState,
      isExcludedFromStats:
          data.isExcludedFromStats.present
              ? data.isExcludedFromStats.value
              : this.isExcludedFromStats,
      isExcludedFromBudget:
          data.isExcludedFromBudget.present
              ? data.isExcludedFromBudget.value
              : this.isExcludedFromBudget,
      sourceKind:
          data.sourceKind.present ? data.sourceKind.value : this.sourceKind,
      ownerType: data.ownerType.present ? data.ownerType.value : this.ownerType,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      ownerRole: data.ownerRole.present ? data.ownerRole.value : this.ownerRole,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionRow(')
          ..write('id: $id, ')
          ..write('rootTransactionId: $rootTransactionId, ')
          ..write('businessPurpose: $businessPurpose, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('primaryAmountMinor: $primaryAmountMinor, ')
          ..write('counterpartyName: $counterpartyName, ')
          ..write('note: $note, ')
          ..write('parentTransactionId: $parentTransactionId, ')
          ..write(
            'reimbursementExpenseAccountId: $reimbursementExpenseAccountId, ',
          )
          ..write('mutationKind: $mutationKind, ')
          ..write(
            'mutationPreviousTransactionId: $mutationPreviousTransactionId, ',
          )
          ..write('mutationReason: $mutationReason, ')
          ..write('businessState: $businessState, ')
          ..write('isExcludedFromStats: $isExcludedFromStats, ')
          ..write('isExcludedFromBudget: $isExcludedFromBudget, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('ownerType: $ownerType, ')
          ..write('ownerId: $ownerId, ')
          ..write('ownerRole: $ownerRole, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    rootTransactionId,
    businessPurpose,
    occurredAt,
    primaryAmountMinor,
    counterpartyName,
    note,
    parentTransactionId,
    reimbursementExpenseAccountId,
    mutationKind,
    mutationPreviousTransactionId,
    mutationReason,
    businessState,
    isExcludedFromStats,
    isExcludedFromBudget,
    sourceKind,
    ownerType,
    ownerId,
    ownerRole,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionRow &&
          other.id == this.id &&
          other.rootTransactionId == this.rootTransactionId &&
          other.businessPurpose == this.businessPurpose &&
          other.occurredAt == this.occurredAt &&
          other.primaryAmountMinor == this.primaryAmountMinor &&
          other.counterpartyName == this.counterpartyName &&
          other.note == this.note &&
          other.parentTransactionId == this.parentTransactionId &&
          other.reimbursementExpenseAccountId ==
              this.reimbursementExpenseAccountId &&
          other.mutationKind == this.mutationKind &&
          other.mutationPreviousTransactionId ==
              this.mutationPreviousTransactionId &&
          other.mutationReason == this.mutationReason &&
          other.businessState == this.businessState &&
          other.isExcludedFromStats == this.isExcludedFromStats &&
          other.isExcludedFromBudget == this.isExcludedFromBudget &&
          other.sourceKind == this.sourceKind &&
          other.ownerType == this.ownerType &&
          other.ownerId == this.ownerId &&
          other.ownerRole == this.ownerRole &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TransactionsCompanion extends UpdateCompanion<TransactionRow> {
  final Value<String> id;
  final Value<String?> rootTransactionId;
  final Value<BusinessPurpose> businessPurpose;
  final Value<DateTime> occurredAt;
  final Value<int> primaryAmountMinor;
  final Value<String?> counterpartyName;
  final Value<String?> note;
  final Value<String?> parentTransactionId;
  final Value<String?> reimbursementExpenseAccountId;
  final Value<MutationKind> mutationKind;
  final Value<String?> mutationPreviousTransactionId;
  final Value<MutationReason?> mutationReason;
  final Value<BusinessState> businessState;
  final Value<bool> isExcludedFromStats;
  final Value<bool> isExcludedFromBudget;
  final Value<SourceKind> sourceKind;
  final Value<String?> ownerType;
  final Value<String?> ownerId;
  final Value<String?> ownerRole;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.rootTransactionId = const Value.absent(),
    this.businessPurpose = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.primaryAmountMinor = const Value.absent(),
    this.counterpartyName = const Value.absent(),
    this.note = const Value.absent(),
    this.parentTransactionId = const Value.absent(),
    this.reimbursementExpenseAccountId = const Value.absent(),
    this.mutationKind = const Value.absent(),
    this.mutationPreviousTransactionId = const Value.absent(),
    this.mutationReason = const Value.absent(),
    this.businessState = const Value.absent(),
    this.isExcludedFromStats = const Value.absent(),
    this.isExcludedFromBudget = const Value.absent(),
    this.sourceKind = const Value.absent(),
    this.ownerType = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.ownerRole = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    this.rootTransactionId = const Value.absent(),
    required BusinessPurpose businessPurpose,
    required DateTime occurredAt,
    required int primaryAmountMinor,
    this.counterpartyName = const Value.absent(),
    this.note = const Value.absent(),
    this.parentTransactionId = const Value.absent(),
    this.reimbursementExpenseAccountId = const Value.absent(),
    required MutationKind mutationKind,
    this.mutationPreviousTransactionId = const Value.absent(),
    this.mutationReason = const Value.absent(),
    required BusinessState businessState,
    this.isExcludedFromStats = const Value.absent(),
    this.isExcludedFromBudget = const Value.absent(),
    required SourceKind sourceKind,
    this.ownerType = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.ownerRole = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       businessPurpose = Value(businessPurpose),
       occurredAt = Value(occurredAt),
       primaryAmountMinor = Value(primaryAmountMinor),
       mutationKind = Value(mutationKind),
       businessState = Value(businessState),
       sourceKind = Value(sourceKind);
  static Insertable<TransactionRow> custom({
    Expression<String>? id,
    Expression<String>? rootTransactionId,
    Expression<String>? businessPurpose,
    Expression<DateTime>? occurredAt,
    Expression<int>? primaryAmountMinor,
    Expression<String>? counterpartyName,
    Expression<String>? note,
    Expression<String>? parentTransactionId,
    Expression<String>? reimbursementExpenseAccountId,
    Expression<String>? mutationKind,
    Expression<String>? mutationPreviousTransactionId,
    Expression<String>? mutationReason,
    Expression<String>? businessState,
    Expression<bool>? isExcludedFromStats,
    Expression<bool>? isExcludedFromBudget,
    Expression<String>? sourceKind,
    Expression<String>? ownerType,
    Expression<String>? ownerId,
    Expression<String>? ownerRole,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rootTransactionId != null) 'root_transaction_id': rootTransactionId,
      if (businessPurpose != null) 'business_purpose': businessPurpose,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (primaryAmountMinor != null)
        'primary_amount_minor': primaryAmountMinor,
      if (counterpartyName != null) 'counterparty_name': counterpartyName,
      if (note != null) 'note': note,
      if (parentTransactionId != null)
        'parent_transaction_id': parentTransactionId,
      if (reimbursementExpenseAccountId != null)
        'reimbursement_expense_account_id': reimbursementExpenseAccountId,
      if (mutationKind != null) 'mutation_kind': mutationKind,
      if (mutationPreviousTransactionId != null)
        'mutation_previous_transaction_id': mutationPreviousTransactionId,
      if (mutationReason != null) 'mutation_reason': mutationReason,
      if (businessState != null) 'business_state': businessState,
      if (isExcludedFromStats != null)
        'is_excluded_from_stats': isExcludedFromStats,
      if (isExcludedFromBudget != null)
        'is_excluded_from_budget': isExcludedFromBudget,
      if (sourceKind != null) 'source_kind': sourceKind,
      if (ownerType != null) 'owner_type': ownerType,
      if (ownerId != null) 'owner_id': ownerId,
      if (ownerRole != null) 'owner_role': ownerRole,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? rootTransactionId,
    Value<BusinessPurpose>? businessPurpose,
    Value<DateTime>? occurredAt,
    Value<int>? primaryAmountMinor,
    Value<String?>? counterpartyName,
    Value<String?>? note,
    Value<String?>? parentTransactionId,
    Value<String?>? reimbursementExpenseAccountId,
    Value<MutationKind>? mutationKind,
    Value<String?>? mutationPreviousTransactionId,
    Value<MutationReason?>? mutationReason,
    Value<BusinessState>? businessState,
    Value<bool>? isExcludedFromStats,
    Value<bool>? isExcludedFromBudget,
    Value<SourceKind>? sourceKind,
    Value<String?>? ownerType,
    Value<String?>? ownerId,
    Value<String?>? ownerRole,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      rootTransactionId: rootTransactionId ?? this.rootTransactionId,
      businessPurpose: businessPurpose ?? this.businessPurpose,
      occurredAt: occurredAt ?? this.occurredAt,
      primaryAmountMinor: primaryAmountMinor ?? this.primaryAmountMinor,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      note: note ?? this.note,
      parentTransactionId: parentTransactionId ?? this.parentTransactionId,
      reimbursementExpenseAccountId:
          reimbursementExpenseAccountId ?? this.reimbursementExpenseAccountId,
      mutationKind: mutationKind ?? this.mutationKind,
      mutationPreviousTransactionId:
          mutationPreviousTransactionId ?? this.mutationPreviousTransactionId,
      mutationReason: mutationReason ?? this.mutationReason,
      businessState: businessState ?? this.businessState,
      isExcludedFromStats: isExcludedFromStats ?? this.isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget ?? this.isExcludedFromBudget,
      sourceKind: sourceKind ?? this.sourceKind,
      ownerType: ownerType ?? this.ownerType,
      ownerId: ownerId ?? this.ownerId,
      ownerRole: ownerRole ?? this.ownerRole,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (rootTransactionId.present) {
      map['root_transaction_id'] = Variable<String>(rootTransactionId.value);
    }
    if (businessPurpose.present) {
      map['business_purpose'] = Variable<String>(
        $TransactionsTable.$converterbusinessPurpose.toSql(
          businessPurpose.value,
        ),
      );
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (primaryAmountMinor.present) {
      map['primary_amount_minor'] = Variable<int>(primaryAmountMinor.value);
    }
    if (counterpartyName.present) {
      map['counterparty_name'] = Variable<String>(counterpartyName.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (parentTransactionId.present) {
      map['parent_transaction_id'] = Variable<String>(
        parentTransactionId.value,
      );
    }
    if (reimbursementExpenseAccountId.present) {
      map['reimbursement_expense_account_id'] = Variable<String>(
        reimbursementExpenseAccountId.value,
      );
    }
    if (mutationKind.present) {
      map['mutation_kind'] = Variable<String>(
        $TransactionsTable.$convertermutationKind.toSql(mutationKind.value),
      );
    }
    if (mutationPreviousTransactionId.present) {
      map['mutation_previous_transaction_id'] = Variable<String>(
        mutationPreviousTransactionId.value,
      );
    }
    if (mutationReason.present) {
      map['mutation_reason'] = Variable<String>(
        $TransactionsTable.$convertermutationReasonn.toSql(
          mutationReason.value,
        ),
      );
    }
    if (businessState.present) {
      map['business_state'] = Variable<String>(
        $TransactionsTable.$converterbusinessState.toSql(businessState.value),
      );
    }
    if (isExcludedFromStats.present) {
      map['is_excluded_from_stats'] = Variable<bool>(isExcludedFromStats.value);
    }
    if (isExcludedFromBudget.present) {
      map['is_excluded_from_budget'] = Variable<bool>(
        isExcludedFromBudget.value,
      );
    }
    if (sourceKind.present) {
      map['source_kind'] = Variable<String>(
        $TransactionsTable.$convertersourceKind.toSql(sourceKind.value),
      );
    }
    if (ownerType.present) {
      map['owner_type'] = Variable<String>(ownerType.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (ownerRole.present) {
      map['owner_role'] = Variable<String>(ownerRole.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('rootTransactionId: $rootTransactionId, ')
          ..write('businessPurpose: $businessPurpose, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('primaryAmountMinor: $primaryAmountMinor, ')
          ..write('counterpartyName: $counterpartyName, ')
          ..write('note: $note, ')
          ..write('parentTransactionId: $parentTransactionId, ')
          ..write(
            'reimbursementExpenseAccountId: $reimbursementExpenseAccountId, ',
          )
          ..write('mutationKind: $mutationKind, ')
          ..write(
            'mutationPreviousTransactionId: $mutationPreviousTransactionId, ',
          )
          ..write('mutationReason: $mutationReason, ')
          ..write('businessState: $businessState, ')
          ..write('isExcludedFromStats: $isExcludedFromStats, ')
          ..write('isExcludedFromBudget: $isExcludedFromBudget, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('ownerType: $ownerType, ')
          ..write('ownerId: $ownerId, ')
          ..write('ownerRole: $ownerRole, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionDetailsTable extends TransactionDetails
    with TableInfo<$TransactionDetailsTable, TransactionDetailRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionDetailsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineNoMeta = const VerificationMeta('lineNo');
  @override
  late final GeneratedColumn<int> lineNo = GeneratedColumn<int>(
    'line_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TransactionDetailType, String>
  detailType = GeneratedColumn<String>(
    'detail_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<TransactionDetailType>(
    $TransactionDetailsTable.$converterdetailType,
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    transactionId,
    lineNo,
    detailType,
    amountMinor,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_details';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionDetailRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('line_no')) {
      context.handle(
        _lineNoMeta,
        lineNo.isAcceptableOrUnknown(data['line_no']!, _lineNoMeta),
      );
    } else if (isInserting) {
      context.missing(_lineNoMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionDetailRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionDetailRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      transactionId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}transaction_id'],
          )!,
      lineNo:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}line_no'],
          )!,
      detailType: $TransactionDetailsTable.$converterdetailType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}detail_type'],
        )!,
      ),
      amountMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}amount_minor'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $TransactionDetailsTable createAlias(String alias) {
    return $TransactionDetailsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TransactionDetailType, String, String>
  $converterdetailType = const EnumNameConverter<TransactionDetailType>(
    TransactionDetailType.values,
  );
}

class TransactionDetailRow extends DataClass
    implements Insertable<TransactionDetailRow> {
  final String id;
  final String transactionId;
  final int lineNo;
  final TransactionDetailType detailType;
  final int amountMinor;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TransactionDetailRow({
    required this.id,
    required this.transactionId,
    required this.lineNo,
    required this.detailType,
    required this.amountMinor,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['transaction_id'] = Variable<String>(transactionId);
    map['line_no'] = Variable<int>(lineNo);
    {
      map['detail_type'] = Variable<String>(
        $TransactionDetailsTable.$converterdetailType.toSql(detailType),
      );
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TransactionDetailsCompanion toCompanion(bool nullToAbsent) {
    return TransactionDetailsCompanion(
      id: Value(id),
      transactionId: Value(transactionId),
      lineNo: Value(lineNo),
      detailType: Value(detailType),
      amountMinor: Value(amountMinor),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TransactionDetailRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionDetailRow(
      id: serializer.fromJson<String>(json['id']),
      transactionId: serializer.fromJson<String>(json['transactionId']),
      lineNo: serializer.fromJson<int>(json['lineNo']),
      detailType: $TransactionDetailsTable.$converterdetailType.fromJson(
        serializer.fromJson<String>(json['detailType']),
      ),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'transactionId': serializer.toJson<String>(transactionId),
      'lineNo': serializer.toJson<int>(lineNo),
      'detailType': serializer.toJson<String>(
        $TransactionDetailsTable.$converterdetailType.toJson(detailType),
      ),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TransactionDetailRow copyWith({
    String? id,
    String? transactionId,
    int? lineNo,
    TransactionDetailType? detailType,
    int? amountMinor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TransactionDetailRow(
    id: id ?? this.id,
    transactionId: transactionId ?? this.transactionId,
    lineNo: lineNo ?? this.lineNo,
    detailType: detailType ?? this.detailType,
    amountMinor: amountMinor ?? this.amountMinor,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TransactionDetailRow copyWithCompanion(TransactionDetailsCompanion data) {
    return TransactionDetailRow(
      id: data.id.present ? data.id.value : this.id,
      transactionId:
          data.transactionId.present
              ? data.transactionId.value
              : this.transactionId,
      lineNo: data.lineNo.present ? data.lineNo.value : this.lineNo,
      detailType:
          data.detailType.present ? data.detailType.value : this.detailType,
      amountMinor:
          data.amountMinor.present ? data.amountMinor.value : this.amountMinor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionDetailRow(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('lineNo: $lineNo, ')
          ..write('detailType: $detailType, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    transactionId,
    lineNo,
    detailType,
    amountMinor,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionDetailRow &&
          other.id == this.id &&
          other.transactionId == this.transactionId &&
          other.lineNo == this.lineNo &&
          other.detailType == this.detailType &&
          other.amountMinor == this.amountMinor &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TransactionDetailsCompanion
    extends UpdateCompanion<TransactionDetailRow> {
  final Value<String> id;
  final Value<String> transactionId;
  final Value<int> lineNo;
  final Value<TransactionDetailType> detailType;
  final Value<int> amountMinor;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TransactionDetailsCompanion({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.lineNo = const Value.absent(),
    this.detailType = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionDetailsCompanion.insert({
    required String id,
    required String transactionId,
    required int lineNo,
    required TransactionDetailType detailType,
    required int amountMinor,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       transactionId = Value(transactionId),
       lineNo = Value(lineNo),
       detailType = Value(detailType),
       amountMinor = Value(amountMinor);
  static Insertable<TransactionDetailRow> custom({
    Expression<String>? id,
    Expression<String>? transactionId,
    Expression<int>? lineNo,
    Expression<String>? detailType,
    Expression<int>? amountMinor,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      if (lineNo != null) 'line_no': lineNo,
      if (detailType != null) 'detail_type': detailType,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionDetailsCompanion copyWith({
    Value<String>? id,
    Value<String>? transactionId,
    Value<int>? lineNo,
    Value<TransactionDetailType>? detailType,
    Value<int>? amountMinor,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TransactionDetailsCompanion(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      lineNo: lineNo ?? this.lineNo,
      detailType: detailType ?? this.detailType,
      amountMinor: amountMinor ?? this.amountMinor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (lineNo.present) {
      map['line_no'] = Variable<int>(lineNo.value);
    }
    if (detailType.present) {
      map['detail_type'] = Variable<String>(
        $TransactionDetailsTable.$converterdetailType.toSql(detailType.value),
      );
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionDetailsCompanion(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('lineNo: $lineNo, ')
          ..write('detailType: $detailType, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntriesTable extends Entries with TableInfo<$EntriesTable, EntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<EntryDirection, String>
  direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<EntryDirection>($EntriesTable.$converterdirection);
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    transactionId,
    accountId,
    direction,
    amountMinor,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      transactionId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}transaction_id'],
          )!,
      accountId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}account_id'],
          )!,
      direction: $EntriesTable.$converterdirection.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}direction'],
        )!,
      ),
      amountMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}amount_minor'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EntryDirection, String, String>
  $converterdirection = const EnumNameConverter<EntryDirection>(
    EntryDirection.values,
  );
}

class EntryRow extends DataClass implements Insertable<EntryRow> {
  final String id;
  final String transactionId;
  final String accountId;
  final EntryDirection direction;
  final int amountMinor;
  final DateTime createdAt;
  final DateTime updatedAt;
  const EntryRow({
    required this.id,
    required this.transactionId,
    required this.accountId,
    required this.direction,
    required this.amountMinor,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['transaction_id'] = Variable<String>(transactionId);
    map['account_id'] = Variable<String>(accountId);
    {
      map['direction'] = Variable<String>(
        $EntriesTable.$converterdirection.toSql(direction),
      );
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      transactionId: Value(transactionId),
      accountId: Value(accountId),
      direction: Value(direction),
      amountMinor: Value(amountMinor),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory EntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryRow(
      id: serializer.fromJson<String>(json['id']),
      transactionId: serializer.fromJson<String>(json['transactionId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      direction: $EntriesTable.$converterdirection.fromJson(
        serializer.fromJson<String>(json['direction']),
      ),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'transactionId': serializer.toJson<String>(transactionId),
      'accountId': serializer.toJson<String>(accountId),
      'direction': serializer.toJson<String>(
        $EntriesTable.$converterdirection.toJson(direction),
      ),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EntryRow copyWith({
    String? id,
    String? transactionId,
    String? accountId,
    EntryDirection? direction,
    int? amountMinor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => EntryRow(
    id: id ?? this.id,
    transactionId: transactionId ?? this.transactionId,
    accountId: accountId ?? this.accountId,
    direction: direction ?? this.direction,
    amountMinor: amountMinor ?? this.amountMinor,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EntryRow copyWithCompanion(EntriesCompanion data) {
    return EntryRow(
      id: data.id.present ? data.id.value : this.id,
      transactionId:
          data.transactionId.present
              ? data.transactionId.value
              : this.transactionId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      direction: data.direction.present ? data.direction.value : this.direction,
      amountMinor:
          data.amountMinor.present ? data.amountMinor.value : this.amountMinor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryRow(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('accountId: $accountId, ')
          ..write('direction: $direction, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    transactionId,
    accountId,
    direction,
    amountMinor,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryRow &&
          other.id == this.id &&
          other.transactionId == this.transactionId &&
          other.accountId == this.accountId &&
          other.direction == this.direction &&
          other.amountMinor == this.amountMinor &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class EntriesCompanion extends UpdateCompanion<EntryRow> {
  final Value<String> id;
  final Value<String> transactionId;
  final Value<String> accountId;
  final Value<EntryDirection> direction;
  final Value<int> amountMinor;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.direction = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntriesCompanion.insert({
    required String id,
    required String transactionId,
    required String accountId,
    required EntryDirection direction,
    required int amountMinor,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       transactionId = Value(transactionId),
       accountId = Value(accountId),
       direction = Value(direction),
       amountMinor = Value(amountMinor);
  static Insertable<EntryRow> custom({
    Expression<String>? id,
    Expression<String>? transactionId,
    Expression<String>? accountId,
    Expression<String>? direction,
    Expression<int>? amountMinor,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      if (accountId != null) 'account_id': accountId,
      if (direction != null) 'direction': direction,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? transactionId,
    Value<String>? accountId,
    Value<EntryDirection>? direction,
    Value<int>? amountMinor,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      accountId: accountId ?? this.accountId,
      direction: direction ?? this.direction,
      amountMinor: amountMinor ?? this.amountMinor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(
        $EntriesTable.$converterdirection.toSql(direction.value),
      );
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('accountId: $accountId, ')
          ..write('direction: $direction, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, BudgetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthKeyMeta = const VerificationMeta(
    'monthKey',
  );
  @override
  late final GeneratedColumn<int> monthKey = GeneratedColumn<int>(
    'month_key',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    monthKey,
    accountId,
    amountMinor,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<BudgetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('month_key')) {
      context.handle(
        _monthKeyMeta,
        monthKey.isAcceptableOrUnknown(data['month_key']!, _monthKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_monthKeyMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BudgetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      monthKey:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}month_key'],
          )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      amountMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}amount_minor'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class BudgetRow extends DataClass implements Insertable<BudgetRow> {
  final String id;
  final int monthKey;
  final String? accountId;
  final int amountMinor;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BudgetRow({
    required this.id,
    required this.monthKey,
    this.accountId,
    required this.amountMinor,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['month_key'] = Variable<int>(monthKey);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      monthKey: Value(monthKey),
      accountId:
          accountId == null && nullToAbsent
              ? const Value.absent()
              : Value(accountId),
      amountMinor: Value(amountMinor),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BudgetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetRow(
      id: serializer.fromJson<String>(json['id']),
      monthKey: serializer.fromJson<int>(json['monthKey']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'monthKey': serializer.toJson<int>(monthKey),
      'accountId': serializer.toJson<String?>(accountId),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BudgetRow copyWith({
    String? id,
    int? monthKey,
    Value<String?> accountId = const Value.absent(),
    int? amountMinor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BudgetRow(
    id: id ?? this.id,
    monthKey: monthKey ?? this.monthKey,
    accountId: accountId.present ? accountId.value : this.accountId,
    amountMinor: amountMinor ?? this.amountMinor,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BudgetRow copyWithCompanion(BudgetsCompanion data) {
    return BudgetRow(
      id: data.id.present ? data.id.value : this.id,
      monthKey: data.monthKey.present ? data.monthKey.value : this.monthKey,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      amountMinor:
          data.amountMinor.present ? data.amountMinor.value : this.amountMinor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetRow(')
          ..write('id: $id, ')
          ..write('monthKey: $monthKey, ')
          ..write('accountId: $accountId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, monthKey, accountId, amountMinor, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetRow &&
          other.id == this.id &&
          other.monthKey == this.monthKey &&
          other.accountId == this.accountId &&
          other.amountMinor == this.amountMinor &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BudgetsCompanion extends UpdateCompanion<BudgetRow> {
  final Value<String> id;
  final Value<int> monthKey;
  final Value<String?> accountId;
  final Value<int> amountMinor;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.monthKey = const Value.absent(),
    this.accountId = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetsCompanion.insert({
    required String id,
    required int monthKey,
    this.accountId = const Value.absent(),
    required int amountMinor,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       monthKey = Value(monthKey),
       amountMinor = Value(amountMinor);
  static Insertable<BudgetRow> custom({
    Expression<String>? id,
    Expression<int>? monthKey,
    Expression<String>? accountId,
    Expression<int>? amountMinor,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (monthKey != null) 'month_key': monthKey,
      if (accountId != null) 'account_id': accountId,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetsCompanion copyWith({
    Value<String>? id,
    Value<int>? monthKey,
    Value<String?>? accountId,
    Value<int>? amountMinor,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BudgetsCompanion(
      id: id ?? this.id,
      monthKey: monthKey ?? this.monthKey,
      accountId: accountId ?? this.accountId,
      amountMinor: amountMinor ?? this.amountMinor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (monthKey.present) {
      map['month_key'] = Variable<int>(monthKey.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('monthKey: $monthKey, ')
          ..write('accountId: $accountId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CreditLiabilityAccountsTable extends CreditLiabilityAccounts
    with TableInfo<$CreditLiabilityAccountsTable, CreditLiabilityAccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CreditLiabilityAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<
    CreditLiabilityAccountKind,
    String
  >
  kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<CreditLiabilityAccountKind>(
    $CreditLiabilityAccountsTable.$converterkind,
  );
  static const VerificationMeta _creditLimitMinorMeta = const VerificationMeta(
    'creditLimitMinor',
  );
  @override
  late final GeneratedColumn<int> creditLimitMinor = GeneratedColumn<int>(
    'credit_limit_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _billingDayMeta = const VerificationMeta(
    'billingDay',
  );
  @override
  late final GeneratedColumn<int> billingDay = GeneratedColumn<int>(
    'billing_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repaymentDayMeta = const VerificationMeta(
    'repaymentDay',
  );
  @override
  late final GeneratedColumn<int> repaymentDay = GeneratedColumn<int>(
    'repayment_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _billingStartPeriodMeta =
      const VerificationMeta('billingStartPeriod');
  @override
  late final GeneratedColumn<int> billingStartPeriod = GeneratedColumn<int>(
    'billing_start_period',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _billingDayToNextMeta = const VerificationMeta(
    'billingDayToNext',
  );
  @override
  late final GeneratedColumn<bool> billingDayToNext = GeneratedColumn<bool>(
    'billing_day_to_next',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("billing_day_to_next" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    kind,
    creditLimitMinor,
    billingDay,
    repaymentDay,
    billingStartPeriod,
    billingDayToNext,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'credit_liability_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<CreditLiabilityAccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('credit_limit_minor')) {
      context.handle(
        _creditLimitMinorMeta,
        creditLimitMinor.isAcceptableOrUnknown(
          data['credit_limit_minor']!,
          _creditLimitMinorMeta,
        ),
      );
    }
    if (data.containsKey('billing_day')) {
      context.handle(
        _billingDayMeta,
        billingDay.isAcceptableOrUnknown(data['billing_day']!, _billingDayMeta),
      );
    }
    if (data.containsKey('repayment_day')) {
      context.handle(
        _repaymentDayMeta,
        repaymentDay.isAcceptableOrUnknown(
          data['repayment_day']!,
          _repaymentDayMeta,
        ),
      );
    }
    if (data.containsKey('billing_start_period')) {
      context.handle(
        _billingStartPeriodMeta,
        billingStartPeriod.isAcceptableOrUnknown(
          data['billing_start_period']!,
          _billingStartPeriodMeta,
        ),
      );
    }
    if (data.containsKey('billing_day_to_next')) {
      context.handle(
        _billingDayToNextMeta,
        billingDayToNext.isAcceptableOrUnknown(
          data['billing_day_to_next']!,
          _billingDayToNextMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CreditLiabilityAccountRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CreditLiabilityAccountRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      accountId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}account_id'],
          )!,
      kind: $CreditLiabilityAccountsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      creditLimitMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credit_limit_minor'],
      ),
      billingDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}billing_day'],
      ),
      repaymentDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repayment_day'],
      ),
      billingStartPeriod: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}billing_start_period'],
      ),
      billingDayToNext:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}billing_day_to_next'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $CreditLiabilityAccountsTable createAlias(String alias) {
    return $CreditLiabilityAccountsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CreditLiabilityAccountKind, String, String>
  $converterkind = const EnumNameConverter<CreditLiabilityAccountKind>(
    CreditLiabilityAccountKind.values,
  );
}

class CreditLiabilityAccountRow extends DataClass
    implements Insertable<CreditLiabilityAccountRow> {
  final String id;
  final String accountId;
  final CreditLiabilityAccountKind kind;
  final int? creditLimitMinor;
  final int? billingDay;
  final int? repaymentDay;
  final int? billingStartPeriod;
  final bool billingDayToNext;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CreditLiabilityAccountRow({
    required this.id,
    required this.accountId,
    required this.kind,
    this.creditLimitMinor,
    this.billingDay,
    this.repaymentDay,
    this.billingStartPeriod,
    required this.billingDayToNext,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    {
      map['kind'] = Variable<String>(
        $CreditLiabilityAccountsTable.$converterkind.toSql(kind),
      );
    }
    if (!nullToAbsent || creditLimitMinor != null) {
      map['credit_limit_minor'] = Variable<int>(creditLimitMinor);
    }
    if (!nullToAbsent || billingDay != null) {
      map['billing_day'] = Variable<int>(billingDay);
    }
    if (!nullToAbsent || repaymentDay != null) {
      map['repayment_day'] = Variable<int>(repaymentDay);
    }
    if (!nullToAbsent || billingStartPeriod != null) {
      map['billing_start_period'] = Variable<int>(billingStartPeriod);
    }
    map['billing_day_to_next'] = Variable<bool>(billingDayToNext);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CreditLiabilityAccountsCompanion toCompanion(bool nullToAbsent) {
    return CreditLiabilityAccountsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      kind: Value(kind),
      creditLimitMinor:
          creditLimitMinor == null && nullToAbsent
              ? const Value.absent()
              : Value(creditLimitMinor),
      billingDay:
          billingDay == null && nullToAbsent
              ? const Value.absent()
              : Value(billingDay),
      repaymentDay:
          repaymentDay == null && nullToAbsent
              ? const Value.absent()
              : Value(repaymentDay),
      billingStartPeriod:
          billingStartPeriod == null && nullToAbsent
              ? const Value.absent()
              : Value(billingStartPeriod),
      billingDayToNext: Value(billingDayToNext),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CreditLiabilityAccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CreditLiabilityAccountRow(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      kind: $CreditLiabilityAccountsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      creditLimitMinor: serializer.fromJson<int?>(json['creditLimitMinor']),
      billingDay: serializer.fromJson<int?>(json['billingDay']),
      repaymentDay: serializer.fromJson<int?>(json['repaymentDay']),
      billingStartPeriod: serializer.fromJson<int?>(json['billingStartPeriod']),
      billingDayToNext: serializer.fromJson<bool>(json['billingDayToNext']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'kind': serializer.toJson<String>(
        $CreditLiabilityAccountsTable.$converterkind.toJson(kind),
      ),
      'creditLimitMinor': serializer.toJson<int?>(creditLimitMinor),
      'billingDay': serializer.toJson<int?>(billingDay),
      'repaymentDay': serializer.toJson<int?>(repaymentDay),
      'billingStartPeriod': serializer.toJson<int?>(billingStartPeriod),
      'billingDayToNext': serializer.toJson<bool>(billingDayToNext),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CreditLiabilityAccountRow copyWith({
    String? id,
    String? accountId,
    CreditLiabilityAccountKind? kind,
    Value<int?> creditLimitMinor = const Value.absent(),
    Value<int?> billingDay = const Value.absent(),
    Value<int?> repaymentDay = const Value.absent(),
    Value<int?> billingStartPeriod = const Value.absent(),
    bool? billingDayToNext,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CreditLiabilityAccountRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    kind: kind ?? this.kind,
    creditLimitMinor:
        creditLimitMinor.present
            ? creditLimitMinor.value
            : this.creditLimitMinor,
    billingDay: billingDay.present ? billingDay.value : this.billingDay,
    repaymentDay: repaymentDay.present ? repaymentDay.value : this.repaymentDay,
    billingStartPeriod:
        billingStartPeriod.present
            ? billingStartPeriod.value
            : this.billingStartPeriod,
    billingDayToNext: billingDayToNext ?? this.billingDayToNext,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CreditLiabilityAccountRow copyWithCompanion(
    CreditLiabilityAccountsCompanion data,
  ) {
    return CreditLiabilityAccountRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      kind: data.kind.present ? data.kind.value : this.kind,
      creditLimitMinor:
          data.creditLimitMinor.present
              ? data.creditLimitMinor.value
              : this.creditLimitMinor,
      billingDay:
          data.billingDay.present ? data.billingDay.value : this.billingDay,
      repaymentDay:
          data.repaymentDay.present
              ? data.repaymentDay.value
              : this.repaymentDay,
      billingStartPeriod:
          data.billingStartPeriod.present
              ? data.billingStartPeriod.value
              : this.billingStartPeriod,
      billingDayToNext:
          data.billingDayToNext.present
              ? data.billingDayToNext.value
              : this.billingDayToNext,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CreditLiabilityAccountRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('kind: $kind, ')
          ..write('creditLimitMinor: $creditLimitMinor, ')
          ..write('billingDay: $billingDay, ')
          ..write('repaymentDay: $repaymentDay, ')
          ..write('billingStartPeriod: $billingStartPeriod, ')
          ..write('billingDayToNext: $billingDayToNext, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    kind,
    creditLimitMinor,
    billingDay,
    repaymentDay,
    billingStartPeriod,
    billingDayToNext,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CreditLiabilityAccountRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.kind == this.kind &&
          other.creditLimitMinor == this.creditLimitMinor &&
          other.billingDay == this.billingDay &&
          other.repaymentDay == this.repaymentDay &&
          other.billingStartPeriod == this.billingStartPeriod &&
          other.billingDayToNext == this.billingDayToNext &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CreditLiabilityAccountsCompanion
    extends UpdateCompanion<CreditLiabilityAccountRow> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<CreditLiabilityAccountKind> kind;
  final Value<int?> creditLimitMinor;
  final Value<int?> billingDay;
  final Value<int?> repaymentDay;
  final Value<int?> billingStartPeriod;
  final Value<bool> billingDayToNext;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CreditLiabilityAccountsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.kind = const Value.absent(),
    this.creditLimitMinor = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.repaymentDay = const Value.absent(),
    this.billingStartPeriod = const Value.absent(),
    this.billingDayToNext = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CreditLiabilityAccountsCompanion.insert({
    required String id,
    required String accountId,
    required CreditLiabilityAccountKind kind,
    this.creditLimitMinor = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.repaymentDay = const Value.absent(),
    this.billingStartPeriod = const Value.absent(),
    this.billingDayToNext = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       kind = Value(kind);
  static Insertable<CreditLiabilityAccountRow> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? kind,
    Expression<int>? creditLimitMinor,
    Expression<int>? billingDay,
    Expression<int>? repaymentDay,
    Expression<int>? billingStartPeriod,
    Expression<bool>? billingDayToNext,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (kind != null) 'kind': kind,
      if (creditLimitMinor != null) 'credit_limit_minor': creditLimitMinor,
      if (billingDay != null) 'billing_day': billingDay,
      if (repaymentDay != null) 'repayment_day': repaymentDay,
      if (billingStartPeriod != null)
        'billing_start_period': billingStartPeriod,
      if (billingDayToNext != null) 'billing_day_to_next': billingDayToNext,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CreditLiabilityAccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<CreditLiabilityAccountKind>? kind,
    Value<int?>? creditLimitMinor,
    Value<int?>? billingDay,
    Value<int?>? repaymentDay,
    Value<int?>? billingStartPeriod,
    Value<bool>? billingDayToNext,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CreditLiabilityAccountsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      kind: kind ?? this.kind,
      creditLimitMinor: creditLimitMinor ?? this.creditLimitMinor,
      billingDay: billingDay ?? this.billingDay,
      repaymentDay: repaymentDay ?? this.repaymentDay,
      billingStartPeriod: billingStartPeriod ?? this.billingStartPeriod,
      billingDayToNext: billingDayToNext ?? this.billingDayToNext,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $CreditLiabilityAccountsTable.$converterkind.toSql(kind.value),
      );
    }
    if (creditLimitMinor.present) {
      map['credit_limit_minor'] = Variable<int>(creditLimitMinor.value);
    }
    if (billingDay.present) {
      map['billing_day'] = Variable<int>(billingDay.value);
    }
    if (repaymentDay.present) {
      map['repayment_day'] = Variable<int>(repaymentDay.value);
    }
    if (billingStartPeriod.present) {
      map['billing_start_period'] = Variable<int>(billingStartPeriod.value);
    }
    if (billingDayToNext.present) {
      map['billing_day_to_next'] = Variable<bool>(billingDayToNext.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CreditLiabilityAccountsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('kind: $kind, ')
          ..write('creditLimitMinor: $creditLimitMinor, ')
          ..write('billingDay: $billingDay, ')
          ..write('repaymentDay: $repaymentDay, ')
          ..write('billingStartPeriod: $billingStartPeriod, ')
          ..write('billingDayToNext: $billingDayToNext, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BillsTable extends Bills with TableInfo<$BillsTable, BillRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodMeta = const VerificationMeta('period');
  @override
  late final GeneratedColumn<int> period = GeneratedColumn<int>(
    'period',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _billingDateMeta = const VerificationMeta(
    'billingDate',
  );
  @override
  late final GeneratedColumn<DateTime> billingDate = GeneratedColumn<DateTime>(
    'billing_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repaymentDateMeta = const VerificationMeta(
    'repaymentDate',
  );
  @override
  late final GeneratedColumn<DateTime> repaymentDate =
      GeneratedColumn<DateTime>(
        'repayment_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  late final GeneratedColumnWithTypeConverter<BillStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<BillStatus>($BillsTable.$converterstatus);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    period,
    startDate,
    billingDate,
    repaymentDate,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bills';
  @override
  VerificationContext validateIntegrity(
    Insertable<BillRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('period')) {
      context.handle(
        _periodMeta,
        period.isAcceptableOrUnknown(data['period']!, _periodMeta),
      );
    } else if (isInserting) {
      context.missing(_periodMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('billing_date')) {
      context.handle(
        _billingDateMeta,
        billingDate.isAcceptableOrUnknown(
          data['billing_date']!,
          _billingDateMeta,
        ),
      );
    }
    if (data.containsKey('repayment_date')) {
      context.handle(
        _repaymentDateMeta,
        repaymentDate.isAcceptableOrUnknown(
          data['repayment_date']!,
          _repaymentDateMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BillRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BillRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      accountId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}account_id'],
          )!,
      period:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}period'],
          )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      ),
      billingDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}billing_date'],
      ),
      repaymentDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}repayment_date'],
      ),
      status: $BillsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $BillsTable createAlias(String alias) {
    return $BillsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<BillStatus, String, String> $converterstatus =
      const EnumNameConverter<BillStatus>(BillStatus.values);
}

class BillRow extends DataClass implements Insertable<BillRow> {
  final String id;
  final String accountId;
  final int period;
  final DateTime? startDate;
  final DateTime? billingDate;
  final DateTime? repaymentDate;
  final BillStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BillRow({
    required this.id,
    required this.accountId,
    required this.period,
    this.startDate,
    this.billingDate,
    this.repaymentDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['period'] = Variable<int>(period);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || billingDate != null) {
      map['billing_date'] = Variable<DateTime>(billingDate);
    }
    if (!nullToAbsent || repaymentDate != null) {
      map['repayment_date'] = Variable<DateTime>(repaymentDate);
    }
    {
      map['status'] = Variable<String>(
        $BillsTable.$converterstatus.toSql(status),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BillsCompanion toCompanion(bool nullToAbsent) {
    return BillsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      period: Value(period),
      startDate:
          startDate == null && nullToAbsent
              ? const Value.absent()
              : Value(startDate),
      billingDate:
          billingDate == null && nullToAbsent
              ? const Value.absent()
              : Value(billingDate),
      repaymentDate:
          repaymentDate == null && nullToAbsent
              ? const Value.absent()
              : Value(repaymentDate),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BillRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BillRow(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      period: serializer.fromJson<int>(json['period']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      billingDate: serializer.fromJson<DateTime?>(json['billingDate']),
      repaymentDate: serializer.fromJson<DateTime?>(json['repaymentDate']),
      status: $BillsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'period': serializer.toJson<int>(period),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'billingDate': serializer.toJson<DateTime?>(billingDate),
      'repaymentDate': serializer.toJson<DateTime?>(repaymentDate),
      'status': serializer.toJson<String>(
        $BillsTable.$converterstatus.toJson(status),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BillRow copyWith({
    String? id,
    String? accountId,
    int? period,
    Value<DateTime?> startDate = const Value.absent(),
    Value<DateTime?> billingDate = const Value.absent(),
    Value<DateTime?> repaymentDate = const Value.absent(),
    BillStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BillRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    period: period ?? this.period,
    startDate: startDate.present ? startDate.value : this.startDate,
    billingDate: billingDate.present ? billingDate.value : this.billingDate,
    repaymentDate:
        repaymentDate.present ? repaymentDate.value : this.repaymentDate,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BillRow copyWithCompanion(BillsCompanion data) {
    return BillRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      period: data.period.present ? data.period.value : this.period,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      billingDate:
          data.billingDate.present ? data.billingDate.value : this.billingDate,
      repaymentDate:
          data.repaymentDate.present
              ? data.repaymentDate.value
              : this.repaymentDate,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BillRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('period: $period, ')
          ..write('startDate: $startDate, ')
          ..write('billingDate: $billingDate, ')
          ..write('repaymentDate: $repaymentDate, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    period,
    startDate,
    billingDate,
    repaymentDate,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BillRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.period == this.period &&
          other.startDate == this.startDate &&
          other.billingDate == this.billingDate &&
          other.repaymentDate == this.repaymentDate &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BillsCompanion extends UpdateCompanion<BillRow> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<int> period;
  final Value<DateTime?> startDate;
  final Value<DateTime?> billingDate;
  final Value<DateTime?> repaymentDate;
  final Value<BillStatus> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BillsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.period = const Value.absent(),
    this.startDate = const Value.absent(),
    this.billingDate = const Value.absent(),
    this.repaymentDate = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BillsCompanion.insert({
    required String id,
    required String accountId,
    required int period,
    this.startDate = const Value.absent(),
    this.billingDate = const Value.absent(),
    this.repaymentDate = const Value.absent(),
    required BillStatus status,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       period = Value(period),
       status = Value(status);
  static Insertable<BillRow> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<int>? period,
    Expression<DateTime>? startDate,
    Expression<DateTime>? billingDate,
    Expression<DateTime>? repaymentDate,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (period != null) 'period': period,
      if (startDate != null) 'start_date': startDate,
      if (billingDate != null) 'billing_date': billingDate,
      if (repaymentDate != null) 'repayment_date': repaymentDate,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BillsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<int>? period,
    Value<DateTime?>? startDate,
    Value<DateTime?>? billingDate,
    Value<DateTime?>? repaymentDate,
    Value<BillStatus>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BillsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      billingDate: billingDate ?? this.billingDate,
      repaymentDate: repaymentDate ?? this.repaymentDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (period.present) {
      map['period'] = Variable<int>(period.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (billingDate.present) {
      map['billing_date'] = Variable<DateTime>(billingDate.value);
    }
    if (repaymentDate.present) {
      map['repayment_date'] = Variable<DateTime>(repaymentDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $BillsTable.$converterstatus.toSql(status.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('period: $period, ')
          ..write('startDate: $startDate, ')
          ..write('billingDate: $billingDate, ')
          ..write('repaymentDate: $repaymentDate, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BillItemsTable extends BillItems
    with TableInfo<$BillItemsTable, BillItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _billIdMeta = const VerificationMeta('billId');
  @override
  late final GeneratedColumn<String> billId = GeneratedColumn<String>(
    'bill_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BillItemType, String> itemType =
      GeneratedColumn<String>(
        'item_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<BillItemType>($BillItemsTable.$converteritemType);
  static const VerificationMeta _contractIdMeta = const VerificationMeta(
    'contractId',
  );
  @override
  late final GeneratedColumn<String> contractId = GeneratedColumn<String>(
    'contract_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduleIdMeta = const VerificationMeta(
    'scheduleId',
  );
  @override
  late final GeneratedColumn<String> scheduleId = GeneratedColumn<String>(
    'schedule_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repaymentDateMeta = const VerificationMeta(
    'repaymentDate',
  );
  @override
  late final GeneratedColumn<DateTime> repaymentDate =
      GeneratedColumn<DateTime>(
        'repayment_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _expectedPrincipalMinorMeta =
      const VerificationMeta('expectedPrincipalMinor');
  @override
  late final GeneratedColumn<int> expectedPrincipalMinor = GeneratedColumn<int>(
    'expected_principal_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedInterestMinorMeta =
      const VerificationMeta('expectedInterestMinor');
  @override
  late final GeneratedColumn<int> expectedInterestMinor = GeneratedColumn<int>(
    'expected_interest_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedFeeMinorMeta = const VerificationMeta(
    'expectedFeeMinor',
  );
  @override
  late final GeneratedColumn<int> expectedFeeMinor = GeneratedColumn<int>(
    'expected_fee_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BillItemStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<BillItemStatus>($BillItemsTable.$converterstatus);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    billId,
    itemType,
    contractId,
    scheduleId,
    repaymentDate,
    expectedPrincipalMinor,
    expectedInterestMinor,
    expectedFeeMinor,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bill_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<BillItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('bill_id')) {
      context.handle(
        _billIdMeta,
        billId.isAcceptableOrUnknown(data['bill_id']!, _billIdMeta),
      );
    } else if (isInserting) {
      context.missing(_billIdMeta);
    }
    if (data.containsKey('contract_id')) {
      context.handle(
        _contractIdMeta,
        contractId.isAcceptableOrUnknown(data['contract_id']!, _contractIdMeta),
      );
    }
    if (data.containsKey('schedule_id')) {
      context.handle(
        _scheduleIdMeta,
        scheduleId.isAcceptableOrUnknown(data['schedule_id']!, _scheduleIdMeta),
      );
    }
    if (data.containsKey('repayment_date')) {
      context.handle(
        _repaymentDateMeta,
        repaymentDate.isAcceptableOrUnknown(
          data['repayment_date']!,
          _repaymentDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repaymentDateMeta);
    }
    if (data.containsKey('expected_principal_minor')) {
      context.handle(
        _expectedPrincipalMinorMeta,
        expectedPrincipalMinor.isAcceptableOrUnknown(
          data['expected_principal_minor']!,
          _expectedPrincipalMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expectedPrincipalMinorMeta);
    }
    if (data.containsKey('expected_interest_minor')) {
      context.handle(
        _expectedInterestMinorMeta,
        expectedInterestMinor.isAcceptableOrUnknown(
          data['expected_interest_minor']!,
          _expectedInterestMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expectedInterestMinorMeta);
    }
    if (data.containsKey('expected_fee_minor')) {
      context.handle(
        _expectedFeeMinorMeta,
        expectedFeeMinor.isAcceptableOrUnknown(
          data['expected_fee_minor']!,
          _expectedFeeMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expectedFeeMinorMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BillItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BillItemRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      billId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}bill_id'],
          )!,
      itemType: $BillItemsTable.$converteritemType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}item_type'],
        )!,
      ),
      contractId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contract_id'],
      ),
      scheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_id'],
      ),
      repaymentDate:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}repayment_date'],
          )!,
      expectedPrincipalMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}expected_principal_minor'],
          )!,
      expectedInterestMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}expected_interest_minor'],
          )!,
      expectedFeeMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}expected_fee_minor'],
          )!,
      status: $BillItemsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $BillItemsTable createAlias(String alias) {
    return $BillItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<BillItemType, String, String> $converteritemType =
      const EnumNameConverter<BillItemType>(BillItemType.values);
  static JsonTypeConverter2<BillItemStatus, String, String> $converterstatus =
      const EnumNameConverter<BillItemStatus>(BillItemStatus.values);
}

class BillItemRow extends DataClass implements Insertable<BillItemRow> {
  final String id;
  final String billId;
  final BillItemType itemType;
  final String? contractId;
  final String? scheduleId;
  final DateTime repaymentDate;
  final int expectedPrincipalMinor;
  final int expectedInterestMinor;
  final int expectedFeeMinor;
  final BillItemStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BillItemRow({
    required this.id,
    required this.billId,
    required this.itemType,
    this.contractId,
    this.scheduleId,
    required this.repaymentDate,
    required this.expectedPrincipalMinor,
    required this.expectedInterestMinor,
    required this.expectedFeeMinor,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['bill_id'] = Variable<String>(billId);
    {
      map['item_type'] = Variable<String>(
        $BillItemsTable.$converteritemType.toSql(itemType),
      );
    }
    if (!nullToAbsent || contractId != null) {
      map['contract_id'] = Variable<String>(contractId);
    }
    if (!nullToAbsent || scheduleId != null) {
      map['schedule_id'] = Variable<String>(scheduleId);
    }
    map['repayment_date'] = Variable<DateTime>(repaymentDate);
    map['expected_principal_minor'] = Variable<int>(expectedPrincipalMinor);
    map['expected_interest_minor'] = Variable<int>(expectedInterestMinor);
    map['expected_fee_minor'] = Variable<int>(expectedFeeMinor);
    {
      map['status'] = Variable<String>(
        $BillItemsTable.$converterstatus.toSql(status),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BillItemsCompanion toCompanion(bool nullToAbsent) {
    return BillItemsCompanion(
      id: Value(id),
      billId: Value(billId),
      itemType: Value(itemType),
      contractId:
          contractId == null && nullToAbsent
              ? const Value.absent()
              : Value(contractId),
      scheduleId:
          scheduleId == null && nullToAbsent
              ? const Value.absent()
              : Value(scheduleId),
      repaymentDate: Value(repaymentDate),
      expectedPrincipalMinor: Value(expectedPrincipalMinor),
      expectedInterestMinor: Value(expectedInterestMinor),
      expectedFeeMinor: Value(expectedFeeMinor),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BillItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BillItemRow(
      id: serializer.fromJson<String>(json['id']),
      billId: serializer.fromJson<String>(json['billId']),
      itemType: $BillItemsTable.$converteritemType.fromJson(
        serializer.fromJson<String>(json['itemType']),
      ),
      contractId: serializer.fromJson<String?>(json['contractId']),
      scheduleId: serializer.fromJson<String?>(json['scheduleId']),
      repaymentDate: serializer.fromJson<DateTime>(json['repaymentDate']),
      expectedPrincipalMinor: serializer.fromJson<int>(
        json['expectedPrincipalMinor'],
      ),
      expectedInterestMinor: serializer.fromJson<int>(
        json['expectedInterestMinor'],
      ),
      expectedFeeMinor: serializer.fromJson<int>(json['expectedFeeMinor']),
      status: $BillItemsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'billId': serializer.toJson<String>(billId),
      'itemType': serializer.toJson<String>(
        $BillItemsTable.$converteritemType.toJson(itemType),
      ),
      'contractId': serializer.toJson<String?>(contractId),
      'scheduleId': serializer.toJson<String?>(scheduleId),
      'repaymentDate': serializer.toJson<DateTime>(repaymentDate),
      'expectedPrincipalMinor': serializer.toJson<int>(expectedPrincipalMinor),
      'expectedInterestMinor': serializer.toJson<int>(expectedInterestMinor),
      'expectedFeeMinor': serializer.toJson<int>(expectedFeeMinor),
      'status': serializer.toJson<String>(
        $BillItemsTable.$converterstatus.toJson(status),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BillItemRow copyWith({
    String? id,
    String? billId,
    BillItemType? itemType,
    Value<String?> contractId = const Value.absent(),
    Value<String?> scheduleId = const Value.absent(),
    DateTime? repaymentDate,
    int? expectedPrincipalMinor,
    int? expectedInterestMinor,
    int? expectedFeeMinor,
    BillItemStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BillItemRow(
    id: id ?? this.id,
    billId: billId ?? this.billId,
    itemType: itemType ?? this.itemType,
    contractId: contractId.present ? contractId.value : this.contractId,
    scheduleId: scheduleId.present ? scheduleId.value : this.scheduleId,
    repaymentDate: repaymentDate ?? this.repaymentDate,
    expectedPrincipalMinor:
        expectedPrincipalMinor ?? this.expectedPrincipalMinor,
    expectedInterestMinor: expectedInterestMinor ?? this.expectedInterestMinor,
    expectedFeeMinor: expectedFeeMinor ?? this.expectedFeeMinor,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BillItemRow copyWithCompanion(BillItemsCompanion data) {
    return BillItemRow(
      id: data.id.present ? data.id.value : this.id,
      billId: data.billId.present ? data.billId.value : this.billId,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      contractId:
          data.contractId.present ? data.contractId.value : this.contractId,
      scheduleId:
          data.scheduleId.present ? data.scheduleId.value : this.scheduleId,
      repaymentDate:
          data.repaymentDate.present
              ? data.repaymentDate.value
              : this.repaymentDate,
      expectedPrincipalMinor:
          data.expectedPrincipalMinor.present
              ? data.expectedPrincipalMinor.value
              : this.expectedPrincipalMinor,
      expectedInterestMinor:
          data.expectedInterestMinor.present
              ? data.expectedInterestMinor.value
              : this.expectedInterestMinor,
      expectedFeeMinor:
          data.expectedFeeMinor.present
              ? data.expectedFeeMinor.value
              : this.expectedFeeMinor,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BillItemRow(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('itemType: $itemType, ')
          ..write('contractId: $contractId, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('repaymentDate: $repaymentDate, ')
          ..write('expectedPrincipalMinor: $expectedPrincipalMinor, ')
          ..write('expectedInterestMinor: $expectedInterestMinor, ')
          ..write('expectedFeeMinor: $expectedFeeMinor, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    billId,
    itemType,
    contractId,
    scheduleId,
    repaymentDate,
    expectedPrincipalMinor,
    expectedInterestMinor,
    expectedFeeMinor,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BillItemRow &&
          other.id == this.id &&
          other.billId == this.billId &&
          other.itemType == this.itemType &&
          other.contractId == this.contractId &&
          other.scheduleId == this.scheduleId &&
          other.repaymentDate == this.repaymentDate &&
          other.expectedPrincipalMinor == this.expectedPrincipalMinor &&
          other.expectedInterestMinor == this.expectedInterestMinor &&
          other.expectedFeeMinor == this.expectedFeeMinor &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BillItemsCompanion extends UpdateCompanion<BillItemRow> {
  final Value<String> id;
  final Value<String> billId;
  final Value<BillItemType> itemType;
  final Value<String?> contractId;
  final Value<String?> scheduleId;
  final Value<DateTime> repaymentDate;
  final Value<int> expectedPrincipalMinor;
  final Value<int> expectedInterestMinor;
  final Value<int> expectedFeeMinor;
  final Value<BillItemStatus> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BillItemsCompanion({
    this.id = const Value.absent(),
    this.billId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.contractId = const Value.absent(),
    this.scheduleId = const Value.absent(),
    this.repaymentDate = const Value.absent(),
    this.expectedPrincipalMinor = const Value.absent(),
    this.expectedInterestMinor = const Value.absent(),
    this.expectedFeeMinor = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BillItemsCompanion.insert({
    required String id,
    required String billId,
    required BillItemType itemType,
    this.contractId = const Value.absent(),
    this.scheduleId = const Value.absent(),
    required DateTime repaymentDate,
    required int expectedPrincipalMinor,
    required int expectedInterestMinor,
    required int expectedFeeMinor,
    required BillItemStatus status,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       billId = Value(billId),
       itemType = Value(itemType),
       repaymentDate = Value(repaymentDate),
       expectedPrincipalMinor = Value(expectedPrincipalMinor),
       expectedInterestMinor = Value(expectedInterestMinor),
       expectedFeeMinor = Value(expectedFeeMinor),
       status = Value(status);
  static Insertable<BillItemRow> custom({
    Expression<String>? id,
    Expression<String>? billId,
    Expression<String>? itemType,
    Expression<String>? contractId,
    Expression<String>? scheduleId,
    Expression<DateTime>? repaymentDate,
    Expression<int>? expectedPrincipalMinor,
    Expression<int>? expectedInterestMinor,
    Expression<int>? expectedFeeMinor,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (billId != null) 'bill_id': billId,
      if (itemType != null) 'item_type': itemType,
      if (contractId != null) 'contract_id': contractId,
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (repaymentDate != null) 'repayment_date': repaymentDate,
      if (expectedPrincipalMinor != null)
        'expected_principal_minor': expectedPrincipalMinor,
      if (expectedInterestMinor != null)
        'expected_interest_minor': expectedInterestMinor,
      if (expectedFeeMinor != null) 'expected_fee_minor': expectedFeeMinor,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BillItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? billId,
    Value<BillItemType>? itemType,
    Value<String?>? contractId,
    Value<String?>? scheduleId,
    Value<DateTime>? repaymentDate,
    Value<int>? expectedPrincipalMinor,
    Value<int>? expectedInterestMinor,
    Value<int>? expectedFeeMinor,
    Value<BillItemStatus>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BillItemsCompanion(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      itemType: itemType ?? this.itemType,
      contractId: contractId ?? this.contractId,
      scheduleId: scheduleId ?? this.scheduleId,
      repaymentDate: repaymentDate ?? this.repaymentDate,
      expectedPrincipalMinor:
          expectedPrincipalMinor ?? this.expectedPrincipalMinor,
      expectedInterestMinor:
          expectedInterestMinor ?? this.expectedInterestMinor,
      expectedFeeMinor: expectedFeeMinor ?? this.expectedFeeMinor,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (billId.present) {
      map['bill_id'] = Variable<String>(billId.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(
        $BillItemsTable.$converteritemType.toSql(itemType.value),
      );
    }
    if (contractId.present) {
      map['contract_id'] = Variable<String>(contractId.value);
    }
    if (scheduleId.present) {
      map['schedule_id'] = Variable<String>(scheduleId.value);
    }
    if (repaymentDate.present) {
      map['repayment_date'] = Variable<DateTime>(repaymentDate.value);
    }
    if (expectedPrincipalMinor.present) {
      map['expected_principal_minor'] = Variable<int>(
        expectedPrincipalMinor.value,
      );
    }
    if (expectedInterestMinor.present) {
      map['expected_interest_minor'] = Variable<int>(
        expectedInterestMinor.value,
      );
    }
    if (expectedFeeMinor.present) {
      map['expected_fee_minor'] = Variable<int>(expectedFeeMinor.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $BillItemsTable.$converterstatus.toSql(status.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillItemsCompanion(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('itemType: $itemType, ')
          ..write('contractId: $contractId, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('repaymentDate: $repaymentDate, ')
          ..write('expectedPrincipalMinor: $expectedPrincipalMinor, ')
          ..write('expectedInterestMinor: $expectedInterestMinor, ')
          ..write('expectedFeeMinor: $expectedFeeMinor, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InstallmentContractsTable extends InstallmentContracts
    with TableInfo<$InstallmentContractsTable, InstallmentContractRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstallmentContractsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _liabilityAccountIdMeta =
      const VerificationMeta('liabilityAccountId');
  @override
  late final GeneratedColumn<String> liabilityAccountId =
      GeneratedColumn<String>(
        'liability_account_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  late final GeneratedColumnWithTypeConverter<InstallmentSourceType, String>
  sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<InstallmentSourceType>(
    $InstallmentContractsTable.$convertersourceType,
  );
  static const VerificationMeta _disbursementAccountIdMeta =
      const VerificationMeta('disbursementAccountId');
  @override
  late final GeneratedColumn<String> disbursementAccountId =
      GeneratedColumn<String>(
        'disbursement_account_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _disbursementTransactionIdMeta =
      const VerificationMeta('disbursementTransactionId');
  @override
  late final GeneratedColumn<String> disbursementTransactionId =
      GeneratedColumn<String>(
        'disbursement_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sourceRepaymentIdMeta = const VerificationMeta(
    'sourceRepaymentId',
  );
  @override
  late final GeneratedColumn<String> sourceRepaymentId =
      GeneratedColumn<String>(
        'source_repayment_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _principalMinorMeta = const VerificationMeta(
    'principalMinor',
  );
  @override
  late final GeneratedColumn<int> principalMinor = GeneratedColumn<int>(
    'principal_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalPeriodsMeta = const VerificationMeta(
    'totalPeriods',
  );
  @override
  late final GeneratedColumn<int> totalPeriods = GeneratedColumn<int>(
    'total_periods',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _borrowingDateMeta = const VerificationMeta(
    'borrowingDate',
  );
  @override
  late final GeneratedColumn<DateTime> borrowingDate =
      GeneratedColumn<DateTime>(
        'start_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _firstRepaymentDateMeta =
      const VerificationMeta('firstRepaymentDate');
  @override
  late final GeneratedColumn<DateTime> firstRepaymentDate =
      GeneratedColumn<DateTime>(
        'first_repayment_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastRepaymentDateMeta = const VerificationMeta(
    'lastRepaymentDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastRepaymentDate =
      GeneratedColumn<DateTime>(
        'last_repayment_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  late final GeneratedColumnWithTypeConverter<
    InstallmentRepaymentMethod,
    String
  >
  repaymentMethod = GeneratedColumn<String>(
    'repayment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<InstallmentRepaymentMethod>(
    $InstallmentContractsTable.$converterrepaymentMethod,
  );
  @override
  late final GeneratedColumnWithTypeConverter<InterestRatePeriod?, String>
  interestRatePeriod = GeneratedColumn<String>(
    'interest_rate_period',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<InterestRatePeriod?>(
    $InstallmentContractsTable.$converterinterestRatePeriodn,
  );
  static const VerificationMeta _interestRatePpmMeta = const VerificationMeta(
    'interestRatePpm',
  );
  @override
  late final GeneratedColumn<int> interestRatePpm = GeneratedColumn<int>(
    'interest_rate_ppm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<InterestAccrualMethod, String>
  interestAccrualMethod = GeneratedColumn<String>(
    'interest_accrual_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('daily'),
  ).withConverter<InterestAccrualMethod>(
    $InstallmentContractsTable.$converterinterestAccrualMethod,
  );
  static const VerificationMeta _totalFeeMinorMeta = const VerificationMeta(
    'totalFeeMinor',
  );
  @override
  late final GeneratedColumn<int> totalFeeMinor = GeneratedColumn<int>(
    'total_fee_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<InstallmentContractStatus, String>
  status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<InstallmentContractStatus>(
    $InstallmentContractsTable.$converterstatus,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    liabilityAccountId,
    sourceType,
    disbursementAccountId,
    disbursementTransactionId,
    sourceRepaymentId,
    principalMinor,
    totalPeriods,
    borrowingDate,
    firstRepaymentDate,
    lastRepaymentDate,
    repaymentMethod,
    interestRatePeriod,
    interestRatePpm,
    interestAccrualMethod,
    totalFeeMinor,
    status,
    note,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'installment_contracts';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstallmentContractRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('liability_account_id')) {
      context.handle(
        _liabilityAccountIdMeta,
        liabilityAccountId.isAcceptableOrUnknown(
          data['liability_account_id']!,
          _liabilityAccountIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_liabilityAccountIdMeta);
    }
    if (data.containsKey('disbursement_account_id')) {
      context.handle(
        _disbursementAccountIdMeta,
        disbursementAccountId.isAcceptableOrUnknown(
          data['disbursement_account_id']!,
          _disbursementAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('disbursement_transaction_id')) {
      context.handle(
        _disbursementTransactionIdMeta,
        disbursementTransactionId.isAcceptableOrUnknown(
          data['disbursement_transaction_id']!,
          _disbursementTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('source_repayment_id')) {
      context.handle(
        _sourceRepaymentIdMeta,
        sourceRepaymentId.isAcceptableOrUnknown(
          data['source_repayment_id']!,
          _sourceRepaymentIdMeta,
        ),
      );
    }
    if (data.containsKey('principal_minor')) {
      context.handle(
        _principalMinorMeta,
        principalMinor.isAcceptableOrUnknown(
          data['principal_minor']!,
          _principalMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_principalMinorMeta);
    }
    if (data.containsKey('total_periods')) {
      context.handle(
        _totalPeriodsMeta,
        totalPeriods.isAcceptableOrUnknown(
          data['total_periods']!,
          _totalPeriodsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalPeriodsMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _borrowingDateMeta,
        borrowingDate.isAcceptableOrUnknown(
          data['start_date']!,
          _borrowingDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_borrowingDateMeta);
    }
    if (data.containsKey('first_repayment_date')) {
      context.handle(
        _firstRepaymentDateMeta,
        firstRepaymentDate.isAcceptableOrUnknown(
          data['first_repayment_date']!,
          _firstRepaymentDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstRepaymentDateMeta);
    }
    if (data.containsKey('last_repayment_date')) {
      context.handle(
        _lastRepaymentDateMeta,
        lastRepaymentDate.isAcceptableOrUnknown(
          data['last_repayment_date']!,
          _lastRepaymentDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastRepaymentDateMeta);
    }
    if (data.containsKey('interest_rate_ppm')) {
      context.handle(
        _interestRatePpmMeta,
        interestRatePpm.isAcceptableOrUnknown(
          data['interest_rate_ppm']!,
          _interestRatePpmMeta,
        ),
      );
    }
    if (data.containsKey('total_fee_minor')) {
      context.handle(
        _totalFeeMinorMeta,
        totalFeeMinor.isAcceptableOrUnknown(
          data['total_fee_minor']!,
          _totalFeeMinorMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InstallmentContractRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstallmentContractRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      liabilityAccountId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}liability_account_id'],
          )!,
      sourceType: $InstallmentContractsTable.$convertersourceType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source_type'],
        )!,
      ),
      disbursementAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}disbursement_account_id'],
      ),
      disbursementTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}disbursement_transaction_id'],
      ),
      sourceRepaymentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_repayment_id'],
      ),
      principalMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}principal_minor'],
          )!,
      totalPeriods:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}total_periods'],
          )!,
      borrowingDate:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}start_date'],
          )!,
      firstRepaymentDate:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}first_repayment_date'],
          )!,
      lastRepaymentDate:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}last_repayment_date'],
          )!,
      repaymentMethod: $InstallmentContractsTable.$converterrepaymentMethod
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}repayment_method'],
            )!,
          ),
      interestRatePeriod: $InstallmentContractsTable
          .$converterinterestRatePeriodn
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}interest_rate_period'],
            ),
          ),
      interestRatePpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interest_rate_ppm'],
      ),
      interestAccrualMethod: $InstallmentContractsTable
          .$converterinterestAccrualMethod
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}interest_accrual_method'],
            )!,
          ),
      totalFeeMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}total_fee_minor'],
          )!,
      status: $InstallmentContractsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $InstallmentContractsTable createAlias(String alias) {
    return $InstallmentContractsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<InstallmentSourceType, String, String>
  $convertersourceType = const EnumNameConverter<InstallmentSourceType>(
    InstallmentSourceType.values,
  );
  static JsonTypeConverter2<InstallmentRepaymentMethod, String, String>
  $converterrepaymentMethod =
      const EnumNameConverter<InstallmentRepaymentMethod>(
        InstallmentRepaymentMethod.values,
      );
  static JsonTypeConverter2<InterestRatePeriod, String, String>
  $converterinterestRatePeriod = const EnumNameConverter<InterestRatePeriod>(
    InterestRatePeriod.values,
  );
  static JsonTypeConverter2<InterestRatePeriod?, String?, String?>
  $converterinterestRatePeriodn = JsonTypeConverter2.asNullable(
    $converterinterestRatePeriod,
  );
  static JsonTypeConverter2<InterestAccrualMethod, String, String>
  $converterinterestAccrualMethod =
      const EnumNameConverter<InterestAccrualMethod>(
        InterestAccrualMethod.values,
      );
  static JsonTypeConverter2<InstallmentContractStatus, String, String>
  $converterstatus = const EnumNameConverter<InstallmentContractStatus>(
    InstallmentContractStatus.values,
  );
}

class InstallmentContractRow extends DataClass
    implements Insertable<InstallmentContractRow> {
  final String id;
  final String liabilityAccountId;
  final InstallmentSourceType sourceType;
  final String? disbursementAccountId;
  final String? disbursementTransactionId;
  final String? sourceRepaymentId;
  final int principalMinor;
  final int totalPeriods;

  /// 借款日期 / 合同起算日（旧字段 start_date 沿用，语义统一为借款日期）。
  final DateTime borrowingDate;

  /// 首期还款日。
  final DateTime firstRepaymentDate;

  /// 末期还款日。默认 = 首期 + (期数-1) 月，可独调。
  final DateTime lastRepaymentDate;
  final InstallmentRepaymentMethod repaymentMethod;
  final InterestRatePeriod? interestRatePeriod;
  final int? interestRatePpm;

  /// 计息方式（按日 / 按月）。drift 序列化为 enum.name，存量行默认 'daily' 保留旧行为。
  final InterestAccrualMethod interestAccrualMethod;

  /// 合同总手续费，用于编辑时按 method 重新分配。
  final int totalFeeMinor;
  final InstallmentContractStatus status;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  const InstallmentContractRow({
    required this.id,
    required this.liabilityAccountId,
    required this.sourceType,
    this.disbursementAccountId,
    this.disbursementTransactionId,
    this.sourceRepaymentId,
    required this.principalMinor,
    required this.totalPeriods,
    required this.borrowingDate,
    required this.firstRepaymentDate,
    required this.lastRepaymentDate,
    required this.repaymentMethod,
    this.interestRatePeriod,
    this.interestRatePpm,
    required this.interestAccrualMethod,
    required this.totalFeeMinor,
    required this.status,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['liability_account_id'] = Variable<String>(liabilityAccountId);
    {
      map['source_type'] = Variable<String>(
        $InstallmentContractsTable.$convertersourceType.toSql(sourceType),
      );
    }
    if (!nullToAbsent || disbursementAccountId != null) {
      map['disbursement_account_id'] = Variable<String>(disbursementAccountId);
    }
    if (!nullToAbsent || disbursementTransactionId != null) {
      map['disbursement_transaction_id'] = Variable<String>(
        disbursementTransactionId,
      );
    }
    if (!nullToAbsent || sourceRepaymentId != null) {
      map['source_repayment_id'] = Variable<String>(sourceRepaymentId);
    }
    map['principal_minor'] = Variable<int>(principalMinor);
    map['total_periods'] = Variable<int>(totalPeriods);
    map['start_date'] = Variable<DateTime>(borrowingDate);
    map['first_repayment_date'] = Variable<DateTime>(firstRepaymentDate);
    map['last_repayment_date'] = Variable<DateTime>(lastRepaymentDate);
    {
      map['repayment_method'] = Variable<String>(
        $InstallmentContractsTable.$converterrepaymentMethod.toSql(
          repaymentMethod,
        ),
      );
    }
    if (!nullToAbsent || interestRatePeriod != null) {
      map['interest_rate_period'] = Variable<String>(
        $InstallmentContractsTable.$converterinterestRatePeriodn.toSql(
          interestRatePeriod,
        ),
      );
    }
    if (!nullToAbsent || interestRatePpm != null) {
      map['interest_rate_ppm'] = Variable<int>(interestRatePpm);
    }
    {
      map['interest_accrual_method'] = Variable<String>(
        $InstallmentContractsTable.$converterinterestAccrualMethod.toSql(
          interestAccrualMethod,
        ),
      );
    }
    map['total_fee_minor'] = Variable<int>(totalFeeMinor);
    {
      map['status'] = Variable<String>(
        $InstallmentContractsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  InstallmentContractsCompanion toCompanion(bool nullToAbsent) {
    return InstallmentContractsCompanion(
      id: Value(id),
      liabilityAccountId: Value(liabilityAccountId),
      sourceType: Value(sourceType),
      disbursementAccountId:
          disbursementAccountId == null && nullToAbsent
              ? const Value.absent()
              : Value(disbursementAccountId),
      disbursementTransactionId:
          disbursementTransactionId == null && nullToAbsent
              ? const Value.absent()
              : Value(disbursementTransactionId),
      sourceRepaymentId:
          sourceRepaymentId == null && nullToAbsent
              ? const Value.absent()
              : Value(sourceRepaymentId),
      principalMinor: Value(principalMinor),
      totalPeriods: Value(totalPeriods),
      borrowingDate: Value(borrowingDate),
      firstRepaymentDate: Value(firstRepaymentDate),
      lastRepaymentDate: Value(lastRepaymentDate),
      repaymentMethod: Value(repaymentMethod),
      interestRatePeriod:
          interestRatePeriod == null && nullToAbsent
              ? const Value.absent()
              : Value(interestRatePeriod),
      interestRatePpm:
          interestRatePpm == null && nullToAbsent
              ? const Value.absent()
              : Value(interestRatePpm),
      interestAccrualMethod: Value(interestAccrualMethod),
      totalFeeMinor: Value(totalFeeMinor),
      status: Value(status),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory InstallmentContractRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstallmentContractRow(
      id: serializer.fromJson<String>(json['id']),
      liabilityAccountId: serializer.fromJson<String>(
        json['liabilityAccountId'],
      ),
      sourceType: $InstallmentContractsTable.$convertersourceType.fromJson(
        serializer.fromJson<String>(json['sourceType']),
      ),
      disbursementAccountId: serializer.fromJson<String?>(
        json['disbursementAccountId'],
      ),
      disbursementTransactionId: serializer.fromJson<String?>(
        json['disbursementTransactionId'],
      ),
      sourceRepaymentId: serializer.fromJson<String?>(
        json['sourceRepaymentId'],
      ),
      principalMinor: serializer.fromJson<int>(json['principalMinor']),
      totalPeriods: serializer.fromJson<int>(json['totalPeriods']),
      borrowingDate: serializer.fromJson<DateTime>(json['borrowingDate']),
      firstRepaymentDate: serializer.fromJson<DateTime>(
        json['firstRepaymentDate'],
      ),
      lastRepaymentDate: serializer.fromJson<DateTime>(
        json['lastRepaymentDate'],
      ),
      repaymentMethod: $InstallmentContractsTable.$converterrepaymentMethod
          .fromJson(serializer.fromJson<String>(json['repaymentMethod'])),
      interestRatePeriod: $InstallmentContractsTable
          .$converterinterestRatePeriodn
          .fromJson(serializer.fromJson<String?>(json['interestRatePeriod'])),
      interestRatePpm: serializer.fromJson<int?>(json['interestRatePpm']),
      interestAccrualMethod: $InstallmentContractsTable
          .$converterinterestAccrualMethod
          .fromJson(serializer.fromJson<String>(json['interestAccrualMethod'])),
      totalFeeMinor: serializer.fromJson<int>(json['totalFeeMinor']),
      status: $InstallmentContractsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'liabilityAccountId': serializer.toJson<String>(liabilityAccountId),
      'sourceType': serializer.toJson<String>(
        $InstallmentContractsTable.$convertersourceType.toJson(sourceType),
      ),
      'disbursementAccountId': serializer.toJson<String?>(
        disbursementAccountId,
      ),
      'disbursementTransactionId': serializer.toJson<String?>(
        disbursementTransactionId,
      ),
      'sourceRepaymentId': serializer.toJson<String?>(sourceRepaymentId),
      'principalMinor': serializer.toJson<int>(principalMinor),
      'totalPeriods': serializer.toJson<int>(totalPeriods),
      'borrowingDate': serializer.toJson<DateTime>(borrowingDate),
      'firstRepaymentDate': serializer.toJson<DateTime>(firstRepaymentDate),
      'lastRepaymentDate': serializer.toJson<DateTime>(lastRepaymentDate),
      'repaymentMethod': serializer.toJson<String>(
        $InstallmentContractsTable.$converterrepaymentMethod.toJson(
          repaymentMethod,
        ),
      ),
      'interestRatePeriod': serializer.toJson<String?>(
        $InstallmentContractsTable.$converterinterestRatePeriodn.toJson(
          interestRatePeriod,
        ),
      ),
      'interestRatePpm': serializer.toJson<int?>(interestRatePpm),
      'interestAccrualMethod': serializer.toJson<String>(
        $InstallmentContractsTable.$converterinterestAccrualMethod.toJson(
          interestAccrualMethod,
        ),
      ),
      'totalFeeMinor': serializer.toJson<int>(totalFeeMinor),
      'status': serializer.toJson<String>(
        $InstallmentContractsTable.$converterstatus.toJson(status),
      ),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  InstallmentContractRow copyWith({
    String? id,
    String? liabilityAccountId,
    InstallmentSourceType? sourceType,
    Value<String?> disbursementAccountId = const Value.absent(),
    Value<String?> disbursementTransactionId = const Value.absent(),
    Value<String?> sourceRepaymentId = const Value.absent(),
    int? principalMinor,
    int? totalPeriods,
    DateTime? borrowingDate,
    DateTime? firstRepaymentDate,
    DateTime? lastRepaymentDate,
    InstallmentRepaymentMethod? repaymentMethod,
    Value<InterestRatePeriod?> interestRatePeriod = const Value.absent(),
    Value<int?> interestRatePpm = const Value.absent(),
    InterestAccrualMethod? interestAccrualMethod,
    int? totalFeeMinor,
    InstallmentContractStatus? status,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => InstallmentContractRow(
    id: id ?? this.id,
    liabilityAccountId: liabilityAccountId ?? this.liabilityAccountId,
    sourceType: sourceType ?? this.sourceType,
    disbursementAccountId:
        disbursementAccountId.present
            ? disbursementAccountId.value
            : this.disbursementAccountId,
    disbursementTransactionId:
        disbursementTransactionId.present
            ? disbursementTransactionId.value
            : this.disbursementTransactionId,
    sourceRepaymentId:
        sourceRepaymentId.present
            ? sourceRepaymentId.value
            : this.sourceRepaymentId,
    principalMinor: principalMinor ?? this.principalMinor,
    totalPeriods: totalPeriods ?? this.totalPeriods,
    borrowingDate: borrowingDate ?? this.borrowingDate,
    firstRepaymentDate: firstRepaymentDate ?? this.firstRepaymentDate,
    lastRepaymentDate: lastRepaymentDate ?? this.lastRepaymentDate,
    repaymentMethod: repaymentMethod ?? this.repaymentMethod,
    interestRatePeriod:
        interestRatePeriod.present
            ? interestRatePeriod.value
            : this.interestRatePeriod,
    interestRatePpm:
        interestRatePpm.present ? interestRatePpm.value : this.interestRatePpm,
    interestAccrualMethod: interestAccrualMethod ?? this.interestAccrualMethod,
    totalFeeMinor: totalFeeMinor ?? this.totalFeeMinor,
    status: status ?? this.status,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  InstallmentContractRow copyWithCompanion(InstallmentContractsCompanion data) {
    return InstallmentContractRow(
      id: data.id.present ? data.id.value : this.id,
      liabilityAccountId:
          data.liabilityAccountId.present
              ? data.liabilityAccountId.value
              : this.liabilityAccountId,
      sourceType:
          data.sourceType.present ? data.sourceType.value : this.sourceType,
      disbursementAccountId:
          data.disbursementAccountId.present
              ? data.disbursementAccountId.value
              : this.disbursementAccountId,
      disbursementTransactionId:
          data.disbursementTransactionId.present
              ? data.disbursementTransactionId.value
              : this.disbursementTransactionId,
      sourceRepaymentId:
          data.sourceRepaymentId.present
              ? data.sourceRepaymentId.value
              : this.sourceRepaymentId,
      principalMinor:
          data.principalMinor.present
              ? data.principalMinor.value
              : this.principalMinor,
      totalPeriods:
          data.totalPeriods.present
              ? data.totalPeriods.value
              : this.totalPeriods,
      borrowingDate:
          data.borrowingDate.present
              ? data.borrowingDate.value
              : this.borrowingDate,
      firstRepaymentDate:
          data.firstRepaymentDate.present
              ? data.firstRepaymentDate.value
              : this.firstRepaymentDate,
      lastRepaymentDate:
          data.lastRepaymentDate.present
              ? data.lastRepaymentDate.value
              : this.lastRepaymentDate,
      repaymentMethod:
          data.repaymentMethod.present
              ? data.repaymentMethod.value
              : this.repaymentMethod,
      interestRatePeriod:
          data.interestRatePeriod.present
              ? data.interestRatePeriod.value
              : this.interestRatePeriod,
      interestRatePpm:
          data.interestRatePpm.present
              ? data.interestRatePpm.value
              : this.interestRatePpm,
      interestAccrualMethod:
          data.interestAccrualMethod.present
              ? data.interestAccrualMethod.value
              : this.interestAccrualMethod,
      totalFeeMinor:
          data.totalFeeMinor.present
              ? data.totalFeeMinor.value
              : this.totalFeeMinor,
      status: data.status.present ? data.status.value : this.status,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstallmentContractRow(')
          ..write('id: $id, ')
          ..write('liabilityAccountId: $liabilityAccountId, ')
          ..write('sourceType: $sourceType, ')
          ..write('disbursementAccountId: $disbursementAccountId, ')
          ..write('disbursementTransactionId: $disbursementTransactionId, ')
          ..write('sourceRepaymentId: $sourceRepaymentId, ')
          ..write('principalMinor: $principalMinor, ')
          ..write('totalPeriods: $totalPeriods, ')
          ..write('borrowingDate: $borrowingDate, ')
          ..write('firstRepaymentDate: $firstRepaymentDate, ')
          ..write('lastRepaymentDate: $lastRepaymentDate, ')
          ..write('repaymentMethod: $repaymentMethod, ')
          ..write('interestRatePeriod: $interestRatePeriod, ')
          ..write('interestRatePpm: $interestRatePpm, ')
          ..write('interestAccrualMethod: $interestAccrualMethod, ')
          ..write('totalFeeMinor: $totalFeeMinor, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    liabilityAccountId,
    sourceType,
    disbursementAccountId,
    disbursementTransactionId,
    sourceRepaymentId,
    principalMinor,
    totalPeriods,
    borrowingDate,
    firstRepaymentDate,
    lastRepaymentDate,
    repaymentMethod,
    interestRatePeriod,
    interestRatePpm,
    interestAccrualMethod,
    totalFeeMinor,
    status,
    note,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstallmentContractRow &&
          other.id == this.id &&
          other.liabilityAccountId == this.liabilityAccountId &&
          other.sourceType == this.sourceType &&
          other.disbursementAccountId == this.disbursementAccountId &&
          other.disbursementTransactionId == this.disbursementTransactionId &&
          other.sourceRepaymentId == this.sourceRepaymentId &&
          other.principalMinor == this.principalMinor &&
          other.totalPeriods == this.totalPeriods &&
          other.borrowingDate == this.borrowingDate &&
          other.firstRepaymentDate == this.firstRepaymentDate &&
          other.lastRepaymentDate == this.lastRepaymentDate &&
          other.repaymentMethod == this.repaymentMethod &&
          other.interestRatePeriod == this.interestRatePeriod &&
          other.interestRatePpm == this.interestRatePpm &&
          other.interestAccrualMethod == this.interestAccrualMethod &&
          other.totalFeeMinor == this.totalFeeMinor &&
          other.status == this.status &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class InstallmentContractsCompanion
    extends UpdateCompanion<InstallmentContractRow> {
  final Value<String> id;
  final Value<String> liabilityAccountId;
  final Value<InstallmentSourceType> sourceType;
  final Value<String?> disbursementAccountId;
  final Value<String?> disbursementTransactionId;
  final Value<String?> sourceRepaymentId;
  final Value<int> principalMinor;
  final Value<int> totalPeriods;
  final Value<DateTime> borrowingDate;
  final Value<DateTime> firstRepaymentDate;
  final Value<DateTime> lastRepaymentDate;
  final Value<InstallmentRepaymentMethod> repaymentMethod;
  final Value<InterestRatePeriod?> interestRatePeriod;
  final Value<int?> interestRatePpm;
  final Value<InterestAccrualMethod> interestAccrualMethod;
  final Value<int> totalFeeMinor;
  final Value<InstallmentContractStatus> status;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const InstallmentContractsCompanion({
    this.id = const Value.absent(),
    this.liabilityAccountId = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.disbursementAccountId = const Value.absent(),
    this.disbursementTransactionId = const Value.absent(),
    this.sourceRepaymentId = const Value.absent(),
    this.principalMinor = const Value.absent(),
    this.totalPeriods = const Value.absent(),
    this.borrowingDate = const Value.absent(),
    this.firstRepaymentDate = const Value.absent(),
    this.lastRepaymentDate = const Value.absent(),
    this.repaymentMethod = const Value.absent(),
    this.interestRatePeriod = const Value.absent(),
    this.interestRatePpm = const Value.absent(),
    this.interestAccrualMethod = const Value.absent(),
    this.totalFeeMinor = const Value.absent(),
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InstallmentContractsCompanion.insert({
    required String id,
    required String liabilityAccountId,
    required InstallmentSourceType sourceType,
    this.disbursementAccountId = const Value.absent(),
    this.disbursementTransactionId = const Value.absent(),
    this.sourceRepaymentId = const Value.absent(),
    required int principalMinor,
    required int totalPeriods,
    required DateTime borrowingDate,
    required DateTime firstRepaymentDate,
    required DateTime lastRepaymentDate,
    required InstallmentRepaymentMethod repaymentMethod,
    this.interestRatePeriod = const Value.absent(),
    this.interestRatePpm = const Value.absent(),
    this.interestAccrualMethod = const Value.absent(),
    this.totalFeeMinor = const Value.absent(),
    required InstallmentContractStatus status,
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       liabilityAccountId = Value(liabilityAccountId),
       sourceType = Value(sourceType),
       principalMinor = Value(principalMinor),
       totalPeriods = Value(totalPeriods),
       borrowingDate = Value(borrowingDate),
       firstRepaymentDate = Value(firstRepaymentDate),
       lastRepaymentDate = Value(lastRepaymentDate),
       repaymentMethod = Value(repaymentMethod),
       status = Value(status);
  static Insertable<InstallmentContractRow> custom({
    Expression<String>? id,
    Expression<String>? liabilityAccountId,
    Expression<String>? sourceType,
    Expression<String>? disbursementAccountId,
    Expression<String>? disbursementTransactionId,
    Expression<String>? sourceRepaymentId,
    Expression<int>? principalMinor,
    Expression<int>? totalPeriods,
    Expression<DateTime>? borrowingDate,
    Expression<DateTime>? firstRepaymentDate,
    Expression<DateTime>? lastRepaymentDate,
    Expression<String>? repaymentMethod,
    Expression<String>? interestRatePeriod,
    Expression<int>? interestRatePpm,
    Expression<String>? interestAccrualMethod,
    Expression<int>? totalFeeMinor,
    Expression<String>? status,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (liabilityAccountId != null)
        'liability_account_id': liabilityAccountId,
      if (sourceType != null) 'source_type': sourceType,
      if (disbursementAccountId != null)
        'disbursement_account_id': disbursementAccountId,
      if (disbursementTransactionId != null)
        'disbursement_transaction_id': disbursementTransactionId,
      if (sourceRepaymentId != null) 'source_repayment_id': sourceRepaymentId,
      if (principalMinor != null) 'principal_minor': principalMinor,
      if (totalPeriods != null) 'total_periods': totalPeriods,
      if (borrowingDate != null) 'start_date': borrowingDate,
      if (firstRepaymentDate != null)
        'first_repayment_date': firstRepaymentDate,
      if (lastRepaymentDate != null) 'last_repayment_date': lastRepaymentDate,
      if (repaymentMethod != null) 'repayment_method': repaymentMethod,
      if (interestRatePeriod != null)
        'interest_rate_period': interestRatePeriod,
      if (interestRatePpm != null) 'interest_rate_ppm': interestRatePpm,
      if (interestAccrualMethod != null)
        'interest_accrual_method': interestAccrualMethod,
      if (totalFeeMinor != null) 'total_fee_minor': totalFeeMinor,
      if (status != null) 'status': status,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InstallmentContractsCompanion copyWith({
    Value<String>? id,
    Value<String>? liabilityAccountId,
    Value<InstallmentSourceType>? sourceType,
    Value<String?>? disbursementAccountId,
    Value<String?>? disbursementTransactionId,
    Value<String?>? sourceRepaymentId,
    Value<int>? principalMinor,
    Value<int>? totalPeriods,
    Value<DateTime>? borrowingDate,
    Value<DateTime>? firstRepaymentDate,
    Value<DateTime>? lastRepaymentDate,
    Value<InstallmentRepaymentMethod>? repaymentMethod,
    Value<InterestRatePeriod?>? interestRatePeriod,
    Value<int?>? interestRatePpm,
    Value<InterestAccrualMethod>? interestAccrualMethod,
    Value<int>? totalFeeMinor,
    Value<InstallmentContractStatus>? status,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return InstallmentContractsCompanion(
      id: id ?? this.id,
      liabilityAccountId: liabilityAccountId ?? this.liabilityAccountId,
      sourceType: sourceType ?? this.sourceType,
      disbursementAccountId:
          disbursementAccountId ?? this.disbursementAccountId,
      disbursementTransactionId:
          disbursementTransactionId ?? this.disbursementTransactionId,
      sourceRepaymentId: sourceRepaymentId ?? this.sourceRepaymentId,
      principalMinor: principalMinor ?? this.principalMinor,
      totalPeriods: totalPeriods ?? this.totalPeriods,
      borrowingDate: borrowingDate ?? this.borrowingDate,
      firstRepaymentDate: firstRepaymentDate ?? this.firstRepaymentDate,
      lastRepaymentDate: lastRepaymentDate ?? this.lastRepaymentDate,
      repaymentMethod: repaymentMethod ?? this.repaymentMethod,
      interestRatePeriod: interestRatePeriod ?? this.interestRatePeriod,
      interestRatePpm: interestRatePpm ?? this.interestRatePpm,
      interestAccrualMethod:
          interestAccrualMethod ?? this.interestAccrualMethod,
      totalFeeMinor: totalFeeMinor ?? this.totalFeeMinor,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (liabilityAccountId.present) {
      map['liability_account_id'] = Variable<String>(liabilityAccountId.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(
        $InstallmentContractsTable.$convertersourceType.toSql(sourceType.value),
      );
    }
    if (disbursementAccountId.present) {
      map['disbursement_account_id'] = Variable<String>(
        disbursementAccountId.value,
      );
    }
    if (disbursementTransactionId.present) {
      map['disbursement_transaction_id'] = Variable<String>(
        disbursementTransactionId.value,
      );
    }
    if (sourceRepaymentId.present) {
      map['source_repayment_id'] = Variable<String>(sourceRepaymentId.value);
    }
    if (principalMinor.present) {
      map['principal_minor'] = Variable<int>(principalMinor.value);
    }
    if (totalPeriods.present) {
      map['total_periods'] = Variable<int>(totalPeriods.value);
    }
    if (borrowingDate.present) {
      map['start_date'] = Variable<DateTime>(borrowingDate.value);
    }
    if (firstRepaymentDate.present) {
      map['first_repayment_date'] = Variable<DateTime>(
        firstRepaymentDate.value,
      );
    }
    if (lastRepaymentDate.present) {
      map['last_repayment_date'] = Variable<DateTime>(lastRepaymentDate.value);
    }
    if (repaymentMethod.present) {
      map['repayment_method'] = Variable<String>(
        $InstallmentContractsTable.$converterrepaymentMethod.toSql(
          repaymentMethod.value,
        ),
      );
    }
    if (interestRatePeriod.present) {
      map['interest_rate_period'] = Variable<String>(
        $InstallmentContractsTable.$converterinterestRatePeriodn.toSql(
          interestRatePeriod.value,
        ),
      );
    }
    if (interestRatePpm.present) {
      map['interest_rate_ppm'] = Variable<int>(interestRatePpm.value);
    }
    if (interestAccrualMethod.present) {
      map['interest_accrual_method'] = Variable<String>(
        $InstallmentContractsTable.$converterinterestAccrualMethod.toSql(
          interestAccrualMethod.value,
        ),
      );
    }
    if (totalFeeMinor.present) {
      map['total_fee_minor'] = Variable<int>(totalFeeMinor.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $InstallmentContractsTable.$converterstatus.toSql(status.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstallmentContractsCompanion(')
          ..write('id: $id, ')
          ..write('liabilityAccountId: $liabilityAccountId, ')
          ..write('sourceType: $sourceType, ')
          ..write('disbursementAccountId: $disbursementAccountId, ')
          ..write('disbursementTransactionId: $disbursementTransactionId, ')
          ..write('sourceRepaymentId: $sourceRepaymentId, ')
          ..write('principalMinor: $principalMinor, ')
          ..write('totalPeriods: $totalPeriods, ')
          ..write('borrowingDate: $borrowingDate, ')
          ..write('firstRepaymentDate: $firstRepaymentDate, ')
          ..write('lastRepaymentDate: $lastRepaymentDate, ')
          ..write('repaymentMethod: $repaymentMethod, ')
          ..write('interestRatePeriod: $interestRatePeriod, ')
          ..write('interestRatePpm: $interestRatePpm, ')
          ..write('interestAccrualMethod: $interestAccrualMethod, ')
          ..write('totalFeeMinor: $totalFeeMinor, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InstallmentSchedulesTable extends InstallmentSchedules
    with TableInfo<$InstallmentSchedulesTable, InstallmentScheduleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstallmentSchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contractIdMeta = const VerificationMeta(
    'contractId',
  );
  @override
  late final GeneratedColumn<String> contractId = GeneratedColumn<String>(
    'contract_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodNoMeta = const VerificationMeta(
    'periodNo',
  );
  @override
  late final GeneratedColumn<int> periodNo = GeneratedColumn<int>(
    'period_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedRepaymentDateMeta =
      const VerificationMeta('expectedRepaymentDate');
  @override
  late final GeneratedColumn<DateTime> expectedRepaymentDate =
      GeneratedColumn<DateTime>(
        'expected_repayment_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _expectedPrincipalMinorMeta =
      const VerificationMeta('expectedPrincipalMinor');
  @override
  late final GeneratedColumn<int> expectedPrincipalMinor = GeneratedColumn<int>(
    'expected_principal_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _expectedInterestMinorMeta =
      const VerificationMeta('expectedInterestMinor');
  @override
  late final GeneratedColumn<int> expectedInterestMinor = GeneratedColumn<int>(
    'expected_interest_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _expectedFeeMinorMeta = const VerificationMeta(
    'expectedFeeMinor',
  );
  @override
  late final GeneratedColumn<int> expectedFeeMinor = GeneratedColumn<int>(
    'expected_fee_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<InstallmentScheduleStatus, String>
  status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<InstallmentScheduleStatus>(
    $InstallmentSchedulesTable.$converterstatus,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    contractId,
    periodNo,
    expectedRepaymentDate,
    expectedPrincipalMinor,
    expectedInterestMinor,
    expectedFeeMinor,
    status,
    note,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'installment_schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstallmentScheduleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('contract_id')) {
      context.handle(
        _contractIdMeta,
        contractId.isAcceptableOrUnknown(data['contract_id']!, _contractIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contractIdMeta);
    }
    if (data.containsKey('period_no')) {
      context.handle(
        _periodNoMeta,
        periodNo.isAcceptableOrUnknown(data['period_no']!, _periodNoMeta),
      );
    } else if (isInserting) {
      context.missing(_periodNoMeta);
    }
    if (data.containsKey('expected_repayment_date')) {
      context.handle(
        _expectedRepaymentDateMeta,
        expectedRepaymentDate.isAcceptableOrUnknown(
          data['expected_repayment_date']!,
          _expectedRepaymentDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expectedRepaymentDateMeta);
    }
    if (data.containsKey('expected_principal_minor')) {
      context.handle(
        _expectedPrincipalMinorMeta,
        expectedPrincipalMinor.isAcceptableOrUnknown(
          data['expected_principal_minor']!,
          _expectedPrincipalMinorMeta,
        ),
      );
    }
    if (data.containsKey('expected_interest_minor')) {
      context.handle(
        _expectedInterestMinorMeta,
        expectedInterestMinor.isAcceptableOrUnknown(
          data['expected_interest_minor']!,
          _expectedInterestMinorMeta,
        ),
      );
    }
    if (data.containsKey('expected_fee_minor')) {
      context.handle(
        _expectedFeeMinorMeta,
        expectedFeeMinor.isAcceptableOrUnknown(
          data['expected_fee_minor']!,
          _expectedFeeMinorMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InstallmentScheduleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstallmentScheduleRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      contractId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}contract_id'],
          )!,
      periodNo:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}period_no'],
          )!,
      expectedRepaymentDate:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}expected_repayment_date'],
          )!,
      expectedPrincipalMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}expected_principal_minor'],
          )!,
      expectedInterestMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}expected_interest_minor'],
          )!,
      expectedFeeMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}expected_fee_minor'],
          )!,
      status: $InstallmentSchedulesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $InstallmentSchedulesTable createAlias(String alias) {
    return $InstallmentSchedulesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<InstallmentScheduleStatus, String, String>
  $converterstatus = const EnumNameConverter<InstallmentScheduleStatus>(
    InstallmentScheduleStatus.values,
  );
}

class InstallmentScheduleRow extends DataClass
    implements Insertable<InstallmentScheduleRow> {
  final String id;
  final String contractId;
  final int periodNo;
  final DateTime expectedRepaymentDate;
  final int expectedPrincipalMinor;
  final int expectedInterestMinor;
  final int expectedFeeMinor;
  final InstallmentScheduleStatus status;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  const InstallmentScheduleRow({
    required this.id,
    required this.contractId,
    required this.periodNo,
    required this.expectedRepaymentDate,
    required this.expectedPrincipalMinor,
    required this.expectedInterestMinor,
    required this.expectedFeeMinor,
    required this.status,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['contract_id'] = Variable<String>(contractId);
    map['period_no'] = Variable<int>(periodNo);
    map['expected_repayment_date'] = Variable<DateTime>(expectedRepaymentDate);
    map['expected_principal_minor'] = Variable<int>(expectedPrincipalMinor);
    map['expected_interest_minor'] = Variable<int>(expectedInterestMinor);
    map['expected_fee_minor'] = Variable<int>(expectedFeeMinor);
    {
      map['status'] = Variable<String>(
        $InstallmentSchedulesTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  InstallmentSchedulesCompanion toCompanion(bool nullToAbsent) {
    return InstallmentSchedulesCompanion(
      id: Value(id),
      contractId: Value(contractId),
      periodNo: Value(periodNo),
      expectedRepaymentDate: Value(expectedRepaymentDate),
      expectedPrincipalMinor: Value(expectedPrincipalMinor),
      expectedInterestMinor: Value(expectedInterestMinor),
      expectedFeeMinor: Value(expectedFeeMinor),
      status: Value(status),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory InstallmentScheduleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstallmentScheduleRow(
      id: serializer.fromJson<String>(json['id']),
      contractId: serializer.fromJson<String>(json['contractId']),
      periodNo: serializer.fromJson<int>(json['periodNo']),
      expectedRepaymentDate: serializer.fromJson<DateTime>(
        json['expectedRepaymentDate'],
      ),
      expectedPrincipalMinor: serializer.fromJson<int>(
        json['expectedPrincipalMinor'],
      ),
      expectedInterestMinor: serializer.fromJson<int>(
        json['expectedInterestMinor'],
      ),
      expectedFeeMinor: serializer.fromJson<int>(json['expectedFeeMinor']),
      status: $InstallmentSchedulesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'contractId': serializer.toJson<String>(contractId),
      'periodNo': serializer.toJson<int>(periodNo),
      'expectedRepaymentDate': serializer.toJson<DateTime>(
        expectedRepaymentDate,
      ),
      'expectedPrincipalMinor': serializer.toJson<int>(expectedPrincipalMinor),
      'expectedInterestMinor': serializer.toJson<int>(expectedInterestMinor),
      'expectedFeeMinor': serializer.toJson<int>(expectedFeeMinor),
      'status': serializer.toJson<String>(
        $InstallmentSchedulesTable.$converterstatus.toJson(status),
      ),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  InstallmentScheduleRow copyWith({
    String? id,
    String? contractId,
    int? periodNo,
    DateTime? expectedRepaymentDate,
    int? expectedPrincipalMinor,
    int? expectedInterestMinor,
    int? expectedFeeMinor,
    InstallmentScheduleStatus? status,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => InstallmentScheduleRow(
    id: id ?? this.id,
    contractId: contractId ?? this.contractId,
    periodNo: periodNo ?? this.periodNo,
    expectedRepaymentDate: expectedRepaymentDate ?? this.expectedRepaymentDate,
    expectedPrincipalMinor:
        expectedPrincipalMinor ?? this.expectedPrincipalMinor,
    expectedInterestMinor: expectedInterestMinor ?? this.expectedInterestMinor,
    expectedFeeMinor: expectedFeeMinor ?? this.expectedFeeMinor,
    status: status ?? this.status,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  InstallmentScheduleRow copyWithCompanion(InstallmentSchedulesCompanion data) {
    return InstallmentScheduleRow(
      id: data.id.present ? data.id.value : this.id,
      contractId:
          data.contractId.present ? data.contractId.value : this.contractId,
      periodNo: data.periodNo.present ? data.periodNo.value : this.periodNo,
      expectedRepaymentDate:
          data.expectedRepaymentDate.present
              ? data.expectedRepaymentDate.value
              : this.expectedRepaymentDate,
      expectedPrincipalMinor:
          data.expectedPrincipalMinor.present
              ? data.expectedPrincipalMinor.value
              : this.expectedPrincipalMinor,
      expectedInterestMinor:
          data.expectedInterestMinor.present
              ? data.expectedInterestMinor.value
              : this.expectedInterestMinor,
      expectedFeeMinor:
          data.expectedFeeMinor.present
              ? data.expectedFeeMinor.value
              : this.expectedFeeMinor,
      status: data.status.present ? data.status.value : this.status,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstallmentScheduleRow(')
          ..write('id: $id, ')
          ..write('contractId: $contractId, ')
          ..write('periodNo: $periodNo, ')
          ..write('expectedRepaymentDate: $expectedRepaymentDate, ')
          ..write('expectedPrincipalMinor: $expectedPrincipalMinor, ')
          ..write('expectedInterestMinor: $expectedInterestMinor, ')
          ..write('expectedFeeMinor: $expectedFeeMinor, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    contractId,
    periodNo,
    expectedRepaymentDate,
    expectedPrincipalMinor,
    expectedInterestMinor,
    expectedFeeMinor,
    status,
    note,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstallmentScheduleRow &&
          other.id == this.id &&
          other.contractId == this.contractId &&
          other.periodNo == this.periodNo &&
          other.expectedRepaymentDate == this.expectedRepaymentDate &&
          other.expectedPrincipalMinor == this.expectedPrincipalMinor &&
          other.expectedInterestMinor == this.expectedInterestMinor &&
          other.expectedFeeMinor == this.expectedFeeMinor &&
          other.status == this.status &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class InstallmentSchedulesCompanion
    extends UpdateCompanion<InstallmentScheduleRow> {
  final Value<String> id;
  final Value<String> contractId;
  final Value<int> periodNo;
  final Value<DateTime> expectedRepaymentDate;
  final Value<int> expectedPrincipalMinor;
  final Value<int> expectedInterestMinor;
  final Value<int> expectedFeeMinor;
  final Value<InstallmentScheduleStatus> status;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const InstallmentSchedulesCompanion({
    this.id = const Value.absent(),
    this.contractId = const Value.absent(),
    this.periodNo = const Value.absent(),
    this.expectedRepaymentDate = const Value.absent(),
    this.expectedPrincipalMinor = const Value.absent(),
    this.expectedInterestMinor = const Value.absent(),
    this.expectedFeeMinor = const Value.absent(),
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InstallmentSchedulesCompanion.insert({
    required String id,
    required String contractId,
    required int periodNo,
    required DateTime expectedRepaymentDate,
    this.expectedPrincipalMinor = const Value.absent(),
    this.expectedInterestMinor = const Value.absent(),
    this.expectedFeeMinor = const Value.absent(),
    required InstallmentScheduleStatus status,
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       contractId = Value(contractId),
       periodNo = Value(periodNo),
       expectedRepaymentDate = Value(expectedRepaymentDate),
       status = Value(status);
  static Insertable<InstallmentScheduleRow> custom({
    Expression<String>? id,
    Expression<String>? contractId,
    Expression<int>? periodNo,
    Expression<DateTime>? expectedRepaymentDate,
    Expression<int>? expectedPrincipalMinor,
    Expression<int>? expectedInterestMinor,
    Expression<int>? expectedFeeMinor,
    Expression<String>? status,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (contractId != null) 'contract_id': contractId,
      if (periodNo != null) 'period_no': periodNo,
      if (expectedRepaymentDate != null)
        'expected_repayment_date': expectedRepaymentDate,
      if (expectedPrincipalMinor != null)
        'expected_principal_minor': expectedPrincipalMinor,
      if (expectedInterestMinor != null)
        'expected_interest_minor': expectedInterestMinor,
      if (expectedFeeMinor != null) 'expected_fee_minor': expectedFeeMinor,
      if (status != null) 'status': status,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InstallmentSchedulesCompanion copyWith({
    Value<String>? id,
    Value<String>? contractId,
    Value<int>? periodNo,
    Value<DateTime>? expectedRepaymentDate,
    Value<int>? expectedPrincipalMinor,
    Value<int>? expectedInterestMinor,
    Value<int>? expectedFeeMinor,
    Value<InstallmentScheduleStatus>? status,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return InstallmentSchedulesCompanion(
      id: id ?? this.id,
      contractId: contractId ?? this.contractId,
      periodNo: periodNo ?? this.periodNo,
      expectedRepaymentDate:
          expectedRepaymentDate ?? this.expectedRepaymentDate,
      expectedPrincipalMinor:
          expectedPrincipalMinor ?? this.expectedPrincipalMinor,
      expectedInterestMinor:
          expectedInterestMinor ?? this.expectedInterestMinor,
      expectedFeeMinor: expectedFeeMinor ?? this.expectedFeeMinor,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (contractId.present) {
      map['contract_id'] = Variable<String>(contractId.value);
    }
    if (periodNo.present) {
      map['period_no'] = Variable<int>(periodNo.value);
    }
    if (expectedRepaymentDate.present) {
      map['expected_repayment_date'] = Variable<DateTime>(
        expectedRepaymentDate.value,
      );
    }
    if (expectedPrincipalMinor.present) {
      map['expected_principal_minor'] = Variable<int>(
        expectedPrincipalMinor.value,
      );
    }
    if (expectedInterestMinor.present) {
      map['expected_interest_minor'] = Variable<int>(
        expectedInterestMinor.value,
      );
    }
    if (expectedFeeMinor.present) {
      map['expected_fee_minor'] = Variable<int>(expectedFeeMinor.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $InstallmentSchedulesTable.$converterstatus.toSql(status.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstallmentSchedulesCompanion(')
          ..write('id: $id, ')
          ..write('contractId: $contractId, ')
          ..write('periodNo: $periodNo, ')
          ..write('expectedRepaymentDate: $expectedRepaymentDate, ')
          ..write('expectedPrincipalMinor: $expectedPrincipalMinor, ')
          ..write('expectedInterestMinor: $expectedInterestMinor, ')
          ..write('expectedFeeMinor: $expectedFeeMinor, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RepaymentsTable extends Repayments
    with TableInfo<$RepaymentsTable, RepaymentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repaymentTypeMeta = const VerificationMeta(
    'repaymentType',
  );
  @override
  late final GeneratedColumn<String> repaymentType = GeneratedColumn<String>(
    'repayment_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTypeMeta = const VerificationMeta(
    'targetType',
  );
  @override
  late final GeneratedColumn<String> targetType = GeneratedColumn<String>(
    'target_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootTransactionIdMeta = const VerificationMeta(
    'rootTransactionId',
  );
  @override
  late final GeneratedColumn<String> rootTransactionId =
      GeneratedColumn<String>(
        'root_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repaymentType,
    targetType,
    targetId,
    rootTransactionId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'repayments';
  @override
  VerificationContext validateIntegrity(
    Insertable<RepaymentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('repayment_type')) {
      context.handle(
        _repaymentTypeMeta,
        repaymentType.isAcceptableOrUnknown(
          data['repayment_type']!,
          _repaymentTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repaymentTypeMeta);
    }
    if (data.containsKey('target_type')) {
      context.handle(
        _targetTypeMeta,
        targetType.isAcceptableOrUnknown(data['target_type']!, _targetTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_targetTypeMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('root_transaction_id')) {
      context.handle(
        _rootTransactionIdMeta,
        rootTransactionId.isAcceptableOrUnknown(
          data['root_transaction_id']!,
          _rootTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RepaymentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RepaymentRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      repaymentType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}repayment_type'],
          )!,
      targetType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}target_type'],
          )!,
      targetId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}target_id'],
          )!,
      rootTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_transaction_id'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $RepaymentsTable createAlias(String alias) {
    return $RepaymentsTable(attachedDatabase, alias);
  }
}

class RepaymentRow extends DataClass implements Insertable<RepaymentRow> {
  final String id;
  final String repaymentType;
  final String targetType;
  final String targetId;
  final String? rootTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const RepaymentRow({
    required this.id,
    required this.repaymentType,
    required this.targetType,
    required this.targetId,
    this.rootTransactionId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['repayment_type'] = Variable<String>(repaymentType);
    map['target_type'] = Variable<String>(targetType);
    map['target_id'] = Variable<String>(targetId);
    if (!nullToAbsent || rootTransactionId != null) {
      map['root_transaction_id'] = Variable<String>(rootTransactionId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RepaymentsCompanion toCompanion(bool nullToAbsent) {
    return RepaymentsCompanion(
      id: Value(id),
      repaymentType: Value(repaymentType),
      targetType: Value(targetType),
      targetId: Value(targetId),
      rootTransactionId:
          rootTransactionId == null && nullToAbsent
              ? const Value.absent()
              : Value(rootTransactionId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RepaymentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RepaymentRow(
      id: serializer.fromJson<String>(json['id']),
      repaymentType: serializer.fromJson<String>(json['repaymentType']),
      targetType: serializer.fromJson<String>(json['targetType']),
      targetId: serializer.fromJson<String>(json['targetId']),
      rootTransactionId: serializer.fromJson<String?>(
        json['rootTransactionId'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'repaymentType': serializer.toJson<String>(repaymentType),
      'targetType': serializer.toJson<String>(targetType),
      'targetId': serializer.toJson<String>(targetId),
      'rootTransactionId': serializer.toJson<String?>(rootTransactionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RepaymentRow copyWith({
    String? id,
    String? repaymentType,
    String? targetType,
    String? targetId,
    Value<String?> rootTransactionId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RepaymentRow(
    id: id ?? this.id,
    repaymentType: repaymentType ?? this.repaymentType,
    targetType: targetType ?? this.targetType,
    targetId: targetId ?? this.targetId,
    rootTransactionId:
        rootTransactionId.present
            ? rootTransactionId.value
            : this.rootTransactionId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RepaymentRow copyWithCompanion(RepaymentsCompanion data) {
    return RepaymentRow(
      id: data.id.present ? data.id.value : this.id,
      repaymentType:
          data.repaymentType.present
              ? data.repaymentType.value
              : this.repaymentType,
      targetType:
          data.targetType.present ? data.targetType.value : this.targetType,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      rootTransactionId:
          data.rootTransactionId.present
              ? data.rootTransactionId.value
              : this.rootTransactionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RepaymentRow(')
          ..write('id: $id, ')
          ..write('repaymentType: $repaymentType, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('rootTransactionId: $rootTransactionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    repaymentType,
    targetType,
    targetId,
    rootTransactionId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepaymentRow &&
          other.id == this.id &&
          other.repaymentType == this.repaymentType &&
          other.targetType == this.targetType &&
          other.targetId == this.targetId &&
          other.rootTransactionId == this.rootTransactionId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RepaymentsCompanion extends UpdateCompanion<RepaymentRow> {
  final Value<String> id;
  final Value<String> repaymentType;
  final Value<String> targetType;
  final Value<String> targetId;
  final Value<String?> rootTransactionId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RepaymentsCompanion({
    this.id = const Value.absent(),
    this.repaymentType = const Value.absent(),
    this.targetType = const Value.absent(),
    this.targetId = const Value.absent(),
    this.rootTransactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RepaymentsCompanion.insert({
    required String id,
    required String repaymentType,
    required String targetType,
    required String targetId,
    this.rootTransactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       repaymentType = Value(repaymentType),
       targetType = Value(targetType),
       targetId = Value(targetId);
  static Insertable<RepaymentRow> custom({
    Expression<String>? id,
    Expression<String>? repaymentType,
    Expression<String>? targetType,
    Expression<String>? targetId,
    Expression<String>? rootTransactionId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repaymentType != null) 'repayment_type': repaymentType,
      if (targetType != null) 'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      if (rootTransactionId != null) 'root_transaction_id': rootTransactionId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RepaymentsCompanion copyWith({
    Value<String>? id,
    Value<String>? repaymentType,
    Value<String>? targetType,
    Value<String>? targetId,
    Value<String?>? rootTransactionId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RepaymentsCompanion(
      id: id ?? this.id,
      repaymentType: repaymentType ?? this.repaymentType,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      rootTransactionId: rootTransactionId ?? this.rootTransactionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (repaymentType.present) {
      map['repayment_type'] = Variable<String>(repaymentType.value);
    }
    if (targetType.present) {
      map['target_type'] = Variable<String>(targetType.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (rootTransactionId.present) {
      map['root_transaction_id'] = Variable<String>(rootTransactionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepaymentsCompanion(')
          ..write('id: $id, ')
          ..write('repaymentType: $repaymentType, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('rootTransactionId: $rootTransactionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RepaymentItemsTable extends RepaymentItems
    with TableInfo<$RepaymentItemsTable, RepaymentItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepaymentItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repaymentIdMeta = const VerificationMeta(
    'repaymentId',
  );
  @override
  late final GeneratedColumn<String> repaymentId = GeneratedColumn<String>(
    'repayment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _billItemIdMeta = const VerificationMeta(
    'billItemId',
  );
  @override
  late final GeneratedColumn<String> billItemId = GeneratedColumn<String>(
    'bill_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allocatedPrincipalMinorMeta =
      const VerificationMeta('allocatedPrincipalMinor');
  @override
  late final GeneratedColumn<int> allocatedPrincipalMinor =
      GeneratedColumn<int>(
        'allocated_principal_minor',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _allocatedInterestMinorMeta =
      const VerificationMeta('allocatedInterestMinor');
  @override
  late final GeneratedColumn<int> allocatedInterestMinor = GeneratedColumn<int>(
    'allocated_interest_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _allocatedFeeMinorMeta = const VerificationMeta(
    'allocatedFeeMinor',
  );
  @override
  late final GeneratedColumn<int> allocatedFeeMinor = GeneratedColumn<int>(
    'allocated_fee_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _allocatedDiscountMinorMeta =
      const VerificationMeta('allocatedDiscountMinor');
  @override
  late final GeneratedColumn<int> allocatedDiscountMinor = GeneratedColumn<int>(
    'allocated_discount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repaymentId,
    billItemId,
    allocatedPrincipalMinor,
    allocatedInterestMinor,
    allocatedFeeMinor,
    allocatedDiscountMinor,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'repayment_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<RepaymentItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('repayment_id')) {
      context.handle(
        _repaymentIdMeta,
        repaymentId.isAcceptableOrUnknown(
          data['repayment_id']!,
          _repaymentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repaymentIdMeta);
    }
    if (data.containsKey('bill_item_id')) {
      context.handle(
        _billItemIdMeta,
        billItemId.isAcceptableOrUnknown(
          data['bill_item_id']!,
          _billItemIdMeta,
        ),
      );
    }
    if (data.containsKey('allocated_principal_minor')) {
      context.handle(
        _allocatedPrincipalMinorMeta,
        allocatedPrincipalMinor.isAcceptableOrUnknown(
          data['allocated_principal_minor']!,
          _allocatedPrincipalMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_allocatedPrincipalMinorMeta);
    }
    if (data.containsKey('allocated_interest_minor')) {
      context.handle(
        _allocatedInterestMinorMeta,
        allocatedInterestMinor.isAcceptableOrUnknown(
          data['allocated_interest_minor']!,
          _allocatedInterestMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_allocatedInterestMinorMeta);
    }
    if (data.containsKey('allocated_fee_minor')) {
      context.handle(
        _allocatedFeeMinorMeta,
        allocatedFeeMinor.isAcceptableOrUnknown(
          data['allocated_fee_minor']!,
          _allocatedFeeMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_allocatedFeeMinorMeta);
    }
    if (data.containsKey('allocated_discount_minor')) {
      context.handle(
        _allocatedDiscountMinorMeta,
        allocatedDiscountMinor.isAcceptableOrUnknown(
          data['allocated_discount_minor']!,
          _allocatedDiscountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_allocatedDiscountMinorMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RepaymentItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RepaymentItemRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      repaymentId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}repayment_id'],
          )!,
      billItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bill_item_id'],
      ),
      allocatedPrincipalMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}allocated_principal_minor'],
          )!,
      allocatedInterestMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}allocated_interest_minor'],
          )!,
      allocatedFeeMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}allocated_fee_minor'],
          )!,
      allocatedDiscountMinor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}allocated_discount_minor'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $RepaymentItemsTable createAlias(String alias) {
    return $RepaymentItemsTable(attachedDatabase, alias);
  }
}

class RepaymentItemRow extends DataClass
    implements Insertable<RepaymentItemRow> {
  final String id;
  final String repaymentId;
  final String? billItemId;
  final int allocatedPrincipalMinor;
  final int allocatedInterestMinor;
  final int allocatedFeeMinor;
  final int allocatedDiscountMinor;
  final DateTime createdAt;
  final DateTime updatedAt;
  const RepaymentItemRow({
    required this.id,
    required this.repaymentId,
    this.billItemId,
    required this.allocatedPrincipalMinor,
    required this.allocatedInterestMinor,
    required this.allocatedFeeMinor,
    required this.allocatedDiscountMinor,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['repayment_id'] = Variable<String>(repaymentId);
    if (!nullToAbsent || billItemId != null) {
      map['bill_item_id'] = Variable<String>(billItemId);
    }
    map['allocated_principal_minor'] = Variable<int>(allocatedPrincipalMinor);
    map['allocated_interest_minor'] = Variable<int>(allocatedInterestMinor);
    map['allocated_fee_minor'] = Variable<int>(allocatedFeeMinor);
    map['allocated_discount_minor'] = Variable<int>(allocatedDiscountMinor);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RepaymentItemsCompanion toCompanion(bool nullToAbsent) {
    return RepaymentItemsCompanion(
      id: Value(id),
      repaymentId: Value(repaymentId),
      billItemId:
          billItemId == null && nullToAbsent
              ? const Value.absent()
              : Value(billItemId),
      allocatedPrincipalMinor: Value(allocatedPrincipalMinor),
      allocatedInterestMinor: Value(allocatedInterestMinor),
      allocatedFeeMinor: Value(allocatedFeeMinor),
      allocatedDiscountMinor: Value(allocatedDiscountMinor),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RepaymentItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RepaymentItemRow(
      id: serializer.fromJson<String>(json['id']),
      repaymentId: serializer.fromJson<String>(json['repaymentId']),
      billItemId: serializer.fromJson<String?>(json['billItemId']),
      allocatedPrincipalMinor: serializer.fromJson<int>(
        json['allocatedPrincipalMinor'],
      ),
      allocatedInterestMinor: serializer.fromJson<int>(
        json['allocatedInterestMinor'],
      ),
      allocatedFeeMinor: serializer.fromJson<int>(json['allocatedFeeMinor']),
      allocatedDiscountMinor: serializer.fromJson<int>(
        json['allocatedDiscountMinor'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'repaymentId': serializer.toJson<String>(repaymentId),
      'billItemId': serializer.toJson<String?>(billItemId),
      'allocatedPrincipalMinor': serializer.toJson<int>(
        allocatedPrincipalMinor,
      ),
      'allocatedInterestMinor': serializer.toJson<int>(allocatedInterestMinor),
      'allocatedFeeMinor': serializer.toJson<int>(allocatedFeeMinor),
      'allocatedDiscountMinor': serializer.toJson<int>(allocatedDiscountMinor),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RepaymentItemRow copyWith({
    String? id,
    String? repaymentId,
    Value<String?> billItemId = const Value.absent(),
    int? allocatedPrincipalMinor,
    int? allocatedInterestMinor,
    int? allocatedFeeMinor,
    int? allocatedDiscountMinor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RepaymentItemRow(
    id: id ?? this.id,
    repaymentId: repaymentId ?? this.repaymentId,
    billItemId: billItemId.present ? billItemId.value : this.billItemId,
    allocatedPrincipalMinor:
        allocatedPrincipalMinor ?? this.allocatedPrincipalMinor,
    allocatedInterestMinor:
        allocatedInterestMinor ?? this.allocatedInterestMinor,
    allocatedFeeMinor: allocatedFeeMinor ?? this.allocatedFeeMinor,
    allocatedDiscountMinor:
        allocatedDiscountMinor ?? this.allocatedDiscountMinor,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RepaymentItemRow copyWithCompanion(RepaymentItemsCompanion data) {
    return RepaymentItemRow(
      id: data.id.present ? data.id.value : this.id,
      repaymentId:
          data.repaymentId.present ? data.repaymentId.value : this.repaymentId,
      billItemId:
          data.billItemId.present ? data.billItemId.value : this.billItemId,
      allocatedPrincipalMinor:
          data.allocatedPrincipalMinor.present
              ? data.allocatedPrincipalMinor.value
              : this.allocatedPrincipalMinor,
      allocatedInterestMinor:
          data.allocatedInterestMinor.present
              ? data.allocatedInterestMinor.value
              : this.allocatedInterestMinor,
      allocatedFeeMinor:
          data.allocatedFeeMinor.present
              ? data.allocatedFeeMinor.value
              : this.allocatedFeeMinor,
      allocatedDiscountMinor:
          data.allocatedDiscountMinor.present
              ? data.allocatedDiscountMinor.value
              : this.allocatedDiscountMinor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RepaymentItemRow(')
          ..write('id: $id, ')
          ..write('repaymentId: $repaymentId, ')
          ..write('billItemId: $billItemId, ')
          ..write('allocatedPrincipalMinor: $allocatedPrincipalMinor, ')
          ..write('allocatedInterestMinor: $allocatedInterestMinor, ')
          ..write('allocatedFeeMinor: $allocatedFeeMinor, ')
          ..write('allocatedDiscountMinor: $allocatedDiscountMinor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    repaymentId,
    billItemId,
    allocatedPrincipalMinor,
    allocatedInterestMinor,
    allocatedFeeMinor,
    allocatedDiscountMinor,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepaymentItemRow &&
          other.id == this.id &&
          other.repaymentId == this.repaymentId &&
          other.billItemId == this.billItemId &&
          other.allocatedPrincipalMinor == this.allocatedPrincipalMinor &&
          other.allocatedInterestMinor == this.allocatedInterestMinor &&
          other.allocatedFeeMinor == this.allocatedFeeMinor &&
          other.allocatedDiscountMinor == this.allocatedDiscountMinor &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RepaymentItemsCompanion extends UpdateCompanion<RepaymentItemRow> {
  final Value<String> id;
  final Value<String> repaymentId;
  final Value<String?> billItemId;
  final Value<int> allocatedPrincipalMinor;
  final Value<int> allocatedInterestMinor;
  final Value<int> allocatedFeeMinor;
  final Value<int> allocatedDiscountMinor;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RepaymentItemsCompanion({
    this.id = const Value.absent(),
    this.repaymentId = const Value.absent(),
    this.billItemId = const Value.absent(),
    this.allocatedPrincipalMinor = const Value.absent(),
    this.allocatedInterestMinor = const Value.absent(),
    this.allocatedFeeMinor = const Value.absent(),
    this.allocatedDiscountMinor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RepaymentItemsCompanion.insert({
    required String id,
    required String repaymentId,
    this.billItemId = const Value.absent(),
    required int allocatedPrincipalMinor,
    required int allocatedInterestMinor,
    required int allocatedFeeMinor,
    required int allocatedDiscountMinor,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       repaymentId = Value(repaymentId),
       allocatedPrincipalMinor = Value(allocatedPrincipalMinor),
       allocatedInterestMinor = Value(allocatedInterestMinor),
       allocatedFeeMinor = Value(allocatedFeeMinor),
       allocatedDiscountMinor = Value(allocatedDiscountMinor);
  static Insertable<RepaymentItemRow> custom({
    Expression<String>? id,
    Expression<String>? repaymentId,
    Expression<String>? billItemId,
    Expression<int>? allocatedPrincipalMinor,
    Expression<int>? allocatedInterestMinor,
    Expression<int>? allocatedFeeMinor,
    Expression<int>? allocatedDiscountMinor,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repaymentId != null) 'repayment_id': repaymentId,
      if (billItemId != null) 'bill_item_id': billItemId,
      if (allocatedPrincipalMinor != null)
        'allocated_principal_minor': allocatedPrincipalMinor,
      if (allocatedInterestMinor != null)
        'allocated_interest_minor': allocatedInterestMinor,
      if (allocatedFeeMinor != null) 'allocated_fee_minor': allocatedFeeMinor,
      if (allocatedDiscountMinor != null)
        'allocated_discount_minor': allocatedDiscountMinor,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RepaymentItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? repaymentId,
    Value<String?>? billItemId,
    Value<int>? allocatedPrincipalMinor,
    Value<int>? allocatedInterestMinor,
    Value<int>? allocatedFeeMinor,
    Value<int>? allocatedDiscountMinor,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RepaymentItemsCompanion(
      id: id ?? this.id,
      repaymentId: repaymentId ?? this.repaymentId,
      billItemId: billItemId ?? this.billItemId,
      allocatedPrincipalMinor:
          allocatedPrincipalMinor ?? this.allocatedPrincipalMinor,
      allocatedInterestMinor:
          allocatedInterestMinor ?? this.allocatedInterestMinor,
      allocatedFeeMinor: allocatedFeeMinor ?? this.allocatedFeeMinor,
      allocatedDiscountMinor:
          allocatedDiscountMinor ?? this.allocatedDiscountMinor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (repaymentId.present) {
      map['repayment_id'] = Variable<String>(repaymentId.value);
    }
    if (billItemId.present) {
      map['bill_item_id'] = Variable<String>(billItemId.value);
    }
    if (allocatedPrincipalMinor.present) {
      map['allocated_principal_minor'] = Variable<int>(
        allocatedPrincipalMinor.value,
      );
    }
    if (allocatedInterestMinor.present) {
      map['allocated_interest_minor'] = Variable<int>(
        allocatedInterestMinor.value,
      );
    }
    if (allocatedFeeMinor.present) {
      map['allocated_fee_minor'] = Variable<int>(allocatedFeeMinor.value);
    }
    if (allocatedDiscountMinor.present) {
      map['allocated_discount_minor'] = Variable<int>(
        allocatedDiscountMinor.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepaymentItemsCompanion(')
          ..write('id: $id, ')
          ..write('repaymentId: $repaymentId, ')
          ..write('billItemId: $billItemId, ')
          ..write('allocatedPrincipalMinor: $allocatedPrincipalMinor, ')
          ..write('allocatedInterestMinor: $allocatedInterestMinor, ')
          ..write('allocatedFeeMinor: $allocatedFeeMinor, ')
          ..write('allocatedDiscountMinor: $allocatedDiscountMinor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $AppMetadataTable appMetadata = $AppMetadataTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $TransactionDetailsTable transactionDetails =
      $TransactionDetailsTable(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $CreditLiabilityAccountsTable creditLiabilityAccounts =
      $CreditLiabilityAccountsTable(this);
  late final $BillsTable bills = $BillsTable(this);
  late final $BillItemsTable billItems = $BillItemsTable(this);
  late final $InstallmentContractsTable installmentContracts =
      $InstallmentContractsTable(this);
  late final $InstallmentSchedulesTable installmentSchedules =
      $InstallmentSchedulesTable(this);
  late final $RepaymentsTable repayments = $RepaymentsTable(this);
  late final $RepaymentItemsTable repaymentItems = $RepaymentItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    appMetadata,
    transactions,
    transactionDetails,
    entries,
    budgets,
    creditLiabilityAccounts,
    bills,
    billItems,
    installmentContracts,
    installmentSchedules,
    repayments,
    repaymentItems,
  ];
}

typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      required String id,
      required String name,
      required AccountType accountType,
      Value<AccountSubtype?> accountSubtype,
      Value<String?> accountProfileKey,
      Value<String?> parentId,
      Value<int> balanceMinor,
      Value<String?> iconKey,
      Value<String?> note,
      Value<int?> creditLimitMinor,
      Value<int?> billingDay,
      Value<int?> repaymentDay,
      Value<int> sortOrder,
      Value<bool> isHidden,
      Value<DateTime?> archivedAt,
      Value<SystemKey?> systemKey,
      Value<AccountSource> source,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<AccountType> accountType,
      Value<AccountSubtype?> accountSubtype,
      Value<String?> accountProfileKey,
      Value<String?> parentId,
      Value<int> balanceMinor,
      Value<String?> iconKey,
      Value<String?> note,
      Value<int?> creditLimitMinor,
      Value<int?> billingDay,
      Value<int?> repaymentDay,
      Value<int> sortOrder,
      Value<bool> isHidden,
      Value<DateTime?> archivedAt,
      Value<SystemKey?> systemKey,
      Value<AccountSource> source,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AccountType, AccountType, String>
  get accountType => $composableBuilder(
    column: $table.accountType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<AccountSubtype?, AccountSubtype, String>
  get accountSubtype => $composableBuilder(
    column: $table.accountSubtype,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get accountProfileKey => $composableBuilder(
    column: $table.accountProfileKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get balanceMinor => $composableBuilder(
    column: $table.balanceMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creditLimitMinor => $composableBuilder(
    column: $table.creditLimitMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get billingDay => $composableBuilder(
    column: $table.billingDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repaymentDay => $composableBuilder(
    column: $table.repaymentDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SystemKey?, SystemKey, String> get systemKey =>
      $composableBuilder(
        column: $table.systemKey,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<AccountSource, AccountSource, String>
  get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountType => $composableBuilder(
    column: $table.accountType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountSubtype => $composableBuilder(
    column: $table.accountSubtype,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountProfileKey => $composableBuilder(
    column: $table.accountProfileKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get balanceMinor => $composableBuilder(
    column: $table.balanceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditLimitMinor => $composableBuilder(
    column: $table.creditLimitMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get billingDay => $composableBuilder(
    column: $table.billingDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repaymentDay => $composableBuilder(
    column: $table.repaymentDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get systemKey => $composableBuilder(
    column: $table.systemKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountType, String> get accountType =>
      $composableBuilder(
        column: $table.accountType,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<AccountSubtype?, String>
  get accountSubtype => $composableBuilder(
    column: $table.accountSubtype,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountProfileKey => $composableBuilder(
    column: $table.accountProfileKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get balanceMinor => $composableBuilder(
    column: $table.balanceMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get creditLimitMinor => $composableBuilder(
    column: $table.creditLimitMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get billingDay => $composableBuilder(
    column: $table.billingDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repaymentDay => $composableBuilder(
    column: $table.repaymentDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isHidden =>
      $composableBuilder(column: $table.isHidden, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SystemKey?, String> get systemKey =>
      $composableBuilder(column: $table.systemKey, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          AccountRow,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (
            AccountRow,
            BaseReferences<_$AppDatabase, $AccountsTable, AccountRow>,
          ),
          AccountRow,
          PrefetchHooks Function()
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<AccountType> accountType = const Value.absent(),
                Value<AccountSubtype?> accountSubtype = const Value.absent(),
                Value<String?> accountProfileKey = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> balanceMinor = const Value.absent(),
                Value<String?> iconKey = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> creditLimitMinor = const Value.absent(),
                Value<int?> billingDay = const Value.absent(),
                Value<int?> repaymentDay = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<SystemKey?> systemKey = const Value.absent(),
                Value<AccountSource> source = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                name: name,
                accountType: accountType,
                accountSubtype: accountSubtype,
                accountProfileKey: accountProfileKey,
                parentId: parentId,
                balanceMinor: balanceMinor,
                iconKey: iconKey,
                note: note,
                creditLimitMinor: creditLimitMinor,
                billingDay: billingDay,
                repaymentDay: repaymentDay,
                sortOrder: sortOrder,
                isHidden: isHidden,
                archivedAt: archivedAt,
                systemKey: systemKey,
                source: source,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required AccountType accountType,
                Value<AccountSubtype?> accountSubtype = const Value.absent(),
                Value<String?> accountProfileKey = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> balanceMinor = const Value.absent(),
                Value<String?> iconKey = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> creditLimitMinor = const Value.absent(),
                Value<int?> billingDay = const Value.absent(),
                Value<int?> repaymentDay = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<SystemKey?> systemKey = const Value.absent(),
                Value<AccountSource> source = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                name: name,
                accountType: accountType,
                accountSubtype: accountSubtype,
                accountProfileKey: accountProfileKey,
                parentId: parentId,
                balanceMinor: balanceMinor,
                iconKey: iconKey,
                note: note,
                creditLimitMinor: creditLimitMinor,
                billingDay: billingDay,
                repaymentDay: repaymentDay,
                sortOrder: sortOrder,
                isHidden: isHidden,
                archivedAt: archivedAt,
                systemKey: systemKey,
                source: source,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      AccountRow,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (AccountRow, BaseReferences<_$AppDatabase, $AccountsTable, AccountRow>),
      AccountRow,
      PrefetchHooks Function()
    >;
typedef $$AppMetadataTableCreateCompanionBuilder =
    AppMetadataCompanion Function({
      required String key,
      required String value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$AppMetadataTableUpdateCompanionBuilder =
    AppMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $AppMetadataTable> {
  $$AppMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $AppMetadataTable> {
  $$AppMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppMetadataTable> {
  $$AppMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppMetadataTable,
          AppMetadataRow,
          $$AppMetadataTableFilterComposer,
          $$AppMetadataTableOrderingComposer,
          $$AppMetadataTableAnnotationComposer,
          $$AppMetadataTableCreateCompanionBuilder,
          $$AppMetadataTableUpdateCompanionBuilder,
          (
            AppMetadataRow,
            BaseReferences<_$AppDatabase, $AppMetadataTable, AppMetadataRow>,
          ),
          AppMetadataRow,
          PrefetchHooks Function()
        > {
  $$AppMetadataTableTableManager(_$AppDatabase db, $AppMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$AppMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$AppMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$AppMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppMetadataCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppMetadataCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppMetadataTable,
      AppMetadataRow,
      $$AppMetadataTableFilterComposer,
      $$AppMetadataTableOrderingComposer,
      $$AppMetadataTableAnnotationComposer,
      $$AppMetadataTableCreateCompanionBuilder,
      $$AppMetadataTableUpdateCompanionBuilder,
      (
        AppMetadataRow,
        BaseReferences<_$AppDatabase, $AppMetadataTable, AppMetadataRow>,
      ),
      AppMetadataRow,
      PrefetchHooks Function()
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      required String id,
      Value<String?> rootTransactionId,
      required BusinessPurpose businessPurpose,
      required DateTime occurredAt,
      required int primaryAmountMinor,
      Value<String?> counterpartyName,
      Value<String?> note,
      Value<String?> parentTransactionId,
      Value<String?> reimbursementExpenseAccountId,
      required MutationKind mutationKind,
      Value<String?> mutationPreviousTransactionId,
      Value<MutationReason?> mutationReason,
      required BusinessState businessState,
      Value<bool> isExcludedFromStats,
      Value<bool> isExcludedFromBudget,
      required SourceKind sourceKind,
      Value<String?> ownerType,
      Value<String?> ownerId,
      Value<String?> ownerRole,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<String?> rootTransactionId,
      Value<BusinessPurpose> businessPurpose,
      Value<DateTime> occurredAt,
      Value<int> primaryAmountMinor,
      Value<String?> counterpartyName,
      Value<String?> note,
      Value<String?> parentTransactionId,
      Value<String?> reimbursementExpenseAccountId,
      Value<MutationKind> mutationKind,
      Value<String?> mutationPreviousTransactionId,
      Value<MutationReason?> mutationReason,
      Value<BusinessState> businessState,
      Value<bool> isExcludedFromStats,
      Value<bool> isExcludedFromBudget,
      Value<SourceKind> sourceKind,
      Value<String?> ownerType,
      Value<String?> ownerId,
      Value<String?> ownerRole,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootTransactionId => $composableBuilder(
    column: $table.rootTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BusinessPurpose, BusinessPurpose, String>
  get businessPurpose => $composableBuilder(
    column: $table.businessPurpose,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get primaryAmountMinor => $composableBuilder(
    column: $table.primaryAmountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counterpartyName => $composableBuilder(
    column: $table.counterpartyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentTransactionId => $composableBuilder(
    column: $table.parentTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reimbursementExpenseAccountId => $composableBuilder(
    column: $table.reimbursementExpenseAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MutationKind, MutationKind, String>
  get mutationKind => $composableBuilder(
    column: $table.mutationKind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get mutationPreviousTransactionId => $composableBuilder(
    column: $table.mutationPreviousTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MutationReason?, MutationReason, String>
  get mutationReason => $composableBuilder(
    column: $table.mutationReason,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<BusinessState, BusinessState, String>
  get businessState => $composableBuilder(
    column: $table.businessState,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get isExcludedFromStats => $composableBuilder(
    column: $table.isExcludedFromStats,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isExcludedFromBudget => $composableBuilder(
    column: $table.isExcludedFromBudget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SourceKind, SourceKind, String>
  get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get ownerType => $composableBuilder(
    column: $table.ownerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerRole => $composableBuilder(
    column: $table.ownerRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootTransactionId => $composableBuilder(
    column: $table.rootTransactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessPurpose => $composableBuilder(
    column: $table.businessPurpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get primaryAmountMinor => $composableBuilder(
    column: $table.primaryAmountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counterpartyName => $composableBuilder(
    column: $table.counterpartyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentTransactionId => $composableBuilder(
    column: $table.parentTransactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reimbursementExpenseAccountId =>
      $composableBuilder(
        column: $table.reimbursementExpenseAccountId,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get mutationKind => $composableBuilder(
    column: $table.mutationKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationPreviousTransactionId =>
      $composableBuilder(
        column: $table.mutationPreviousTransactionId,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get mutationReason => $composableBuilder(
    column: $table.mutationReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessState => $composableBuilder(
    column: $table.businessState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isExcludedFromStats => $composableBuilder(
    column: $table.isExcludedFromStats,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isExcludedFromBudget => $composableBuilder(
    column: $table.isExcludedFromBudget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerType => $composableBuilder(
    column: $table.ownerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerRole => $composableBuilder(
    column: $table.ownerRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rootTransactionId => $composableBuilder(
    column: $table.rootTransactionId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<BusinessPurpose, String>
  get businessPurpose => $composableBuilder(
    column: $table.businessPurpose,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get primaryAmountMinor => $composableBuilder(
    column: $table.primaryAmountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get counterpartyName => $composableBuilder(
    column: $table.counterpartyName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get parentTransactionId => $composableBuilder(
    column: $table.parentTransactionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reimbursementExpenseAccountId =>
      $composableBuilder(
        column: $table.reimbursementExpenseAccountId,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<MutationKind, String> get mutationKind =>
      $composableBuilder(
        column: $table.mutationKind,
        builder: (column) => column,
      );

  GeneratedColumn<String> get mutationPreviousTransactionId =>
      $composableBuilder(
        column: $table.mutationPreviousTransactionId,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<MutationReason?, String>
  get mutationReason => $composableBuilder(
    column: $table.mutationReason,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<BusinessState, String> get businessState =>
      $composableBuilder(
        column: $table.businessState,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get isExcludedFromStats => $composableBuilder(
    column: $table.isExcludedFromStats,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isExcludedFromBudget => $composableBuilder(
    column: $table.isExcludedFromBudget,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SourceKind, String> get sourceKind =>
      $composableBuilder(
        column: $table.sourceKind,
        builder: (column) => column,
      );

  GeneratedColumn<String> get ownerType =>
      $composableBuilder(column: $table.ownerType, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get ownerRole =>
      $composableBuilder(column: $table.ownerRole, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          TransactionRow,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (
            TransactionRow,
            BaseReferences<_$AppDatabase, $TransactionsTable, TransactionRow>,
          ),
          TransactionRow,
          PrefetchHooks Function()
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> rootTransactionId = const Value.absent(),
                Value<BusinessPurpose> businessPurpose = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<int> primaryAmountMinor = const Value.absent(),
                Value<String?> counterpartyName = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> parentTransactionId = const Value.absent(),
                Value<String?> reimbursementExpenseAccountId =
                    const Value.absent(),
                Value<MutationKind> mutationKind = const Value.absent(),
                Value<String?> mutationPreviousTransactionId =
                    const Value.absent(),
                Value<MutationReason?> mutationReason = const Value.absent(),
                Value<BusinessState> businessState = const Value.absent(),
                Value<bool> isExcludedFromStats = const Value.absent(),
                Value<bool> isExcludedFromBudget = const Value.absent(),
                Value<SourceKind> sourceKind = const Value.absent(),
                Value<String?> ownerType = const Value.absent(),
                Value<String?> ownerId = const Value.absent(),
                Value<String?> ownerRole = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                rootTransactionId: rootTransactionId,
                businessPurpose: businessPurpose,
                occurredAt: occurredAt,
                primaryAmountMinor: primaryAmountMinor,
                counterpartyName: counterpartyName,
                note: note,
                parentTransactionId: parentTransactionId,
                reimbursementExpenseAccountId: reimbursementExpenseAccountId,
                mutationKind: mutationKind,
                mutationPreviousTransactionId: mutationPreviousTransactionId,
                mutationReason: mutationReason,
                businessState: businessState,
                isExcludedFromStats: isExcludedFromStats,
                isExcludedFromBudget: isExcludedFromBudget,
                sourceKind: sourceKind,
                ownerType: ownerType,
                ownerId: ownerId,
                ownerRole: ownerRole,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> rootTransactionId = const Value.absent(),
                required BusinessPurpose businessPurpose,
                required DateTime occurredAt,
                required int primaryAmountMinor,
                Value<String?> counterpartyName = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> parentTransactionId = const Value.absent(),
                Value<String?> reimbursementExpenseAccountId =
                    const Value.absent(),
                required MutationKind mutationKind,
                Value<String?> mutationPreviousTransactionId =
                    const Value.absent(),
                Value<MutationReason?> mutationReason = const Value.absent(),
                required BusinessState businessState,
                Value<bool> isExcludedFromStats = const Value.absent(),
                Value<bool> isExcludedFromBudget = const Value.absent(),
                required SourceKind sourceKind,
                Value<String?> ownerType = const Value.absent(),
                Value<String?> ownerId = const Value.absent(),
                Value<String?> ownerRole = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                rootTransactionId: rootTransactionId,
                businessPurpose: businessPurpose,
                occurredAt: occurredAt,
                primaryAmountMinor: primaryAmountMinor,
                counterpartyName: counterpartyName,
                note: note,
                parentTransactionId: parentTransactionId,
                reimbursementExpenseAccountId: reimbursementExpenseAccountId,
                mutationKind: mutationKind,
                mutationPreviousTransactionId: mutationPreviousTransactionId,
                mutationReason: mutationReason,
                businessState: businessState,
                isExcludedFromStats: isExcludedFromStats,
                isExcludedFromBudget: isExcludedFromBudget,
                sourceKind: sourceKind,
                ownerType: ownerType,
                ownerId: ownerId,
                ownerRole: ownerRole,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      TransactionRow,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (
        TransactionRow,
        BaseReferences<_$AppDatabase, $TransactionsTable, TransactionRow>,
      ),
      TransactionRow,
      PrefetchHooks Function()
    >;
typedef $$TransactionDetailsTableCreateCompanionBuilder =
    TransactionDetailsCompanion Function({
      required String id,
      required String transactionId,
      required int lineNo,
      required TransactionDetailType detailType,
      required int amountMinor,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$TransactionDetailsTableUpdateCompanionBuilder =
    TransactionDetailsCompanion Function({
      Value<String> id,
      Value<String> transactionId,
      Value<int> lineNo,
      Value<TransactionDetailType> detailType,
      Value<int> amountMinor,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$TransactionDetailsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionDetailsTable> {
  $$TransactionDetailsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineNo => $composableBuilder(
    column: $table.lineNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    TransactionDetailType,
    TransactionDetailType,
    String
  >
  get detailType => $composableBuilder(
    column: $table.detailType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransactionDetailsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionDetailsTable> {
  $$TransactionDetailsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineNo => $composableBuilder(
    column: $table.lineNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailType => $composableBuilder(
    column: $table.detailType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransactionDetailsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionDetailsTable> {
  $$TransactionDetailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lineNo =>
      $composableBuilder(column: $table.lineNo, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TransactionDetailType, String>
  get detailType => $composableBuilder(
    column: $table.detailType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TransactionDetailsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionDetailsTable,
          TransactionDetailRow,
          $$TransactionDetailsTableFilterComposer,
          $$TransactionDetailsTableOrderingComposer,
          $$TransactionDetailsTableAnnotationComposer,
          $$TransactionDetailsTableCreateCompanionBuilder,
          $$TransactionDetailsTableUpdateCompanionBuilder,
          (
            TransactionDetailRow,
            BaseReferences<
              _$AppDatabase,
              $TransactionDetailsTable,
              TransactionDetailRow
            >,
          ),
          TransactionDetailRow,
          PrefetchHooks Function()
        > {
  $$TransactionDetailsTableTableManager(
    _$AppDatabase db,
    $TransactionDetailsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$TransactionDetailsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$TransactionDetailsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$TransactionDetailsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> transactionId = const Value.absent(),
                Value<int> lineNo = const Value.absent(),
                Value<TransactionDetailType> detailType = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionDetailsCompanion(
                id: id,
                transactionId: transactionId,
                lineNo: lineNo,
                detailType: detailType,
                amountMinor: amountMinor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String transactionId,
                required int lineNo,
                required TransactionDetailType detailType,
                required int amountMinor,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionDetailsCompanion.insert(
                id: id,
                transactionId: transactionId,
                lineNo: lineNo,
                detailType: detailType,
                amountMinor: amountMinor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransactionDetailsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionDetailsTable,
      TransactionDetailRow,
      $$TransactionDetailsTableFilterComposer,
      $$TransactionDetailsTableOrderingComposer,
      $$TransactionDetailsTableAnnotationComposer,
      $$TransactionDetailsTableCreateCompanionBuilder,
      $$TransactionDetailsTableUpdateCompanionBuilder,
      (
        TransactionDetailRow,
        BaseReferences<
          _$AppDatabase,
          $TransactionDetailsTable,
          TransactionDetailRow
        >,
      ),
      TransactionDetailRow,
      PrefetchHooks Function()
    >;
typedef $$EntriesTableCreateCompanionBuilder =
    EntriesCompanion Function({
      required String id,
      required String transactionId,
      required String accountId,
      required EntryDirection direction,
      required int amountMinor,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$EntriesTableUpdateCompanionBuilder =
    EntriesCompanion Function({
      Value<String> id,
      Value<String> transactionId,
      Value<String> accountId,
      Value<EntryDirection> direction,
      Value<int> amountMinor,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$EntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EntryDirection, EntryDirection, String>
  get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EntryDirection, String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntriesTable,
          EntryRow,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (EntryRow, BaseReferences<_$AppDatabase, $EntriesTable, EntryRow>),
          EntryRow,
          PrefetchHooks Function()
        > {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> transactionId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<EntryDirection> direction = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                transactionId: transactionId,
                accountId: accountId,
                direction: direction,
                amountMinor: amountMinor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String transactionId,
                required String accountId,
                required EntryDirection direction,
                required int amountMinor,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                transactionId: transactionId,
                accountId: accountId,
                direction: direction,
                amountMinor: amountMinor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntriesTable,
      EntryRow,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (EntryRow, BaseReferences<_$AppDatabase, $EntriesTable, EntryRow>),
      EntryRow,
      PrefetchHooks Function()
    >;
typedef $$BudgetsTableCreateCompanionBuilder =
    BudgetsCompanion Function({
      required String id,
      required int monthKey,
      Value<String?> accountId,
      required int amountMinor,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$BudgetsTableUpdateCompanionBuilder =
    BudgetsCompanion Function({
      Value<String> id,
      Value<int> monthKey,
      Value<String?> accountId,
      Value<int> amountMinor,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$BudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthKey => $composableBuilder(
    column: $table.monthKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthKey => $composableBuilder(
    column: $table.monthKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get monthKey =>
      $composableBuilder(column: $table.monthKey, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetsTable,
          BudgetRow,
          $$BudgetsTableFilterComposer,
          $$BudgetsTableOrderingComposer,
          $$BudgetsTableAnnotationComposer,
          $$BudgetsTableCreateCompanionBuilder,
          $$BudgetsTableUpdateCompanionBuilder,
          (BudgetRow, BaseReferences<_$AppDatabase, $BudgetsTable, BudgetRow>),
          BudgetRow,
          PrefetchHooks Function()
        > {
  $$BudgetsTableTableManager(_$AppDatabase db, $BudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> monthKey = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion(
                id: id,
                monthKey: monthKey,
                accountId: accountId,
                amountMinor: amountMinor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int monthKey,
                Value<String?> accountId = const Value.absent(),
                required int amountMinor,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion.insert(
                id: id,
                monthKey: monthKey,
                accountId: accountId,
                amountMinor: amountMinor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetsTable,
      BudgetRow,
      $$BudgetsTableFilterComposer,
      $$BudgetsTableOrderingComposer,
      $$BudgetsTableAnnotationComposer,
      $$BudgetsTableCreateCompanionBuilder,
      $$BudgetsTableUpdateCompanionBuilder,
      (BudgetRow, BaseReferences<_$AppDatabase, $BudgetsTable, BudgetRow>),
      BudgetRow,
      PrefetchHooks Function()
    >;
typedef $$CreditLiabilityAccountsTableCreateCompanionBuilder =
    CreditLiabilityAccountsCompanion Function({
      required String id,
      required String accountId,
      required CreditLiabilityAccountKind kind,
      Value<int?> creditLimitMinor,
      Value<int?> billingDay,
      Value<int?> repaymentDay,
      Value<int?> billingStartPeriod,
      Value<bool> billingDayToNext,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CreditLiabilityAccountsTableUpdateCompanionBuilder =
    CreditLiabilityAccountsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<CreditLiabilityAccountKind> kind,
      Value<int?> creditLimitMinor,
      Value<int?> billingDay,
      Value<int?> repaymentDay,
      Value<int?> billingStartPeriod,
      Value<bool> billingDayToNext,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CreditLiabilityAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $CreditLiabilityAccountsTable> {
  $$CreditLiabilityAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    CreditLiabilityAccountKind,
    CreditLiabilityAccountKind,
    String
  >
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get creditLimitMinor => $composableBuilder(
    column: $table.creditLimitMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get billingDay => $composableBuilder(
    column: $table.billingDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repaymentDay => $composableBuilder(
    column: $table.repaymentDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get billingStartPeriod => $composableBuilder(
    column: $table.billingStartPeriod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get billingDayToNext => $composableBuilder(
    column: $table.billingDayToNext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CreditLiabilityAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $CreditLiabilityAccountsTable> {
  $$CreditLiabilityAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditLimitMinor => $composableBuilder(
    column: $table.creditLimitMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get billingDay => $composableBuilder(
    column: $table.billingDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repaymentDay => $composableBuilder(
    column: $table.repaymentDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get billingStartPeriod => $composableBuilder(
    column: $table.billingStartPeriod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get billingDayToNext => $composableBuilder(
    column: $table.billingDayToNext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CreditLiabilityAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CreditLiabilityAccountsTable> {
  $$CreditLiabilityAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CreditLiabilityAccountKind, String>
  get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get creditLimitMinor => $composableBuilder(
    column: $table.creditLimitMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get billingDay => $composableBuilder(
    column: $table.billingDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repaymentDay => $composableBuilder(
    column: $table.repaymentDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get billingStartPeriod => $composableBuilder(
    column: $table.billingStartPeriod,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get billingDayToNext => $composableBuilder(
    column: $table.billingDayToNext,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CreditLiabilityAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CreditLiabilityAccountsTable,
          CreditLiabilityAccountRow,
          $$CreditLiabilityAccountsTableFilterComposer,
          $$CreditLiabilityAccountsTableOrderingComposer,
          $$CreditLiabilityAccountsTableAnnotationComposer,
          $$CreditLiabilityAccountsTableCreateCompanionBuilder,
          $$CreditLiabilityAccountsTableUpdateCompanionBuilder,
          (
            CreditLiabilityAccountRow,
            BaseReferences<
              _$AppDatabase,
              $CreditLiabilityAccountsTable,
              CreditLiabilityAccountRow
            >,
          ),
          CreditLiabilityAccountRow,
          PrefetchHooks Function()
        > {
  $$CreditLiabilityAccountsTableTableManager(
    _$AppDatabase db,
    $CreditLiabilityAccountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$CreditLiabilityAccountsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$CreditLiabilityAccountsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$CreditLiabilityAccountsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<CreditLiabilityAccountKind> kind = const Value.absent(),
                Value<int?> creditLimitMinor = const Value.absent(),
                Value<int?> billingDay = const Value.absent(),
                Value<int?> repaymentDay = const Value.absent(),
                Value<int?> billingStartPeriod = const Value.absent(),
                Value<bool> billingDayToNext = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CreditLiabilityAccountsCompanion(
                id: id,
                accountId: accountId,
                kind: kind,
                creditLimitMinor: creditLimitMinor,
                billingDay: billingDay,
                repaymentDay: repaymentDay,
                billingStartPeriod: billingStartPeriod,
                billingDayToNext: billingDayToNext,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required CreditLiabilityAccountKind kind,
                Value<int?> creditLimitMinor = const Value.absent(),
                Value<int?> billingDay = const Value.absent(),
                Value<int?> repaymentDay = const Value.absent(),
                Value<int?> billingStartPeriod = const Value.absent(),
                Value<bool> billingDayToNext = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CreditLiabilityAccountsCompanion.insert(
                id: id,
                accountId: accountId,
                kind: kind,
                creditLimitMinor: creditLimitMinor,
                billingDay: billingDay,
                repaymentDay: repaymentDay,
                billingStartPeriod: billingStartPeriod,
                billingDayToNext: billingDayToNext,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CreditLiabilityAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CreditLiabilityAccountsTable,
      CreditLiabilityAccountRow,
      $$CreditLiabilityAccountsTableFilterComposer,
      $$CreditLiabilityAccountsTableOrderingComposer,
      $$CreditLiabilityAccountsTableAnnotationComposer,
      $$CreditLiabilityAccountsTableCreateCompanionBuilder,
      $$CreditLiabilityAccountsTableUpdateCompanionBuilder,
      (
        CreditLiabilityAccountRow,
        BaseReferences<
          _$AppDatabase,
          $CreditLiabilityAccountsTable,
          CreditLiabilityAccountRow
        >,
      ),
      CreditLiabilityAccountRow,
      PrefetchHooks Function()
    >;
typedef $$BillsTableCreateCompanionBuilder =
    BillsCompanion Function({
      required String id,
      required String accountId,
      required int period,
      Value<DateTime?> startDate,
      Value<DateTime?> billingDate,
      Value<DateTime?> repaymentDate,
      required BillStatus status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$BillsTableUpdateCompanionBuilder =
    BillsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<int> period,
      Value<DateTime?> startDate,
      Value<DateTime?> billingDate,
      Value<DateTime?> repaymentDate,
      Value<BillStatus> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$BillsTableFilterComposer extends Composer<_$AppDatabase, $BillsTable> {
  $$BillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get billingDate => $composableBuilder(
    column: $table.billingDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get repaymentDate => $composableBuilder(
    column: $table.repaymentDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BillStatus, BillStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BillsTableOrderingComposer
    extends Composer<_$AppDatabase, $BillsTable> {
  $$BillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get billingDate => $composableBuilder(
    column: $table.billingDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get repaymentDate => $composableBuilder(
    column: $table.repaymentDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BillsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BillsTable> {
  $$BillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get billingDate => $composableBuilder(
    column: $table.billingDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get repaymentDate => $composableBuilder(
    column: $table.repaymentDate,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<BillStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BillsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BillsTable,
          BillRow,
          $$BillsTableFilterComposer,
          $$BillsTableOrderingComposer,
          $$BillsTableAnnotationComposer,
          $$BillsTableCreateCompanionBuilder,
          $$BillsTableUpdateCompanionBuilder,
          (BillRow, BaseReferences<_$AppDatabase, $BillsTable, BillRow>),
          BillRow,
          PrefetchHooks Function()
        > {
  $$BillsTableTableManager(_$AppDatabase db, $BillsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$BillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$BillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$BillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<int> period = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> billingDate = const Value.absent(),
                Value<DateTime?> repaymentDate = const Value.absent(),
                Value<BillStatus> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BillsCompanion(
                id: id,
                accountId: accountId,
                period: period,
                startDate: startDate,
                billingDate: billingDate,
                repaymentDate: repaymentDate,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required int period,
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> billingDate = const Value.absent(),
                Value<DateTime?> repaymentDate = const Value.absent(),
                required BillStatus status,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BillsCompanion.insert(
                id: id,
                accountId: accountId,
                period: period,
                startDate: startDate,
                billingDate: billingDate,
                repaymentDate: repaymentDate,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BillsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BillsTable,
      BillRow,
      $$BillsTableFilterComposer,
      $$BillsTableOrderingComposer,
      $$BillsTableAnnotationComposer,
      $$BillsTableCreateCompanionBuilder,
      $$BillsTableUpdateCompanionBuilder,
      (BillRow, BaseReferences<_$AppDatabase, $BillsTable, BillRow>),
      BillRow,
      PrefetchHooks Function()
    >;
typedef $$BillItemsTableCreateCompanionBuilder =
    BillItemsCompanion Function({
      required String id,
      required String billId,
      required BillItemType itemType,
      Value<String?> contractId,
      Value<String?> scheduleId,
      required DateTime repaymentDate,
      required int expectedPrincipalMinor,
      required int expectedInterestMinor,
      required int expectedFeeMinor,
      required BillItemStatus status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$BillItemsTableUpdateCompanionBuilder =
    BillItemsCompanion Function({
      Value<String> id,
      Value<String> billId,
      Value<BillItemType> itemType,
      Value<String?> contractId,
      Value<String?> scheduleId,
      Value<DateTime> repaymentDate,
      Value<int> expectedPrincipalMinor,
      Value<int> expectedInterestMinor,
      Value<int> expectedFeeMinor,
      Value<BillItemStatus> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$BillItemsTableFilterComposer
    extends Composer<_$AppDatabase, $BillItemsTable> {
  $$BillItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get billId => $composableBuilder(
    column: $table.billId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BillItemType, BillItemType, String>
  get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get contractId => $composableBuilder(
    column: $table.contractId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get repaymentDate => $composableBuilder(
    column: $table.repaymentDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedPrincipalMinor => $composableBuilder(
    column: $table.expectedPrincipalMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedInterestMinor => $composableBuilder(
    column: $table.expectedInterestMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedFeeMinor => $composableBuilder(
    column: $table.expectedFeeMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BillItemStatus, BillItemStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BillItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $BillItemsTable> {
  $$BillItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get billId => $composableBuilder(
    column: $table.billId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contractId => $composableBuilder(
    column: $table.contractId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get repaymentDate => $composableBuilder(
    column: $table.repaymentDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedPrincipalMinor => $composableBuilder(
    column: $table.expectedPrincipalMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedInterestMinor => $composableBuilder(
    column: $table.expectedInterestMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedFeeMinor => $composableBuilder(
    column: $table.expectedFeeMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BillItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BillItemsTable> {
  $$BillItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get billId =>
      $composableBuilder(column: $table.billId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BillItemType, String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get contractId => $composableBuilder(
    column: $table.contractId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get repaymentDate => $composableBuilder(
    column: $table.repaymentDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expectedPrincipalMinor => $composableBuilder(
    column: $table.expectedPrincipalMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expectedInterestMinor => $composableBuilder(
    column: $table.expectedInterestMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expectedFeeMinor => $composableBuilder(
    column: $table.expectedFeeMinor,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<BillItemStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BillItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BillItemsTable,
          BillItemRow,
          $$BillItemsTableFilterComposer,
          $$BillItemsTableOrderingComposer,
          $$BillItemsTableAnnotationComposer,
          $$BillItemsTableCreateCompanionBuilder,
          $$BillItemsTableUpdateCompanionBuilder,
          (
            BillItemRow,
            BaseReferences<_$AppDatabase, $BillItemsTable, BillItemRow>,
          ),
          BillItemRow,
          PrefetchHooks Function()
        > {
  $$BillItemsTableTableManager(_$AppDatabase db, $BillItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$BillItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$BillItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$BillItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> billId = const Value.absent(),
                Value<BillItemType> itemType = const Value.absent(),
                Value<String?> contractId = const Value.absent(),
                Value<String?> scheduleId = const Value.absent(),
                Value<DateTime> repaymentDate = const Value.absent(),
                Value<int> expectedPrincipalMinor = const Value.absent(),
                Value<int> expectedInterestMinor = const Value.absent(),
                Value<int> expectedFeeMinor = const Value.absent(),
                Value<BillItemStatus> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BillItemsCompanion(
                id: id,
                billId: billId,
                itemType: itemType,
                contractId: contractId,
                scheduleId: scheduleId,
                repaymentDate: repaymentDate,
                expectedPrincipalMinor: expectedPrincipalMinor,
                expectedInterestMinor: expectedInterestMinor,
                expectedFeeMinor: expectedFeeMinor,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String billId,
                required BillItemType itemType,
                Value<String?> contractId = const Value.absent(),
                Value<String?> scheduleId = const Value.absent(),
                required DateTime repaymentDate,
                required int expectedPrincipalMinor,
                required int expectedInterestMinor,
                required int expectedFeeMinor,
                required BillItemStatus status,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BillItemsCompanion.insert(
                id: id,
                billId: billId,
                itemType: itemType,
                contractId: contractId,
                scheduleId: scheduleId,
                repaymentDate: repaymentDate,
                expectedPrincipalMinor: expectedPrincipalMinor,
                expectedInterestMinor: expectedInterestMinor,
                expectedFeeMinor: expectedFeeMinor,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BillItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BillItemsTable,
      BillItemRow,
      $$BillItemsTableFilterComposer,
      $$BillItemsTableOrderingComposer,
      $$BillItemsTableAnnotationComposer,
      $$BillItemsTableCreateCompanionBuilder,
      $$BillItemsTableUpdateCompanionBuilder,
      (
        BillItemRow,
        BaseReferences<_$AppDatabase, $BillItemsTable, BillItemRow>,
      ),
      BillItemRow,
      PrefetchHooks Function()
    >;
typedef $$InstallmentContractsTableCreateCompanionBuilder =
    InstallmentContractsCompanion Function({
      required String id,
      required String liabilityAccountId,
      required InstallmentSourceType sourceType,
      Value<String?> disbursementAccountId,
      Value<String?> disbursementTransactionId,
      Value<String?> sourceRepaymentId,
      required int principalMinor,
      required int totalPeriods,
      required DateTime borrowingDate,
      required DateTime firstRepaymentDate,
      required DateTime lastRepaymentDate,
      required InstallmentRepaymentMethod repaymentMethod,
      Value<InterestRatePeriod?> interestRatePeriod,
      Value<int?> interestRatePpm,
      Value<InterestAccrualMethod> interestAccrualMethod,
      Value<int> totalFeeMinor,
      required InstallmentContractStatus status,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$InstallmentContractsTableUpdateCompanionBuilder =
    InstallmentContractsCompanion Function({
      Value<String> id,
      Value<String> liabilityAccountId,
      Value<InstallmentSourceType> sourceType,
      Value<String?> disbursementAccountId,
      Value<String?> disbursementTransactionId,
      Value<String?> sourceRepaymentId,
      Value<int> principalMinor,
      Value<int> totalPeriods,
      Value<DateTime> borrowingDate,
      Value<DateTime> firstRepaymentDate,
      Value<DateTime> lastRepaymentDate,
      Value<InstallmentRepaymentMethod> repaymentMethod,
      Value<InterestRatePeriod?> interestRatePeriod,
      Value<int?> interestRatePpm,
      Value<InterestAccrualMethod> interestAccrualMethod,
      Value<int> totalFeeMinor,
      Value<InstallmentContractStatus> status,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$InstallmentContractsTableFilterComposer
    extends Composer<_$AppDatabase, $InstallmentContractsTable> {
  $$InstallmentContractsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get liabilityAccountId => $composableBuilder(
    column: $table.liabilityAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    InstallmentSourceType,
    InstallmentSourceType,
    String
  >
  get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get disbursementAccountId => $composableBuilder(
    column: $table.disbursementAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get disbursementTransactionId => $composableBuilder(
    column: $table.disbursementTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRepaymentId => $composableBuilder(
    column: $table.sourceRepaymentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get principalMinor => $composableBuilder(
    column: $table.principalMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPeriods => $composableBuilder(
    column: $table.totalPeriods,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get borrowingDate => $composableBuilder(
    column: $table.borrowingDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstRepaymentDate => $composableBuilder(
    column: $table.firstRepaymentDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastRepaymentDate => $composableBuilder(
    column: $table.lastRepaymentDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    InstallmentRepaymentMethod,
    InstallmentRepaymentMethod,
    String
  >
  get repaymentMethod => $composableBuilder(
    column: $table.repaymentMethod,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<
    InterestRatePeriod?,
    InterestRatePeriod,
    String
  >
  get interestRatePeriod => $composableBuilder(
    column: $table.interestRatePeriod,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get interestRatePpm => $composableBuilder(
    column: $table.interestRatePpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    InterestAccrualMethod,
    InterestAccrualMethod,
    String
  >
  get interestAccrualMethod => $composableBuilder(
    column: $table.interestAccrualMethod,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get totalFeeMinor => $composableBuilder(
    column: $table.totalFeeMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    InstallmentContractStatus,
    InstallmentContractStatus,
    String
  >
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InstallmentContractsTableOrderingComposer
    extends Composer<_$AppDatabase, $InstallmentContractsTable> {
  $$InstallmentContractsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get liabilityAccountId => $composableBuilder(
    column: $table.liabilityAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get disbursementAccountId => $composableBuilder(
    column: $table.disbursementAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get disbursementTransactionId => $composableBuilder(
    column: $table.disbursementTransactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRepaymentId => $composableBuilder(
    column: $table.sourceRepaymentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get principalMinor => $composableBuilder(
    column: $table.principalMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPeriods => $composableBuilder(
    column: $table.totalPeriods,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get borrowingDate => $composableBuilder(
    column: $table.borrowingDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstRepaymentDate => $composableBuilder(
    column: $table.firstRepaymentDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastRepaymentDate => $composableBuilder(
    column: $table.lastRepaymentDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repaymentMethod => $composableBuilder(
    column: $table.repaymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interestRatePeriod => $composableBuilder(
    column: $table.interestRatePeriod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get interestRatePpm => $composableBuilder(
    column: $table.interestRatePpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interestAccrualMethod => $composableBuilder(
    column: $table.interestAccrualMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalFeeMinor => $composableBuilder(
    column: $table.totalFeeMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InstallmentContractsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InstallmentContractsTable> {
  $$InstallmentContractsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get liabilityAccountId => $composableBuilder(
    column: $table.liabilityAccountId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<InstallmentSourceType, String>
  get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get disbursementAccountId => $composableBuilder(
    column: $table.disbursementAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get disbursementTransactionId => $composableBuilder(
    column: $table.disbursementTransactionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceRepaymentId => $composableBuilder(
    column: $table.sourceRepaymentId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get principalMinor => $composableBuilder(
    column: $table.principalMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalPeriods => $composableBuilder(
    column: $table.totalPeriods,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get borrowingDate => $composableBuilder(
    column: $table.borrowingDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get firstRepaymentDate => $composableBuilder(
    column: $table.firstRepaymentDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastRepaymentDate => $composableBuilder(
    column: $table.lastRepaymentDate,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<InstallmentRepaymentMethod, String>
  get repaymentMethod => $composableBuilder(
    column: $table.repaymentMethod,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<InterestRatePeriod?, String>
  get interestRatePeriod => $composableBuilder(
    column: $table.interestRatePeriod,
    builder: (column) => column,
  );

  GeneratedColumn<int> get interestRatePpm => $composableBuilder(
    column: $table.interestRatePpm,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<InterestAccrualMethod, String>
  get interestAccrualMethod => $composableBuilder(
    column: $table.interestAccrualMethod,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalFeeMinor => $composableBuilder(
    column: $table.totalFeeMinor,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<InstallmentContractStatus, String>
  get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$InstallmentContractsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InstallmentContractsTable,
          InstallmentContractRow,
          $$InstallmentContractsTableFilterComposer,
          $$InstallmentContractsTableOrderingComposer,
          $$InstallmentContractsTableAnnotationComposer,
          $$InstallmentContractsTableCreateCompanionBuilder,
          $$InstallmentContractsTableUpdateCompanionBuilder,
          (
            InstallmentContractRow,
            BaseReferences<
              _$AppDatabase,
              $InstallmentContractsTable,
              InstallmentContractRow
            >,
          ),
          InstallmentContractRow,
          PrefetchHooks Function()
        > {
  $$InstallmentContractsTableTableManager(
    _$AppDatabase db,
    $InstallmentContractsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$InstallmentContractsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$InstallmentContractsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$InstallmentContractsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> liabilityAccountId = const Value.absent(),
                Value<InstallmentSourceType> sourceType = const Value.absent(),
                Value<String?> disbursementAccountId = const Value.absent(),
                Value<String?> disbursementTransactionId = const Value.absent(),
                Value<String?> sourceRepaymentId = const Value.absent(),
                Value<int> principalMinor = const Value.absent(),
                Value<int> totalPeriods = const Value.absent(),
                Value<DateTime> borrowingDate = const Value.absent(),
                Value<DateTime> firstRepaymentDate = const Value.absent(),
                Value<DateTime> lastRepaymentDate = const Value.absent(),
                Value<InstallmentRepaymentMethod> repaymentMethod =
                    const Value.absent(),
                Value<InterestRatePeriod?> interestRatePeriod =
                    const Value.absent(),
                Value<int?> interestRatePpm = const Value.absent(),
                Value<InterestAccrualMethod> interestAccrualMethod =
                    const Value.absent(),
                Value<int> totalFeeMinor = const Value.absent(),
                Value<InstallmentContractStatus> status = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstallmentContractsCompanion(
                id: id,
                liabilityAccountId: liabilityAccountId,
                sourceType: sourceType,
                disbursementAccountId: disbursementAccountId,
                disbursementTransactionId: disbursementTransactionId,
                sourceRepaymentId: sourceRepaymentId,
                principalMinor: principalMinor,
                totalPeriods: totalPeriods,
                borrowingDate: borrowingDate,
                firstRepaymentDate: firstRepaymentDate,
                lastRepaymentDate: lastRepaymentDate,
                repaymentMethod: repaymentMethod,
                interestRatePeriod: interestRatePeriod,
                interestRatePpm: interestRatePpm,
                interestAccrualMethod: interestAccrualMethod,
                totalFeeMinor: totalFeeMinor,
                status: status,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String liabilityAccountId,
                required InstallmentSourceType sourceType,
                Value<String?> disbursementAccountId = const Value.absent(),
                Value<String?> disbursementTransactionId = const Value.absent(),
                Value<String?> sourceRepaymentId = const Value.absent(),
                required int principalMinor,
                required int totalPeriods,
                required DateTime borrowingDate,
                required DateTime firstRepaymentDate,
                required DateTime lastRepaymentDate,
                required InstallmentRepaymentMethod repaymentMethod,
                Value<InterestRatePeriod?> interestRatePeriod =
                    const Value.absent(),
                Value<int?> interestRatePpm = const Value.absent(),
                Value<InterestAccrualMethod> interestAccrualMethod =
                    const Value.absent(),
                Value<int> totalFeeMinor = const Value.absent(),
                required InstallmentContractStatus status,
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstallmentContractsCompanion.insert(
                id: id,
                liabilityAccountId: liabilityAccountId,
                sourceType: sourceType,
                disbursementAccountId: disbursementAccountId,
                disbursementTransactionId: disbursementTransactionId,
                sourceRepaymentId: sourceRepaymentId,
                principalMinor: principalMinor,
                totalPeriods: totalPeriods,
                borrowingDate: borrowingDate,
                firstRepaymentDate: firstRepaymentDate,
                lastRepaymentDate: lastRepaymentDate,
                repaymentMethod: repaymentMethod,
                interestRatePeriod: interestRatePeriod,
                interestRatePpm: interestRatePpm,
                interestAccrualMethod: interestAccrualMethod,
                totalFeeMinor: totalFeeMinor,
                status: status,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InstallmentContractsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InstallmentContractsTable,
      InstallmentContractRow,
      $$InstallmentContractsTableFilterComposer,
      $$InstallmentContractsTableOrderingComposer,
      $$InstallmentContractsTableAnnotationComposer,
      $$InstallmentContractsTableCreateCompanionBuilder,
      $$InstallmentContractsTableUpdateCompanionBuilder,
      (
        InstallmentContractRow,
        BaseReferences<
          _$AppDatabase,
          $InstallmentContractsTable,
          InstallmentContractRow
        >,
      ),
      InstallmentContractRow,
      PrefetchHooks Function()
    >;
typedef $$InstallmentSchedulesTableCreateCompanionBuilder =
    InstallmentSchedulesCompanion Function({
      required String id,
      required String contractId,
      required int periodNo,
      required DateTime expectedRepaymentDate,
      Value<int> expectedPrincipalMinor,
      Value<int> expectedInterestMinor,
      Value<int> expectedFeeMinor,
      required InstallmentScheduleStatus status,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$InstallmentSchedulesTableUpdateCompanionBuilder =
    InstallmentSchedulesCompanion Function({
      Value<String> id,
      Value<String> contractId,
      Value<int> periodNo,
      Value<DateTime> expectedRepaymentDate,
      Value<int> expectedPrincipalMinor,
      Value<int> expectedInterestMinor,
      Value<int> expectedFeeMinor,
      Value<InstallmentScheduleStatus> status,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$InstallmentSchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $InstallmentSchedulesTable> {
  $$InstallmentSchedulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contractId => $composableBuilder(
    column: $table.contractId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get periodNo => $composableBuilder(
    column: $table.periodNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expectedRepaymentDate => $composableBuilder(
    column: $table.expectedRepaymentDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedPrincipalMinor => $composableBuilder(
    column: $table.expectedPrincipalMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedInterestMinor => $composableBuilder(
    column: $table.expectedInterestMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedFeeMinor => $composableBuilder(
    column: $table.expectedFeeMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    InstallmentScheduleStatus,
    InstallmentScheduleStatus,
    String
  >
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InstallmentSchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $InstallmentSchedulesTable> {
  $$InstallmentSchedulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contractId => $composableBuilder(
    column: $table.contractId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get periodNo => $composableBuilder(
    column: $table.periodNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expectedRepaymentDate => $composableBuilder(
    column: $table.expectedRepaymentDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedPrincipalMinor => $composableBuilder(
    column: $table.expectedPrincipalMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedInterestMinor => $composableBuilder(
    column: $table.expectedInterestMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedFeeMinor => $composableBuilder(
    column: $table.expectedFeeMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InstallmentSchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InstallmentSchedulesTable> {
  $$InstallmentSchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get contractId => $composableBuilder(
    column: $table.contractId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get periodNo =>
      $composableBuilder(column: $table.periodNo, builder: (column) => column);

  GeneratedColumn<DateTime> get expectedRepaymentDate => $composableBuilder(
    column: $table.expectedRepaymentDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expectedPrincipalMinor => $composableBuilder(
    column: $table.expectedPrincipalMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expectedInterestMinor => $composableBuilder(
    column: $table.expectedInterestMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expectedFeeMinor => $composableBuilder(
    column: $table.expectedFeeMinor,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<InstallmentScheduleStatus, String>
  get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$InstallmentSchedulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InstallmentSchedulesTable,
          InstallmentScheduleRow,
          $$InstallmentSchedulesTableFilterComposer,
          $$InstallmentSchedulesTableOrderingComposer,
          $$InstallmentSchedulesTableAnnotationComposer,
          $$InstallmentSchedulesTableCreateCompanionBuilder,
          $$InstallmentSchedulesTableUpdateCompanionBuilder,
          (
            InstallmentScheduleRow,
            BaseReferences<
              _$AppDatabase,
              $InstallmentSchedulesTable,
              InstallmentScheduleRow
            >,
          ),
          InstallmentScheduleRow,
          PrefetchHooks Function()
        > {
  $$InstallmentSchedulesTableTableManager(
    _$AppDatabase db,
    $InstallmentSchedulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$InstallmentSchedulesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$InstallmentSchedulesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$InstallmentSchedulesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> contractId = const Value.absent(),
                Value<int> periodNo = const Value.absent(),
                Value<DateTime> expectedRepaymentDate = const Value.absent(),
                Value<int> expectedPrincipalMinor = const Value.absent(),
                Value<int> expectedInterestMinor = const Value.absent(),
                Value<int> expectedFeeMinor = const Value.absent(),
                Value<InstallmentScheduleStatus> status = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstallmentSchedulesCompanion(
                id: id,
                contractId: contractId,
                periodNo: periodNo,
                expectedRepaymentDate: expectedRepaymentDate,
                expectedPrincipalMinor: expectedPrincipalMinor,
                expectedInterestMinor: expectedInterestMinor,
                expectedFeeMinor: expectedFeeMinor,
                status: status,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String contractId,
                required int periodNo,
                required DateTime expectedRepaymentDate,
                Value<int> expectedPrincipalMinor = const Value.absent(),
                Value<int> expectedInterestMinor = const Value.absent(),
                Value<int> expectedFeeMinor = const Value.absent(),
                required InstallmentScheduleStatus status,
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstallmentSchedulesCompanion.insert(
                id: id,
                contractId: contractId,
                periodNo: periodNo,
                expectedRepaymentDate: expectedRepaymentDate,
                expectedPrincipalMinor: expectedPrincipalMinor,
                expectedInterestMinor: expectedInterestMinor,
                expectedFeeMinor: expectedFeeMinor,
                status: status,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InstallmentSchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InstallmentSchedulesTable,
      InstallmentScheduleRow,
      $$InstallmentSchedulesTableFilterComposer,
      $$InstallmentSchedulesTableOrderingComposer,
      $$InstallmentSchedulesTableAnnotationComposer,
      $$InstallmentSchedulesTableCreateCompanionBuilder,
      $$InstallmentSchedulesTableUpdateCompanionBuilder,
      (
        InstallmentScheduleRow,
        BaseReferences<
          _$AppDatabase,
          $InstallmentSchedulesTable,
          InstallmentScheduleRow
        >,
      ),
      InstallmentScheduleRow,
      PrefetchHooks Function()
    >;
typedef $$RepaymentsTableCreateCompanionBuilder =
    RepaymentsCompanion Function({
      required String id,
      required String repaymentType,
      required String targetType,
      required String targetId,
      Value<String?> rootTransactionId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$RepaymentsTableUpdateCompanionBuilder =
    RepaymentsCompanion Function({
      Value<String> id,
      Value<String> repaymentType,
      Value<String> targetType,
      Value<String> targetId,
      Value<String?> rootTransactionId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$RepaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $RepaymentsTable> {
  $$RepaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repaymentType => $composableBuilder(
    column: $table.repaymentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootTransactionId => $composableBuilder(
    column: $table.rootTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RepaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $RepaymentsTable> {
  $$RepaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repaymentType => $composableBuilder(
    column: $table.repaymentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootTransactionId => $composableBuilder(
    column: $table.rootTransactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RepaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RepaymentsTable> {
  $$RepaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get repaymentType => $composableBuilder(
    column: $table.repaymentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get rootTransactionId => $composableBuilder(
    column: $table.rootTransactionId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RepaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RepaymentsTable,
          RepaymentRow,
          $$RepaymentsTableFilterComposer,
          $$RepaymentsTableOrderingComposer,
          $$RepaymentsTableAnnotationComposer,
          $$RepaymentsTableCreateCompanionBuilder,
          $$RepaymentsTableUpdateCompanionBuilder,
          (
            RepaymentRow,
            BaseReferences<_$AppDatabase, $RepaymentsTable, RepaymentRow>,
          ),
          RepaymentRow,
          PrefetchHooks Function()
        > {
  $$RepaymentsTableTableManager(_$AppDatabase db, $RepaymentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$RepaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$RepaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$RepaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> repaymentType = const Value.absent(),
                Value<String> targetType = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<String?> rootTransactionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RepaymentsCompanion(
                id: id,
                repaymentType: repaymentType,
                targetType: targetType,
                targetId: targetId,
                rootTransactionId: rootTransactionId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String repaymentType,
                required String targetType,
                required String targetId,
                Value<String?> rootTransactionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RepaymentsCompanion.insert(
                id: id,
                repaymentType: repaymentType,
                targetType: targetType,
                targetId: targetId,
                rootTransactionId: rootTransactionId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RepaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RepaymentsTable,
      RepaymentRow,
      $$RepaymentsTableFilterComposer,
      $$RepaymentsTableOrderingComposer,
      $$RepaymentsTableAnnotationComposer,
      $$RepaymentsTableCreateCompanionBuilder,
      $$RepaymentsTableUpdateCompanionBuilder,
      (
        RepaymentRow,
        BaseReferences<_$AppDatabase, $RepaymentsTable, RepaymentRow>,
      ),
      RepaymentRow,
      PrefetchHooks Function()
    >;
typedef $$RepaymentItemsTableCreateCompanionBuilder =
    RepaymentItemsCompanion Function({
      required String id,
      required String repaymentId,
      Value<String?> billItemId,
      required int allocatedPrincipalMinor,
      required int allocatedInterestMinor,
      required int allocatedFeeMinor,
      required int allocatedDiscountMinor,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$RepaymentItemsTableUpdateCompanionBuilder =
    RepaymentItemsCompanion Function({
      Value<String> id,
      Value<String> repaymentId,
      Value<String?> billItemId,
      Value<int> allocatedPrincipalMinor,
      Value<int> allocatedInterestMinor,
      Value<int> allocatedFeeMinor,
      Value<int> allocatedDiscountMinor,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$RepaymentItemsTableFilterComposer
    extends Composer<_$AppDatabase, $RepaymentItemsTable> {
  $$RepaymentItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repaymentId => $composableBuilder(
    column: $table.repaymentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get billItemId => $composableBuilder(
    column: $table.billItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get allocatedPrincipalMinor => $composableBuilder(
    column: $table.allocatedPrincipalMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get allocatedInterestMinor => $composableBuilder(
    column: $table.allocatedInterestMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get allocatedFeeMinor => $composableBuilder(
    column: $table.allocatedFeeMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get allocatedDiscountMinor => $composableBuilder(
    column: $table.allocatedDiscountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RepaymentItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $RepaymentItemsTable> {
  $$RepaymentItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repaymentId => $composableBuilder(
    column: $table.repaymentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get billItemId => $composableBuilder(
    column: $table.billItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get allocatedPrincipalMinor => $composableBuilder(
    column: $table.allocatedPrincipalMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get allocatedInterestMinor => $composableBuilder(
    column: $table.allocatedInterestMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get allocatedFeeMinor => $composableBuilder(
    column: $table.allocatedFeeMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get allocatedDiscountMinor => $composableBuilder(
    column: $table.allocatedDiscountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RepaymentItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RepaymentItemsTable> {
  $$RepaymentItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get repaymentId => $composableBuilder(
    column: $table.repaymentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get billItemId => $composableBuilder(
    column: $table.billItemId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get allocatedPrincipalMinor => $composableBuilder(
    column: $table.allocatedPrincipalMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get allocatedInterestMinor => $composableBuilder(
    column: $table.allocatedInterestMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get allocatedFeeMinor => $composableBuilder(
    column: $table.allocatedFeeMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get allocatedDiscountMinor => $composableBuilder(
    column: $table.allocatedDiscountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RepaymentItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RepaymentItemsTable,
          RepaymentItemRow,
          $$RepaymentItemsTableFilterComposer,
          $$RepaymentItemsTableOrderingComposer,
          $$RepaymentItemsTableAnnotationComposer,
          $$RepaymentItemsTableCreateCompanionBuilder,
          $$RepaymentItemsTableUpdateCompanionBuilder,
          (
            RepaymentItemRow,
            BaseReferences<
              _$AppDatabase,
              $RepaymentItemsTable,
              RepaymentItemRow
            >,
          ),
          RepaymentItemRow,
          PrefetchHooks Function()
        > {
  $$RepaymentItemsTableTableManager(
    _$AppDatabase db,
    $RepaymentItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$RepaymentItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$RepaymentItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$RepaymentItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> repaymentId = const Value.absent(),
                Value<String?> billItemId = const Value.absent(),
                Value<int> allocatedPrincipalMinor = const Value.absent(),
                Value<int> allocatedInterestMinor = const Value.absent(),
                Value<int> allocatedFeeMinor = const Value.absent(),
                Value<int> allocatedDiscountMinor = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RepaymentItemsCompanion(
                id: id,
                repaymentId: repaymentId,
                billItemId: billItemId,
                allocatedPrincipalMinor: allocatedPrincipalMinor,
                allocatedInterestMinor: allocatedInterestMinor,
                allocatedFeeMinor: allocatedFeeMinor,
                allocatedDiscountMinor: allocatedDiscountMinor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String repaymentId,
                Value<String?> billItemId = const Value.absent(),
                required int allocatedPrincipalMinor,
                required int allocatedInterestMinor,
                required int allocatedFeeMinor,
                required int allocatedDiscountMinor,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RepaymentItemsCompanion.insert(
                id: id,
                repaymentId: repaymentId,
                billItemId: billItemId,
                allocatedPrincipalMinor: allocatedPrincipalMinor,
                allocatedInterestMinor: allocatedInterestMinor,
                allocatedFeeMinor: allocatedFeeMinor,
                allocatedDiscountMinor: allocatedDiscountMinor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RepaymentItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RepaymentItemsTable,
      RepaymentItemRow,
      $$RepaymentItemsTableFilterComposer,
      $$RepaymentItemsTableOrderingComposer,
      $$RepaymentItemsTableAnnotationComposer,
      $$RepaymentItemsTableCreateCompanionBuilder,
      $$RepaymentItemsTableUpdateCompanionBuilder,
      (
        RepaymentItemRow,
        BaseReferences<_$AppDatabase, $RepaymentItemsTable, RepaymentItemRow>,
      ),
      RepaymentItemRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$AppMetadataTableTableManager get appMetadata =>
      $$AppMetadataTableTableManager(_db, _db.appMetadata);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$TransactionDetailsTableTableManager get transactionDetails =>
      $$TransactionDetailsTableTableManager(_db, _db.transactionDetails);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$CreditLiabilityAccountsTableTableManager get creditLiabilityAccounts =>
      $$CreditLiabilityAccountsTableTableManager(
        _db,
        _db.creditLiabilityAccounts,
      );
  $$BillsTableTableManager get bills =>
      $$BillsTableTableManager(_db, _db.bills);
  $$BillItemsTableTableManager get billItems =>
      $$BillItemsTableTableManager(_db, _db.billItems);
  $$InstallmentContractsTableTableManager get installmentContracts =>
      $$InstallmentContractsTableTableManager(_db, _db.installmentContracts);
  $$InstallmentSchedulesTableTableManager get installmentSchedules =>
      $$InstallmentSchedulesTableTableManager(_db, _db.installmentSchedules);
  $$RepaymentsTableTableManager get repayments =>
      $$RepaymentsTableTableManager(_db, _db.repayments);
  $$RepaymentItemsTableTableManager get repaymentItems =>
      $$RepaymentItemsTableTableManager(_db, _db.repaymentItems);
}
