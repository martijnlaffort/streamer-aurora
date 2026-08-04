// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AccountsTableTable extends AccountsTable
    with TableInfo<$AccountsTableTable, AccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AccountType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AccountType>($AccountsTableTable.$convertertype);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverUrlMeta = const VerificationMeta(
    'serverUrl',
  );
  @override
  late final GeneratedColumn<String> serverUrl = GeneratedColumn<String>(
    'server_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _epgUrlMeta = const VerificationMeta('epgUrl');
  @override
  late final GeneratedColumn<String> epgUrl = GeneratedColumn<String>(
    'epg_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMillisUtcMeta =
      const VerificationMeta('createdAtMillisUtc');
  @override
  late final GeneratedColumn<int> createdAtMillisUtc = GeneratedColumn<int>(
    'created_at_millis_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    name,
    serverUrl,
    username,
    epgUrl,
    createdAtMillisUtc,
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
    if (data.containsKey('server_url')) {
      context.handle(
        _serverUrlMeta,
        serverUrl.isAcceptableOrUnknown(data['server_url']!, _serverUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_serverUrlMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('epg_url')) {
      context.handle(
        _epgUrlMeta,
        epgUrl.isAcceptableOrUnknown(data['epg_url']!, _epgUrlMeta),
      );
    }
    if (data.containsKey('created_at_millis_utc')) {
      context.handle(
        _createdAtMillisUtcMeta,
        createdAtMillisUtc.isAcceptableOrUnknown(
          data['created_at_millis_utc']!,
          _createdAtMillisUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMillisUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: $AccountsTableTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      serverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_url'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      epgUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_url'],
      ),
      createdAtMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_millis_utc'],
      )!,
    );
  }

  @override
  $AccountsTableTable createAlias(String alias) {
    return $AccountsTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AccountType, String, String> $convertertype =
      const EnumNameConverter<AccountType>(AccountType.values);
}

class AccountRow extends DataClass implements Insertable<AccountRow> {
  final String id;
  final AccountType type;
  final String name;
  final String serverUrl;
  final String username;

  /// Optional XMLTV EPG url for M3U accounts.
  final String? epgUrl;
  final int createdAtMillisUtc;
  const AccountRow({
    required this.id,
    required this.type,
    required this.name,
    required this.serverUrl,
    required this.username,
    this.epgUrl,
    required this.createdAtMillisUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['type'] = Variable<String>(
        $AccountsTableTable.$convertertype.toSql(type),
      );
    }
    map['name'] = Variable<String>(name);
    map['server_url'] = Variable<String>(serverUrl);
    map['username'] = Variable<String>(username);
    if (!nullToAbsent || epgUrl != null) {
      map['epg_url'] = Variable<String>(epgUrl);
    }
    map['created_at_millis_utc'] = Variable<int>(createdAtMillisUtc);
    return map;
  }

  AccountsTableCompanion toCompanion(bool nullToAbsent) {
    return AccountsTableCompanion(
      id: Value(id),
      type: Value(type),
      name: Value(name),
      serverUrl: Value(serverUrl),
      username: Value(username),
      epgUrl: epgUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(epgUrl),
      createdAtMillisUtc: Value(createdAtMillisUtc),
    );
  }

  factory AccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountRow(
      id: serializer.fromJson<String>(json['id']),
      type: $AccountsTableTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      name: serializer.fromJson<String>(json['name']),
      serverUrl: serializer.fromJson<String>(json['serverUrl']),
      username: serializer.fromJson<String>(json['username']),
      epgUrl: serializer.fromJson<String?>(json['epgUrl']),
      createdAtMillisUtc: serializer.fromJson<int>(json['createdAtMillisUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(
        $AccountsTableTable.$convertertype.toJson(type),
      ),
      'name': serializer.toJson<String>(name),
      'serverUrl': serializer.toJson<String>(serverUrl),
      'username': serializer.toJson<String>(username),
      'epgUrl': serializer.toJson<String?>(epgUrl),
      'createdAtMillisUtc': serializer.toJson<int>(createdAtMillisUtc),
    };
  }

  AccountRow copyWith({
    String? id,
    AccountType? type,
    String? name,
    String? serverUrl,
    String? username,
    Value<String?> epgUrl = const Value.absent(),
    int? createdAtMillisUtc,
  }) => AccountRow(
    id: id ?? this.id,
    type: type ?? this.type,
    name: name ?? this.name,
    serverUrl: serverUrl ?? this.serverUrl,
    username: username ?? this.username,
    epgUrl: epgUrl.present ? epgUrl.value : this.epgUrl,
    createdAtMillisUtc: createdAtMillisUtc ?? this.createdAtMillisUtc,
  );
  AccountRow copyWithCompanion(AccountsTableCompanion data) {
    return AccountRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      serverUrl: data.serverUrl.present ? data.serverUrl.value : this.serverUrl,
      username: data.username.present ? data.username.value : this.username,
      epgUrl: data.epgUrl.present ? data.epgUrl.value : this.epgUrl,
      createdAtMillisUtc: data.createdAtMillisUtc.present
          ? data.createdAtMillisUtc.value
          : this.createdAtMillisUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('serverUrl: $serverUrl, ')
          ..write('username: $username, ')
          ..write('epgUrl: $epgUrl, ')
          ..write('createdAtMillisUtc: $createdAtMillisUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    name,
    serverUrl,
    username,
    epgUrl,
    createdAtMillisUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.serverUrl == this.serverUrl &&
          other.username == this.username &&
          other.epgUrl == this.epgUrl &&
          other.createdAtMillisUtc == this.createdAtMillisUtc);
}

class AccountsTableCompanion extends UpdateCompanion<AccountRow> {
  final Value<String> id;
  final Value<AccountType> type;
  final Value<String> name;
  final Value<String> serverUrl;
  final Value<String> username;
  final Value<String?> epgUrl;
  final Value<int> createdAtMillisUtc;
  final Value<int> rowid;
  const AccountsTableCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.serverUrl = const Value.absent(),
    this.username = const Value.absent(),
    this.epgUrl = const Value.absent(),
    this.createdAtMillisUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsTableCompanion.insert({
    required String id,
    required AccountType type,
    required String name,
    required String serverUrl,
    required String username,
    this.epgUrl = const Value.absent(),
    required int createdAtMillisUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       name = Value(name),
       serverUrl = Value(serverUrl),
       username = Value(username),
       createdAtMillisUtc = Value(createdAtMillisUtc);
  static Insertable<AccountRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? name,
    Expression<String>? serverUrl,
    Expression<String>? username,
    Expression<String>? epgUrl,
    Expression<int>? createdAtMillisUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (serverUrl != null) 'server_url': serverUrl,
      if (username != null) 'username': username,
      if (epgUrl != null) 'epg_url': epgUrl,
      if (createdAtMillisUtc != null)
        'created_at_millis_utc': createdAtMillisUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsTableCompanion copyWith({
    Value<String>? id,
    Value<AccountType>? type,
    Value<String>? name,
    Value<String>? serverUrl,
    Value<String>? username,
    Value<String?>? epgUrl,
    Value<int>? createdAtMillisUtc,
    Value<int>? rowid,
  }) {
    return AccountsTableCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      epgUrl: epgUrl ?? this.epgUrl,
      createdAtMillisUtc: createdAtMillisUtc ?? this.createdAtMillisUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $AccountsTableTable.$convertertype.toSql(type.value),
      );
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (serverUrl.present) {
      map['server_url'] = Variable<String>(serverUrl.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (epgUrl.present) {
      map['epg_url'] = Variable<String>(epgUrl.value);
    }
    if (createdAtMillisUtc.present) {
      map['created_at_millis_utc'] = Variable<int>(createdAtMillisUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsTableCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('serverUrl: $serverUrl, ')
          ..write('username: $username, ')
          ..write('epgUrl: $epgUrl, ')
          ..write('createdAtMillisUtc: $createdAtMillisUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTableTable extends CategoriesTable
    with TableInfo<$CategoriesTableTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTableTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumnWithTypeConverter<CategoryType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CategoryType>($CategoriesTableTable.$convertertype);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, accountId, type, name, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, type, id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      type: $CategoriesTableTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $CategoriesTableTable createAlias(String alias) {
    return $CategoriesTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CategoryType, String, String> $convertertype =
      const EnumNameConverter<CategoryType>(CategoryType.values);
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final String id;
  final String accountId;
  final CategoryType type;
  final String name;
  final int sortOrder;
  const CategoryRow({
    required this.id,
    required this.accountId,
    required this.type,
    required this.name,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    {
      map['type'] = Variable<String>(
        $CategoriesTableTable.$convertertype.toSql(type),
      );
    }
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  CategoriesTableCompanion toCompanion(bool nullToAbsent) {
    return CategoriesTableCompanion(
      id: Value(id),
      accountId: Value(accountId),
      type: Value(type),
      name: Value(name),
      sortOrder: Value(sortOrder),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      type: $CategoriesTableTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'type': serializer.toJson<String>(
        $CategoriesTableTable.$convertertype.toJson(type),
      ),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  CategoryRow copyWith({
    String? id,
    String? accountId,
    CategoryType? type,
    String? name,
    int? sortOrder,
  }) => CategoryRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    type: type ?? this.type,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  CategoryRow copyWithCompanion(CategoriesTableCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, accountId, type, name, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.type == this.type &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder);
}

class CategoriesTableCompanion extends UpdateCompanion<CategoryRow> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<CategoryType> type;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const CategoriesTableCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesTableCompanion.insert({
    required String id,
    required String accountId,
    required CategoryType type,
    required String name,
    required int sortOrder,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       type = Value(type),
       name = Value(name),
       sortOrder = Value(sortOrder);
  static Insertable<CategoryRow> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? type,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<CategoryType>? type,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return CategoriesTableCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (type.present) {
      map['type'] = Variable<String>(
        $CategoriesTableTable.$convertertype.toSql(type.value),
      );
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesTableCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MoviesTableTable extends MoviesTable
    with TableInfo<$MoviesTableTable, MovieRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MoviesTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
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
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _posterUrlMeta = const VerificationMeta(
    'posterUrl',
  );
  @override
  late final GeneratedColumn<String> posterUrl = GeneratedColumn<String>(
    'poster_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backdropUrlMeta = const VerificationMeta(
    'backdropUrl',
  );
  @override
  late final GeneratedColumn<String> backdropUrl = GeneratedColumn<String>(
    'backdrop_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
    'plot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _castMeta = const VerificationMeta('cast');
  @override
  late final GeneratedColumn<String> cast = GeneratedColumn<String>(
    'cast',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _containerExtMeta = const VerificationMeta(
    'containerExt',
  );
  @override
  late final GeneratedColumn<String> containerExt = GeneratedColumn<String>(
    'container_ext',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMillisUtcMeta = const VerificationMeta(
    'addedAtMillisUtc',
  );
  @override
  late final GeneratedColumn<int> addedAtMillisUtc = GeneratedColumn<int>(
    'added_at_millis_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMillisUtcMeta = const VerificationMeta(
    'cachedAtMillisUtc',
  );
  @override
  late final GeneratedColumn<int> cachedAtMillisUtc = GeneratedColumn<int>(
    'cached_at_millis_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    categoryId,
    name,
    posterUrl,
    backdropUrl,
    rating,
    year,
    plot,
    genre,
    cast,
    durationSeconds,
    containerExt,
    addedAtMillisUtc,
    cachedAtMillisUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'movies';
  @override
  VerificationContext validateIntegrity(
    Insertable<MovieRow> instance, {
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
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('poster_url')) {
      context.handle(
        _posterUrlMeta,
        posterUrl.isAcceptableOrUnknown(data['poster_url']!, _posterUrlMeta),
      );
    }
    if (data.containsKey('backdrop_url')) {
      context.handle(
        _backdropUrlMeta,
        backdropUrl.isAcceptableOrUnknown(
          data['backdrop_url']!,
          _backdropUrlMeta,
        ),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('plot')) {
      context.handle(
        _plotMeta,
        plot.isAcceptableOrUnknown(data['plot']!, _plotMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('cast')) {
      context.handle(
        _castMeta,
        cast.isAcceptableOrUnknown(data['cast']!, _castMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('container_ext')) {
      context.handle(
        _containerExtMeta,
        containerExt.isAcceptableOrUnknown(
          data['container_ext']!,
          _containerExtMeta,
        ),
      );
    }
    if (data.containsKey('added_at_millis_utc')) {
      context.handle(
        _addedAtMillisUtcMeta,
        addedAtMillisUtc.isAcceptableOrUnknown(
          data['added_at_millis_utc']!,
          _addedAtMillisUtcMeta,
        ),
      );
    }
    if (data.containsKey('cached_at_millis_utc')) {
      context.handle(
        _cachedAtMillisUtcMeta,
        cachedAtMillisUtc.isAcceptableOrUnknown(
          data['cached_at_millis_utc']!,
          _cachedAtMillisUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMillisUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, id};
  @override
  MovieRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MovieRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      posterUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster_url'],
      ),
      backdropUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backdrop_url'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      plot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plot'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      cast: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cast'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      containerExt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}container_ext'],
      ),
      addedAtMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at_millis_utc'],
      ),
      cachedAtMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at_millis_utc'],
      )!,
    );
  }

  @override
  $MoviesTableTable createAlias(String alias) {
    return $MoviesTableTable(attachedDatabase, alias);
  }
}

class MovieRow extends DataClass implements Insertable<MovieRow> {
  final String id;
  final String accountId;
  final String categoryId;
  final String name;
  final String? posterUrl;
  final String? backdropUrl;
  final double? rating;
  final int? year;
  final String? plot;
  final String? genre;
  final String? cast;
  final int? durationSeconds;
  final String? containerExt;
  final int? addedAtMillisUtc;
  final int cachedAtMillisUtc;
  const MovieRow({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.name,
    this.posterUrl,
    this.backdropUrl,
    this.rating,
    this.year,
    this.plot,
    this.genre,
    this.cast,
    this.durationSeconds,
    this.containerExt,
    this.addedAtMillisUtc,
    required this.cachedAtMillisUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['category_id'] = Variable<String>(categoryId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || posterUrl != null) {
      map['poster_url'] = Variable<String>(posterUrl);
    }
    if (!nullToAbsent || backdropUrl != null) {
      map['backdrop_url'] = Variable<String>(backdropUrl);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || cast != null) {
      map['cast'] = Variable<String>(cast);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || containerExt != null) {
      map['container_ext'] = Variable<String>(containerExt);
    }
    if (!nullToAbsent || addedAtMillisUtc != null) {
      map['added_at_millis_utc'] = Variable<int>(addedAtMillisUtc);
    }
    map['cached_at_millis_utc'] = Variable<int>(cachedAtMillisUtc);
    return map;
  }

  MoviesTableCompanion toCompanion(bool nullToAbsent) {
    return MoviesTableCompanion(
      id: Value(id),
      accountId: Value(accountId),
      categoryId: Value(categoryId),
      name: Value(name),
      posterUrl: posterUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(posterUrl),
      backdropUrl: backdropUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropUrl),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      cast: cast == null && nullToAbsent ? const Value.absent() : Value(cast),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      containerExt: containerExt == null && nullToAbsent
          ? const Value.absent()
          : Value(containerExt),
      addedAtMillisUtc: addedAtMillisUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(addedAtMillisUtc),
      cachedAtMillisUtc: Value(cachedAtMillisUtc),
    );
  }

  factory MovieRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MovieRow(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      posterUrl: serializer.fromJson<String?>(json['posterUrl']),
      backdropUrl: serializer.fromJson<String?>(json['backdropUrl']),
      rating: serializer.fromJson<double?>(json['rating']),
      year: serializer.fromJson<int?>(json['year']),
      plot: serializer.fromJson<String?>(json['plot']),
      genre: serializer.fromJson<String?>(json['genre']),
      cast: serializer.fromJson<String?>(json['cast']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      containerExt: serializer.fromJson<String?>(json['containerExt']),
      addedAtMillisUtc: serializer.fromJson<int?>(json['addedAtMillisUtc']),
      cachedAtMillisUtc: serializer.fromJson<int>(json['cachedAtMillisUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'categoryId': serializer.toJson<String>(categoryId),
      'name': serializer.toJson<String>(name),
      'posterUrl': serializer.toJson<String?>(posterUrl),
      'backdropUrl': serializer.toJson<String?>(backdropUrl),
      'rating': serializer.toJson<double?>(rating),
      'year': serializer.toJson<int?>(year),
      'plot': serializer.toJson<String?>(plot),
      'genre': serializer.toJson<String?>(genre),
      'cast': serializer.toJson<String?>(cast),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'containerExt': serializer.toJson<String?>(containerExt),
      'addedAtMillisUtc': serializer.toJson<int?>(addedAtMillisUtc),
      'cachedAtMillisUtc': serializer.toJson<int>(cachedAtMillisUtc),
    };
  }

  MovieRow copyWith({
    String? id,
    String? accountId,
    String? categoryId,
    String? name,
    Value<String?> posterUrl = const Value.absent(),
    Value<String?> backdropUrl = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> plot = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<String?> cast = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    Value<String?> containerExt = const Value.absent(),
    Value<int?> addedAtMillisUtc = const Value.absent(),
    int? cachedAtMillisUtc,
  }) => MovieRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    categoryId: categoryId ?? this.categoryId,
    name: name ?? this.name,
    posterUrl: posterUrl.present ? posterUrl.value : this.posterUrl,
    backdropUrl: backdropUrl.present ? backdropUrl.value : this.backdropUrl,
    rating: rating.present ? rating.value : this.rating,
    year: year.present ? year.value : this.year,
    plot: plot.present ? plot.value : this.plot,
    genre: genre.present ? genre.value : this.genre,
    cast: cast.present ? cast.value : this.cast,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    containerExt: containerExt.present ? containerExt.value : this.containerExt,
    addedAtMillisUtc: addedAtMillisUtc.present
        ? addedAtMillisUtc.value
        : this.addedAtMillisUtc,
    cachedAtMillisUtc: cachedAtMillisUtc ?? this.cachedAtMillisUtc,
  );
  MovieRow copyWithCompanion(MoviesTableCompanion data) {
    return MovieRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      posterUrl: data.posterUrl.present ? data.posterUrl.value : this.posterUrl,
      backdropUrl: data.backdropUrl.present
          ? data.backdropUrl.value
          : this.backdropUrl,
      rating: data.rating.present ? data.rating.value : this.rating,
      year: data.year.present ? data.year.value : this.year,
      plot: data.plot.present ? data.plot.value : this.plot,
      genre: data.genre.present ? data.genre.value : this.genre,
      cast: data.cast.present ? data.cast.value : this.cast,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      containerExt: data.containerExt.present
          ? data.containerExt.value
          : this.containerExt,
      addedAtMillisUtc: data.addedAtMillisUtc.present
          ? data.addedAtMillisUtc.value
          : this.addedAtMillisUtc,
      cachedAtMillisUtc: data.cachedAtMillisUtc.present
          ? data.cachedAtMillisUtc.value
          : this.cachedAtMillisUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MovieRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('rating: $rating, ')
          ..write('year: $year, ')
          ..write('plot: $plot, ')
          ..write('genre: $genre, ')
          ..write('cast: $cast, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('containerExt: $containerExt, ')
          ..write('addedAtMillisUtc: $addedAtMillisUtc, ')
          ..write('cachedAtMillisUtc: $cachedAtMillisUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    categoryId,
    name,
    posterUrl,
    backdropUrl,
    rating,
    year,
    plot,
    genre,
    cast,
    durationSeconds,
    containerExt,
    addedAtMillisUtc,
    cachedAtMillisUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MovieRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.posterUrl == this.posterUrl &&
          other.backdropUrl == this.backdropUrl &&
          other.rating == this.rating &&
          other.year == this.year &&
          other.plot == this.plot &&
          other.genre == this.genre &&
          other.cast == this.cast &&
          other.durationSeconds == this.durationSeconds &&
          other.containerExt == this.containerExt &&
          other.addedAtMillisUtc == this.addedAtMillisUtc &&
          other.cachedAtMillisUtc == this.cachedAtMillisUtc);
}

class MoviesTableCompanion extends UpdateCompanion<MovieRow> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> categoryId;
  final Value<String> name;
  final Value<String?> posterUrl;
  final Value<String?> backdropUrl;
  final Value<double?> rating;
  final Value<int?> year;
  final Value<String?> plot;
  final Value<String?> genre;
  final Value<String?> cast;
  final Value<int?> durationSeconds;
  final Value<String?> containerExt;
  final Value<int?> addedAtMillisUtc;
  final Value<int> cachedAtMillisUtc;
  final Value<int> rowid;
  const MoviesTableCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.posterUrl = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.rating = const Value.absent(),
    this.year = const Value.absent(),
    this.plot = const Value.absent(),
    this.genre = const Value.absent(),
    this.cast = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.containerExt = const Value.absent(),
    this.addedAtMillisUtc = const Value.absent(),
    this.cachedAtMillisUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MoviesTableCompanion.insert({
    required String id,
    required String accountId,
    required String categoryId,
    required String name,
    this.posterUrl = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.rating = const Value.absent(),
    this.year = const Value.absent(),
    this.plot = const Value.absent(),
    this.genre = const Value.absent(),
    this.cast = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.containerExt = const Value.absent(),
    this.addedAtMillisUtc = const Value.absent(),
    required int cachedAtMillisUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       categoryId = Value(categoryId),
       name = Value(name),
       cachedAtMillisUtc = Value(cachedAtMillisUtc);
  static Insertable<MovieRow> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? categoryId,
    Expression<String>? name,
    Expression<String>? posterUrl,
    Expression<String>? backdropUrl,
    Expression<double>? rating,
    Expression<int>? year,
    Expression<String>? plot,
    Expression<String>? genre,
    Expression<String>? cast,
    Expression<int>? durationSeconds,
    Expression<String>? containerExt,
    Expression<int>? addedAtMillisUtc,
    Expression<int>? cachedAtMillisUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (posterUrl != null) 'poster_url': posterUrl,
      if (backdropUrl != null) 'backdrop_url': backdropUrl,
      if (rating != null) 'rating': rating,
      if (year != null) 'year': year,
      if (plot != null) 'plot': plot,
      if (genre != null) 'genre': genre,
      if (cast != null) 'cast': cast,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (containerExt != null) 'container_ext': containerExt,
      if (addedAtMillisUtc != null) 'added_at_millis_utc': addedAtMillisUtc,
      if (cachedAtMillisUtc != null) 'cached_at_millis_utc': cachedAtMillisUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MoviesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? categoryId,
    Value<String>? name,
    Value<String?>? posterUrl,
    Value<String?>? backdropUrl,
    Value<double?>? rating,
    Value<int?>? year,
    Value<String?>? plot,
    Value<String?>? genre,
    Value<String?>? cast,
    Value<int?>? durationSeconds,
    Value<String?>? containerExt,
    Value<int?>? addedAtMillisUtc,
    Value<int>? cachedAtMillisUtc,
    Value<int>? rowid,
  }) {
    return MoviesTableCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      rating: rating ?? this.rating,
      year: year ?? this.year,
      plot: plot ?? this.plot,
      genre: genre ?? this.genre,
      cast: cast ?? this.cast,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      containerExt: containerExt ?? this.containerExt,
      addedAtMillisUtc: addedAtMillisUtc ?? this.addedAtMillisUtc,
      cachedAtMillisUtc: cachedAtMillisUtc ?? this.cachedAtMillisUtc,
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
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (posterUrl.present) {
      map['poster_url'] = Variable<String>(posterUrl.value);
    }
    if (backdropUrl.present) {
      map['backdrop_url'] = Variable<String>(backdropUrl.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (cast.present) {
      map['cast'] = Variable<String>(cast.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (containerExt.present) {
      map['container_ext'] = Variable<String>(containerExt.value);
    }
    if (addedAtMillisUtc.present) {
      map['added_at_millis_utc'] = Variable<int>(addedAtMillisUtc.value);
    }
    if (cachedAtMillisUtc.present) {
      map['cached_at_millis_utc'] = Variable<int>(cachedAtMillisUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MoviesTableCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('rating: $rating, ')
          ..write('year: $year, ')
          ..write('plot: $plot, ')
          ..write('genre: $genre, ')
          ..write('cast: $cast, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('containerExt: $containerExt, ')
          ..write('addedAtMillisUtc: $addedAtMillisUtc, ')
          ..write('cachedAtMillisUtc: $cachedAtMillisUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeriesTableTable extends SeriesTable
    with TableInfo<$SeriesTableTable, SeriesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
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
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _posterUrlMeta = const VerificationMeta(
    'posterUrl',
  );
  @override
  late final GeneratedColumn<String> posterUrl = GeneratedColumn<String>(
    'poster_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backdropUrlMeta = const VerificationMeta(
    'backdropUrl',
  );
  @override
  late final GeneratedColumn<String> backdropUrl = GeneratedColumn<String>(
    'backdrop_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
    'plot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _castMeta = const VerificationMeta('cast');
  @override
  late final GeneratedColumn<String> cast = GeneratedColumn<String>(
    'cast',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMillisUtcMeta = const VerificationMeta(
    'cachedAtMillisUtc',
  );
  @override
  late final GeneratedColumn<int> cachedAtMillisUtc = GeneratedColumn<int>(
    'cached_at_millis_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    categoryId,
    name,
    posterUrl,
    backdropUrl,
    rating,
    year,
    plot,
    genre,
    cast,
    cachedAtMillisUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeriesRow> instance, {
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
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('poster_url')) {
      context.handle(
        _posterUrlMeta,
        posterUrl.isAcceptableOrUnknown(data['poster_url']!, _posterUrlMeta),
      );
    }
    if (data.containsKey('backdrop_url')) {
      context.handle(
        _backdropUrlMeta,
        backdropUrl.isAcceptableOrUnknown(
          data['backdrop_url']!,
          _backdropUrlMeta,
        ),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('plot')) {
      context.handle(
        _plotMeta,
        plot.isAcceptableOrUnknown(data['plot']!, _plotMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('cast')) {
      context.handle(
        _castMeta,
        cast.isAcceptableOrUnknown(data['cast']!, _castMeta),
      );
    }
    if (data.containsKey('cached_at_millis_utc')) {
      context.handle(
        _cachedAtMillisUtcMeta,
        cachedAtMillisUtc.isAcceptableOrUnknown(
          data['cached_at_millis_utc']!,
          _cachedAtMillisUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMillisUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, id};
  @override
  SeriesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeriesRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      posterUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster_url'],
      ),
      backdropUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backdrop_url'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      plot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plot'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      cast: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cast'],
      ),
      cachedAtMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at_millis_utc'],
      )!,
    );
  }

  @override
  $SeriesTableTable createAlias(String alias) {
    return $SeriesTableTable(attachedDatabase, alias);
  }
}

class SeriesRow extends DataClass implements Insertable<SeriesRow> {
  final String id;
  final String accountId;
  final String categoryId;
  final String name;
  final String? posterUrl;
  final String? backdropUrl;
  final double? rating;
  final int? year;
  final String? plot;
  final String? genre;
  final String? cast;
  final int cachedAtMillisUtc;
  const SeriesRow({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.name,
    this.posterUrl,
    this.backdropUrl,
    this.rating,
    this.year,
    this.plot,
    this.genre,
    this.cast,
    required this.cachedAtMillisUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['category_id'] = Variable<String>(categoryId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || posterUrl != null) {
      map['poster_url'] = Variable<String>(posterUrl);
    }
    if (!nullToAbsent || backdropUrl != null) {
      map['backdrop_url'] = Variable<String>(backdropUrl);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || cast != null) {
      map['cast'] = Variable<String>(cast);
    }
    map['cached_at_millis_utc'] = Variable<int>(cachedAtMillisUtc);
    return map;
  }

  SeriesTableCompanion toCompanion(bool nullToAbsent) {
    return SeriesTableCompanion(
      id: Value(id),
      accountId: Value(accountId),
      categoryId: Value(categoryId),
      name: Value(name),
      posterUrl: posterUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(posterUrl),
      backdropUrl: backdropUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropUrl),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      cast: cast == null && nullToAbsent ? const Value.absent() : Value(cast),
      cachedAtMillisUtc: Value(cachedAtMillisUtc),
    );
  }

  factory SeriesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeriesRow(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      posterUrl: serializer.fromJson<String?>(json['posterUrl']),
      backdropUrl: serializer.fromJson<String?>(json['backdropUrl']),
      rating: serializer.fromJson<double?>(json['rating']),
      year: serializer.fromJson<int?>(json['year']),
      plot: serializer.fromJson<String?>(json['plot']),
      genre: serializer.fromJson<String?>(json['genre']),
      cast: serializer.fromJson<String?>(json['cast']),
      cachedAtMillisUtc: serializer.fromJson<int>(json['cachedAtMillisUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'categoryId': serializer.toJson<String>(categoryId),
      'name': serializer.toJson<String>(name),
      'posterUrl': serializer.toJson<String?>(posterUrl),
      'backdropUrl': serializer.toJson<String?>(backdropUrl),
      'rating': serializer.toJson<double?>(rating),
      'year': serializer.toJson<int?>(year),
      'plot': serializer.toJson<String?>(plot),
      'genre': serializer.toJson<String?>(genre),
      'cast': serializer.toJson<String?>(cast),
      'cachedAtMillisUtc': serializer.toJson<int>(cachedAtMillisUtc),
    };
  }

  SeriesRow copyWith({
    String? id,
    String? accountId,
    String? categoryId,
    String? name,
    Value<String?> posterUrl = const Value.absent(),
    Value<String?> backdropUrl = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> plot = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<String?> cast = const Value.absent(),
    int? cachedAtMillisUtc,
  }) => SeriesRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    categoryId: categoryId ?? this.categoryId,
    name: name ?? this.name,
    posterUrl: posterUrl.present ? posterUrl.value : this.posterUrl,
    backdropUrl: backdropUrl.present ? backdropUrl.value : this.backdropUrl,
    rating: rating.present ? rating.value : this.rating,
    year: year.present ? year.value : this.year,
    plot: plot.present ? plot.value : this.plot,
    genre: genre.present ? genre.value : this.genre,
    cast: cast.present ? cast.value : this.cast,
    cachedAtMillisUtc: cachedAtMillisUtc ?? this.cachedAtMillisUtc,
  );
  SeriesRow copyWithCompanion(SeriesTableCompanion data) {
    return SeriesRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      posterUrl: data.posterUrl.present ? data.posterUrl.value : this.posterUrl,
      backdropUrl: data.backdropUrl.present
          ? data.backdropUrl.value
          : this.backdropUrl,
      rating: data.rating.present ? data.rating.value : this.rating,
      year: data.year.present ? data.year.value : this.year,
      plot: data.plot.present ? data.plot.value : this.plot,
      genre: data.genre.present ? data.genre.value : this.genre,
      cast: data.cast.present ? data.cast.value : this.cast,
      cachedAtMillisUtc: data.cachedAtMillisUtc.present
          ? data.cachedAtMillisUtc.value
          : this.cachedAtMillisUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeriesRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('rating: $rating, ')
          ..write('year: $year, ')
          ..write('plot: $plot, ')
          ..write('genre: $genre, ')
          ..write('cast: $cast, ')
          ..write('cachedAtMillisUtc: $cachedAtMillisUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    categoryId,
    name,
    posterUrl,
    backdropUrl,
    rating,
    year,
    plot,
    genre,
    cast,
    cachedAtMillisUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.posterUrl == this.posterUrl &&
          other.backdropUrl == this.backdropUrl &&
          other.rating == this.rating &&
          other.year == this.year &&
          other.plot == this.plot &&
          other.genre == this.genre &&
          other.cast == this.cast &&
          other.cachedAtMillisUtc == this.cachedAtMillisUtc);
}

class SeriesTableCompanion extends UpdateCompanion<SeriesRow> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> categoryId;
  final Value<String> name;
  final Value<String?> posterUrl;
  final Value<String?> backdropUrl;
  final Value<double?> rating;
  final Value<int?> year;
  final Value<String?> plot;
  final Value<String?> genre;
  final Value<String?> cast;
  final Value<int> cachedAtMillisUtc;
  final Value<int> rowid;
  const SeriesTableCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.posterUrl = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.rating = const Value.absent(),
    this.year = const Value.absent(),
    this.plot = const Value.absent(),
    this.genre = const Value.absent(),
    this.cast = const Value.absent(),
    this.cachedAtMillisUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeriesTableCompanion.insert({
    required String id,
    required String accountId,
    required String categoryId,
    required String name,
    this.posterUrl = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.rating = const Value.absent(),
    this.year = const Value.absent(),
    this.plot = const Value.absent(),
    this.genre = const Value.absent(),
    this.cast = const Value.absent(),
    required int cachedAtMillisUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       categoryId = Value(categoryId),
       name = Value(name),
       cachedAtMillisUtc = Value(cachedAtMillisUtc);
  static Insertable<SeriesRow> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? categoryId,
    Expression<String>? name,
    Expression<String>? posterUrl,
    Expression<String>? backdropUrl,
    Expression<double>? rating,
    Expression<int>? year,
    Expression<String>? plot,
    Expression<String>? genre,
    Expression<String>? cast,
    Expression<int>? cachedAtMillisUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (posterUrl != null) 'poster_url': posterUrl,
      if (backdropUrl != null) 'backdrop_url': backdropUrl,
      if (rating != null) 'rating': rating,
      if (year != null) 'year': year,
      if (plot != null) 'plot': plot,
      if (genre != null) 'genre': genre,
      if (cast != null) 'cast': cast,
      if (cachedAtMillisUtc != null) 'cached_at_millis_utc': cachedAtMillisUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeriesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? categoryId,
    Value<String>? name,
    Value<String?>? posterUrl,
    Value<String?>? backdropUrl,
    Value<double?>? rating,
    Value<int?>? year,
    Value<String?>? plot,
    Value<String?>? genre,
    Value<String?>? cast,
    Value<int>? cachedAtMillisUtc,
    Value<int>? rowid,
  }) {
    return SeriesTableCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      rating: rating ?? this.rating,
      year: year ?? this.year,
      plot: plot ?? this.plot,
      genre: genre ?? this.genre,
      cast: cast ?? this.cast,
      cachedAtMillisUtc: cachedAtMillisUtc ?? this.cachedAtMillisUtc,
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
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (posterUrl.present) {
      map['poster_url'] = Variable<String>(posterUrl.value);
    }
    if (backdropUrl.present) {
      map['backdrop_url'] = Variable<String>(backdropUrl.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (cast.present) {
      map['cast'] = Variable<String>(cast.value);
    }
    if (cachedAtMillisUtc.present) {
      map['cached_at_millis_utc'] = Variable<int>(cachedAtMillisUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesTableCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('rating: $rating, ')
          ..write('year: $year, ')
          ..write('plot: $plot, ')
          ..write('genre: $genre, ')
          ..write('cast: $cast, ')
          ..write('cachedAtMillisUtc: $cachedAtMillisUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpisodesTableTable extends EpisodesTable
    with TableInfo<$EpisodesTableTable, EpisodeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodesTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seasonNumberMeta = const VerificationMeta(
    'seasonNumber',
  );
  @override
  late final GeneratedColumn<int> seasonNumber = GeneratedColumn<int>(
    'season_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeNumberMeta = const VerificationMeta(
    'episodeNumber',
  );
  @override
  late final GeneratedColumn<int> episodeNumber = GeneratedColumn<int>(
    'episode_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
    'plot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stillUrlMeta = const VerificationMeta(
    'stillUrl',
  );
  @override
  late final GeneratedColumn<String> stillUrl = GeneratedColumn<String>(
    'still_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _containerExtMeta = const VerificationMeta(
    'containerExt',
  );
  @override
  late final GeneratedColumn<String> containerExt = GeneratedColumn<String>(
    'container_ext',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _airDateMillisUtcMeta = const VerificationMeta(
    'airDateMillisUtc',
  );
  @override
  late final GeneratedColumn<int> airDateMillisUtc = GeneratedColumn<int>(
    'air_date_millis_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMillisUtcMeta = const VerificationMeta(
    'cachedAtMillisUtc',
  );
  @override
  late final GeneratedColumn<int> cachedAtMillisUtc = GeneratedColumn<int>(
    'cached_at_millis_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    seriesId,
    seasonNumber,
    episodeNumber,
    title,
    plot,
    durationSeconds,
    stillUrl,
    containerExt,
    airDateMillisUtc,
    cachedAtMillisUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpisodeRow> instance, {
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
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesIdMeta);
    }
    if (data.containsKey('season_number')) {
      context.handle(
        _seasonNumberMeta,
        seasonNumber.isAcceptableOrUnknown(
          data['season_number']!,
          _seasonNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_seasonNumberMeta);
    }
    if (data.containsKey('episode_number')) {
      context.handle(
        _episodeNumberMeta,
        episodeNumber.isAcceptableOrUnknown(
          data['episode_number']!,
          _episodeNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_episodeNumberMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('plot')) {
      context.handle(
        _plotMeta,
        plot.isAcceptableOrUnknown(data['plot']!, _plotMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('still_url')) {
      context.handle(
        _stillUrlMeta,
        stillUrl.isAcceptableOrUnknown(data['still_url']!, _stillUrlMeta),
      );
    }
    if (data.containsKey('container_ext')) {
      context.handle(
        _containerExtMeta,
        containerExt.isAcceptableOrUnknown(
          data['container_ext']!,
          _containerExtMeta,
        ),
      );
    }
    if (data.containsKey('air_date_millis_utc')) {
      context.handle(
        _airDateMillisUtcMeta,
        airDateMillisUtc.isAcceptableOrUnknown(
          data['air_date_millis_utc']!,
          _airDateMillisUtcMeta,
        ),
      );
    }
    if (data.containsKey('cached_at_millis_utc')) {
      context.handle(
        _cachedAtMillisUtcMeta,
        cachedAtMillisUtc.isAcceptableOrUnknown(
          data['cached_at_millis_utc']!,
          _cachedAtMillisUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMillisUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, id};
  @override
  EpisodeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      )!,
      seasonNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season_number'],
      )!,
      episodeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_number'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      plot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plot'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      stillUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}still_url'],
      ),
      containerExt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}container_ext'],
      ),
      airDateMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}air_date_millis_utc'],
      ),
      cachedAtMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at_millis_utc'],
      )!,
    );
  }

  @override
  $EpisodesTableTable createAlias(String alias) {
    return $EpisodesTableTable(attachedDatabase, alias);
  }
}

class EpisodeRow extends DataClass implements Insertable<EpisodeRow> {
  final String id;
  final String accountId;
  final String seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final String title;
  final String? plot;
  final int? durationSeconds;
  final String? stillUrl;
  final String? containerExt;
  final int? airDateMillisUtc;
  final int cachedAtMillisUtc;
  const EpisodeRow({
    required this.id,
    required this.accountId,
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
    this.plot,
    this.durationSeconds,
    this.stillUrl,
    this.containerExt,
    this.airDateMillisUtc,
    required this.cachedAtMillisUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['series_id'] = Variable<String>(seriesId);
    map['season_number'] = Variable<int>(seasonNumber);
    map['episode_number'] = Variable<int>(episodeNumber);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || stillUrl != null) {
      map['still_url'] = Variable<String>(stillUrl);
    }
    if (!nullToAbsent || containerExt != null) {
      map['container_ext'] = Variable<String>(containerExt);
    }
    if (!nullToAbsent || airDateMillisUtc != null) {
      map['air_date_millis_utc'] = Variable<int>(airDateMillisUtc);
    }
    map['cached_at_millis_utc'] = Variable<int>(cachedAtMillisUtc);
    return map;
  }

  EpisodesTableCompanion toCompanion(bool nullToAbsent) {
    return EpisodesTableCompanion(
      id: Value(id),
      accountId: Value(accountId),
      seriesId: Value(seriesId),
      seasonNumber: Value(seasonNumber),
      episodeNumber: Value(episodeNumber),
      title: Value(title),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      stillUrl: stillUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(stillUrl),
      containerExt: containerExt == null && nullToAbsent
          ? const Value.absent()
          : Value(containerExt),
      airDateMillisUtc: airDateMillisUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(airDateMillisUtc),
      cachedAtMillisUtc: Value(cachedAtMillisUtc),
    );
  }

  factory EpisodeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodeRow(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      seriesId: serializer.fromJson<String>(json['seriesId']),
      seasonNumber: serializer.fromJson<int>(json['seasonNumber']),
      episodeNumber: serializer.fromJson<int>(json['episodeNumber']),
      title: serializer.fromJson<String>(json['title']),
      plot: serializer.fromJson<String?>(json['plot']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      stillUrl: serializer.fromJson<String?>(json['stillUrl']),
      containerExt: serializer.fromJson<String?>(json['containerExt']),
      airDateMillisUtc: serializer.fromJson<int?>(json['airDateMillisUtc']),
      cachedAtMillisUtc: serializer.fromJson<int>(json['cachedAtMillisUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'seriesId': serializer.toJson<String>(seriesId),
      'seasonNumber': serializer.toJson<int>(seasonNumber),
      'episodeNumber': serializer.toJson<int>(episodeNumber),
      'title': serializer.toJson<String>(title),
      'plot': serializer.toJson<String?>(plot),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'stillUrl': serializer.toJson<String?>(stillUrl),
      'containerExt': serializer.toJson<String?>(containerExt),
      'airDateMillisUtc': serializer.toJson<int?>(airDateMillisUtc),
      'cachedAtMillisUtc': serializer.toJson<int>(cachedAtMillisUtc),
    };
  }

  EpisodeRow copyWith({
    String? id,
    String? accountId,
    String? seriesId,
    int? seasonNumber,
    int? episodeNumber,
    String? title,
    Value<String?> plot = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    Value<String?> stillUrl = const Value.absent(),
    Value<String?> containerExt = const Value.absent(),
    Value<int?> airDateMillisUtc = const Value.absent(),
    int? cachedAtMillisUtc,
  }) => EpisodeRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    seriesId: seriesId ?? this.seriesId,
    seasonNumber: seasonNumber ?? this.seasonNumber,
    episodeNumber: episodeNumber ?? this.episodeNumber,
    title: title ?? this.title,
    plot: plot.present ? plot.value : this.plot,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    stillUrl: stillUrl.present ? stillUrl.value : this.stillUrl,
    containerExt: containerExt.present ? containerExt.value : this.containerExt,
    airDateMillisUtc: airDateMillisUtc.present
        ? airDateMillisUtc.value
        : this.airDateMillisUtc,
    cachedAtMillisUtc: cachedAtMillisUtc ?? this.cachedAtMillisUtc,
  );
  EpisodeRow copyWithCompanion(EpisodesTableCompanion data) {
    return EpisodeRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      seasonNumber: data.seasonNumber.present
          ? data.seasonNumber.value
          : this.seasonNumber,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      title: data.title.present ? data.title.value : this.title,
      plot: data.plot.present ? data.plot.value : this.plot,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      stillUrl: data.stillUrl.present ? data.stillUrl.value : this.stillUrl,
      containerExt: data.containerExt.present
          ? data.containerExt.value
          : this.containerExt,
      airDateMillisUtc: data.airDateMillisUtc.present
          ? data.airDateMillisUtc.value
          : this.airDateMillisUtc,
      cachedAtMillisUtc: data.cachedAtMillisUtc.present
          ? data.cachedAtMillisUtc.value
          : this.cachedAtMillisUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('seriesId: $seriesId, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('title: $title, ')
          ..write('plot: $plot, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('stillUrl: $stillUrl, ')
          ..write('containerExt: $containerExt, ')
          ..write('airDateMillisUtc: $airDateMillisUtc, ')
          ..write('cachedAtMillisUtc: $cachedAtMillisUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    seriesId,
    seasonNumber,
    episodeNumber,
    title,
    plot,
    durationSeconds,
    stillUrl,
    containerExt,
    airDateMillisUtc,
    cachedAtMillisUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.seriesId == this.seriesId &&
          other.seasonNumber == this.seasonNumber &&
          other.episodeNumber == this.episodeNumber &&
          other.title == this.title &&
          other.plot == this.plot &&
          other.durationSeconds == this.durationSeconds &&
          other.stillUrl == this.stillUrl &&
          other.containerExt == this.containerExt &&
          other.airDateMillisUtc == this.airDateMillisUtc &&
          other.cachedAtMillisUtc == this.cachedAtMillisUtc);
}

class EpisodesTableCompanion extends UpdateCompanion<EpisodeRow> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> seriesId;
  final Value<int> seasonNumber;
  final Value<int> episodeNumber;
  final Value<String> title;
  final Value<String?> plot;
  final Value<int?> durationSeconds;
  final Value<String?> stillUrl;
  final Value<String?> containerExt;
  final Value<int?> airDateMillisUtc;
  final Value<int> cachedAtMillisUtc;
  final Value<int> rowid;
  const EpisodesTableCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.seasonNumber = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.title = const Value.absent(),
    this.plot = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.stillUrl = const Value.absent(),
    this.containerExt = const Value.absent(),
    this.airDateMillisUtc = const Value.absent(),
    this.cachedAtMillisUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpisodesTableCompanion.insert({
    required String id,
    required String accountId,
    required String seriesId,
    required int seasonNumber,
    required int episodeNumber,
    required String title,
    this.plot = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.stillUrl = const Value.absent(),
    this.containerExt = const Value.absent(),
    this.airDateMillisUtc = const Value.absent(),
    required int cachedAtMillisUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       seriesId = Value(seriesId),
       seasonNumber = Value(seasonNumber),
       episodeNumber = Value(episodeNumber),
       title = Value(title),
       cachedAtMillisUtc = Value(cachedAtMillisUtc);
  static Insertable<EpisodeRow> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? seriesId,
    Expression<int>? seasonNumber,
    Expression<int>? episodeNumber,
    Expression<String>? title,
    Expression<String>? plot,
    Expression<int>? durationSeconds,
    Expression<String>? stillUrl,
    Expression<String>? containerExt,
    Expression<int>? airDateMillisUtc,
    Expression<int>? cachedAtMillisUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (seriesId != null) 'series_id': seriesId,
      if (seasonNumber != null) 'season_number': seasonNumber,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (title != null) 'title': title,
      if (plot != null) 'plot': plot,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (stillUrl != null) 'still_url': stillUrl,
      if (containerExt != null) 'container_ext': containerExt,
      if (airDateMillisUtc != null) 'air_date_millis_utc': airDateMillisUtc,
      if (cachedAtMillisUtc != null) 'cached_at_millis_utc': cachedAtMillisUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpisodesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? seriesId,
    Value<int>? seasonNumber,
    Value<int>? episodeNumber,
    Value<String>? title,
    Value<String?>? plot,
    Value<int?>? durationSeconds,
    Value<String?>? stillUrl,
    Value<String?>? containerExt,
    Value<int?>? airDateMillisUtc,
    Value<int>? cachedAtMillisUtc,
    Value<int>? rowid,
  }) {
    return EpisodesTableCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      seriesId: seriesId ?? this.seriesId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      plot: plot ?? this.plot,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      stillUrl: stillUrl ?? this.stillUrl,
      containerExt: containerExt ?? this.containerExt,
      airDateMillisUtc: airDateMillisUtc ?? this.airDateMillisUtc,
      cachedAtMillisUtc: cachedAtMillisUtc ?? this.cachedAtMillisUtc,
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
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (seasonNumber.present) {
      map['season_number'] = Variable<int>(seasonNumber.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<int>(episodeNumber.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (stillUrl.present) {
      map['still_url'] = Variable<String>(stillUrl.value);
    }
    if (containerExt.present) {
      map['container_ext'] = Variable<String>(containerExt.value);
    }
    if (airDateMillisUtc.present) {
      map['air_date_millis_utc'] = Variable<int>(airDateMillisUtc.value);
    }
    if (cachedAtMillisUtc.present) {
      map['cached_at_millis_utc'] = Variable<int>(cachedAtMillisUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodesTableCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('seriesId: $seriesId, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('title: $title, ')
          ..write('plot: $plot, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('stillUrl: $stillUrl, ')
          ..write('containerExt: $containerExt, ')
          ..write('airDateMillisUtc: $airDateMillisUtc, ')
          ..write('cachedAtMillisUtc: $cachedAtMillisUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChannelsTableTable extends ChannelsTable
    with TableInfo<$ChannelsTableTable, ChannelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChannelsTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
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
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _logoUrlMeta = const VerificationMeta(
    'logoUrl',
  );
  @override
  late final GeneratedColumn<String> logoUrl = GeneratedColumn<String>(
    'logo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _epgChannelIdMeta = const VerificationMeta(
    'epgChannelId',
  );
  @override
  late final GeneratedColumn<String> epgChannelId = GeneratedColumn<String>(
    'epg_channel_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMillisUtcMeta = const VerificationMeta(
    'cachedAtMillisUtc',
  );
  @override
  late final GeneratedColumn<int> cachedAtMillisUtc = GeneratedColumn<int>(
    'cached_at_millis_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    categoryId,
    name,
    logoUrl,
    epgChannelId,
    sortOrder,
    cachedAtMillisUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChannelRow> instance, {
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
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('logo_url')) {
      context.handle(
        _logoUrlMeta,
        logoUrl.isAcceptableOrUnknown(data['logo_url']!, _logoUrlMeta),
      );
    }
    if (data.containsKey('epg_channel_id')) {
      context.handle(
        _epgChannelIdMeta,
        epgChannelId.isAcceptableOrUnknown(
          data['epg_channel_id']!,
          _epgChannelIdMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('cached_at_millis_utc')) {
      context.handle(
        _cachedAtMillisUtcMeta,
        cachedAtMillisUtc.isAcceptableOrUnknown(
          data['cached_at_millis_utc']!,
          _cachedAtMillisUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMillisUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, id};
  @override
  ChannelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChannelRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      logoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_url'],
      ),
      epgChannelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_channel_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      ),
      cachedAtMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at_millis_utc'],
      )!,
    );
  }

  @override
  $ChannelsTableTable createAlias(String alias) {
    return $ChannelsTableTable(attachedDatabase, alias);
  }
}

class ChannelRow extends DataClass implements Insertable<ChannelRow> {
  final String id;
  final String accountId;
  final String categoryId;
  final String name;
  final String? logoUrl;
  final String? epgChannelId;
  final int? sortOrder;
  final int cachedAtMillisUtc;
  const ChannelRow({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.name,
    this.logoUrl,
    this.epgChannelId,
    this.sortOrder,
    required this.cachedAtMillisUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['category_id'] = Variable<String>(categoryId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || logoUrl != null) {
      map['logo_url'] = Variable<String>(logoUrl);
    }
    if (!nullToAbsent || epgChannelId != null) {
      map['epg_channel_id'] = Variable<String>(epgChannelId);
    }
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<int>(sortOrder);
    }
    map['cached_at_millis_utc'] = Variable<int>(cachedAtMillisUtc);
    return map;
  }

  ChannelsTableCompanion toCompanion(bool nullToAbsent) {
    return ChannelsTableCompanion(
      id: Value(id),
      accountId: Value(accountId),
      categoryId: Value(categoryId),
      name: Value(name),
      logoUrl: logoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(logoUrl),
      epgChannelId: epgChannelId == null && nullToAbsent
          ? const Value.absent()
          : Value(epgChannelId),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
      cachedAtMillisUtc: Value(cachedAtMillisUtc),
    );
  }

  factory ChannelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChannelRow(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      logoUrl: serializer.fromJson<String?>(json['logoUrl']),
      epgChannelId: serializer.fromJson<String?>(json['epgChannelId']),
      sortOrder: serializer.fromJson<int?>(json['sortOrder']),
      cachedAtMillisUtc: serializer.fromJson<int>(json['cachedAtMillisUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'categoryId': serializer.toJson<String>(categoryId),
      'name': serializer.toJson<String>(name),
      'logoUrl': serializer.toJson<String?>(logoUrl),
      'epgChannelId': serializer.toJson<String?>(epgChannelId),
      'sortOrder': serializer.toJson<int?>(sortOrder),
      'cachedAtMillisUtc': serializer.toJson<int>(cachedAtMillisUtc),
    };
  }

  ChannelRow copyWith({
    String? id,
    String? accountId,
    String? categoryId,
    String? name,
    Value<String?> logoUrl = const Value.absent(),
    Value<String?> epgChannelId = const Value.absent(),
    Value<int?> sortOrder = const Value.absent(),
    int? cachedAtMillisUtc,
  }) => ChannelRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    categoryId: categoryId ?? this.categoryId,
    name: name ?? this.name,
    logoUrl: logoUrl.present ? logoUrl.value : this.logoUrl,
    epgChannelId: epgChannelId.present ? epgChannelId.value : this.epgChannelId,
    sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
    cachedAtMillisUtc: cachedAtMillisUtc ?? this.cachedAtMillisUtc,
  );
  ChannelRow copyWithCompanion(ChannelsTableCompanion data) {
    return ChannelRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      logoUrl: data.logoUrl.present ? data.logoUrl.value : this.logoUrl,
      epgChannelId: data.epgChannelId.present
          ? data.epgChannelId.value
          : this.epgChannelId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      cachedAtMillisUtc: data.cachedAtMillisUtc.present
          ? data.cachedAtMillisUtc.value
          : this.cachedAtMillisUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChannelRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('cachedAtMillisUtc: $cachedAtMillisUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    categoryId,
    name,
    logoUrl,
    epgChannelId,
    sortOrder,
    cachedAtMillisUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChannelRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.logoUrl == this.logoUrl &&
          other.epgChannelId == this.epgChannelId &&
          other.sortOrder == this.sortOrder &&
          other.cachedAtMillisUtc == this.cachedAtMillisUtc);
}

class ChannelsTableCompanion extends UpdateCompanion<ChannelRow> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> categoryId;
  final Value<String> name;
  final Value<String?> logoUrl;
  final Value<String?> epgChannelId;
  final Value<int?> sortOrder;
  final Value<int> cachedAtMillisUtc;
  final Value<int> rowid;
  const ChannelsTableCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.epgChannelId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.cachedAtMillisUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChannelsTableCompanion.insert({
    required String id,
    required String accountId,
    required String categoryId,
    required String name,
    this.logoUrl = const Value.absent(),
    this.epgChannelId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int cachedAtMillisUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       categoryId = Value(categoryId),
       name = Value(name),
       cachedAtMillisUtc = Value(cachedAtMillisUtc);
  static Insertable<ChannelRow> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? categoryId,
    Expression<String>? name,
    Expression<String>? logoUrl,
    Expression<String>? epgChannelId,
    Expression<int>? sortOrder,
    Expression<int>? cachedAtMillisUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (epgChannelId != null) 'epg_channel_id': epgChannelId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (cachedAtMillisUtc != null) 'cached_at_millis_utc': cachedAtMillisUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChannelsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? categoryId,
    Value<String>? name,
    Value<String?>? logoUrl,
    Value<String?>? epgChannelId,
    Value<int?>? sortOrder,
    Value<int>? cachedAtMillisUtc,
    Value<int>? rowid,
  }) {
    return ChannelsTableCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      sortOrder: sortOrder ?? this.sortOrder,
      cachedAtMillisUtc: cachedAtMillisUtc ?? this.cachedAtMillisUtc,
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
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (logoUrl.present) {
      map['logo_url'] = Variable<String>(logoUrl.value);
    }
    if (epgChannelId.present) {
      map['epg_channel_id'] = Variable<String>(epgChannelId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (cachedAtMillisUtc.present) {
      map['cached_at_millis_utc'] = Variable<int>(cachedAtMillisUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChannelsTableCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('cachedAtMillisUtc: $cachedAtMillisUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchProgressTableTable extends WatchProgressTable
    with TableInfo<$WatchProgressTableTable, WatchProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchProgressTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentKeyMeta = const VerificationMeta(
    'contentKey',
  );
  @override
  late final GeneratedColumn<String> contentKey = GeneratedColumn<String>(
    'content_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionSecondsMeta = const VerificationMeta(
    'positionSeconds',
  );
  @override
  late final GeneratedColumn<int> positionSeconds = GeneratedColumn<int>(
    'position_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMillisUtcMeta =
      const VerificationMeta('updatedAtMillisUtc');
  @override
  late final GeneratedColumn<int> updatedAtMillisUtc = GeneratedColumn<int>(
    'updated_at_millis_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMillisUtcMeta = const VerificationMeta(
    'syncedAtMillisUtc',
  );
  @override
  late final GeneratedColumn<int> syncedAtMillisUtc = GeneratedColumn<int>(
    'synced_at_millis_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    contentKey,
    positionSeconds,
    durationSeconds,
    updatedAtMillisUtc,
    syncedAtMillisUtc,
    completed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_key')) {
      context.handle(
        _contentKeyMeta,
        contentKey.isAcceptableOrUnknown(data['content_key']!, _contentKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_contentKeyMeta);
    }
    if (data.containsKey('position_seconds')) {
      context.handle(
        _positionSecondsMeta,
        positionSeconds.isAcceptableOrUnknown(
          data['position_seconds']!,
          _positionSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_positionSecondsMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('updated_at_millis_utc')) {
      context.handle(
        _updatedAtMillisUtcMeta,
        updatedAtMillisUtc.isAcceptableOrUnknown(
          data['updated_at_millis_utc']!,
          _updatedAtMillisUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMillisUtcMeta);
    }
    if (data.containsKey('synced_at_millis_utc')) {
      context.handle(
        _syncedAtMillisUtcMeta,
        syncedAtMillisUtc.isAcceptableOrUnknown(
          data['synced_at_millis_utc']!,
          _syncedAtMillisUtcMeta,
        ),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentKey};
  @override
  WatchProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchProgressRow(
      contentKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_key'],
      )!,
      positionSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_seconds'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      updatedAtMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_millis_utc'],
      )!,
      syncedAtMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at_millis_utc'],
      ),
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
    );
  }

  @override
  $WatchProgressTableTable createAlias(String alias) {
    return $WatchProgressTableTable(attachedDatabase, alias);
  }
}

class WatchProgressRow extends DataClass
    implements Insertable<WatchProgressRow> {
  /// `account:type:id` (see `contentKeyFor`).
  final String contentKey;
  final int positionSeconds;
  final int durationSeconds;

  /// Last-write-wins key for the future sync backend (PRD §9).
  final int updatedAtMillisUtc;
  final int? syncedAtMillisUtc;
  final bool completed;
  const WatchProgressRow({
    required this.contentKey,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.updatedAtMillisUtc,
    this.syncedAtMillisUtc,
    required this.completed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_key'] = Variable<String>(contentKey);
    map['position_seconds'] = Variable<int>(positionSeconds);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['updated_at_millis_utc'] = Variable<int>(updatedAtMillisUtc);
    if (!nullToAbsent || syncedAtMillisUtc != null) {
      map['synced_at_millis_utc'] = Variable<int>(syncedAtMillisUtc);
    }
    map['completed'] = Variable<bool>(completed);
    return map;
  }

  WatchProgressTableCompanion toCompanion(bool nullToAbsent) {
    return WatchProgressTableCompanion(
      contentKey: Value(contentKey),
      positionSeconds: Value(positionSeconds),
      durationSeconds: Value(durationSeconds),
      updatedAtMillisUtc: Value(updatedAtMillisUtc),
      syncedAtMillisUtc: syncedAtMillisUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAtMillisUtc),
      completed: Value(completed),
    );
  }

  factory WatchProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchProgressRow(
      contentKey: serializer.fromJson<String>(json['contentKey']),
      positionSeconds: serializer.fromJson<int>(json['positionSeconds']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      updatedAtMillisUtc: serializer.fromJson<int>(json['updatedAtMillisUtc']),
      syncedAtMillisUtc: serializer.fromJson<int?>(json['syncedAtMillisUtc']),
      completed: serializer.fromJson<bool>(json['completed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentKey': serializer.toJson<String>(contentKey),
      'positionSeconds': serializer.toJson<int>(positionSeconds),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'updatedAtMillisUtc': serializer.toJson<int>(updatedAtMillisUtc),
      'syncedAtMillisUtc': serializer.toJson<int?>(syncedAtMillisUtc),
      'completed': serializer.toJson<bool>(completed),
    };
  }

  WatchProgressRow copyWith({
    String? contentKey,
    int? positionSeconds,
    int? durationSeconds,
    int? updatedAtMillisUtc,
    Value<int?> syncedAtMillisUtc = const Value.absent(),
    bool? completed,
  }) => WatchProgressRow(
    contentKey: contentKey ?? this.contentKey,
    positionSeconds: positionSeconds ?? this.positionSeconds,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    updatedAtMillisUtc: updatedAtMillisUtc ?? this.updatedAtMillisUtc,
    syncedAtMillisUtc: syncedAtMillisUtc.present
        ? syncedAtMillisUtc.value
        : this.syncedAtMillisUtc,
    completed: completed ?? this.completed,
  );
  WatchProgressRow copyWithCompanion(WatchProgressTableCompanion data) {
    return WatchProgressRow(
      contentKey: data.contentKey.present
          ? data.contentKey.value
          : this.contentKey,
      positionSeconds: data.positionSeconds.present
          ? data.positionSeconds.value
          : this.positionSeconds,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      updatedAtMillisUtc: data.updatedAtMillisUtc.present
          ? data.updatedAtMillisUtc.value
          : this.updatedAtMillisUtc,
      syncedAtMillisUtc: data.syncedAtMillisUtc.present
          ? data.syncedAtMillisUtc.value
          : this.syncedAtMillisUtc,
      completed: data.completed.present ? data.completed.value : this.completed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchProgressRow(')
          ..write('contentKey: $contentKey, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('updatedAtMillisUtc: $updatedAtMillisUtc, ')
          ..write('syncedAtMillisUtc: $syncedAtMillisUtc, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    contentKey,
    positionSeconds,
    durationSeconds,
    updatedAtMillisUtc,
    syncedAtMillisUtc,
    completed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchProgressRow &&
          other.contentKey == this.contentKey &&
          other.positionSeconds == this.positionSeconds &&
          other.durationSeconds == this.durationSeconds &&
          other.updatedAtMillisUtc == this.updatedAtMillisUtc &&
          other.syncedAtMillisUtc == this.syncedAtMillisUtc &&
          other.completed == this.completed);
}

class WatchProgressTableCompanion extends UpdateCompanion<WatchProgressRow> {
  final Value<String> contentKey;
  final Value<int> positionSeconds;
  final Value<int> durationSeconds;
  final Value<int> updatedAtMillisUtc;
  final Value<int?> syncedAtMillisUtc;
  final Value<bool> completed;
  final Value<int> rowid;
  const WatchProgressTableCompanion({
    this.contentKey = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.updatedAtMillisUtc = const Value.absent(),
    this.syncedAtMillisUtc = const Value.absent(),
    this.completed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchProgressTableCompanion.insert({
    required String contentKey,
    required int positionSeconds,
    required int durationSeconds,
    required int updatedAtMillisUtc,
    this.syncedAtMillisUtc = const Value.absent(),
    this.completed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : contentKey = Value(contentKey),
       positionSeconds = Value(positionSeconds),
       durationSeconds = Value(durationSeconds),
       updatedAtMillisUtc = Value(updatedAtMillisUtc);
  static Insertable<WatchProgressRow> custom({
    Expression<String>? contentKey,
    Expression<int>? positionSeconds,
    Expression<int>? durationSeconds,
    Expression<int>? updatedAtMillisUtc,
    Expression<int>? syncedAtMillisUtc,
    Expression<bool>? completed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentKey != null) 'content_key': contentKey,
      if (positionSeconds != null) 'position_seconds': positionSeconds,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (updatedAtMillisUtc != null)
        'updated_at_millis_utc': updatedAtMillisUtc,
      if (syncedAtMillisUtc != null) 'synced_at_millis_utc': syncedAtMillisUtc,
      if (completed != null) 'completed': completed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchProgressTableCompanion copyWith({
    Value<String>? contentKey,
    Value<int>? positionSeconds,
    Value<int>? durationSeconds,
    Value<int>? updatedAtMillisUtc,
    Value<int?>? syncedAtMillisUtc,
    Value<bool>? completed,
    Value<int>? rowid,
  }) {
    return WatchProgressTableCompanion(
      contentKey: contentKey ?? this.contentKey,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      updatedAtMillisUtc: updatedAtMillisUtc ?? this.updatedAtMillisUtc,
      syncedAtMillisUtc: syncedAtMillisUtc ?? this.syncedAtMillisUtc,
      completed: completed ?? this.completed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentKey.present) {
      map['content_key'] = Variable<String>(contentKey.value);
    }
    if (positionSeconds.present) {
      map['position_seconds'] = Variable<int>(positionSeconds.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (updatedAtMillisUtc.present) {
      map['updated_at_millis_utc'] = Variable<int>(updatedAtMillisUtc.value);
    }
    if (syncedAtMillisUtc.present) {
      map['synced_at_millis_utc'] = Variable<int>(syncedAtMillisUtc.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchProgressTableCompanion(')
          ..write('contentKey: $contentKey, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('updatedAtMillisUtc: $updatedAtMillisUtc, ')
          ..write('syncedAtMillisUtc: $syncedAtMillisUtc, ')
          ..write('completed: $completed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PreferencesTableTable extends PreferencesTable
    with TableInfo<$PreferencesTableTable, PreferencesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferencesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preferredAudioLangMeta =
      const VerificationMeta('preferredAudioLang');
  @override
  late final GeneratedColumn<String> preferredAudioLang =
      GeneratedColumn<String>(
        'preferred_audio_lang',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _preferredSubtitleLangMeta =
      const VerificationMeta('preferredSubtitleLang');
  @override
  late final GeneratedColumn<String> preferredSubtitleLang =
      GeneratedColumn<String>(
        'preferred_subtitle_lang',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _autoplayNextMeta = const VerificationMeta(
    'autoplayNext',
  );
  @override
  late final GeneratedColumn<bool> autoplayNext = GeneratedColumn<bool>(
    'autoplay_next',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("autoplay_next" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _backgroundPlaybackMeta =
      const VerificationMeta('backgroundPlayback');
  @override
  late final GeneratedColumn<bool> backgroundPlayback = GeneratedColumn<bool>(
    'background_playback',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("background_playback" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _contentLanguagesMeta = const VerificationMeta(
    'contentLanguages',
  );
  @override
  late final GeneratedColumn<String> contentLanguages = GeneratedColumn<String>(
    'content_languages',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tmdbApiKeyMeta = const VerificationMeta(
    'tmdbApiKey',
  );
  @override
  late final GeneratedColumn<String> tmdbApiKey = GeneratedColumn<String>(
    'tmdb_api_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discoveryRegionMeta = const VerificationMeta(
    'discoveryRegion',
  );
  @override
  late final GeneratedColumn<String> discoveryRegion = GeneratedColumn<String>(
    'discovery_region',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeAccountIdMeta = const VerificationMeta(
    'activeAccountId',
  );
  @override
  late final GeneratedColumn<String> activeAccountId = GeneratedColumn<String>(
    'active_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    preferredAudioLang,
    preferredSubtitleLang,
    autoplayNext,
    backgroundPlayback,
    contentLanguages,
    tmdbApiKey,
    discoveryRegion,
    activeAccountId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<PreferencesRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('preferred_audio_lang')) {
      context.handle(
        _preferredAudioLangMeta,
        preferredAudioLang.isAcceptableOrUnknown(
          data['preferred_audio_lang']!,
          _preferredAudioLangMeta,
        ),
      );
    }
    if (data.containsKey('preferred_subtitle_lang')) {
      context.handle(
        _preferredSubtitleLangMeta,
        preferredSubtitleLang.isAcceptableOrUnknown(
          data['preferred_subtitle_lang']!,
          _preferredSubtitleLangMeta,
        ),
      );
    }
    if (data.containsKey('autoplay_next')) {
      context.handle(
        _autoplayNextMeta,
        autoplayNext.isAcceptableOrUnknown(
          data['autoplay_next']!,
          _autoplayNextMeta,
        ),
      );
    }
    if (data.containsKey('background_playback')) {
      context.handle(
        _backgroundPlaybackMeta,
        backgroundPlayback.isAcceptableOrUnknown(
          data['background_playback']!,
          _backgroundPlaybackMeta,
        ),
      );
    }
    if (data.containsKey('content_languages')) {
      context.handle(
        _contentLanguagesMeta,
        contentLanguages.isAcceptableOrUnknown(
          data['content_languages']!,
          _contentLanguagesMeta,
        ),
      );
    }
    if (data.containsKey('tmdb_api_key')) {
      context.handle(
        _tmdbApiKeyMeta,
        tmdbApiKey.isAcceptableOrUnknown(
          data['tmdb_api_key']!,
          _tmdbApiKeyMeta,
        ),
      );
    }
    if (data.containsKey('discovery_region')) {
      context.handle(
        _discoveryRegionMeta,
        discoveryRegion.isAcceptableOrUnknown(
          data['discovery_region']!,
          _discoveryRegionMeta,
        ),
      );
    }
    if (data.containsKey('active_account_id')) {
      context.handle(
        _activeAccountIdMeta,
        activeAccountId.isAcceptableOrUnknown(
          data['active_account_id']!,
          _activeAccountIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PreferencesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PreferencesRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      preferredAudioLang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_audio_lang'],
      ),
      preferredSubtitleLang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_subtitle_lang'],
      ),
      autoplayNext: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}autoplay_next'],
      )!,
      backgroundPlayback: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}background_playback'],
      )!,
      contentLanguages: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_languages'],
      ),
      tmdbApiKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tmdb_api_key'],
      ),
      discoveryRegion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}discovery_region'],
      ),
      activeAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_account_id'],
      ),
    );
  }

  @override
  $PreferencesTableTable createAlias(String alias) {
    return $PreferencesTableTable(attachedDatabase, alias);
  }
}

class PreferencesRow extends DataClass implements Insertable<PreferencesRow> {
  /// Single-row table; id is always [PreferencesRepository.singletonId].
  final int id;
  final String? preferredAudioLang;
  final String? preferredSubtitleLang;
  final bool autoplayNext;

  /// Keep audio playing when the app is backgrounded (added in schema v2).
  final bool backgroundPlayback;

  /// Content-language filter: CSV of ContentLanguage codes to show, or null
  /// for "all languages" (added in schema v4).
  final String? contentLanguages;

  /// TMDB v3 API key for the discovery rails, or null when not configured —
  /// in which case only the bundled award rails appear (added in schema v6).
  /// Kept here rather than in secure storage deliberately: it is a personal
  /// read-only key for public list data, not a credential granting access to
  /// anything of the user's.
  final String? tmdbApiKey;

  /// ISO 3166-1 country for region-aware discovery ("what's popular/new *here*").
  /// Null → derived from the device locale (added in schema v6).
  final String? discoveryRegion;

  /// App state, not a user preference — which account the UI is showing.
  final String? activeAccountId;
  const PreferencesRow({
    required this.id,
    this.preferredAudioLang,
    this.preferredSubtitleLang,
    required this.autoplayNext,
    required this.backgroundPlayback,
    this.contentLanguages,
    this.tmdbApiKey,
    this.discoveryRegion,
    this.activeAccountId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || preferredAudioLang != null) {
      map['preferred_audio_lang'] = Variable<String>(preferredAudioLang);
    }
    if (!nullToAbsent || preferredSubtitleLang != null) {
      map['preferred_subtitle_lang'] = Variable<String>(preferredSubtitleLang);
    }
    map['autoplay_next'] = Variable<bool>(autoplayNext);
    map['background_playback'] = Variable<bool>(backgroundPlayback);
    if (!nullToAbsent || contentLanguages != null) {
      map['content_languages'] = Variable<String>(contentLanguages);
    }
    if (!nullToAbsent || tmdbApiKey != null) {
      map['tmdb_api_key'] = Variable<String>(tmdbApiKey);
    }
    if (!nullToAbsent || discoveryRegion != null) {
      map['discovery_region'] = Variable<String>(discoveryRegion);
    }
    if (!nullToAbsent || activeAccountId != null) {
      map['active_account_id'] = Variable<String>(activeAccountId);
    }
    return map;
  }

  PreferencesTableCompanion toCompanion(bool nullToAbsent) {
    return PreferencesTableCompanion(
      id: Value(id),
      preferredAudioLang: preferredAudioLang == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredAudioLang),
      preferredSubtitleLang: preferredSubtitleLang == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredSubtitleLang),
      autoplayNext: Value(autoplayNext),
      backgroundPlayback: Value(backgroundPlayback),
      contentLanguages: contentLanguages == null && nullToAbsent
          ? const Value.absent()
          : Value(contentLanguages),
      tmdbApiKey: tmdbApiKey == null && nullToAbsent
          ? const Value.absent()
          : Value(tmdbApiKey),
      discoveryRegion: discoveryRegion == null && nullToAbsent
          ? const Value.absent()
          : Value(discoveryRegion),
      activeAccountId: activeAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeAccountId),
    );
  }

  factory PreferencesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PreferencesRow(
      id: serializer.fromJson<int>(json['id']),
      preferredAudioLang: serializer.fromJson<String?>(
        json['preferredAudioLang'],
      ),
      preferredSubtitleLang: serializer.fromJson<String?>(
        json['preferredSubtitleLang'],
      ),
      autoplayNext: serializer.fromJson<bool>(json['autoplayNext']),
      backgroundPlayback: serializer.fromJson<bool>(json['backgroundPlayback']),
      contentLanguages: serializer.fromJson<String?>(json['contentLanguages']),
      tmdbApiKey: serializer.fromJson<String?>(json['tmdbApiKey']),
      discoveryRegion: serializer.fromJson<String?>(json['discoveryRegion']),
      activeAccountId: serializer.fromJson<String?>(json['activeAccountId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'preferredAudioLang': serializer.toJson<String?>(preferredAudioLang),
      'preferredSubtitleLang': serializer.toJson<String?>(
        preferredSubtitleLang,
      ),
      'autoplayNext': serializer.toJson<bool>(autoplayNext),
      'backgroundPlayback': serializer.toJson<bool>(backgroundPlayback),
      'contentLanguages': serializer.toJson<String?>(contentLanguages),
      'tmdbApiKey': serializer.toJson<String?>(tmdbApiKey),
      'discoveryRegion': serializer.toJson<String?>(discoveryRegion),
      'activeAccountId': serializer.toJson<String?>(activeAccountId),
    };
  }

  PreferencesRow copyWith({
    int? id,
    Value<String?> preferredAudioLang = const Value.absent(),
    Value<String?> preferredSubtitleLang = const Value.absent(),
    bool? autoplayNext,
    bool? backgroundPlayback,
    Value<String?> contentLanguages = const Value.absent(),
    Value<String?> tmdbApiKey = const Value.absent(),
    Value<String?> discoveryRegion = const Value.absent(),
    Value<String?> activeAccountId = const Value.absent(),
  }) => PreferencesRow(
    id: id ?? this.id,
    preferredAudioLang: preferredAudioLang.present
        ? preferredAudioLang.value
        : this.preferredAudioLang,
    preferredSubtitleLang: preferredSubtitleLang.present
        ? preferredSubtitleLang.value
        : this.preferredSubtitleLang,
    autoplayNext: autoplayNext ?? this.autoplayNext,
    backgroundPlayback: backgroundPlayback ?? this.backgroundPlayback,
    contentLanguages: contentLanguages.present
        ? contentLanguages.value
        : this.contentLanguages,
    tmdbApiKey: tmdbApiKey.present ? tmdbApiKey.value : this.tmdbApiKey,
    discoveryRegion: discoveryRegion.present
        ? discoveryRegion.value
        : this.discoveryRegion,
    activeAccountId: activeAccountId.present
        ? activeAccountId.value
        : this.activeAccountId,
  );
  PreferencesRow copyWithCompanion(PreferencesTableCompanion data) {
    return PreferencesRow(
      id: data.id.present ? data.id.value : this.id,
      preferredAudioLang: data.preferredAudioLang.present
          ? data.preferredAudioLang.value
          : this.preferredAudioLang,
      preferredSubtitleLang: data.preferredSubtitleLang.present
          ? data.preferredSubtitleLang.value
          : this.preferredSubtitleLang,
      autoplayNext: data.autoplayNext.present
          ? data.autoplayNext.value
          : this.autoplayNext,
      backgroundPlayback: data.backgroundPlayback.present
          ? data.backgroundPlayback.value
          : this.backgroundPlayback,
      contentLanguages: data.contentLanguages.present
          ? data.contentLanguages.value
          : this.contentLanguages,
      tmdbApiKey: data.tmdbApiKey.present
          ? data.tmdbApiKey.value
          : this.tmdbApiKey,
      discoveryRegion: data.discoveryRegion.present
          ? data.discoveryRegion.value
          : this.discoveryRegion,
      activeAccountId: data.activeAccountId.present
          ? data.activeAccountId.value
          : this.activeAccountId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PreferencesRow(')
          ..write('id: $id, ')
          ..write('preferredAudioLang: $preferredAudioLang, ')
          ..write('preferredSubtitleLang: $preferredSubtitleLang, ')
          ..write('autoplayNext: $autoplayNext, ')
          ..write('backgroundPlayback: $backgroundPlayback, ')
          ..write('contentLanguages: $contentLanguages, ')
          ..write('tmdbApiKey: $tmdbApiKey, ')
          ..write('discoveryRegion: $discoveryRegion, ')
          ..write('activeAccountId: $activeAccountId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    preferredAudioLang,
    preferredSubtitleLang,
    autoplayNext,
    backgroundPlayback,
    contentLanguages,
    tmdbApiKey,
    discoveryRegion,
    activeAccountId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PreferencesRow &&
          other.id == this.id &&
          other.preferredAudioLang == this.preferredAudioLang &&
          other.preferredSubtitleLang == this.preferredSubtitleLang &&
          other.autoplayNext == this.autoplayNext &&
          other.backgroundPlayback == this.backgroundPlayback &&
          other.contentLanguages == this.contentLanguages &&
          other.tmdbApiKey == this.tmdbApiKey &&
          other.discoveryRegion == this.discoveryRegion &&
          other.activeAccountId == this.activeAccountId);
}

class PreferencesTableCompanion extends UpdateCompanion<PreferencesRow> {
  final Value<int> id;
  final Value<String?> preferredAudioLang;
  final Value<String?> preferredSubtitleLang;
  final Value<bool> autoplayNext;
  final Value<bool> backgroundPlayback;
  final Value<String?> contentLanguages;
  final Value<String?> tmdbApiKey;
  final Value<String?> discoveryRegion;
  final Value<String?> activeAccountId;
  const PreferencesTableCompanion({
    this.id = const Value.absent(),
    this.preferredAudioLang = const Value.absent(),
    this.preferredSubtitleLang = const Value.absent(),
    this.autoplayNext = const Value.absent(),
    this.backgroundPlayback = const Value.absent(),
    this.contentLanguages = const Value.absent(),
    this.tmdbApiKey = const Value.absent(),
    this.discoveryRegion = const Value.absent(),
    this.activeAccountId = const Value.absent(),
  });
  PreferencesTableCompanion.insert({
    this.id = const Value.absent(),
    this.preferredAudioLang = const Value.absent(),
    this.preferredSubtitleLang = const Value.absent(),
    this.autoplayNext = const Value.absent(),
    this.backgroundPlayback = const Value.absent(),
    this.contentLanguages = const Value.absent(),
    this.tmdbApiKey = const Value.absent(),
    this.discoveryRegion = const Value.absent(),
    this.activeAccountId = const Value.absent(),
  });
  static Insertable<PreferencesRow> custom({
    Expression<int>? id,
    Expression<String>? preferredAudioLang,
    Expression<String>? preferredSubtitleLang,
    Expression<bool>? autoplayNext,
    Expression<bool>? backgroundPlayback,
    Expression<String>? contentLanguages,
    Expression<String>? tmdbApiKey,
    Expression<String>? discoveryRegion,
    Expression<String>? activeAccountId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (preferredAudioLang != null)
        'preferred_audio_lang': preferredAudioLang,
      if (preferredSubtitleLang != null)
        'preferred_subtitle_lang': preferredSubtitleLang,
      if (autoplayNext != null) 'autoplay_next': autoplayNext,
      if (backgroundPlayback != null) 'background_playback': backgroundPlayback,
      if (contentLanguages != null) 'content_languages': contentLanguages,
      if (tmdbApiKey != null) 'tmdb_api_key': tmdbApiKey,
      if (discoveryRegion != null) 'discovery_region': discoveryRegion,
      if (activeAccountId != null) 'active_account_id': activeAccountId,
    });
  }

  PreferencesTableCompanion copyWith({
    Value<int>? id,
    Value<String?>? preferredAudioLang,
    Value<String?>? preferredSubtitleLang,
    Value<bool>? autoplayNext,
    Value<bool>? backgroundPlayback,
    Value<String?>? contentLanguages,
    Value<String?>? tmdbApiKey,
    Value<String?>? discoveryRegion,
    Value<String?>? activeAccountId,
  }) {
    return PreferencesTableCompanion(
      id: id ?? this.id,
      preferredAudioLang: preferredAudioLang ?? this.preferredAudioLang,
      preferredSubtitleLang:
          preferredSubtitleLang ?? this.preferredSubtitleLang,
      autoplayNext: autoplayNext ?? this.autoplayNext,
      backgroundPlayback: backgroundPlayback ?? this.backgroundPlayback,
      contentLanguages: contentLanguages ?? this.contentLanguages,
      tmdbApiKey: tmdbApiKey ?? this.tmdbApiKey,
      discoveryRegion: discoveryRegion ?? this.discoveryRegion,
      activeAccountId: activeAccountId ?? this.activeAccountId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (preferredAudioLang.present) {
      map['preferred_audio_lang'] = Variable<String>(preferredAudioLang.value);
    }
    if (preferredSubtitleLang.present) {
      map['preferred_subtitle_lang'] = Variable<String>(
        preferredSubtitleLang.value,
      );
    }
    if (autoplayNext.present) {
      map['autoplay_next'] = Variable<bool>(autoplayNext.value);
    }
    if (backgroundPlayback.present) {
      map['background_playback'] = Variable<bool>(backgroundPlayback.value);
    }
    if (contentLanguages.present) {
      map['content_languages'] = Variable<String>(contentLanguages.value);
    }
    if (tmdbApiKey.present) {
      map['tmdb_api_key'] = Variable<String>(tmdbApiKey.value);
    }
    if (discoveryRegion.present) {
      map['discovery_region'] = Variable<String>(discoveryRegion.value);
    }
    if (activeAccountId.present) {
      map['active_account_id'] = Variable<String>(activeAccountId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferencesTableCompanion(')
          ..write('id: $id, ')
          ..write('preferredAudioLang: $preferredAudioLang, ')
          ..write('preferredSubtitleLang: $preferredSubtitleLang, ')
          ..write('autoplayNext: $autoplayNext, ')
          ..write('backgroundPlayback: $backgroundPlayback, ')
          ..write('contentLanguages: $contentLanguages, ')
          ..write('tmdbApiKey: $tmdbApiKey, ')
          ..write('discoveryRegion: $discoveryRegion, ')
          ..write('activeAccountId: $activeAccountId')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTableTable extends FavoritesTable
    with TableInfo<$FavoritesTableTable, FavoriteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentKeyMeta = const VerificationMeta(
    'contentKey',
  );
  @override
  late final GeneratedColumn<String> contentKey = GeneratedColumn<String>(
    'content_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMillisUtcMeta = const VerificationMeta(
    'addedAtMillisUtc',
  );
  @override
  late final GeneratedColumn<int> addedAtMillisUtc = GeneratedColumn<int>(
    'added_at_millis_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [contentKey, addedAtMillisUtc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_key')) {
      context.handle(
        _contentKeyMeta,
        contentKey.isAcceptableOrUnknown(data['content_key']!, _contentKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_contentKeyMeta);
    }
    if (data.containsKey('added_at_millis_utc')) {
      context.handle(
        _addedAtMillisUtcMeta,
        addedAtMillisUtc.isAcceptableOrUnknown(
          data['added_at_millis_utc']!,
          _addedAtMillisUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addedAtMillisUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentKey};
  @override
  FavoriteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteRow(
      contentKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_key'],
      )!,
      addedAtMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at_millis_utc'],
      )!,
    );
  }

  @override
  $FavoritesTableTable createAlias(String alias) {
    return $FavoritesTableTable(attachedDatabase, alias);
  }
}

class FavoriteRow extends DataClass implements Insertable<FavoriteRow> {
  final String contentKey;
  final int addedAtMillisUtc;
  const FavoriteRow({required this.contentKey, required this.addedAtMillisUtc});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_key'] = Variable<String>(contentKey);
    map['added_at_millis_utc'] = Variable<int>(addedAtMillisUtc);
    return map;
  }

  FavoritesTableCompanion toCompanion(bool nullToAbsent) {
    return FavoritesTableCompanion(
      contentKey: Value(contentKey),
      addedAtMillisUtc: Value(addedAtMillisUtc),
    );
  }

  factory FavoriteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteRow(
      contentKey: serializer.fromJson<String>(json['contentKey']),
      addedAtMillisUtc: serializer.fromJson<int>(json['addedAtMillisUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentKey': serializer.toJson<String>(contentKey),
      'addedAtMillisUtc': serializer.toJson<int>(addedAtMillisUtc),
    };
  }

  FavoriteRow copyWith({String? contentKey, int? addedAtMillisUtc}) =>
      FavoriteRow(
        contentKey: contentKey ?? this.contentKey,
        addedAtMillisUtc: addedAtMillisUtc ?? this.addedAtMillisUtc,
      );
  FavoriteRow copyWithCompanion(FavoritesTableCompanion data) {
    return FavoriteRow(
      contentKey: data.contentKey.present
          ? data.contentKey.value
          : this.contentKey,
      addedAtMillisUtc: data.addedAtMillisUtc.present
          ? data.addedAtMillisUtc.value
          : this.addedAtMillisUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteRow(')
          ..write('contentKey: $contentKey, ')
          ..write('addedAtMillisUtc: $addedAtMillisUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(contentKey, addedAtMillisUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteRow &&
          other.contentKey == this.contentKey &&
          other.addedAtMillisUtc == this.addedAtMillisUtc);
}

class FavoritesTableCompanion extends UpdateCompanion<FavoriteRow> {
  final Value<String> contentKey;
  final Value<int> addedAtMillisUtc;
  final Value<int> rowid;
  const FavoritesTableCompanion({
    this.contentKey = const Value.absent(),
    this.addedAtMillisUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritesTableCompanion.insert({
    required String contentKey,
    required int addedAtMillisUtc,
    this.rowid = const Value.absent(),
  }) : contentKey = Value(contentKey),
       addedAtMillisUtc = Value(addedAtMillisUtc);
  static Insertable<FavoriteRow> custom({
    Expression<String>? contentKey,
    Expression<int>? addedAtMillisUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentKey != null) 'content_key': contentKey,
      if (addedAtMillisUtc != null) 'added_at_millis_utc': addedAtMillisUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritesTableCompanion copyWith({
    Value<String>? contentKey,
    Value<int>? addedAtMillisUtc,
    Value<int>? rowid,
  }) {
    return FavoritesTableCompanion(
      contentKey: contentKey ?? this.contentKey,
      addedAtMillisUtc: addedAtMillisUtc ?? this.addedAtMillisUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentKey.present) {
      map['content_key'] = Variable<String>(contentKey.value);
    }
    if (addedAtMillisUtc.present) {
      map['added_at_millis_utc'] = Variable<int>(addedAtMillisUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesTableCompanion(')
          ..write('contentKey: $contentKey, ')
          ..write('addedAtMillisUtc: $addedAtMillisUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpgCacheTableTable extends EpgCacheTable
    with TableInfo<$EpgCacheTableTable, EpgRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgCacheTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMillisUtcMeta = const VerificationMeta(
    'startMillisUtc',
  );
  @override
  late final GeneratedColumn<int> startMillisUtc = GeneratedColumn<int>(
    'start_millis_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stopMillisUtcMeta = const VerificationMeta(
    'stopMillisUtc',
  );
  @override
  late final GeneratedColumn<int> stopMillisUtc = GeneratedColumn<int>(
    'stop_millis_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMillisUtcMeta = const VerificationMeta(
    'cachedAtMillisUtc',
  );
  @override
  late final GeneratedColumn<int> cachedAtMillisUtc = GeneratedColumn<int>(
    'cached_at_millis_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    channelId,
    startMillisUtc,
    stopMillisUtc,
    title,
    description,
    cachedAtMillisUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('start_millis_utc')) {
      context.handle(
        _startMillisUtcMeta,
        startMillisUtc.isAcceptableOrUnknown(
          data['start_millis_utc']!,
          _startMillisUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMillisUtcMeta);
    }
    if (data.containsKey('stop_millis_utc')) {
      context.handle(
        _stopMillisUtcMeta,
        stopMillisUtc.isAcceptableOrUnknown(
          data['stop_millis_utc']!,
          _stopMillisUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stopMillisUtcMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('cached_at_millis_utc')) {
      context.handle(
        _cachedAtMillisUtcMeta,
        cachedAtMillisUtc.isAcceptableOrUnknown(
          data['cached_at_millis_utc']!,
          _cachedAtMillisUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMillisUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    accountId,
    channelId,
    startMillisUtc,
  };
  @override
  EpgRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      )!,
      startMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_millis_utc'],
      )!,
      stopMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stop_millis_utc'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      cachedAtMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at_millis_utc'],
      )!,
    );
  }

  @override
  $EpgCacheTableTable createAlias(String alias) {
    return $EpgCacheTableTable(attachedDatabase, alias);
  }
}

class EpgRow extends DataClass implements Insertable<EpgRow> {
  final String accountId;
  final String channelId;
  final int startMillisUtc;
  final int stopMillisUtc;
  final String title;
  final String? description;
  final int cachedAtMillisUtc;
  const EpgRow({
    required this.accountId,
    required this.channelId,
    required this.startMillisUtc,
    required this.stopMillisUtc,
    required this.title,
    this.description,
    required this.cachedAtMillisUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['channel_id'] = Variable<String>(channelId);
    map['start_millis_utc'] = Variable<int>(startMillisUtc);
    map['stop_millis_utc'] = Variable<int>(stopMillisUtc);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['cached_at_millis_utc'] = Variable<int>(cachedAtMillisUtc);
    return map;
  }

  EpgCacheTableCompanion toCompanion(bool nullToAbsent) {
    return EpgCacheTableCompanion(
      accountId: Value(accountId),
      channelId: Value(channelId),
      startMillisUtc: Value(startMillisUtc),
      stopMillisUtc: Value(stopMillisUtc),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      cachedAtMillisUtc: Value(cachedAtMillisUtc),
    );
  }

  factory EpgRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgRow(
      accountId: serializer.fromJson<String>(json['accountId']),
      channelId: serializer.fromJson<String>(json['channelId']),
      startMillisUtc: serializer.fromJson<int>(json['startMillisUtc']),
      stopMillisUtc: serializer.fromJson<int>(json['stopMillisUtc']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      cachedAtMillisUtc: serializer.fromJson<int>(json['cachedAtMillisUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'channelId': serializer.toJson<String>(channelId),
      'startMillisUtc': serializer.toJson<int>(startMillisUtc),
      'stopMillisUtc': serializer.toJson<int>(stopMillisUtc),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'cachedAtMillisUtc': serializer.toJson<int>(cachedAtMillisUtc),
    };
  }

  EpgRow copyWith({
    String? accountId,
    String? channelId,
    int? startMillisUtc,
    int? stopMillisUtc,
    String? title,
    Value<String?> description = const Value.absent(),
    int? cachedAtMillisUtc,
  }) => EpgRow(
    accountId: accountId ?? this.accountId,
    channelId: channelId ?? this.channelId,
    startMillisUtc: startMillisUtc ?? this.startMillisUtc,
    stopMillisUtc: stopMillisUtc ?? this.stopMillisUtc,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    cachedAtMillisUtc: cachedAtMillisUtc ?? this.cachedAtMillisUtc,
  );
  EpgRow copyWithCompanion(EpgCacheTableCompanion data) {
    return EpgRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      startMillisUtc: data.startMillisUtc.present
          ? data.startMillisUtc.value
          : this.startMillisUtc,
      stopMillisUtc: data.stopMillisUtc.present
          ? data.stopMillisUtc.value
          : this.stopMillisUtc,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      cachedAtMillisUtc: data.cachedAtMillisUtc.present
          ? data.cachedAtMillisUtc.value
          : this.cachedAtMillisUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgRow(')
          ..write('accountId: $accountId, ')
          ..write('channelId: $channelId, ')
          ..write('startMillisUtc: $startMillisUtc, ')
          ..write('stopMillisUtc: $stopMillisUtc, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('cachedAtMillisUtc: $cachedAtMillisUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    channelId,
    startMillisUtc,
    stopMillisUtc,
    title,
    description,
    cachedAtMillisUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgRow &&
          other.accountId == this.accountId &&
          other.channelId == this.channelId &&
          other.startMillisUtc == this.startMillisUtc &&
          other.stopMillisUtc == this.stopMillisUtc &&
          other.title == this.title &&
          other.description == this.description &&
          other.cachedAtMillisUtc == this.cachedAtMillisUtc);
}

class EpgCacheTableCompanion extends UpdateCompanion<EpgRow> {
  final Value<String> accountId;
  final Value<String> channelId;
  final Value<int> startMillisUtc;
  final Value<int> stopMillisUtc;
  final Value<String> title;
  final Value<String?> description;
  final Value<int> cachedAtMillisUtc;
  final Value<int> rowid;
  const EpgCacheTableCompanion({
    this.accountId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.startMillisUtc = const Value.absent(),
    this.stopMillisUtc = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.cachedAtMillisUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpgCacheTableCompanion.insert({
    required String accountId,
    required String channelId,
    required int startMillisUtc,
    required int stopMillisUtc,
    required String title,
    this.description = const Value.absent(),
    required int cachedAtMillisUtc,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       channelId = Value(channelId),
       startMillisUtc = Value(startMillisUtc),
       stopMillisUtc = Value(stopMillisUtc),
       title = Value(title),
       cachedAtMillisUtc = Value(cachedAtMillisUtc);
  static Insertable<EpgRow> custom({
    Expression<String>? accountId,
    Expression<String>? channelId,
    Expression<int>? startMillisUtc,
    Expression<int>? stopMillisUtc,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? cachedAtMillisUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (channelId != null) 'channel_id': channelId,
      if (startMillisUtc != null) 'start_millis_utc': startMillisUtc,
      if (stopMillisUtc != null) 'stop_millis_utc': stopMillisUtc,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (cachedAtMillisUtc != null) 'cached_at_millis_utc': cachedAtMillisUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpgCacheTableCompanion copyWith({
    Value<String>? accountId,
    Value<String>? channelId,
    Value<int>? startMillisUtc,
    Value<int>? stopMillisUtc,
    Value<String>? title,
    Value<String?>? description,
    Value<int>? cachedAtMillisUtc,
    Value<int>? rowid,
  }) {
    return EpgCacheTableCompanion(
      accountId: accountId ?? this.accountId,
      channelId: channelId ?? this.channelId,
      startMillisUtc: startMillisUtc ?? this.startMillisUtc,
      stopMillisUtc: stopMillisUtc ?? this.stopMillisUtc,
      title: title ?? this.title,
      description: description ?? this.description,
      cachedAtMillisUtc: cachedAtMillisUtc ?? this.cachedAtMillisUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (startMillisUtc.present) {
      map['start_millis_utc'] = Variable<int>(startMillisUtc.value);
    }
    if (stopMillisUtc.present) {
      map['stop_millis_utc'] = Variable<int>(stopMillisUtc.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (cachedAtMillisUtc.present) {
      map['cached_at_millis_utc'] = Variable<int>(cachedAtMillisUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgCacheTableCompanion(')
          ..write('accountId: $accountId, ')
          ..write('channelId: $channelId, ')
          ..write('startMillisUtc: $startMillisUtc, ')
          ..write('stopMillisUtc: $stopMillisUtc, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('cachedAtMillisUtc: $cachedAtMillisUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogMetaTableTable extends CatalogMetaTable
    with TableInfo<$CatalogMetaTableTable, CatalogMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogMetaTableTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumnWithTypeConverter<CatalogKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CatalogKind>($CatalogMetaTableTable.$converterkind);
  static const VerificationMeta _refreshedAtMillisUtcMeta =
      const VerificationMeta('refreshedAtMillisUtc');
  @override
  late final GeneratedColumn<int> refreshedAtMillisUtc = GeneratedColumn<int>(
    'refreshed_at_millis_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, kind, refreshedAtMillisUtc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('refreshed_at_millis_utc')) {
      context.handle(
        _refreshedAtMillisUtcMeta,
        refreshedAtMillisUtc.isAcceptableOrUnknown(
          data['refreshed_at_millis_utc']!,
          _refreshedAtMillisUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_refreshedAtMillisUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, kind};
  @override
  CatalogMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogMetaRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      kind: $CatalogMetaTableTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      refreshedAtMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}refreshed_at_millis_utc'],
      )!,
    );
  }

  @override
  $CatalogMetaTableTable createAlias(String alias) {
    return $CatalogMetaTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CatalogKind, String, String> $converterkind =
      const EnumNameConverter<CatalogKind>(CatalogKind.values);
}

class CatalogMetaRow extends DataClass implements Insertable<CatalogMetaRow> {
  final String accountId;

  /// One of [CatalogKind] (stored as enum name).
  final CatalogKind kind;
  final int refreshedAtMillisUtc;
  const CatalogMetaRow({
    required this.accountId,
    required this.kind,
    required this.refreshedAtMillisUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    {
      map['kind'] = Variable<String>(
        $CatalogMetaTableTable.$converterkind.toSql(kind),
      );
    }
    map['refreshed_at_millis_utc'] = Variable<int>(refreshedAtMillisUtc);
    return map;
  }

  CatalogMetaTableCompanion toCompanion(bool nullToAbsent) {
    return CatalogMetaTableCompanion(
      accountId: Value(accountId),
      kind: Value(kind),
      refreshedAtMillisUtc: Value(refreshedAtMillisUtc),
    );
  }

  factory CatalogMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogMetaRow(
      accountId: serializer.fromJson<String>(json['accountId']),
      kind: $CatalogMetaTableTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      refreshedAtMillisUtc: serializer.fromJson<int>(
        json['refreshedAtMillisUtc'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'kind': serializer.toJson<String>(
        $CatalogMetaTableTable.$converterkind.toJson(kind),
      ),
      'refreshedAtMillisUtc': serializer.toJson<int>(refreshedAtMillisUtc),
    };
  }

  CatalogMetaRow copyWith({
    String? accountId,
    CatalogKind? kind,
    int? refreshedAtMillisUtc,
  }) => CatalogMetaRow(
    accountId: accountId ?? this.accountId,
    kind: kind ?? this.kind,
    refreshedAtMillisUtc: refreshedAtMillisUtc ?? this.refreshedAtMillisUtc,
  );
  CatalogMetaRow copyWithCompanion(CatalogMetaTableCompanion data) {
    return CatalogMetaRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      kind: data.kind.present ? data.kind.value : this.kind,
      refreshedAtMillisUtc: data.refreshedAtMillisUtc.present
          ? data.refreshedAtMillisUtc.value
          : this.refreshedAtMillisUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogMetaRow(')
          ..write('accountId: $accountId, ')
          ..write('kind: $kind, ')
          ..write('refreshedAtMillisUtc: $refreshedAtMillisUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, kind, refreshedAtMillisUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogMetaRow &&
          other.accountId == this.accountId &&
          other.kind == this.kind &&
          other.refreshedAtMillisUtc == this.refreshedAtMillisUtc);
}

class CatalogMetaTableCompanion extends UpdateCompanion<CatalogMetaRow> {
  final Value<String> accountId;
  final Value<CatalogKind> kind;
  final Value<int> refreshedAtMillisUtc;
  final Value<int> rowid;
  const CatalogMetaTableCompanion({
    this.accountId = const Value.absent(),
    this.kind = const Value.absent(),
    this.refreshedAtMillisUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogMetaTableCompanion.insert({
    required String accountId,
    required CatalogKind kind,
    required int refreshedAtMillisUtc,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       kind = Value(kind),
       refreshedAtMillisUtc = Value(refreshedAtMillisUtc);
  static Insertable<CatalogMetaRow> custom({
    Expression<String>? accountId,
    Expression<String>? kind,
    Expression<int>? refreshedAtMillisUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (kind != null) 'kind': kind,
      if (refreshedAtMillisUtc != null)
        'refreshed_at_millis_utc': refreshedAtMillisUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogMetaTableCompanion copyWith({
    Value<String>? accountId,
    Value<CatalogKind>? kind,
    Value<int>? refreshedAtMillisUtc,
    Value<int>? rowid,
  }) {
    return CatalogMetaTableCompanion(
      accountId: accountId ?? this.accountId,
      kind: kind ?? this.kind,
      refreshedAtMillisUtc: refreshedAtMillisUtc ?? this.refreshedAtMillisUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $CatalogMetaTableTable.$converterkind.toSql(kind.value),
      );
    }
    if (refreshedAtMillisUtc.present) {
      map['refreshed_at_millis_utc'] = Variable<int>(
        refreshedAtMillisUtc.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogMetaTableCompanion(')
          ..write('accountId: $accountId, ')
          ..write('kind: $kind, ')
          ..write('refreshedAtMillisUtc: $refreshedAtMillisUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogCategoryMetaTableTable extends CatalogCategoryMetaTable
    with TableInfo<$CatalogCategoryMetaTableTable, CatalogCategoryMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogCategoryMetaTableTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumnWithTypeConverter<CatalogKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CatalogKind>(
        $CatalogCategoryMetaTableTable.$converterkind,
      );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refreshedAtMillisUtcMeta =
      const VerificationMeta('refreshedAtMillisUtc');
  @override
  late final GeneratedColumn<int> refreshedAtMillisUtc = GeneratedColumn<int>(
    'refreshed_at_millis_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    kind,
    categoryId,
    refreshedAtMillisUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_category_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogCategoryMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('refreshed_at_millis_utc')) {
      context.handle(
        _refreshedAtMillisUtcMeta,
        refreshedAtMillisUtc.isAcceptableOrUnknown(
          data['refreshed_at_millis_utc']!,
          _refreshedAtMillisUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_refreshedAtMillisUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, kind, categoryId};
  @override
  CatalogCategoryMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogCategoryMetaRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      kind: $CatalogCategoryMetaTableTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      refreshedAtMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}refreshed_at_millis_utc'],
      )!,
    );
  }

  @override
  $CatalogCategoryMetaTableTable createAlias(String alias) {
    return $CatalogCategoryMetaTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CatalogKind, String, String> $converterkind =
      const EnumNameConverter<CatalogKind>(CatalogKind.values);
}

class CatalogCategoryMetaRow extends DataClass
    implements Insertable<CatalogCategoryMetaRow> {
  final String accountId;

  /// One of [CatalogKind] (stored as enum name).
  final CatalogKind kind;
  final String categoryId;
  final int refreshedAtMillisUtc;
  const CatalogCategoryMetaRow({
    required this.accountId,
    required this.kind,
    required this.categoryId,
    required this.refreshedAtMillisUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    {
      map['kind'] = Variable<String>(
        $CatalogCategoryMetaTableTable.$converterkind.toSql(kind),
      );
    }
    map['category_id'] = Variable<String>(categoryId);
    map['refreshed_at_millis_utc'] = Variable<int>(refreshedAtMillisUtc);
    return map;
  }

  CatalogCategoryMetaTableCompanion toCompanion(bool nullToAbsent) {
    return CatalogCategoryMetaTableCompanion(
      accountId: Value(accountId),
      kind: Value(kind),
      categoryId: Value(categoryId),
      refreshedAtMillisUtc: Value(refreshedAtMillisUtc),
    );
  }

  factory CatalogCategoryMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogCategoryMetaRow(
      accountId: serializer.fromJson<String>(json['accountId']),
      kind: $CatalogCategoryMetaTableTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      refreshedAtMillisUtc: serializer.fromJson<int>(
        json['refreshedAtMillisUtc'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'kind': serializer.toJson<String>(
        $CatalogCategoryMetaTableTable.$converterkind.toJson(kind),
      ),
      'categoryId': serializer.toJson<String>(categoryId),
      'refreshedAtMillisUtc': serializer.toJson<int>(refreshedAtMillisUtc),
    };
  }

  CatalogCategoryMetaRow copyWith({
    String? accountId,
    CatalogKind? kind,
    String? categoryId,
    int? refreshedAtMillisUtc,
  }) => CatalogCategoryMetaRow(
    accountId: accountId ?? this.accountId,
    kind: kind ?? this.kind,
    categoryId: categoryId ?? this.categoryId,
    refreshedAtMillisUtc: refreshedAtMillisUtc ?? this.refreshedAtMillisUtc,
  );
  CatalogCategoryMetaRow copyWithCompanion(
    CatalogCategoryMetaTableCompanion data,
  ) {
    return CatalogCategoryMetaRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      kind: data.kind.present ? data.kind.value : this.kind,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      refreshedAtMillisUtc: data.refreshedAtMillisUtc.present
          ? data.refreshedAtMillisUtc.value
          : this.refreshedAtMillisUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogCategoryMetaRow(')
          ..write('accountId: $accountId, ')
          ..write('kind: $kind, ')
          ..write('categoryId: $categoryId, ')
          ..write('refreshedAtMillisUtc: $refreshedAtMillisUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(accountId, kind, categoryId, refreshedAtMillisUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogCategoryMetaRow &&
          other.accountId == this.accountId &&
          other.kind == this.kind &&
          other.categoryId == this.categoryId &&
          other.refreshedAtMillisUtc == this.refreshedAtMillisUtc);
}

class CatalogCategoryMetaTableCompanion
    extends UpdateCompanion<CatalogCategoryMetaRow> {
  final Value<String> accountId;
  final Value<CatalogKind> kind;
  final Value<String> categoryId;
  final Value<int> refreshedAtMillisUtc;
  final Value<int> rowid;
  const CatalogCategoryMetaTableCompanion({
    this.accountId = const Value.absent(),
    this.kind = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.refreshedAtMillisUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogCategoryMetaTableCompanion.insert({
    required String accountId,
    required CatalogKind kind,
    required String categoryId,
    required int refreshedAtMillisUtc,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       kind = Value(kind),
       categoryId = Value(categoryId),
       refreshedAtMillisUtc = Value(refreshedAtMillisUtc);
  static Insertable<CatalogCategoryMetaRow> custom({
    Expression<String>? accountId,
    Expression<String>? kind,
    Expression<String>? categoryId,
    Expression<int>? refreshedAtMillisUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (kind != null) 'kind': kind,
      if (categoryId != null) 'category_id': categoryId,
      if (refreshedAtMillisUtc != null)
        'refreshed_at_millis_utc': refreshedAtMillisUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogCategoryMetaTableCompanion copyWith({
    Value<String>? accountId,
    Value<CatalogKind>? kind,
    Value<String>? categoryId,
    Value<int>? refreshedAtMillisUtc,
    Value<int>? rowid,
  }) {
    return CatalogCategoryMetaTableCompanion(
      accountId: accountId ?? this.accountId,
      kind: kind ?? this.kind,
      categoryId: categoryId ?? this.categoryId,
      refreshedAtMillisUtc: refreshedAtMillisUtc ?? this.refreshedAtMillisUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $CatalogCategoryMetaTableTable.$converterkind.toSql(kind.value),
      );
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (refreshedAtMillisUtc.present) {
      map['refreshed_at_millis_utc'] = Variable<int>(
        refreshedAtMillisUtc.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogCategoryMetaTableCompanion(')
          ..write('accountId: $accountId, ')
          ..write('kind: $kind, ')
          ..write('categoryId: $categoryId, ')
          ..write('refreshedAtMillisUtc: $refreshedAtMillisUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiscoveryTitlesTableTable extends DiscoveryTitlesTable
    with TableInfo<$DiscoveryTitlesTableTable, DiscoveryTitleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiscoveryTitlesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rankMeta = const VerificationMeta('rank');
  @override
  late final GeneratedColumn<int> rank = GeneratedColumn<int>(
    'rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DiscoveryKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DiscoveryKind>($DiscoveryTitlesTableTable.$converterkind);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<int> tmdbId = GeneratedColumn<int>(
    'tmdb_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voteAverageMeta = const VerificationMeta(
    'voteAverage',
  );
  @override
  late final GeneratedColumn<double> voteAverage = GeneratedColumn<double>(
    'vote_average',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voteCountMeta = const VerificationMeta(
    'voteCount',
  );
  @override
  late final GeneratedColumn<int> voteCount = GeneratedColumn<int>(
    'vote_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMillisUtcMeta =
      const VerificationMeta('fetchedAtMillisUtc');
  @override
  late final GeneratedColumn<int> fetchedAtMillisUtc = GeneratedColumn<int>(
    'fetched_at_millis_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    listId,
    rank,
    kind,
    title,
    tmdbId,
    year,
    voteAverage,
    voteCount,
    fetchedAtMillisUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'discovery_titles';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiscoveryTitleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('rank')) {
      context.handle(
        _rankMeta,
        rank.isAcceptableOrUnknown(data['rank']!, _rankMeta),
      );
    } else if (isInserting) {
      context.missing(_rankMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(
        _tmdbIdMeta,
        tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('vote_average')) {
      context.handle(
        _voteAverageMeta,
        voteAverage.isAcceptableOrUnknown(
          data['vote_average']!,
          _voteAverageMeta,
        ),
      );
    }
    if (data.containsKey('vote_count')) {
      context.handle(
        _voteCountMeta,
        voteCount.isAcceptableOrUnknown(data['vote_count']!, _voteCountMeta),
      );
    }
    if (data.containsKey('fetched_at_millis_utc')) {
      context.handle(
        _fetchedAtMillisUtcMeta,
        fetchedAtMillisUtc.isAcceptableOrUnknown(
          data['fetched_at_millis_utc']!,
          _fetchedAtMillisUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMillisUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {listId, rank};
  @override
  DiscoveryTitleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiscoveryTitleRow(
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      rank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rank'],
      )!,
      kind: $DiscoveryTitlesTableTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      tmdbId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tmdb_id'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      voteAverage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}vote_average'],
      ),
      voteCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}vote_count'],
      ),
      fetchedAtMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at_millis_utc'],
      )!,
    );
  }

  @override
  $DiscoveryTitlesTableTable createAlias(String alias) {
    return $DiscoveryTitlesTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DiscoveryKind, String, String> $converterkind =
      const EnumNameConverter<DiscoveryKind>(DiscoveryKind.values);
}

class DiscoveryTitleRow extends DataClass
    implements Insertable<DiscoveryTitleRow> {
  final String listId;

  /// Position in the source list. This IS the ranking we render — it already
  /// encodes popularity far better than any panel rating.
  final int rank;
  final DiscoveryKind kind;
  final String title;
  final int? tmdbId;
  final int? year;
  final double? voteAverage;
  final int? voteCount;
  final int fetchedAtMillisUtc;
  const DiscoveryTitleRow({
    required this.listId,
    required this.rank,
    required this.kind,
    required this.title,
    this.tmdbId,
    this.year,
    this.voteAverage,
    this.voteCount,
    required this.fetchedAtMillisUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['list_id'] = Variable<String>(listId);
    map['rank'] = Variable<int>(rank);
    {
      map['kind'] = Variable<String>(
        $DiscoveryTitlesTableTable.$converterkind.toSql(kind),
      );
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || tmdbId != null) {
      map['tmdb_id'] = Variable<int>(tmdbId);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || voteAverage != null) {
      map['vote_average'] = Variable<double>(voteAverage);
    }
    if (!nullToAbsent || voteCount != null) {
      map['vote_count'] = Variable<int>(voteCount);
    }
    map['fetched_at_millis_utc'] = Variable<int>(fetchedAtMillisUtc);
    return map;
  }

  DiscoveryTitlesTableCompanion toCompanion(bool nullToAbsent) {
    return DiscoveryTitlesTableCompanion(
      listId: Value(listId),
      rank: Value(rank),
      kind: Value(kind),
      title: Value(title),
      tmdbId: tmdbId == null && nullToAbsent
          ? const Value.absent()
          : Value(tmdbId),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      voteAverage: voteAverage == null && nullToAbsent
          ? const Value.absent()
          : Value(voteAverage),
      voteCount: voteCount == null && nullToAbsent
          ? const Value.absent()
          : Value(voteCount),
      fetchedAtMillisUtc: Value(fetchedAtMillisUtc),
    );
  }

  factory DiscoveryTitleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiscoveryTitleRow(
      listId: serializer.fromJson<String>(json['listId']),
      rank: serializer.fromJson<int>(json['rank']),
      kind: $DiscoveryTitlesTableTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      title: serializer.fromJson<String>(json['title']),
      tmdbId: serializer.fromJson<int?>(json['tmdbId']),
      year: serializer.fromJson<int?>(json['year']),
      voteAverage: serializer.fromJson<double?>(json['voteAverage']),
      voteCount: serializer.fromJson<int?>(json['voteCount']),
      fetchedAtMillisUtc: serializer.fromJson<int>(json['fetchedAtMillisUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'listId': serializer.toJson<String>(listId),
      'rank': serializer.toJson<int>(rank),
      'kind': serializer.toJson<String>(
        $DiscoveryTitlesTableTable.$converterkind.toJson(kind),
      ),
      'title': serializer.toJson<String>(title),
      'tmdbId': serializer.toJson<int?>(tmdbId),
      'year': serializer.toJson<int?>(year),
      'voteAverage': serializer.toJson<double?>(voteAverage),
      'voteCount': serializer.toJson<int?>(voteCount),
      'fetchedAtMillisUtc': serializer.toJson<int>(fetchedAtMillisUtc),
    };
  }

  DiscoveryTitleRow copyWith({
    String? listId,
    int? rank,
    DiscoveryKind? kind,
    String? title,
    Value<int?> tmdbId = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<double?> voteAverage = const Value.absent(),
    Value<int?> voteCount = const Value.absent(),
    int? fetchedAtMillisUtc,
  }) => DiscoveryTitleRow(
    listId: listId ?? this.listId,
    rank: rank ?? this.rank,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    tmdbId: tmdbId.present ? tmdbId.value : this.tmdbId,
    year: year.present ? year.value : this.year,
    voteAverage: voteAverage.present ? voteAverage.value : this.voteAverage,
    voteCount: voteCount.present ? voteCount.value : this.voteCount,
    fetchedAtMillisUtc: fetchedAtMillisUtc ?? this.fetchedAtMillisUtc,
  );
  DiscoveryTitleRow copyWithCompanion(DiscoveryTitlesTableCompanion data) {
    return DiscoveryTitleRow(
      listId: data.listId.present ? data.listId.value : this.listId,
      rank: data.rank.present ? data.rank.value : this.rank,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
      year: data.year.present ? data.year.value : this.year,
      voteAverage: data.voteAverage.present
          ? data.voteAverage.value
          : this.voteAverage,
      voteCount: data.voteCount.present ? data.voteCount.value : this.voteCount,
      fetchedAtMillisUtc: data.fetchedAtMillisUtc.present
          ? data.fetchedAtMillisUtc.value
          : this.fetchedAtMillisUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveryTitleRow(')
          ..write('listId: $listId, ')
          ..write('rank: $rank, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('year: $year, ')
          ..write('voteAverage: $voteAverage, ')
          ..write('voteCount: $voteCount, ')
          ..write('fetchedAtMillisUtc: $fetchedAtMillisUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    listId,
    rank,
    kind,
    title,
    tmdbId,
    year,
    voteAverage,
    voteCount,
    fetchedAtMillisUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiscoveryTitleRow &&
          other.listId == this.listId &&
          other.rank == this.rank &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.tmdbId == this.tmdbId &&
          other.year == this.year &&
          other.voteAverage == this.voteAverage &&
          other.voteCount == this.voteCount &&
          other.fetchedAtMillisUtc == this.fetchedAtMillisUtc);
}

class DiscoveryTitlesTableCompanion extends UpdateCompanion<DiscoveryTitleRow> {
  final Value<String> listId;
  final Value<int> rank;
  final Value<DiscoveryKind> kind;
  final Value<String> title;
  final Value<int?> tmdbId;
  final Value<int?> year;
  final Value<double?> voteAverage;
  final Value<int?> voteCount;
  final Value<int> fetchedAtMillisUtc;
  final Value<int> rowid;
  const DiscoveryTitlesTableCompanion({
    this.listId = const Value.absent(),
    this.rank = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.year = const Value.absent(),
    this.voteAverage = const Value.absent(),
    this.voteCount = const Value.absent(),
    this.fetchedAtMillisUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiscoveryTitlesTableCompanion.insert({
    required String listId,
    required int rank,
    required DiscoveryKind kind,
    required String title,
    this.tmdbId = const Value.absent(),
    this.year = const Value.absent(),
    this.voteAverage = const Value.absent(),
    this.voteCount = const Value.absent(),
    required int fetchedAtMillisUtc,
    this.rowid = const Value.absent(),
  }) : listId = Value(listId),
       rank = Value(rank),
       kind = Value(kind),
       title = Value(title),
       fetchedAtMillisUtc = Value(fetchedAtMillisUtc);
  static Insertable<DiscoveryTitleRow> custom({
    Expression<String>? listId,
    Expression<int>? rank,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<int>? tmdbId,
    Expression<int>? year,
    Expression<double>? voteAverage,
    Expression<int>? voteCount,
    Expression<int>? fetchedAtMillisUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (listId != null) 'list_id': listId,
      if (rank != null) 'rank': rank,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (tmdbId != null) 'tmdb_id': tmdbId,
      if (year != null) 'year': year,
      if (voteAverage != null) 'vote_average': voteAverage,
      if (voteCount != null) 'vote_count': voteCount,
      if (fetchedAtMillisUtc != null)
        'fetched_at_millis_utc': fetchedAtMillisUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiscoveryTitlesTableCompanion copyWith({
    Value<String>? listId,
    Value<int>? rank,
    Value<DiscoveryKind>? kind,
    Value<String>? title,
    Value<int?>? tmdbId,
    Value<int?>? year,
    Value<double?>? voteAverage,
    Value<int?>? voteCount,
    Value<int>? fetchedAtMillisUtc,
    Value<int>? rowid,
  }) {
    return DiscoveryTitlesTableCompanion(
      listId: listId ?? this.listId,
      rank: rank ?? this.rank,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      tmdbId: tmdbId ?? this.tmdbId,
      year: year ?? this.year,
      voteAverage: voteAverage ?? this.voteAverage,
      voteCount: voteCount ?? this.voteCount,
      fetchedAtMillisUtc: fetchedAtMillisUtc ?? this.fetchedAtMillisUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (rank.present) {
      map['rank'] = Variable<int>(rank.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $DiscoveryTitlesTableTable.$converterkind.toSql(kind.value),
      );
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<int>(tmdbId.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (voteAverage.present) {
      map['vote_average'] = Variable<double>(voteAverage.value);
    }
    if (voteCount.present) {
      map['vote_count'] = Variable<int>(voteCount.value);
    }
    if (fetchedAtMillisUtc.present) {
      map['fetched_at_millis_utc'] = Variable<int>(fetchedAtMillisUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveryTitlesTableCompanion(')
          ..write('listId: $listId, ')
          ..write('rank: $rank, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('year: $year, ')
          ..write('voteAverage: $voteAverage, ')
          ..write('voteCount: $voteCount, ')
          ..write('fetchedAtMillisUtc: $fetchedAtMillisUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiscoveryMatchesTableTable extends DiscoveryMatchesTable
    with TableInfo<$DiscoveryMatchesTableTable, DiscoveryMatchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiscoveryMatchesTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rankMeta = const VerificationMeta('rank');
  @override
  late final GeneratedColumn<int> rank = GeneratedColumn<int>(
    'rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMillisUtcMeta =
      const VerificationMeta('resolvedAtMillisUtc');
  @override
  late final GeneratedColumn<int> resolvedAtMillisUtc = GeneratedColumn<int>(
    'resolved_at_millis_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    listId,
    rank,
    localId,
    resolvedAtMillisUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'discovery_matches';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiscoveryMatchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('rank')) {
      context.handle(
        _rankMeta,
        rank.isAcceptableOrUnknown(data['rank']!, _rankMeta),
      );
    } else if (isInserting) {
      context.missing(_rankMeta);
    }
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('resolved_at_millis_utc')) {
      context.handle(
        _resolvedAtMillisUtcMeta,
        resolvedAtMillisUtc.isAcceptableOrUnknown(
          data['resolved_at_millis_utc']!,
          _resolvedAtMillisUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resolvedAtMillisUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, listId, rank};
  @override
  DiscoveryMatchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiscoveryMatchRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      rank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rank'],
      )!,
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      resolvedAtMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolved_at_millis_utc'],
      )!,
    );
  }

  @override
  $DiscoveryMatchesTableTable createAlias(String alias) {
    return $DiscoveryMatchesTableTable(attachedDatabase, alias);
  }
}

class DiscoveryMatchRow extends DataClass
    implements Insertable<DiscoveryMatchRow> {
  final String accountId;
  final String listId;
  final int rank;

  /// `movies.id` or `series.id`, per the list's kind.
  final String localId;
  final int resolvedAtMillisUtc;
  const DiscoveryMatchRow({
    required this.accountId,
    required this.listId,
    required this.rank,
    required this.localId,
    required this.resolvedAtMillisUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['list_id'] = Variable<String>(listId);
    map['rank'] = Variable<int>(rank);
    map['local_id'] = Variable<String>(localId);
    map['resolved_at_millis_utc'] = Variable<int>(resolvedAtMillisUtc);
    return map;
  }

  DiscoveryMatchesTableCompanion toCompanion(bool nullToAbsent) {
    return DiscoveryMatchesTableCompanion(
      accountId: Value(accountId),
      listId: Value(listId),
      rank: Value(rank),
      localId: Value(localId),
      resolvedAtMillisUtc: Value(resolvedAtMillisUtc),
    );
  }

  factory DiscoveryMatchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiscoveryMatchRow(
      accountId: serializer.fromJson<String>(json['accountId']),
      listId: serializer.fromJson<String>(json['listId']),
      rank: serializer.fromJson<int>(json['rank']),
      localId: serializer.fromJson<String>(json['localId']),
      resolvedAtMillisUtc: serializer.fromJson<int>(
        json['resolvedAtMillisUtc'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'listId': serializer.toJson<String>(listId),
      'rank': serializer.toJson<int>(rank),
      'localId': serializer.toJson<String>(localId),
      'resolvedAtMillisUtc': serializer.toJson<int>(resolvedAtMillisUtc),
    };
  }

  DiscoveryMatchRow copyWith({
    String? accountId,
    String? listId,
    int? rank,
    String? localId,
    int? resolvedAtMillisUtc,
  }) => DiscoveryMatchRow(
    accountId: accountId ?? this.accountId,
    listId: listId ?? this.listId,
    rank: rank ?? this.rank,
    localId: localId ?? this.localId,
    resolvedAtMillisUtc: resolvedAtMillisUtc ?? this.resolvedAtMillisUtc,
  );
  DiscoveryMatchRow copyWithCompanion(DiscoveryMatchesTableCompanion data) {
    return DiscoveryMatchRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      listId: data.listId.present ? data.listId.value : this.listId,
      rank: data.rank.present ? data.rank.value : this.rank,
      localId: data.localId.present ? data.localId.value : this.localId,
      resolvedAtMillisUtc: data.resolvedAtMillisUtc.present
          ? data.resolvedAtMillisUtc.value
          : this.resolvedAtMillisUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveryMatchRow(')
          ..write('accountId: $accountId, ')
          ..write('listId: $listId, ')
          ..write('rank: $rank, ')
          ..write('localId: $localId, ')
          ..write('resolvedAtMillisUtc: $resolvedAtMillisUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(accountId, listId, rank, localId, resolvedAtMillisUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiscoveryMatchRow &&
          other.accountId == this.accountId &&
          other.listId == this.listId &&
          other.rank == this.rank &&
          other.localId == this.localId &&
          other.resolvedAtMillisUtc == this.resolvedAtMillisUtc);
}

class DiscoveryMatchesTableCompanion
    extends UpdateCompanion<DiscoveryMatchRow> {
  final Value<String> accountId;
  final Value<String> listId;
  final Value<int> rank;
  final Value<String> localId;
  final Value<int> resolvedAtMillisUtc;
  final Value<int> rowid;
  const DiscoveryMatchesTableCompanion({
    this.accountId = const Value.absent(),
    this.listId = const Value.absent(),
    this.rank = const Value.absent(),
    this.localId = const Value.absent(),
    this.resolvedAtMillisUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiscoveryMatchesTableCompanion.insert({
    required String accountId,
    required String listId,
    required int rank,
    required String localId,
    required int resolvedAtMillisUtc,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       listId = Value(listId),
       rank = Value(rank),
       localId = Value(localId),
       resolvedAtMillisUtc = Value(resolvedAtMillisUtc);
  static Insertable<DiscoveryMatchRow> custom({
    Expression<String>? accountId,
    Expression<String>? listId,
    Expression<int>? rank,
    Expression<String>? localId,
    Expression<int>? resolvedAtMillisUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (listId != null) 'list_id': listId,
      if (rank != null) 'rank': rank,
      if (localId != null) 'local_id': localId,
      if (resolvedAtMillisUtc != null)
        'resolved_at_millis_utc': resolvedAtMillisUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiscoveryMatchesTableCompanion copyWith({
    Value<String>? accountId,
    Value<String>? listId,
    Value<int>? rank,
    Value<String>? localId,
    Value<int>? resolvedAtMillisUtc,
    Value<int>? rowid,
  }) {
    return DiscoveryMatchesTableCompanion(
      accountId: accountId ?? this.accountId,
      listId: listId ?? this.listId,
      rank: rank ?? this.rank,
      localId: localId ?? this.localId,
      resolvedAtMillisUtc: resolvedAtMillisUtc ?? this.resolvedAtMillisUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (rank.present) {
      map['rank'] = Variable<int>(rank.value);
    }
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (resolvedAtMillisUtc.present) {
      map['resolved_at_millis_utc'] = Variable<int>(resolvedAtMillisUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveryMatchesTableCompanion(')
          ..write('accountId: $accountId, ')
          ..write('listId: $listId, ')
          ..write('rank: $rank, ')
          ..write('localId: $localId, ')
          ..write('resolvedAtMillisUtc: $resolvedAtMillisUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoryTableTable extends SearchHistoryTable
    with TableInfo<$SearchHistoryTableTable, SearchHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchedAtMillisUtcMeta =
      const VerificationMeta('searchedAtMillisUtc');
  @override
  late final GeneratedColumn<int> searchedAtMillisUtc = GeneratedColumn<int>(
    'searched_at_millis_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [query, searchedAtMillisUtc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('searched_at_millis_utc')) {
      context.handle(
        _searchedAtMillisUtcMeta,
        searchedAtMillisUtc.isAcceptableOrUnknown(
          data['searched_at_millis_utc']!,
          _searchedAtMillisUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_searchedAtMillisUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {query};
  @override
  SearchHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistoryRow(
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      searchedAtMillisUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}searched_at_millis_utc'],
      )!,
    );
  }

  @override
  $SearchHistoryTableTable createAlias(String alias) {
    return $SearchHistoryTableTable(attachedDatabase, alias);
  }
}

class SearchHistoryRow extends DataClass
    implements Insertable<SearchHistoryRow> {
  final String query;
  final int searchedAtMillisUtc;
  const SearchHistoryRow({
    required this.query,
    required this.searchedAtMillisUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['query'] = Variable<String>(query);
    map['searched_at_millis_utc'] = Variable<int>(searchedAtMillisUtc);
    return map;
  }

  SearchHistoryTableCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoryTableCompanion(
      query: Value(query),
      searchedAtMillisUtc: Value(searchedAtMillisUtc),
    );
  }

  factory SearchHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistoryRow(
      query: serializer.fromJson<String>(json['query']),
      searchedAtMillisUtc: serializer.fromJson<int>(
        json['searchedAtMillisUtc'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'query': serializer.toJson<String>(query),
      'searchedAtMillisUtc': serializer.toJson<int>(searchedAtMillisUtc),
    };
  }

  SearchHistoryRow copyWith({String? query, int? searchedAtMillisUtc}) =>
      SearchHistoryRow(
        query: query ?? this.query,
        searchedAtMillisUtc: searchedAtMillisUtc ?? this.searchedAtMillisUtc,
      );
  SearchHistoryRow copyWithCompanion(SearchHistoryTableCompanion data) {
    return SearchHistoryRow(
      query: data.query.present ? data.query.value : this.query,
      searchedAtMillisUtc: data.searchedAtMillisUtc.present
          ? data.searchedAtMillisUtc.value
          : this.searchedAtMillisUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryRow(')
          ..write('query: $query, ')
          ..write('searchedAtMillisUtc: $searchedAtMillisUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(query, searchedAtMillisUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistoryRow &&
          other.query == this.query &&
          other.searchedAtMillisUtc == this.searchedAtMillisUtc);
}

class SearchHistoryTableCompanion extends UpdateCompanion<SearchHistoryRow> {
  final Value<String> query;
  final Value<int> searchedAtMillisUtc;
  final Value<int> rowid;
  const SearchHistoryTableCompanion({
    this.query = const Value.absent(),
    this.searchedAtMillisUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchHistoryTableCompanion.insert({
    required String query,
    required int searchedAtMillisUtc,
    this.rowid = const Value.absent(),
  }) : query = Value(query),
       searchedAtMillisUtc = Value(searchedAtMillisUtc);
  static Insertable<SearchHistoryRow> custom({
    Expression<String>? query,
    Expression<int>? searchedAtMillisUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (query != null) 'query': query,
      if (searchedAtMillisUtc != null)
        'searched_at_millis_utc': searchedAtMillisUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchHistoryTableCompanion copyWith({
    Value<String>? query,
    Value<int>? searchedAtMillisUtc,
    Value<int>? rowid,
  }) {
    return SearchHistoryTableCompanion(
      query: query ?? this.query,
      searchedAtMillisUtc: searchedAtMillisUtc ?? this.searchedAtMillisUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (searchedAtMillisUtc.present) {
      map['searched_at_millis_utc'] = Variable<int>(searchedAtMillisUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryTableCompanion(')
          ..write('query: $query, ')
          ..write('searchedAtMillisUtc: $searchedAtMillisUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTableTable accountsTable = $AccountsTableTable(this);
  late final $CategoriesTableTable categoriesTable = $CategoriesTableTable(
    this,
  );
  late final $MoviesTableTable moviesTable = $MoviesTableTable(this);
  late final $SeriesTableTable seriesTable = $SeriesTableTable(this);
  late final $EpisodesTableTable episodesTable = $EpisodesTableTable(this);
  late final $ChannelsTableTable channelsTable = $ChannelsTableTable(this);
  late final $WatchProgressTableTable watchProgressTable =
      $WatchProgressTableTable(this);
  late final $PreferencesTableTable preferencesTable = $PreferencesTableTable(
    this,
  );
  late final $FavoritesTableTable favoritesTable = $FavoritesTableTable(this);
  late final $EpgCacheTableTable epgCacheTable = $EpgCacheTableTable(this);
  late final $CatalogMetaTableTable catalogMetaTable = $CatalogMetaTableTable(
    this,
  );
  late final $CatalogCategoryMetaTableTable catalogCategoryMetaTable =
      $CatalogCategoryMetaTableTable(this);
  late final $DiscoveryTitlesTableTable discoveryTitlesTable =
      $DiscoveryTitlesTableTable(this);
  late final $DiscoveryMatchesTableTable discoveryMatchesTable =
      $DiscoveryMatchesTableTable(this);
  late final $SearchHistoryTableTable searchHistoryTable =
      $SearchHistoryTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accountsTable,
    categoriesTable,
    moviesTable,
    seriesTable,
    episodesTable,
    channelsTable,
    watchProgressTable,
    preferencesTable,
    favoritesTable,
    epgCacheTable,
    catalogMetaTable,
    catalogCategoryMetaTable,
    discoveryTitlesTable,
    discoveryMatchesTable,
    searchHistoryTable,
  ];
}

typedef $$AccountsTableTableCreateCompanionBuilder =
    AccountsTableCompanion Function({
      required String id,
      required AccountType type,
      required String name,
      required String serverUrl,
      required String username,
      Value<String?> epgUrl,
      required int createdAtMillisUtc,
      Value<int> rowid,
    });
typedef $$AccountsTableTableUpdateCompanionBuilder =
    AccountsTableCompanion Function({
      Value<String> id,
      Value<AccountType> type,
      Value<String> name,
      Value<String> serverUrl,
      Value<String> username,
      Value<String?> epgUrl,
      Value<int> createdAtMillisUtc,
      Value<int> rowid,
    });

class $$AccountsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTableTable> {
  $$AccountsTableTableFilterComposer({
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

  ColumnWithTypeConverterFilters<AccountType, AccountType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverUrl => $composableBuilder(
    column: $table.serverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgUrl => $composableBuilder(
    column: $table.epgUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMillisUtc => $composableBuilder(
    column: $table.createdAtMillisUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTableTable> {
  $$AccountsTableTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverUrl => $composableBuilder(
    column: $table.serverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgUrl => $composableBuilder(
    column: $table.epgUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMillisUtc => $composableBuilder(
    column: $table.createdAtMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTableTable> {
  $$AccountsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get serverUrl =>
      $composableBuilder(column: $table.serverUrl, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get epgUrl =>
      $composableBuilder(column: $table.epgUrl, builder: (column) => column);

  GeneratedColumn<int> get createdAtMillisUtc => $composableBuilder(
    column: $table.createdAtMillisUtc,
    builder: (column) => column,
  );
}

class $$AccountsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTableTable,
          AccountRow,
          $$AccountsTableTableFilterComposer,
          $$AccountsTableTableOrderingComposer,
          $$AccountsTableTableAnnotationComposer,
          $$AccountsTableTableCreateCompanionBuilder,
          $$AccountsTableTableUpdateCompanionBuilder,
          (
            AccountRow,
            BaseReferences<_$AppDatabase, $AccountsTableTable, AccountRow>,
          ),
          AccountRow,
          PrefetchHooks Function()
        > {
  $$AccountsTableTableTableManager(_$AppDatabase db, $AccountsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<AccountType> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> serverUrl = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String?> epgUrl = const Value.absent(),
                Value<int> createdAtMillisUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsTableCompanion(
                id: id,
                type: type,
                name: name,
                serverUrl: serverUrl,
                username: username,
                epgUrl: epgUrl,
                createdAtMillisUtc: createdAtMillisUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required AccountType type,
                required String name,
                required String serverUrl,
                required String username,
                Value<String?> epgUrl = const Value.absent(),
                required int createdAtMillisUtc,
                Value<int> rowid = const Value.absent(),
              }) => AccountsTableCompanion.insert(
                id: id,
                type: type,
                name: name,
                serverUrl: serverUrl,
                username: username,
                epgUrl: epgUrl,
                createdAtMillisUtc: createdAtMillisUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTableTable,
      AccountRow,
      $$AccountsTableTableFilterComposer,
      $$AccountsTableTableOrderingComposer,
      $$AccountsTableTableAnnotationComposer,
      $$AccountsTableTableCreateCompanionBuilder,
      $$AccountsTableTableUpdateCompanionBuilder,
      (
        AccountRow,
        BaseReferences<_$AppDatabase, $AccountsTableTable, AccountRow>,
      ),
      AccountRow,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableTableCreateCompanionBuilder =
    CategoriesTableCompanion Function({
      required String id,
      required String accountId,
      required CategoryType type,
      required String name,
      required int sortOrder,
      Value<int> rowid,
    });
typedef $$CategoriesTableTableUpdateCompanionBuilder =
    CategoriesTableCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<CategoryType> type,
      Value<String> name,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$CategoriesTableTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTableTable> {
  $$CategoriesTableTableFilterComposer({
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

  ColumnWithTypeConverterFilters<CategoryType, CategoryType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTableTable> {
  $$CategoriesTableTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTableTable> {
  $$CategoriesTableTableAnnotationComposer({
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

  GeneratedColumnWithTypeConverter<CategoryType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$CategoriesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTableTable,
          CategoryRow,
          $$CategoriesTableTableFilterComposer,
          $$CategoriesTableTableOrderingComposer,
          $$CategoriesTableTableAnnotationComposer,
          $$CategoriesTableTableCreateCompanionBuilder,
          $$CategoriesTableTableUpdateCompanionBuilder,
          (
            CategoryRow,
            BaseReferences<_$AppDatabase, $CategoriesTableTable, CategoryRow>,
          ),
          CategoryRow,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableTableManager(
    _$AppDatabase db,
    $CategoriesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<CategoryType> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesTableCompanion(
                id: id,
                accountId: accountId,
                type: type,
                name: name,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required CategoryType type,
                required String name,
                required int sortOrder,
                Value<int> rowid = const Value.absent(),
              }) => CategoriesTableCompanion.insert(
                id: id,
                accountId: accountId,
                type: type,
                name: name,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTableTable,
      CategoryRow,
      $$CategoriesTableTableFilterComposer,
      $$CategoriesTableTableOrderingComposer,
      $$CategoriesTableTableAnnotationComposer,
      $$CategoriesTableTableCreateCompanionBuilder,
      $$CategoriesTableTableUpdateCompanionBuilder,
      (
        CategoryRow,
        BaseReferences<_$AppDatabase, $CategoriesTableTable, CategoryRow>,
      ),
      CategoryRow,
      PrefetchHooks Function()
    >;
typedef $$MoviesTableTableCreateCompanionBuilder =
    MoviesTableCompanion Function({
      required String id,
      required String accountId,
      required String categoryId,
      required String name,
      Value<String?> posterUrl,
      Value<String?> backdropUrl,
      Value<double?> rating,
      Value<int?> year,
      Value<String?> plot,
      Value<String?> genre,
      Value<String?> cast,
      Value<int?> durationSeconds,
      Value<String?> containerExt,
      Value<int?> addedAtMillisUtc,
      required int cachedAtMillisUtc,
      Value<int> rowid,
    });
typedef $$MoviesTableTableUpdateCompanionBuilder =
    MoviesTableCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> categoryId,
      Value<String> name,
      Value<String?> posterUrl,
      Value<String?> backdropUrl,
      Value<double?> rating,
      Value<int?> year,
      Value<String?> plot,
      Value<String?> genre,
      Value<String?> cast,
      Value<int?> durationSeconds,
      Value<String?> containerExt,
      Value<int?> addedAtMillisUtc,
      Value<int> cachedAtMillisUtc,
      Value<int> rowid,
    });

class $$MoviesTableTableFilterComposer
    extends Composer<_$AppDatabase, $MoviesTableTable> {
  $$MoviesTableTableFilterComposer({
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

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posterUrl => $composableBuilder(
    column: $table.posterUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cast => $composableBuilder(
    column: $table.cast,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get containerExt => $composableBuilder(
    column: $table.containerExt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAtMillisUtc => $composableBuilder(
    column: $table.addedAtMillisUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAtMillisUtc => $composableBuilder(
    column: $table.cachedAtMillisUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MoviesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MoviesTableTable> {
  $$MoviesTableTableOrderingComposer({
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

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posterUrl => $composableBuilder(
    column: $table.posterUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cast => $composableBuilder(
    column: $table.cast,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get containerExt => $composableBuilder(
    column: $table.containerExt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAtMillisUtc => $composableBuilder(
    column: $table.addedAtMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAtMillisUtc => $composableBuilder(
    column: $table.cachedAtMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MoviesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MoviesTableTable> {
  $$MoviesTableTableAnnotationComposer({
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

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get posterUrl =>
      $composableBuilder(column: $table.posterUrl, builder: (column) => column);

  GeneratedColumn<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get cast =>
      $composableBuilder(column: $table.cast, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get containerExt => $composableBuilder(
    column: $table.containerExt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get addedAtMillisUtc => $composableBuilder(
    column: $table.addedAtMillisUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedAtMillisUtc => $composableBuilder(
    column: $table.cachedAtMillisUtc,
    builder: (column) => column,
  );
}

class $$MoviesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MoviesTableTable,
          MovieRow,
          $$MoviesTableTableFilterComposer,
          $$MoviesTableTableOrderingComposer,
          $$MoviesTableTableAnnotationComposer,
          $$MoviesTableTableCreateCompanionBuilder,
          $$MoviesTableTableUpdateCompanionBuilder,
          (
            MovieRow,
            BaseReferences<_$AppDatabase, $MoviesTableTable, MovieRow>,
          ),
          MovieRow,
          PrefetchHooks Function()
        > {
  $$MoviesTableTableTableManager(_$AppDatabase db, $MoviesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MoviesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MoviesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MoviesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> posterUrl = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> cast = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String?> containerExt = const Value.absent(),
                Value<int?> addedAtMillisUtc = const Value.absent(),
                Value<int> cachedAtMillisUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MoviesTableCompanion(
                id: id,
                accountId: accountId,
                categoryId: categoryId,
                name: name,
                posterUrl: posterUrl,
                backdropUrl: backdropUrl,
                rating: rating,
                year: year,
                plot: plot,
                genre: genre,
                cast: cast,
                durationSeconds: durationSeconds,
                containerExt: containerExt,
                addedAtMillisUtc: addedAtMillisUtc,
                cachedAtMillisUtc: cachedAtMillisUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String categoryId,
                required String name,
                Value<String?> posterUrl = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> cast = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String?> containerExt = const Value.absent(),
                Value<int?> addedAtMillisUtc = const Value.absent(),
                required int cachedAtMillisUtc,
                Value<int> rowid = const Value.absent(),
              }) => MoviesTableCompanion.insert(
                id: id,
                accountId: accountId,
                categoryId: categoryId,
                name: name,
                posterUrl: posterUrl,
                backdropUrl: backdropUrl,
                rating: rating,
                year: year,
                plot: plot,
                genre: genre,
                cast: cast,
                durationSeconds: durationSeconds,
                containerExt: containerExt,
                addedAtMillisUtc: addedAtMillisUtc,
                cachedAtMillisUtc: cachedAtMillisUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MoviesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MoviesTableTable,
      MovieRow,
      $$MoviesTableTableFilterComposer,
      $$MoviesTableTableOrderingComposer,
      $$MoviesTableTableAnnotationComposer,
      $$MoviesTableTableCreateCompanionBuilder,
      $$MoviesTableTableUpdateCompanionBuilder,
      (MovieRow, BaseReferences<_$AppDatabase, $MoviesTableTable, MovieRow>),
      MovieRow,
      PrefetchHooks Function()
    >;
typedef $$SeriesTableTableCreateCompanionBuilder =
    SeriesTableCompanion Function({
      required String id,
      required String accountId,
      required String categoryId,
      required String name,
      Value<String?> posterUrl,
      Value<String?> backdropUrl,
      Value<double?> rating,
      Value<int?> year,
      Value<String?> plot,
      Value<String?> genre,
      Value<String?> cast,
      required int cachedAtMillisUtc,
      Value<int> rowid,
    });
typedef $$SeriesTableTableUpdateCompanionBuilder =
    SeriesTableCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> categoryId,
      Value<String> name,
      Value<String?> posterUrl,
      Value<String?> backdropUrl,
      Value<double?> rating,
      Value<int?> year,
      Value<String?> plot,
      Value<String?> genre,
      Value<String?> cast,
      Value<int> cachedAtMillisUtc,
      Value<int> rowid,
    });

class $$SeriesTableTableFilterComposer
    extends Composer<_$AppDatabase, $SeriesTableTable> {
  $$SeriesTableTableFilterComposer({
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

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posterUrl => $composableBuilder(
    column: $table.posterUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cast => $composableBuilder(
    column: $table.cast,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAtMillisUtc => $composableBuilder(
    column: $table.cachedAtMillisUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeriesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SeriesTableTable> {
  $$SeriesTableTableOrderingComposer({
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

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posterUrl => $composableBuilder(
    column: $table.posterUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cast => $composableBuilder(
    column: $table.cast,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAtMillisUtc => $composableBuilder(
    column: $table.cachedAtMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeriesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeriesTableTable> {
  $$SeriesTableTableAnnotationComposer({
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

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get posterUrl =>
      $composableBuilder(column: $table.posterUrl, builder: (column) => column);

  GeneratedColumn<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get cast =>
      $composableBuilder(column: $table.cast, builder: (column) => column);

  GeneratedColumn<int> get cachedAtMillisUtc => $composableBuilder(
    column: $table.cachedAtMillisUtc,
    builder: (column) => column,
  );
}

class $$SeriesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeriesTableTable,
          SeriesRow,
          $$SeriesTableTableFilterComposer,
          $$SeriesTableTableOrderingComposer,
          $$SeriesTableTableAnnotationComposer,
          $$SeriesTableTableCreateCompanionBuilder,
          $$SeriesTableTableUpdateCompanionBuilder,
          (
            SeriesRow,
            BaseReferences<_$AppDatabase, $SeriesTableTable, SeriesRow>,
          ),
          SeriesRow,
          PrefetchHooks Function()
        > {
  $$SeriesTableTableTableManager(_$AppDatabase db, $SeriesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeriesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeriesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeriesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> posterUrl = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> cast = const Value.absent(),
                Value<int> cachedAtMillisUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeriesTableCompanion(
                id: id,
                accountId: accountId,
                categoryId: categoryId,
                name: name,
                posterUrl: posterUrl,
                backdropUrl: backdropUrl,
                rating: rating,
                year: year,
                plot: plot,
                genre: genre,
                cast: cast,
                cachedAtMillisUtc: cachedAtMillisUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String categoryId,
                required String name,
                Value<String?> posterUrl = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> cast = const Value.absent(),
                required int cachedAtMillisUtc,
                Value<int> rowid = const Value.absent(),
              }) => SeriesTableCompanion.insert(
                id: id,
                accountId: accountId,
                categoryId: categoryId,
                name: name,
                posterUrl: posterUrl,
                backdropUrl: backdropUrl,
                rating: rating,
                year: year,
                plot: plot,
                genre: genre,
                cast: cast,
                cachedAtMillisUtc: cachedAtMillisUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeriesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeriesTableTable,
      SeriesRow,
      $$SeriesTableTableFilterComposer,
      $$SeriesTableTableOrderingComposer,
      $$SeriesTableTableAnnotationComposer,
      $$SeriesTableTableCreateCompanionBuilder,
      $$SeriesTableTableUpdateCompanionBuilder,
      (SeriesRow, BaseReferences<_$AppDatabase, $SeriesTableTable, SeriesRow>),
      SeriesRow,
      PrefetchHooks Function()
    >;
typedef $$EpisodesTableTableCreateCompanionBuilder =
    EpisodesTableCompanion Function({
      required String id,
      required String accountId,
      required String seriesId,
      required int seasonNumber,
      required int episodeNumber,
      required String title,
      Value<String?> plot,
      Value<int?> durationSeconds,
      Value<String?> stillUrl,
      Value<String?> containerExt,
      Value<int?> airDateMillisUtc,
      required int cachedAtMillisUtc,
      Value<int> rowid,
    });
typedef $$EpisodesTableTableUpdateCompanionBuilder =
    EpisodesTableCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> seriesId,
      Value<int> seasonNumber,
      Value<int> episodeNumber,
      Value<String> title,
      Value<String?> plot,
      Value<int?> durationSeconds,
      Value<String?> stillUrl,
      Value<String?> containerExt,
      Value<int?> airDateMillisUtc,
      Value<int> cachedAtMillisUtc,
      Value<int> rowid,
    });

class $$EpisodesTableTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodesTableTable> {
  $$EpisodesTableTableFilterComposer({
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

  ColumnFilters<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stillUrl => $composableBuilder(
    column: $table.stillUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get containerExt => $composableBuilder(
    column: $table.containerExt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get airDateMillisUtc => $composableBuilder(
    column: $table.airDateMillisUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAtMillisUtc => $composableBuilder(
    column: $table.cachedAtMillisUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpisodesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodesTableTable> {
  $$EpisodesTableTableOrderingComposer({
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

  ColumnOrderings<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stillUrl => $composableBuilder(
    column: $table.stillUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get containerExt => $composableBuilder(
    column: $table.containerExt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get airDateMillisUtc => $composableBuilder(
    column: $table.airDateMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAtMillisUtc => $composableBuilder(
    column: $table.cachedAtMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpisodesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodesTableTable> {
  $$EpisodesTableTableAnnotationComposer({
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

  GeneratedColumn<String> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stillUrl =>
      $composableBuilder(column: $table.stillUrl, builder: (column) => column);

  GeneratedColumn<String> get containerExt => $composableBuilder(
    column: $table.containerExt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get airDateMillisUtc => $composableBuilder(
    column: $table.airDateMillisUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedAtMillisUtc => $composableBuilder(
    column: $table.cachedAtMillisUtc,
    builder: (column) => column,
  );
}

class $$EpisodesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpisodesTableTable,
          EpisodeRow,
          $$EpisodesTableTableFilterComposer,
          $$EpisodesTableTableOrderingComposer,
          $$EpisodesTableTableAnnotationComposer,
          $$EpisodesTableTableCreateCompanionBuilder,
          $$EpisodesTableTableUpdateCompanionBuilder,
          (
            EpisodeRow,
            BaseReferences<_$AppDatabase, $EpisodesTableTable, EpisodeRow>,
          ),
          EpisodeRow,
          PrefetchHooks Function()
        > {
  $$EpisodesTableTableTableManager(_$AppDatabase db, $EpisodesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> seriesId = const Value.absent(),
                Value<int> seasonNumber = const Value.absent(),
                Value<int> episodeNumber = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String?> stillUrl = const Value.absent(),
                Value<String?> containerExt = const Value.absent(),
                Value<int?> airDateMillisUtc = const Value.absent(),
                Value<int> cachedAtMillisUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpisodesTableCompanion(
                id: id,
                accountId: accountId,
                seriesId: seriesId,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber,
                title: title,
                plot: plot,
                durationSeconds: durationSeconds,
                stillUrl: stillUrl,
                containerExt: containerExt,
                airDateMillisUtc: airDateMillisUtc,
                cachedAtMillisUtc: cachedAtMillisUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String seriesId,
                required int seasonNumber,
                required int episodeNumber,
                required String title,
                Value<String?> plot = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String?> stillUrl = const Value.absent(),
                Value<String?> containerExt = const Value.absent(),
                Value<int?> airDateMillisUtc = const Value.absent(),
                required int cachedAtMillisUtc,
                Value<int> rowid = const Value.absent(),
              }) => EpisodesTableCompanion.insert(
                id: id,
                accountId: accountId,
                seriesId: seriesId,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber,
                title: title,
                plot: plot,
                durationSeconds: durationSeconds,
                stillUrl: stillUrl,
                containerExt: containerExt,
                airDateMillisUtc: airDateMillisUtc,
                cachedAtMillisUtc: cachedAtMillisUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EpisodesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpisodesTableTable,
      EpisodeRow,
      $$EpisodesTableTableFilterComposer,
      $$EpisodesTableTableOrderingComposer,
      $$EpisodesTableTableAnnotationComposer,
      $$EpisodesTableTableCreateCompanionBuilder,
      $$EpisodesTableTableUpdateCompanionBuilder,
      (
        EpisodeRow,
        BaseReferences<_$AppDatabase, $EpisodesTableTable, EpisodeRow>,
      ),
      EpisodeRow,
      PrefetchHooks Function()
    >;
typedef $$ChannelsTableTableCreateCompanionBuilder =
    ChannelsTableCompanion Function({
      required String id,
      required String accountId,
      required String categoryId,
      required String name,
      Value<String?> logoUrl,
      Value<String?> epgChannelId,
      Value<int?> sortOrder,
      required int cachedAtMillisUtc,
      Value<int> rowid,
    });
typedef $$ChannelsTableTableUpdateCompanionBuilder =
    ChannelsTableCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> categoryId,
      Value<String> name,
      Value<String?> logoUrl,
      Value<String?> epgChannelId,
      Value<int?> sortOrder,
      Value<int> cachedAtMillisUtc,
      Value<int> rowid,
    });

class $$ChannelsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ChannelsTableTable> {
  $$ChannelsTableTableFilterComposer({
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

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAtMillisUtc => $composableBuilder(
    column: $table.cachedAtMillisUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChannelsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ChannelsTableTable> {
  $$ChannelsTableTableOrderingComposer({
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

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAtMillisUtc => $composableBuilder(
    column: $table.cachedAtMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChannelsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChannelsTableTable> {
  $$ChannelsTableTableAnnotationComposer({
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

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get logoUrl =>
      $composableBuilder(column: $table.logoUrl, builder: (column) => column);

  GeneratedColumn<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get cachedAtMillisUtc => $composableBuilder(
    column: $table.cachedAtMillisUtc,
    builder: (column) => column,
  );
}

class $$ChannelsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChannelsTableTable,
          ChannelRow,
          $$ChannelsTableTableFilterComposer,
          $$ChannelsTableTableOrderingComposer,
          $$ChannelsTableTableAnnotationComposer,
          $$ChannelsTableTableCreateCompanionBuilder,
          $$ChannelsTableTableUpdateCompanionBuilder,
          (
            ChannelRow,
            BaseReferences<_$AppDatabase, $ChannelsTableTable, ChannelRow>,
          ),
          ChannelRow,
          PrefetchHooks Function()
        > {
  $$ChannelsTableTableTableManager(_$AppDatabase db, $ChannelsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChannelsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChannelsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChannelsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> logoUrl = const Value.absent(),
                Value<String?> epgChannelId = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                Value<int> cachedAtMillisUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChannelsTableCompanion(
                id: id,
                accountId: accountId,
                categoryId: categoryId,
                name: name,
                logoUrl: logoUrl,
                epgChannelId: epgChannelId,
                sortOrder: sortOrder,
                cachedAtMillisUtc: cachedAtMillisUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String categoryId,
                required String name,
                Value<String?> logoUrl = const Value.absent(),
                Value<String?> epgChannelId = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                required int cachedAtMillisUtc,
                Value<int> rowid = const Value.absent(),
              }) => ChannelsTableCompanion.insert(
                id: id,
                accountId: accountId,
                categoryId: categoryId,
                name: name,
                logoUrl: logoUrl,
                epgChannelId: epgChannelId,
                sortOrder: sortOrder,
                cachedAtMillisUtc: cachedAtMillisUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChannelsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChannelsTableTable,
      ChannelRow,
      $$ChannelsTableTableFilterComposer,
      $$ChannelsTableTableOrderingComposer,
      $$ChannelsTableTableAnnotationComposer,
      $$ChannelsTableTableCreateCompanionBuilder,
      $$ChannelsTableTableUpdateCompanionBuilder,
      (
        ChannelRow,
        BaseReferences<_$AppDatabase, $ChannelsTableTable, ChannelRow>,
      ),
      ChannelRow,
      PrefetchHooks Function()
    >;
typedef $$WatchProgressTableTableCreateCompanionBuilder =
    WatchProgressTableCompanion Function({
      required String contentKey,
      required int positionSeconds,
      required int durationSeconds,
      required int updatedAtMillisUtc,
      Value<int?> syncedAtMillisUtc,
      Value<bool> completed,
      Value<int> rowid,
    });
typedef $$WatchProgressTableTableUpdateCompanionBuilder =
    WatchProgressTableCompanion Function({
      Value<String> contentKey,
      Value<int> positionSeconds,
      Value<int> durationSeconds,
      Value<int> updatedAtMillisUtc,
      Value<int?> syncedAtMillisUtc,
      Value<bool> completed,
      Value<int> rowid,
    });

class $$WatchProgressTableTableFilterComposer
    extends Composer<_$AppDatabase, $WatchProgressTableTable> {
  $$WatchProgressTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMillisUtc => $composableBuilder(
    column: $table.updatedAtMillisUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAtMillisUtc => $composableBuilder(
    column: $table.syncedAtMillisUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchProgressTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchProgressTableTable> {
  $$WatchProgressTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMillisUtc => $composableBuilder(
    column: $table.updatedAtMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAtMillisUtc => $composableBuilder(
    column: $table.syncedAtMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchProgressTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchProgressTableTable> {
  $$WatchProgressTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMillisUtc => $composableBuilder(
    column: $table.updatedAtMillisUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncedAtMillisUtc => $composableBuilder(
    column: $table.syncedAtMillisUtc,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);
}

class $$WatchProgressTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchProgressTableTable,
          WatchProgressRow,
          $$WatchProgressTableTableFilterComposer,
          $$WatchProgressTableTableOrderingComposer,
          $$WatchProgressTableTableAnnotationComposer,
          $$WatchProgressTableTableCreateCompanionBuilder,
          $$WatchProgressTableTableUpdateCompanionBuilder,
          (
            WatchProgressRow,
            BaseReferences<
              _$AppDatabase,
              $WatchProgressTableTable,
              WatchProgressRow
            >,
          ),
          WatchProgressRow,
          PrefetchHooks Function()
        > {
  $$WatchProgressTableTableTableManager(
    _$AppDatabase db,
    $WatchProgressTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchProgressTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchProgressTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchProgressTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> contentKey = const Value.absent(),
                Value<int> positionSeconds = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> updatedAtMillisUtc = const Value.absent(),
                Value<int?> syncedAtMillisUtc = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchProgressTableCompanion(
                contentKey: contentKey,
                positionSeconds: positionSeconds,
                durationSeconds: durationSeconds,
                updatedAtMillisUtc: updatedAtMillisUtc,
                syncedAtMillisUtc: syncedAtMillisUtc,
                completed: completed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String contentKey,
                required int positionSeconds,
                required int durationSeconds,
                required int updatedAtMillisUtc,
                Value<int?> syncedAtMillisUtc = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchProgressTableCompanion.insert(
                contentKey: contentKey,
                positionSeconds: positionSeconds,
                durationSeconds: durationSeconds,
                updatedAtMillisUtc: updatedAtMillisUtc,
                syncedAtMillisUtc: syncedAtMillisUtc,
                completed: completed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchProgressTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchProgressTableTable,
      WatchProgressRow,
      $$WatchProgressTableTableFilterComposer,
      $$WatchProgressTableTableOrderingComposer,
      $$WatchProgressTableTableAnnotationComposer,
      $$WatchProgressTableTableCreateCompanionBuilder,
      $$WatchProgressTableTableUpdateCompanionBuilder,
      (
        WatchProgressRow,
        BaseReferences<
          _$AppDatabase,
          $WatchProgressTableTable,
          WatchProgressRow
        >,
      ),
      WatchProgressRow,
      PrefetchHooks Function()
    >;
typedef $$PreferencesTableTableCreateCompanionBuilder =
    PreferencesTableCompanion Function({
      Value<int> id,
      Value<String?> preferredAudioLang,
      Value<String?> preferredSubtitleLang,
      Value<bool> autoplayNext,
      Value<bool> backgroundPlayback,
      Value<String?> contentLanguages,
      Value<String?> tmdbApiKey,
      Value<String?> discoveryRegion,
      Value<String?> activeAccountId,
    });
typedef $$PreferencesTableTableUpdateCompanionBuilder =
    PreferencesTableCompanion Function({
      Value<int> id,
      Value<String?> preferredAudioLang,
      Value<String?> preferredSubtitleLang,
      Value<bool> autoplayNext,
      Value<bool> backgroundPlayback,
      Value<String?> contentLanguages,
      Value<String?> tmdbApiKey,
      Value<String?> discoveryRegion,
      Value<String?> activeAccountId,
    });

class $$PreferencesTableTableFilterComposer
    extends Composer<_$AppDatabase, $PreferencesTableTable> {
  $$PreferencesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredAudioLang => $composableBuilder(
    column: $table.preferredAudioLang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredSubtitleLang => $composableBuilder(
    column: $table.preferredSubtitleLang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoplayNext => $composableBuilder(
    column: $table.autoplayNext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get backgroundPlayback => $composableBuilder(
    column: $table.backgroundPlayback,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentLanguages => $composableBuilder(
    column: $table.contentLanguages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tmdbApiKey => $composableBuilder(
    column: $table.tmdbApiKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get discoveryRegion => $composableBuilder(
    column: $table.discoveryRegion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeAccountId => $composableBuilder(
    column: $table.activeAccountId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreferencesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PreferencesTableTable> {
  $$PreferencesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredAudioLang => $composableBuilder(
    column: $table.preferredAudioLang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredSubtitleLang => $composableBuilder(
    column: $table.preferredSubtitleLang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoplayNext => $composableBuilder(
    column: $table.autoplayNext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get backgroundPlayback => $composableBuilder(
    column: $table.backgroundPlayback,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentLanguages => $composableBuilder(
    column: $table.contentLanguages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tmdbApiKey => $composableBuilder(
    column: $table.tmdbApiKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get discoveryRegion => $composableBuilder(
    column: $table.discoveryRegion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeAccountId => $composableBuilder(
    column: $table.activeAccountId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferencesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PreferencesTableTable> {
  $$PreferencesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get preferredAudioLang => $composableBuilder(
    column: $table.preferredAudioLang,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredSubtitleLang => $composableBuilder(
    column: $table.preferredSubtitleLang,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoplayNext => $composableBuilder(
    column: $table.autoplayNext,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get backgroundPlayback => $composableBuilder(
    column: $table.backgroundPlayback,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentLanguages => $composableBuilder(
    column: $table.contentLanguages,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tmdbApiKey => $composableBuilder(
    column: $table.tmdbApiKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get discoveryRegion => $composableBuilder(
    column: $table.discoveryRegion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activeAccountId => $composableBuilder(
    column: $table.activeAccountId,
    builder: (column) => column,
  );
}

class $$PreferencesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PreferencesTableTable,
          PreferencesRow,
          $$PreferencesTableTableFilterComposer,
          $$PreferencesTableTableOrderingComposer,
          $$PreferencesTableTableAnnotationComposer,
          $$PreferencesTableTableCreateCompanionBuilder,
          $$PreferencesTableTableUpdateCompanionBuilder,
          (
            PreferencesRow,
            BaseReferences<
              _$AppDatabase,
              $PreferencesTableTable,
              PreferencesRow
            >,
          ),
          PreferencesRow,
          PrefetchHooks Function()
        > {
  $$PreferencesTableTableTableManager(
    _$AppDatabase db,
    $PreferencesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferencesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferencesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferencesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> preferredAudioLang = const Value.absent(),
                Value<String?> preferredSubtitleLang = const Value.absent(),
                Value<bool> autoplayNext = const Value.absent(),
                Value<bool> backgroundPlayback = const Value.absent(),
                Value<String?> contentLanguages = const Value.absent(),
                Value<String?> tmdbApiKey = const Value.absent(),
                Value<String?> discoveryRegion = const Value.absent(),
                Value<String?> activeAccountId = const Value.absent(),
              }) => PreferencesTableCompanion(
                id: id,
                preferredAudioLang: preferredAudioLang,
                preferredSubtitleLang: preferredSubtitleLang,
                autoplayNext: autoplayNext,
                backgroundPlayback: backgroundPlayback,
                contentLanguages: contentLanguages,
                tmdbApiKey: tmdbApiKey,
                discoveryRegion: discoveryRegion,
                activeAccountId: activeAccountId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> preferredAudioLang = const Value.absent(),
                Value<String?> preferredSubtitleLang = const Value.absent(),
                Value<bool> autoplayNext = const Value.absent(),
                Value<bool> backgroundPlayback = const Value.absent(),
                Value<String?> contentLanguages = const Value.absent(),
                Value<String?> tmdbApiKey = const Value.absent(),
                Value<String?> discoveryRegion = const Value.absent(),
                Value<String?> activeAccountId = const Value.absent(),
              }) => PreferencesTableCompanion.insert(
                id: id,
                preferredAudioLang: preferredAudioLang,
                preferredSubtitleLang: preferredSubtitleLang,
                autoplayNext: autoplayNext,
                backgroundPlayback: backgroundPlayback,
                contentLanguages: contentLanguages,
                tmdbApiKey: tmdbApiKey,
                discoveryRegion: discoveryRegion,
                activeAccountId: activeAccountId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreferencesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PreferencesTableTable,
      PreferencesRow,
      $$PreferencesTableTableFilterComposer,
      $$PreferencesTableTableOrderingComposer,
      $$PreferencesTableTableAnnotationComposer,
      $$PreferencesTableTableCreateCompanionBuilder,
      $$PreferencesTableTableUpdateCompanionBuilder,
      (
        PreferencesRow,
        BaseReferences<_$AppDatabase, $PreferencesTableTable, PreferencesRow>,
      ),
      PreferencesRow,
      PrefetchHooks Function()
    >;
typedef $$FavoritesTableTableCreateCompanionBuilder =
    FavoritesTableCompanion Function({
      required String contentKey,
      required int addedAtMillisUtc,
      Value<int> rowid,
    });
typedef $$FavoritesTableTableUpdateCompanionBuilder =
    FavoritesTableCompanion Function({
      Value<String> contentKey,
      Value<int> addedAtMillisUtc,
      Value<int> rowid,
    });

class $$FavoritesTableTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTableTable> {
  $$FavoritesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAtMillisUtc => $composableBuilder(
    column: $table.addedAtMillisUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoritesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTableTable> {
  $$FavoritesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAtMillisUtc => $composableBuilder(
    column: $table.addedAtMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoritesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTableTable> {
  $$FavoritesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get addedAtMillisUtc => $composableBuilder(
    column: $table.addedAtMillisUtc,
    builder: (column) => column,
  );
}

class $$FavoritesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTableTable,
          FavoriteRow,
          $$FavoritesTableTableFilterComposer,
          $$FavoritesTableTableOrderingComposer,
          $$FavoritesTableTableAnnotationComposer,
          $$FavoritesTableTableCreateCompanionBuilder,
          $$FavoritesTableTableUpdateCompanionBuilder,
          (
            FavoriteRow,
            BaseReferences<_$AppDatabase, $FavoritesTableTable, FavoriteRow>,
          ),
          FavoriteRow,
          PrefetchHooks Function()
        > {
  $$FavoritesTableTableTableManager(
    _$AppDatabase db,
    $FavoritesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> contentKey = const Value.absent(),
                Value<int> addedAtMillisUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoritesTableCompanion(
                contentKey: contentKey,
                addedAtMillisUtc: addedAtMillisUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String contentKey,
                required int addedAtMillisUtc,
                Value<int> rowid = const Value.absent(),
              }) => FavoritesTableCompanion.insert(
                contentKey: contentKey,
                addedAtMillisUtc: addedAtMillisUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoritesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTableTable,
      FavoriteRow,
      $$FavoritesTableTableFilterComposer,
      $$FavoritesTableTableOrderingComposer,
      $$FavoritesTableTableAnnotationComposer,
      $$FavoritesTableTableCreateCompanionBuilder,
      $$FavoritesTableTableUpdateCompanionBuilder,
      (
        FavoriteRow,
        BaseReferences<_$AppDatabase, $FavoritesTableTable, FavoriteRow>,
      ),
      FavoriteRow,
      PrefetchHooks Function()
    >;
typedef $$EpgCacheTableTableCreateCompanionBuilder =
    EpgCacheTableCompanion Function({
      required String accountId,
      required String channelId,
      required int startMillisUtc,
      required int stopMillisUtc,
      required String title,
      Value<String?> description,
      required int cachedAtMillisUtc,
      Value<int> rowid,
    });
typedef $$EpgCacheTableTableUpdateCompanionBuilder =
    EpgCacheTableCompanion Function({
      Value<String> accountId,
      Value<String> channelId,
      Value<int> startMillisUtc,
      Value<int> stopMillisUtc,
      Value<String> title,
      Value<String?> description,
      Value<int> cachedAtMillisUtc,
      Value<int> rowid,
    });

class $$EpgCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $EpgCacheTableTable> {
  $$EpgCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMillisUtc => $composableBuilder(
    column: $table.startMillisUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stopMillisUtc => $composableBuilder(
    column: $table.stopMillisUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAtMillisUtc => $composableBuilder(
    column: $table.cachedAtMillisUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpgCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgCacheTableTable> {
  $$EpgCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMillisUtc => $composableBuilder(
    column: $table.startMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stopMillisUtc => $composableBuilder(
    column: $table.stopMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAtMillisUtc => $composableBuilder(
    column: $table.cachedAtMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpgCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgCacheTableTable> {
  $$EpgCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<int> get startMillisUtc => $composableBuilder(
    column: $table.startMillisUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stopMillisUtc => $composableBuilder(
    column: $table.stopMillisUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedAtMillisUtc => $composableBuilder(
    column: $table.cachedAtMillisUtc,
    builder: (column) => column,
  );
}

class $$EpgCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpgCacheTableTable,
          EpgRow,
          $$EpgCacheTableTableFilterComposer,
          $$EpgCacheTableTableOrderingComposer,
          $$EpgCacheTableTableAnnotationComposer,
          $$EpgCacheTableTableCreateCompanionBuilder,
          $$EpgCacheTableTableUpdateCompanionBuilder,
          (EpgRow, BaseReferences<_$AppDatabase, $EpgCacheTableTable, EpgRow>),
          EpgRow,
          PrefetchHooks Function()
        > {
  $$EpgCacheTableTableTableManager(_$AppDatabase db, $EpgCacheTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgCacheTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> channelId = const Value.absent(),
                Value<int> startMillisUtc = const Value.absent(),
                Value<int> stopMillisUtc = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> cachedAtMillisUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgCacheTableCompanion(
                accountId: accountId,
                channelId: channelId,
                startMillisUtc: startMillisUtc,
                stopMillisUtc: stopMillisUtc,
                title: title,
                description: description,
                cachedAtMillisUtc: cachedAtMillisUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String channelId,
                required int startMillisUtc,
                required int stopMillisUtc,
                required String title,
                Value<String?> description = const Value.absent(),
                required int cachedAtMillisUtc,
                Value<int> rowid = const Value.absent(),
              }) => EpgCacheTableCompanion.insert(
                accountId: accountId,
                channelId: channelId,
                startMillisUtc: startMillisUtc,
                stopMillisUtc: stopMillisUtc,
                title: title,
                description: description,
                cachedAtMillisUtc: cachedAtMillisUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EpgCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpgCacheTableTable,
      EpgRow,
      $$EpgCacheTableTableFilterComposer,
      $$EpgCacheTableTableOrderingComposer,
      $$EpgCacheTableTableAnnotationComposer,
      $$EpgCacheTableTableCreateCompanionBuilder,
      $$EpgCacheTableTableUpdateCompanionBuilder,
      (EpgRow, BaseReferences<_$AppDatabase, $EpgCacheTableTable, EpgRow>),
      EpgRow,
      PrefetchHooks Function()
    >;
typedef $$CatalogMetaTableTableCreateCompanionBuilder =
    CatalogMetaTableCompanion Function({
      required String accountId,
      required CatalogKind kind,
      required int refreshedAtMillisUtc,
      Value<int> rowid,
    });
typedef $$CatalogMetaTableTableUpdateCompanionBuilder =
    CatalogMetaTableCompanion Function({
      Value<String> accountId,
      Value<CatalogKind> kind,
      Value<int> refreshedAtMillisUtc,
      Value<int> rowid,
    });

class $$CatalogMetaTableTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogMetaTableTable> {
  $$CatalogMetaTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CatalogKind, CatalogKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get refreshedAtMillisUtc => $composableBuilder(
    column: $table.refreshedAtMillisUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatalogMetaTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogMetaTableTable> {
  $$CatalogMetaTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get refreshedAtMillisUtc => $composableBuilder(
    column: $table.refreshedAtMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogMetaTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogMetaTableTable> {
  $$CatalogMetaTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CatalogKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get refreshedAtMillisUtc => $composableBuilder(
    column: $table.refreshedAtMillisUtc,
    builder: (column) => column,
  );
}

class $$CatalogMetaTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatalogMetaTableTable,
          CatalogMetaRow,
          $$CatalogMetaTableTableFilterComposer,
          $$CatalogMetaTableTableOrderingComposer,
          $$CatalogMetaTableTableAnnotationComposer,
          $$CatalogMetaTableTableCreateCompanionBuilder,
          $$CatalogMetaTableTableUpdateCompanionBuilder,
          (
            CatalogMetaRow,
            BaseReferences<
              _$AppDatabase,
              $CatalogMetaTableTable,
              CatalogMetaRow
            >,
          ),
          CatalogMetaRow,
          PrefetchHooks Function()
        > {
  $$CatalogMetaTableTableTableManager(
    _$AppDatabase db,
    $CatalogMetaTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogMetaTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogMetaTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogMetaTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<CatalogKind> kind = const Value.absent(),
                Value<int> refreshedAtMillisUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogMetaTableCompanion(
                accountId: accountId,
                kind: kind,
                refreshedAtMillisUtc: refreshedAtMillisUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required CatalogKind kind,
                required int refreshedAtMillisUtc,
                Value<int> rowid = const Value.absent(),
              }) => CatalogMetaTableCompanion.insert(
                accountId: accountId,
                kind: kind,
                refreshedAtMillisUtc: refreshedAtMillisUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatalogMetaTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatalogMetaTableTable,
      CatalogMetaRow,
      $$CatalogMetaTableTableFilterComposer,
      $$CatalogMetaTableTableOrderingComposer,
      $$CatalogMetaTableTableAnnotationComposer,
      $$CatalogMetaTableTableCreateCompanionBuilder,
      $$CatalogMetaTableTableUpdateCompanionBuilder,
      (
        CatalogMetaRow,
        BaseReferences<_$AppDatabase, $CatalogMetaTableTable, CatalogMetaRow>,
      ),
      CatalogMetaRow,
      PrefetchHooks Function()
    >;
typedef $$CatalogCategoryMetaTableTableCreateCompanionBuilder =
    CatalogCategoryMetaTableCompanion Function({
      required String accountId,
      required CatalogKind kind,
      required String categoryId,
      required int refreshedAtMillisUtc,
      Value<int> rowid,
    });
typedef $$CatalogCategoryMetaTableTableUpdateCompanionBuilder =
    CatalogCategoryMetaTableCompanion Function({
      Value<String> accountId,
      Value<CatalogKind> kind,
      Value<String> categoryId,
      Value<int> refreshedAtMillisUtc,
      Value<int> rowid,
    });

class $$CatalogCategoryMetaTableTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogCategoryMetaTableTable> {
  $$CatalogCategoryMetaTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CatalogKind, CatalogKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get refreshedAtMillisUtc => $composableBuilder(
    column: $table.refreshedAtMillisUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatalogCategoryMetaTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogCategoryMetaTableTable> {
  $$CatalogCategoryMetaTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get refreshedAtMillisUtc => $composableBuilder(
    column: $table.refreshedAtMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogCategoryMetaTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogCategoryMetaTableTable> {
  $$CatalogCategoryMetaTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CatalogKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get refreshedAtMillisUtc => $composableBuilder(
    column: $table.refreshedAtMillisUtc,
    builder: (column) => column,
  );
}

class $$CatalogCategoryMetaTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatalogCategoryMetaTableTable,
          CatalogCategoryMetaRow,
          $$CatalogCategoryMetaTableTableFilterComposer,
          $$CatalogCategoryMetaTableTableOrderingComposer,
          $$CatalogCategoryMetaTableTableAnnotationComposer,
          $$CatalogCategoryMetaTableTableCreateCompanionBuilder,
          $$CatalogCategoryMetaTableTableUpdateCompanionBuilder,
          (
            CatalogCategoryMetaRow,
            BaseReferences<
              _$AppDatabase,
              $CatalogCategoryMetaTableTable,
              CatalogCategoryMetaRow
            >,
          ),
          CatalogCategoryMetaRow,
          PrefetchHooks Function()
        > {
  $$CatalogCategoryMetaTableTableTableManager(
    _$AppDatabase db,
    $CatalogCategoryMetaTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogCategoryMetaTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CatalogCategoryMetaTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CatalogCategoryMetaTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<CatalogKind> kind = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<int> refreshedAtMillisUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogCategoryMetaTableCompanion(
                accountId: accountId,
                kind: kind,
                categoryId: categoryId,
                refreshedAtMillisUtc: refreshedAtMillisUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required CatalogKind kind,
                required String categoryId,
                required int refreshedAtMillisUtc,
                Value<int> rowid = const Value.absent(),
              }) => CatalogCategoryMetaTableCompanion.insert(
                accountId: accountId,
                kind: kind,
                categoryId: categoryId,
                refreshedAtMillisUtc: refreshedAtMillisUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatalogCategoryMetaTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatalogCategoryMetaTableTable,
      CatalogCategoryMetaRow,
      $$CatalogCategoryMetaTableTableFilterComposer,
      $$CatalogCategoryMetaTableTableOrderingComposer,
      $$CatalogCategoryMetaTableTableAnnotationComposer,
      $$CatalogCategoryMetaTableTableCreateCompanionBuilder,
      $$CatalogCategoryMetaTableTableUpdateCompanionBuilder,
      (
        CatalogCategoryMetaRow,
        BaseReferences<
          _$AppDatabase,
          $CatalogCategoryMetaTableTable,
          CatalogCategoryMetaRow
        >,
      ),
      CatalogCategoryMetaRow,
      PrefetchHooks Function()
    >;
typedef $$DiscoveryTitlesTableTableCreateCompanionBuilder =
    DiscoveryTitlesTableCompanion Function({
      required String listId,
      required int rank,
      required DiscoveryKind kind,
      required String title,
      Value<int?> tmdbId,
      Value<int?> year,
      Value<double?> voteAverage,
      Value<int?> voteCount,
      required int fetchedAtMillisUtc,
      Value<int> rowid,
    });
typedef $$DiscoveryTitlesTableTableUpdateCompanionBuilder =
    DiscoveryTitlesTableCompanion Function({
      Value<String> listId,
      Value<int> rank,
      Value<DiscoveryKind> kind,
      Value<String> title,
      Value<int?> tmdbId,
      Value<int?> year,
      Value<double?> voteAverage,
      Value<int?> voteCount,
      Value<int> fetchedAtMillisUtc,
      Value<int> rowid,
    });

class $$DiscoveryTitlesTableTableFilterComposer
    extends Composer<_$AppDatabase, $DiscoveryTitlesTableTable> {
  $$DiscoveryTitlesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DiscoveryKind, DiscoveryKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get voteAverage => $composableBuilder(
    column: $table.voteAverage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get voteCount => $composableBuilder(
    column: $table.voteCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAtMillisUtc => $composableBuilder(
    column: $table.fetchedAtMillisUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiscoveryTitlesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DiscoveryTitlesTableTable> {
  $$DiscoveryTitlesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get voteAverage => $composableBuilder(
    column: $table.voteAverage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get voteCount => $composableBuilder(
    column: $table.voteCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAtMillisUtc => $composableBuilder(
    column: $table.fetchedAtMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiscoveryTitlesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiscoveryTitlesTableTable> {
  $$DiscoveryTitlesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<int> get rank =>
      $composableBuilder(column: $table.rank, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DiscoveryKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<double> get voteAverage => $composableBuilder(
    column: $table.voteAverage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get voteCount =>
      $composableBuilder(column: $table.voteCount, builder: (column) => column);

  GeneratedColumn<int> get fetchedAtMillisUtc => $composableBuilder(
    column: $table.fetchedAtMillisUtc,
    builder: (column) => column,
  );
}

class $$DiscoveryTitlesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiscoveryTitlesTableTable,
          DiscoveryTitleRow,
          $$DiscoveryTitlesTableTableFilterComposer,
          $$DiscoveryTitlesTableTableOrderingComposer,
          $$DiscoveryTitlesTableTableAnnotationComposer,
          $$DiscoveryTitlesTableTableCreateCompanionBuilder,
          $$DiscoveryTitlesTableTableUpdateCompanionBuilder,
          (
            DiscoveryTitleRow,
            BaseReferences<
              _$AppDatabase,
              $DiscoveryTitlesTableTable,
              DiscoveryTitleRow
            >,
          ),
          DiscoveryTitleRow,
          PrefetchHooks Function()
        > {
  $$DiscoveryTitlesTableTableTableManager(
    _$AppDatabase db,
    $DiscoveryTitlesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiscoveryTitlesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiscoveryTitlesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DiscoveryTitlesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> listId = const Value.absent(),
                Value<int> rank = const Value.absent(),
                Value<DiscoveryKind> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> tmdbId = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<double?> voteAverage = const Value.absent(),
                Value<int?> voteCount = const Value.absent(),
                Value<int> fetchedAtMillisUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiscoveryTitlesTableCompanion(
                listId: listId,
                rank: rank,
                kind: kind,
                title: title,
                tmdbId: tmdbId,
                year: year,
                voteAverage: voteAverage,
                voteCount: voteCount,
                fetchedAtMillisUtc: fetchedAtMillisUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String listId,
                required int rank,
                required DiscoveryKind kind,
                required String title,
                Value<int?> tmdbId = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<double?> voteAverage = const Value.absent(),
                Value<int?> voteCount = const Value.absent(),
                required int fetchedAtMillisUtc,
                Value<int> rowid = const Value.absent(),
              }) => DiscoveryTitlesTableCompanion.insert(
                listId: listId,
                rank: rank,
                kind: kind,
                title: title,
                tmdbId: tmdbId,
                year: year,
                voteAverage: voteAverage,
                voteCount: voteCount,
                fetchedAtMillisUtc: fetchedAtMillisUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiscoveryTitlesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiscoveryTitlesTableTable,
      DiscoveryTitleRow,
      $$DiscoveryTitlesTableTableFilterComposer,
      $$DiscoveryTitlesTableTableOrderingComposer,
      $$DiscoveryTitlesTableTableAnnotationComposer,
      $$DiscoveryTitlesTableTableCreateCompanionBuilder,
      $$DiscoveryTitlesTableTableUpdateCompanionBuilder,
      (
        DiscoveryTitleRow,
        BaseReferences<
          _$AppDatabase,
          $DiscoveryTitlesTableTable,
          DiscoveryTitleRow
        >,
      ),
      DiscoveryTitleRow,
      PrefetchHooks Function()
    >;
typedef $$DiscoveryMatchesTableTableCreateCompanionBuilder =
    DiscoveryMatchesTableCompanion Function({
      required String accountId,
      required String listId,
      required int rank,
      required String localId,
      required int resolvedAtMillisUtc,
      Value<int> rowid,
    });
typedef $$DiscoveryMatchesTableTableUpdateCompanionBuilder =
    DiscoveryMatchesTableCompanion Function({
      Value<String> accountId,
      Value<String> listId,
      Value<int> rank,
      Value<String> localId,
      Value<int> resolvedAtMillisUtc,
      Value<int> rowid,
    });

class $$DiscoveryMatchesTableTableFilterComposer
    extends Composer<_$AppDatabase, $DiscoveryMatchesTableTable> {
  $$DiscoveryMatchesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resolvedAtMillisUtc => $composableBuilder(
    column: $table.resolvedAtMillisUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiscoveryMatchesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DiscoveryMatchesTableTable> {
  $$DiscoveryMatchesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolvedAtMillisUtc => $composableBuilder(
    column: $table.resolvedAtMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiscoveryMatchesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiscoveryMatchesTableTable> {
  $$DiscoveryMatchesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<int> get rank =>
      $composableBuilder(column: $table.rank, builder: (column) => column);

  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<int> get resolvedAtMillisUtc => $composableBuilder(
    column: $table.resolvedAtMillisUtc,
    builder: (column) => column,
  );
}

class $$DiscoveryMatchesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiscoveryMatchesTableTable,
          DiscoveryMatchRow,
          $$DiscoveryMatchesTableTableFilterComposer,
          $$DiscoveryMatchesTableTableOrderingComposer,
          $$DiscoveryMatchesTableTableAnnotationComposer,
          $$DiscoveryMatchesTableTableCreateCompanionBuilder,
          $$DiscoveryMatchesTableTableUpdateCompanionBuilder,
          (
            DiscoveryMatchRow,
            BaseReferences<
              _$AppDatabase,
              $DiscoveryMatchesTableTable,
              DiscoveryMatchRow
            >,
          ),
          DiscoveryMatchRow,
          PrefetchHooks Function()
        > {
  $$DiscoveryMatchesTableTableTableManager(
    _$AppDatabase db,
    $DiscoveryMatchesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiscoveryMatchesTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DiscoveryMatchesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DiscoveryMatchesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> listId = const Value.absent(),
                Value<int> rank = const Value.absent(),
                Value<String> localId = const Value.absent(),
                Value<int> resolvedAtMillisUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiscoveryMatchesTableCompanion(
                accountId: accountId,
                listId: listId,
                rank: rank,
                localId: localId,
                resolvedAtMillisUtc: resolvedAtMillisUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String listId,
                required int rank,
                required String localId,
                required int resolvedAtMillisUtc,
                Value<int> rowid = const Value.absent(),
              }) => DiscoveryMatchesTableCompanion.insert(
                accountId: accountId,
                listId: listId,
                rank: rank,
                localId: localId,
                resolvedAtMillisUtc: resolvedAtMillisUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiscoveryMatchesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiscoveryMatchesTableTable,
      DiscoveryMatchRow,
      $$DiscoveryMatchesTableTableFilterComposer,
      $$DiscoveryMatchesTableTableOrderingComposer,
      $$DiscoveryMatchesTableTableAnnotationComposer,
      $$DiscoveryMatchesTableTableCreateCompanionBuilder,
      $$DiscoveryMatchesTableTableUpdateCompanionBuilder,
      (
        DiscoveryMatchRow,
        BaseReferences<
          _$AppDatabase,
          $DiscoveryMatchesTableTable,
          DiscoveryMatchRow
        >,
      ),
      DiscoveryMatchRow,
      PrefetchHooks Function()
    >;
typedef $$SearchHistoryTableTableCreateCompanionBuilder =
    SearchHistoryTableCompanion Function({
      required String query,
      required int searchedAtMillisUtc,
      Value<int> rowid,
    });
typedef $$SearchHistoryTableTableUpdateCompanionBuilder =
    SearchHistoryTableCompanion Function({
      Value<String> query,
      Value<int> searchedAtMillisUtc,
      Value<int> rowid,
    });

class $$SearchHistoryTableTableFilterComposer
    extends Composer<_$AppDatabase, $SearchHistoryTableTable> {
  $$SearchHistoryTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get searchedAtMillisUtc => $composableBuilder(
    column: $table.searchedAtMillisUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchHistoryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchHistoryTableTable> {
  $$SearchHistoryTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get searchedAtMillisUtc => $composableBuilder(
    column: $table.searchedAtMillisUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchHistoryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchHistoryTableTable> {
  $$SearchHistoryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<int> get searchedAtMillisUtc => $composableBuilder(
    column: $table.searchedAtMillisUtc,
    builder: (column) => column,
  );
}

class $$SearchHistoryTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchHistoryTableTable,
          SearchHistoryRow,
          $$SearchHistoryTableTableFilterComposer,
          $$SearchHistoryTableTableOrderingComposer,
          $$SearchHistoryTableTableAnnotationComposer,
          $$SearchHistoryTableTableCreateCompanionBuilder,
          $$SearchHistoryTableTableUpdateCompanionBuilder,
          (
            SearchHistoryRow,
            BaseReferences<
              _$AppDatabase,
              $SearchHistoryTableTable,
              SearchHistoryRow
            >,
          ),
          SearchHistoryRow,
          PrefetchHooks Function()
        > {
  $$SearchHistoryTableTableTableManager(
    _$AppDatabase db,
    $SearchHistoryTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchHistoryTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchHistoryTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> query = const Value.absent(),
                Value<int> searchedAtMillisUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoryTableCompanion(
                query: query,
                searchedAtMillisUtc: searchedAtMillisUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String query,
                required int searchedAtMillisUtc,
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoryTableCompanion.insert(
                query: query,
                searchedAtMillisUtc: searchedAtMillisUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchHistoryTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchHistoryTableTable,
      SearchHistoryRow,
      $$SearchHistoryTableTableFilterComposer,
      $$SearchHistoryTableTableOrderingComposer,
      $$SearchHistoryTableTableAnnotationComposer,
      $$SearchHistoryTableTableCreateCompanionBuilder,
      $$SearchHistoryTableTableUpdateCompanionBuilder,
      (
        SearchHistoryRow,
        BaseReferences<
          _$AppDatabase,
          $SearchHistoryTableTable,
          SearchHistoryRow
        >,
      ),
      SearchHistoryRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableTableManager get accountsTable =>
      $$AccountsTableTableTableManager(_db, _db.accountsTable);
  $$CategoriesTableTableTableManager get categoriesTable =>
      $$CategoriesTableTableTableManager(_db, _db.categoriesTable);
  $$MoviesTableTableTableManager get moviesTable =>
      $$MoviesTableTableTableManager(_db, _db.moviesTable);
  $$SeriesTableTableTableManager get seriesTable =>
      $$SeriesTableTableTableManager(_db, _db.seriesTable);
  $$EpisodesTableTableTableManager get episodesTable =>
      $$EpisodesTableTableTableManager(_db, _db.episodesTable);
  $$ChannelsTableTableTableManager get channelsTable =>
      $$ChannelsTableTableTableManager(_db, _db.channelsTable);
  $$WatchProgressTableTableTableManager get watchProgressTable =>
      $$WatchProgressTableTableTableManager(_db, _db.watchProgressTable);
  $$PreferencesTableTableTableManager get preferencesTable =>
      $$PreferencesTableTableTableManager(_db, _db.preferencesTable);
  $$FavoritesTableTableTableManager get favoritesTable =>
      $$FavoritesTableTableTableManager(_db, _db.favoritesTable);
  $$EpgCacheTableTableTableManager get epgCacheTable =>
      $$EpgCacheTableTableTableManager(_db, _db.epgCacheTable);
  $$CatalogMetaTableTableTableManager get catalogMetaTable =>
      $$CatalogMetaTableTableTableManager(_db, _db.catalogMetaTable);
  $$CatalogCategoryMetaTableTableTableManager get catalogCategoryMetaTable =>
      $$CatalogCategoryMetaTableTableTableManager(
        _db,
        _db.catalogCategoryMetaTable,
      );
  $$DiscoveryTitlesTableTableTableManager get discoveryTitlesTable =>
      $$DiscoveryTitlesTableTableTableManager(_db, _db.discoveryTitlesTable);
  $$DiscoveryMatchesTableTableTableManager get discoveryMatchesTable =>
      $$DiscoveryMatchesTableTableTableManager(_db, _db.discoveryMatchesTable);
  $$SearchHistoryTableTableTableManager get searchHistoryTable =>
      $$SearchHistoryTableTableTableManager(_db, _db.searchHistoryTable);
}
