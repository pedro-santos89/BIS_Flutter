class Member {
  final int? id;
  final String name;
  final String? email;
  final bool communication;
  final bool annualFee;
  final String notes;
  final DateTime? createdAt;
  final int? memberNumber;

  Member({
    this.id,
    required this.name,
    this.email,
    this.communication = false,
    this.annualFee = false,
    this.notes = '',
    this.createdAt,
    this.memberNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'communication': communication ? 1 : 0,
      'annual_fee': annualFee ? 1 : 0,
      'notes': notes,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'member_number': memberNumber,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      email: map['email'] as String?,
      communication: (map['communication'] as int?) == 1,
      annualFee: (map['annual_fee'] as int?) == 1,
      notes: map['notes'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      memberNumber: map['member_number'] as int?,
    );
  }

  Member copyWith({
    int? id,
    String? name,
    String? email,
    bool? communication,
    bool? annualFee,
    String? notes,
    DateTime? createdAt,
    int? memberNumber,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      communication: communication ?? this.communication,
      annualFee: annualFee ?? this.annualFee,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      memberNumber: memberNumber ?? this.memberNumber,
    );
  }
}

class DailyMember {
  final int? id;
  final String name;
  final int? dailyMemberNumber;
  final String notes;
  final DateTime? createdAt;

  DailyMember({
    this.id,
    required this.name,
    this.dailyMemberNumber,
    this.notes = '',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'daily_member_number': dailyMemberNumber,
      'notes': notes,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory DailyMember.fromMap(Map<String, dynamic> map) {
    return DailyMember(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      dailyMemberNumber: map['daily_member_number'] as int?,
      notes: map['notes'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  DailyMember copyWith({
    int? id,
    String? name,
    int? dailyMemberNumber,
    String? notes,
    DateTime? createdAt,
  }) {
    return DailyMember(
      id: id ?? this.id,
      name: name ?? this.name,
      dailyMemberNumber: dailyMemberNumber ?? this.dailyMemberNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ─── Custom Table Definitions ───

class CustomTableDef {
  final int? id;
  final String tableName;
  final String dbTableName;
  final DateTime? createdAt;
  final List<CustomColumnDef> columns;

  CustomTableDef({
    this.id,
    required this.tableName,
    required this.dbTableName,
    this.createdAt,
    this.columns = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'table_name': tableName,
      'db_table_name': dbTableName,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory CustomTableDef.fromMap(Map<String, dynamic> map, {List<CustomColumnDef> columns = const []}) {
    return CustomTableDef(
      id: map['id'] as int?,
      tableName: map['table_name'] as String? ?? '',
      dbTableName: map['db_table_name'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      columns: columns,
    );
  }

  CustomTableDef copyWith({
    int? id,
    String? tableName,
    String? dbTableName,
    DateTime? createdAt,
    List<CustomColumnDef>? columns,
  }) {
    return CustomTableDef(
      id: id ?? this.id,
      tableName: tableName ?? this.tableName,
      dbTableName: dbTableName ?? this.dbTableName,
      createdAt: createdAt ?? this.createdAt,
      columns: columns ?? this.columns,
    );
  }
}

class CustomColumnDef {
  final int? id;
  final int? customTableId;
  final String columnName;
  final String columnType; // TEXT, INTEGER, REAL, BOOLEAN
  final int columnOrder;

  CustomColumnDef({
    this.id,
    this.customTableId,
    required this.columnName,
    this.columnType = 'TEXT',
    this.columnOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'custom_table_id': customTableId,
      'column_name': columnName,
      'column_type': columnType,
      'column_order': columnOrder,
    };
  }

  factory CustomColumnDef.fromMap(Map<String, dynamic> map) {
    return CustomColumnDef(
      id: map['id'] as int?,
      customTableId: map['custom_table_id'] as int?,
      columnName: map['column_name'] as String? ?? '',
      columnType: map['column_type'] as String? ?? 'TEXT',
      columnOrder: map['column_order'] as int? ?? 0,
    );
  }

  CustomColumnDef copyWith({
    int? id,
    int? customTableId,
    String? columnName,
    String? columnType,
    int? columnOrder,
  }) {
    return CustomColumnDef(
      id: id ?? this.id,
      customTableId: customTableId ?? this.customTableId,
      columnName: columnName ?? this.columnName,
      columnType: columnType ?? this.columnType,
      columnOrder: columnOrder ?? this.columnOrder,
    );
  }

  String get dbColumnName {
    return columnName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String get sqlType {
    switch (columnType) {
      case 'INTEGER':
        return 'INTEGER';
      case 'REAL':
        return 'REAL';
      case 'BOOLEAN':
        return 'INTEGER';
      default:
        return 'TEXT';
    }
  }
}

// ─── App User ───

class AppUser {
  final int? id;
  final String username;
  final String? passwordHash;
  final bool isAdmin;

  AppUser({
    this.id,
    required this.username,
    this.passwordHash,
    this.isAdmin = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'is_staff': isAdmin ? 1 : 0,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as int?,
      username: map['username'] as String? ?? '',
      passwordHash: map['password_hash'] as String?,
      isAdmin: (map['is_staff'] as int?) == 1,
    );
  }
}
