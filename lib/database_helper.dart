import 'package:sqflite/sqflite.dart';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('bis.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$filePath';
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT,
        communication INTEGER NOT NULL DEFAULT 0,
        annual_fee INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        member_number INTEGER UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        daily_member_number INTEGER,
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        is_staff INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Create default admin user (password: admin)
    // In production, change this immediately
    await db.insert('users', {
      'username': 'admin',
      'password_hash': 'admin',
      'is_staff': 1,
    });

    // v2 tables
    await _createV2Tables(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createV2Tables(db);
    }
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_tables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        db_table_name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_table_columns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        custom_table_id INTEGER NOT NULL,
        column_name TEXT NOT NULL,
        column_type TEXT NOT NULL DEFAULT 'TEXT',
        column_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (custom_table_id) REFERENCES custom_tables(id) ON DELETE CASCADE
      )
    ''');
  }

  // ─── Members ───

  Future<Member> insertMember(Member member) async {
    final db = await database;

    // Auto-assign member_number if not set
    int? memberNumber = member.memberNumber;
    if (memberNumber == null) {
      final result = await db.rawQuery(
        'SELECT COALESCE(MAX(member_number), 0) + 1 AS next_number FROM members',
      );
      memberNumber = (result.first['next_number'] as int?) ?? 1;

      // Find first available gap
      final existing = await db.rawQuery(
        'SELECT member_number FROM members ORDER BY member_number',
      );
      final existingNumbers =
          existing.map((r) => r['member_number'] as int).toSet();
      int next = 1;
      while (existingNumbers.contains(next)) {
        next++;
      }
      memberNumber = next;
    }

    final data = member.toMap();
    data['member_number'] = memberNumber;
    data.remove('id');
    if (data['created_at'] == null) {
      data['created_at'] = DateTime.now().toIso8601String();
    }

    final id = await db.insert('members', data);
    return member.copyWith(id: id, memberNumber: memberNumber);
  }

  Future<List<Member>> getMembers({
    String? search,
    String searchBy = 'name',
    int limit = 25,
    int offset = 0,
  }) async {
    final db = await database;
    String where = '';
    List<dynamic> args = [];

    if (search != null && search.isNotEmpty) {
      switch (searchBy) {
        case 'member_number':
          where = 'WHERE member_number = ?';
          args = [int.tryParse(search) ?? -1];
          break;
        case 'email':
          where = 'WHERE email LIKE ?';
          args = ['%$search%'];
          break;
        default:
          where = 'WHERE name LIKE ?';
          args = ['%$search%'];
      }
    }

    final result = await db.rawQuery(
      'SELECT * FROM members $where ORDER BY member_number ASC LIMIT ? OFFSET ?',
      [...args, limit, offset],
    );
    return result.map((m) => Member.fromMap(m)).toList();
  }

  Future<int> getMemberCount({String? search, String searchBy = 'name'}) async {
    final db = await database;
    String where = '';
    List<dynamic> args = [];

    if (search != null && search.isNotEmpty) {
      switch (searchBy) {
        case 'member_number':
          where = 'WHERE member_number = ?';
          args = [int.tryParse(search) ?? -1];
          break;
        case 'email':
          where = 'WHERE email LIKE ?';
          args = ['%$search%'];
          break;
        default:
          where = 'WHERE name LIKE ?';
          args = ['%$search%'];
      }
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM members $where',
      args,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Member?> getMember(int id) async {
    final db = await database;
    final result = await db.query('members', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Member.fromMap(result.first);
  }

  Future<void> updateMember(Member member) async {
    final db = await database;
    final data = member.toMap();
    data.remove('id');
    await db.update('members', data, where: 'id = ?', whereArgs: [member.id]);
  }

  Future<void> deleteMember(int id) async {
    final db = await database;
    await db.delete('members', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteMembers(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return await db.rawDelete(
      'DELETE FROM members WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<int> deleteAllMembers() async {
    final db = await database;
    return await db.delete('members');
  }

  Future<List<Member>> getAllMembers() async {
    final db = await database;
    final result = await db.query('members', orderBy: 'member_number ASC');
    return result.map((m) => Member.fromMap(m)).toList();
  }

  // ─── Daily Members ───

  Future<DailyMember> insertDailyMember(DailyMember member) async {
    final db = await database;

    int? dailyNumber = member.dailyMemberNumber;
    if (dailyNumber == null) {
      final result = await db.rawQuery(
        'SELECT COALESCE(MAX(daily_member_number), 0) + 1 AS next_number FROM daily_members',
      );
      dailyNumber = (result.first['next_number'] as int?) ?? 1;
    }

    final data = member.toMap();
    data['daily_member_number'] = dailyNumber;
    data.remove('id');
    if (data['created_at'] == null) {
      data['created_at'] = DateTime.now().toIso8601String();
    }

    final id = await db.insert('daily_members', data);
    return member.copyWith(id: id, dailyMemberNumber: dailyNumber);
  }

  Future<List<DailyMember>> getDailyMembers({
    int limit = 25,
    int offset = 0,
  }) async {
    final db = await database;
    final result = await db.query(
      'daily_members',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return result.map((m) => DailyMember.fromMap(m)).toList();
  }

  Future<int> getDailyMemberCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM daily_members',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<DailyMember?> getDailyMember(int id) async {
    final db = await database;
    final result = await db.query(
      'daily_members',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return DailyMember.fromMap(result.first);
  }

  Future<void> updateDailyMember(DailyMember member) async {
    final db = await database;
    final data = member.toMap();
    data.remove('id');
    await db.update(
      'daily_members',
      data,
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  Future<void> deleteDailyMember(int id) async {
    final db = await database;
    await db.delete('daily_members', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteDailyMembers(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return await db.rawDelete(
      'DELETE FROM daily_members WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<int> deleteAllDailyMembers() async {
    final db = await database;
    return await db.delete('daily_members');
  }

  Future<List<DailyMember>> getAllDailyMembers() async {
    final db = await database;
    final result = await db.query(
      'daily_members',
      orderBy: 'daily_member_number ASC',
    );
    return result.map((m) => DailyMember.fromMap(m)).toList();
  }

  // ─── Authentication ───

  Future<bool> authenticate(String username, String password) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'username = ? AND password_hash = ?',
      whereArgs: [username, password],
    );
    return result.isNotEmpty;
  }

  Future<AppUser?> authenticateUser(String username, String password) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'username = ? AND password_hash = ?',
      whereArgs: [username, password],
    );
    if (result.isEmpty) return null;
    return AppUser.fromMap(result.first);
  }

  // ─── Reports ───

  Future<List<Map<String, dynamic>>> getRegistrationReport({
    required String table,
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;
    final toEnd = DateTime(to.year, to.month, to.day, 23, 59, 59);
    final result = await db.rawQuery(
      '''SELECT DATE(created_at) as date, COUNT(id) as count
         FROM $table
         WHERE created_at >= ? AND created_at <= ?
         GROUP BY DATE(created_at)
         ORDER BY date DESC''',
      [from.toIso8601String(), toEnd.toIso8601String()],
    );
    return result;
  }

  // ─── Bulk import ───

  Future<Map<String, int>> importMembersFromCsv(
    List<Map<String, dynamic>> rows,
  ) async {
    int created = 0, updated = 0, errors = 0;

    for (final row in rows) {
      try {
        final idStr = (row['ID'] ?? '').toString().trim();
        final memberNumberStr =
            (row['member number'] ?? row['member_number'] ?? '').toString().trim();

        Member? existing;
        if (idStr.isNotEmpty) {
          final id = int.tryParse(idStr);
          if (id != null) existing = await getMember(id);
        }

        DateTime? createdAt;
        final dateStr =
            (row['Created (Lisbon)'] ?? row['created at'] ?? row['created_at'] ?? '')
                .toString()
                .trim();
        if (dateStr.isNotEmpty) {
          createdAt = _parseDateString(dateStr);
        }

        if (existing != null) {
          final updatedMember = existing.copyWith(
            name: (row['name'] ?? existing.name).toString(),
            email: (row['email'] ?? existing.email)?.toString(),
            communication:
                _parseBool(row['communication']?.toString() ?? 'false'),
            annualFee: _parseBool(row['annual fee']?.toString() ?? 'false'),
            notes: (row['notes'] ?? existing.notes).toString(),
            memberNumber: memberNumberStr.isNotEmpty
                ? int.tryParse(memberNumberStr)
                : existing.memberNumber,
            createdAt: createdAt ?? existing.createdAt,
          );
          await updateMember(updatedMember);
          updated++;
        } else {
          final newMember = Member(
            name: (row['name'] ?? '').toString(),
            email: row['email']?.toString(),
            communication:
                _parseBool(row['communication']?.toString() ?? 'false'),
            annualFee: _parseBool(row['annual fee']?.toString() ?? 'false'),
            notes: (row['notes'] ?? '').toString(),
            memberNumber: memberNumberStr.isNotEmpty
                ? int.tryParse(memberNumberStr)
                : null,
            createdAt: createdAt,
          );
          await insertMember(newMember);
          created++;
        }
      } catch (e) {
        errors++;
      }
    }
    return {'created': created, 'updated': updated, 'errors': errors};
  }

  Future<Map<String, int>> importDailyMembersFromCsv(
    List<Map<String, dynamic>> rows,
  ) async {
    int created = 0, updated = 0, errors = 0;

    for (final row in rows) {
      try {
        final idStr = (row['ID'] ?? '').toString().trim();
        final dailyNumberStr =
            (row['daily member number'] ?? row['daily_member_number'] ?? '')
                .toString()
                .trim();

        DailyMember? existing;
        if (idStr.isNotEmpty) {
          final id = int.tryParse(idStr);
          if (id != null) existing = await getDailyMember(id);
        }

        DateTime? createdAt;
        final dateStr =
            (row['Created (Lisbon)'] ?? row['created at'] ?? row['created_at'] ?? '')
                .toString()
                .trim();
        if (dateStr.isNotEmpty) {
          createdAt = _parseDateString(dateStr);
        }

        if (existing != null) {
          final updatedMember = existing.copyWith(
            name: (row['name'] ?? existing.name).toString(),
            notes: (row['notes'] ?? existing.notes).toString(),
            dailyMemberNumber: dailyNumberStr.isNotEmpty
                ? int.tryParse(dailyNumberStr)
                : existing.dailyMemberNumber,
            createdAt: createdAt ?? existing.createdAt,
          );
          await updateDailyMember(updatedMember);
          updated++;
        } else {
          final newMember = DailyMember(
            name: (row['name'] ?? '').toString(),
            notes: (row['notes'] ?? '').toString(),
            dailyMemberNumber: dailyNumberStr.isNotEmpty
                ? int.tryParse(dailyNumberStr)
                : null,
            createdAt: createdAt,
          );
          await insertDailyMember(newMember);
          created++;
        }
      } catch (e) {
        errors++;
      }
    }
    return {'created': created, 'updated': updated, 'errors': errors};
  }

  bool _parseBool(String value) {
    return ['true', '1', 'yes'].contains(value.toLowerCase());
  }

  DateTime? _parseDateString(String dateStr) {
    // Try DD/MM/YYYY HH:MM
    try {
      final parts = dateStr.split(' ');
      final dateParts = parts[0].split('/');
      if (dateParts.length == 3) {
        final timeParts = parts.length > 1 ? parts[1].split(':') : ['0', '0'];
        return DateTime(
          int.parse(dateParts[2]),
          int.parse(dateParts[1]),
          int.parse(dateParts[0]),
          int.parse(timeParts[0]),
          timeParts.length > 1 ? int.parse(timeParts[1]) : 0,
        );
      }
    } catch (_) {}

    // Try DD-MM-YYYY HH:MM:SS
    try {
      final parts = dateStr.split(' ');
      final dateParts = parts[0].split('-');
      if (dateParts.length == 3 && dateParts[0].length <= 2) {
        final timeParts =
            parts.length > 1 ? parts[1].split(':') : ['0', '0', '0'];
        return DateTime(
          int.parse(dateParts[2]),
          int.parse(dateParts[1]),
          int.parse(dateParts[0]),
          int.parse(timeParts[0]),
          timeParts.length > 1 ? int.parse(timeParts[1]) : 0,
          timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
        );
      }
    } catch (_) {}

    // Try ISO format
    return DateTime.tryParse(dateStr);
  }

  // ─── Custom Tables ───

  String _sanitizeTableName(String name) {
    final sanitized = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'ct_$sanitized';
  }

  Future<CustomTableDef> createCustomTable(
    String tableName,
    List<CustomColumnDef> columns,
  ) async {
    final db = await database;
    final dbTableName = _sanitizeTableName(tableName);

    final tableId = await db.insert('custom_tables', {
      'table_name': tableName,
      'db_table_name': dbTableName,
      'created_at': DateTime.now().toIso8601String(),
    });

    final insertedColumns = <CustomColumnDef>[];
    for (int i = 0; i < columns.length; i++) {
      final col = columns[i];
      final colId = await db.insert('custom_table_columns', {
        'custom_table_id': tableId,
        'column_name': col.columnName,
        'column_type': col.columnType,
        'column_order': i,
      });
      insertedColumns.add(col.copyWith(id: colId, customTableId: tableId, columnOrder: i));
    }

    // Create the actual data table
    final colDefs = insertedColumns.map((c) => '${c.dbColumnName} ${c.sqlType}').join(', ');
    await db.execute('''
      CREATE TABLE $dbTableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        $colDefs,
        created_at TEXT NOT NULL
      )
    ''');

    return CustomTableDef(
      id: tableId,
      tableName: tableName,
      dbTableName: dbTableName,
      createdAt: DateTime.now(),
      columns: insertedColumns,
    );
  }

  Future<List<CustomTableDef>> getCustomTables() async {
    final db = await database;
    final tables = await db.query('custom_tables', orderBy: 'table_name ASC');
    final result = <CustomTableDef>[];
    for (final t in tables) {
      final cols = await db.query(
        'custom_table_columns',
        where: 'custom_table_id = ?',
        whereArgs: [t['id']],
        orderBy: 'column_order ASC',
      );
      result.add(CustomTableDef.fromMap(t,
          columns: cols.map((c) => CustomColumnDef.fromMap(c)).toList()));
    }
    return result;
  }

  Future<CustomTableDef?> getCustomTable(int id) async {
    final db = await database;
    final tables = await db.query('custom_tables', where: 'id = ?', whereArgs: [id]);
    if (tables.isEmpty) return null;
    final cols = await db.query(
      'custom_table_columns',
      where: 'custom_table_id = ?',
      whereArgs: [id],
      orderBy: 'column_order ASC',
    );
    return CustomTableDef.fromMap(tables.first,
        columns: cols.map((c) => CustomColumnDef.fromMap(c)).toList());
  }

  Future<void> updateCustomTable(
    int tableId,
    String newName,
    List<CustomColumnDef> newColumns,
  ) async {
    final db = await database;
    final existing = await getCustomTable(tableId);
    if (existing == null) return;

    // Update display name
    await db.update('custom_tables', {'table_name': newName},
        where: 'id = ?', whereArgs: [tableId]);

    // Drop and recreate the data table with new columns
    await db.execute('DROP TABLE IF EXISTS ${existing.dbTableName}');
    await db.delete('custom_table_columns',
        where: 'custom_table_id = ?', whereArgs: [tableId]);

    final insertedColumns = <CustomColumnDef>[];
    for (int i = 0; i < newColumns.length; i++) {
      final col = newColumns[i];
      final colId = await db.insert('custom_table_columns', {
        'custom_table_id': tableId,
        'column_name': col.columnName,
        'column_type': col.columnType,
        'column_order': i,
      });
      insertedColumns.add(col.copyWith(id: colId, customTableId: tableId, columnOrder: i));
    }

    final colDefs = insertedColumns.map((c) => '${c.dbColumnName} ${c.sqlType}').join(', ');
    await db.execute('''
      CREATE TABLE ${existing.dbTableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        $colDefs,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> deleteCustomTable(int tableId) async {
    final db = await database;
    final existing = await getCustomTable(tableId);
    if (existing == null) return;

    await db.execute('DROP TABLE IF EXISTS ${existing.dbTableName}');
    await db.delete('custom_table_columns',
        where: 'custom_table_id = ?', whereArgs: [tableId]);
    await db.delete('custom_tables', where: 'id = ?', whereArgs: [tableId]);
  }

  // ─── Custom Table Data CRUD ───

  Future<int> insertCustomRow(String dbTableName, Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    return await db.insert(dbTableName, data);
  }

  Future<List<Map<String, dynamic>>> getCustomRows({
    required String dbTableName,
    String? search,
    String? searchColumn,
    int limit = 25,
    int offset = 0,
  }) async {
    final db = await database;
    String where = '';
    List<dynamic> args = [];

    if (search != null && search.isNotEmpty && searchColumn != null) {
      where = 'WHERE $searchColumn LIKE ?';
      args = ['%$search%'];
    }

    final result = await db.rawQuery(
      'SELECT * FROM $dbTableName $where ORDER BY id DESC LIMIT ? OFFSET ?',
      [...args, limit, offset],
    );
    return result;
  }

  Future<int> getCustomRowCount({
    required String dbTableName,
    String? search,
    String? searchColumn,
  }) async {
    final db = await database;
    String where = '';
    List<dynamic> args = [];

    if (search != null && search.isNotEmpty && searchColumn != null) {
      where = 'WHERE $searchColumn LIKE ?';
      args = ['%$search%'];
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $dbTableName $where',
      args,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getAllCustomRows(String dbTableName) async {
    final db = await database;
    return await db.query(dbTableName, orderBy: 'id ASC');
  }

  Future<void> updateCustomRow(String dbTableName, int id, Map<String, dynamic> data) async {
    final db = await database;
    data.remove('id');
    data.remove('created_at');
    await db.update(dbTableName, data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCustomRow(String dbTableName, int id) async {
    final db = await database;
    await db.delete(dbTableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCustomRows(String dbTableName, List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return await db.rawDelete(
      'DELETE FROM $dbTableName WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<int> deleteAllCustomRows(String dbTableName) async {
    final db = await database;
    return await db.delete(dbTableName);
  }

  Future<Map<String, int>> importCustomRowsFromCsv(
    String dbTableName,
    List<CustomColumnDef> columns,
    List<Map<String, dynamic>> rows,
  ) async {
    int created = 0, errors = 0;
    for (final row in rows) {
      try {
        final data = <String, dynamic>{};
        for (final col in columns) {
          final value = row[col.columnName]?.toString() ?? '';
          switch (col.columnType) {
            case 'INTEGER':
              data[col.dbColumnName] = int.tryParse(value) ?? 0;
              break;
            case 'REAL':
              data[col.dbColumnName] = double.tryParse(value) ?? 0.0;
              break;
            case 'BOOLEAN':
              data[col.dbColumnName] = ['true', '1', 'yes'].contains(value.toLowerCase()) ? 1 : 0;
              break;
            default:
              data[col.dbColumnName] = value;
          }
        }
        await insertCustomRow(dbTableName, data);
        created++;
      } catch (e) {
        errors++;
      }
    }
    return {'created': created, 'errors': errors};
  }

  // ─── User Management ───

  Future<List<AppUser>> getUsers() async {
    final db = await database;
    final result = await db.query('users', orderBy: 'username ASC');
    return result.map((m) => AppUser.fromMap(m)).toList();
  }

  Future<AppUser?> getUser(int id) async {
    final db = await database;
    final result = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return AppUser.fromMap(result.first);
  }

  Future<int> createUser(String username, String password, bool isAdmin) async {
    final db = await database;
    return await db.insert('users', {
      'username': username,
      'password_hash': password,
      'is_staff': isAdmin ? 1 : 0,
    });
  }

  Future<void> updateUserPassword(int userId, String newPassword) async {
    final db = await database;
    await db.update('users', {'password_hash': newPassword},
        where: 'id = ?', whereArgs: [userId]);
  }

  Future<void> updateUserRole(int userId, bool isAdmin) async {
    final db = await database;
    await db.update('users', {'is_staff': isAdmin ? 1 : 0},
        where: 'id = ?', whereArgs: [userId]);
  }

  Future<void> deleteUser(int userId) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }
}
