/// Represents a registered (permanent) member of the BUS organization.
/// Stored in the 'members' SQLite table.
class Member {
  /// Auto-incremented database primary key. Null when creating a new record.
  final int? id;

  /// Full name of the member (required).
  final String name;

  /// Optional email address of the member.
  final String? email;

  /// Whether the member opted-in to receive communications (events/news).
  final bool communication;

  /// Whether the annual membership fee has been paid.
  final bool annualFee;

  /// Free-text notes about the member.
  final String notes;

  /// Timestamp of when the member was registered.
  final DateTime? createdAt;

  /// Unique sequential member number, auto-assigned if not provided.
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

  /// Converts this Member to a Map for SQLite insertion/update.
  /// Booleans are stored as 0/1 integers, dates as ISO 8601 strings.
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

  /// Creates a Member from a SQLite row map.
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

  /// Returns a copy of this Member with the given fields replaced.
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

/// Represents a daily (temporary/one-day) member of BUS.
/// Stored in the 'daily_members' SQLite table.
class DailyMember {
  /// Auto-incremented database primary key. Null when creating a new record.
  final int? id;

  /// Full name of the daily member (required).
  final String name;

  /// Unique sequential daily member number, auto-assigned if not provided.
  final int? dailyMemberNumber;

  /// Free-text notes about the daily member.
  final String notes;

  /// Timestamp of when the daily member was registered.
  final DateTime? createdAt;

  DailyMember({
    this.id,
    required this.name,
    this.dailyMemberNumber,
    this.notes = '',
    this.createdAt,
  });

  /// Converts this DailyMember to a Map for SQLite insertion/update.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'daily_member_number': dailyMemberNumber,
      'notes': notes,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  /// Creates a DailyMember from a SQLite row map.
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

  /// Returns a copy of this DailyMember with the given fields replaced.
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

/// Defines a user-created custom table (e.g. Volunteers, Equipment).
/// Metadata is stored in the 'custom_tables' SQLite table.
/// The actual data table is dynamically created with a 'ct_' prefixed name.
class CustomTableDef {
  /// Auto-incremented database primary key.
  final int? id;

  /// Human-readable display name for the table.
  final String tableName;

  /// Sanitized SQLite table name (prefixed with 'ct_'). Auto-generated from tableName.
  final String dbTableName;

  /// Timestamp of when the custom table was created.
  final DateTime? createdAt;

  /// The column definitions that make up the table's structure.
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

  /// Creates a CustomTableDef from a SQLite row map.
  /// [columns] should be loaded separately from 'custom_table_columns' table.
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

/// Defines a single column within a custom table.
/// Stored in the 'custom_table_columns' SQLite table.
class CustomColumnDef {
  /// Auto-incremented database primary key.
  final int? id;

  /// Foreign key referencing the parent CustomTableDef.
  final int? customTableId;

  /// Human-readable column name.
  final String columnName;

  /// Data type of the column. One of: 'TEXT', 'INTEGER', 'REAL', 'BOOLEAN', 'DATE', 'DATETIME'.
  /// BOOLEAN is stored as INTEGER (0/1) in SQLite.
  /// DATE and DATETIME are stored as TEXT (ISO 8601) in SQLite.
  final String columnType;

  /// Display order of this column (0-based).
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

  /// Returns a sanitized, SQLite-safe column name derived from [columnName].
  /// Converts to lowercase, replaces special chars with underscores.
  String get dbColumnName {
    return columnName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  /// Maps [columnType] to the corresponding SQLite type.
  /// BOOLEAN becomes INTEGER (stored as 0/1).
  String get sqlType {
    switch (columnType) {
      case 'INTEGER':
        return 'INTEGER';
      case 'REAL':
        return 'REAL';
      case 'BOOLEAN':
        return 'INTEGER';
      case 'DATE':
        return 'TEXT';
      case 'DATETIME':
        return 'TEXT';
      default:
        return 'TEXT';
    }
  }
}

// ─── App User ───

/// Represents an application user (admin or normal) for authentication.
/// Stored in the 'users' SQLite table.
class AppUser {
  /// Auto-incremented database primary key.
  final int? id;

  /// Unique login username.
  final String username;

  /// Password hash (currently stored as plain text — should be hashed in production).
  final String? passwordHash;

  /// Whether this user has admin privileges. Maps to 'is_staff' column in DB.
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
