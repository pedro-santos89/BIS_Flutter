import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart' as csv_lib;
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../models.dart';
import 'cloud_storage_provider.dart';

/// Handles database backup, restore, and conflict-aware merge operations
/// between the local SQLite database and cloud storage providers.
class SyncEngine {
  final CloudStorageProvider provider;

  SyncEngine(this.provider);

  /// Exports the full database (members, daily members, custom tables + data,
  /// users) as a comprehensive JSON structure.
  Future<Uint8List> exportFullDatabase() async {
    final db = DatabaseHelper.instance;

    final members = await db.getAllMembers();
    final dailyMembers = await db.getAllDailyMembers();
    final customTables = await db.getCustomTables();

    // Export custom table data
    final customTableData = <Map<String, dynamic>>[];
    for (final table in customTables) {
      final rows = await db.getAllCustomRows(table.dbTableName);
      customTableData.add({
        'table_name': table.tableName,
        'db_table_name': table.dbTableName,
        'columns': table.columns.map((c) => c.toMap()).toList(),
        'rows': rows,
      });
    }

    final data = {
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'members': members.map((m) => m.toMap()).toList(),
      'daily_members': dailyMembers.map((m) => m.toMap()).toList(),
      'custom_tables': customTableData,
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    return Uint8List.fromList(utf8.encode(jsonStr));
  }

  /// Uploads a full database backup to the cloud.
  Future<String> backupToCloud() async {
    if (!provider.isAuthenticated) {
      throw StateError('Provider not authenticated');
    }
    final data = await exportFullDatabase();
    return await provider.uploadDatabaseBackup(data);
  }

  /// Downloads the latest backup from the cloud and performs a
  /// conflict-aware merge with the local database.
  /// Returns a [SyncResult] with counts of actions taken.
  Future<SyncResult> syncFromCloud() async {
    if (!provider.isAuthenticated) {
      throw StateError('Provider not authenticated');
    }

    final cloudData = await provider.downloadLatestBackup();
    if (cloudData == null) {
      return SyncResult(summary: 'No backup found on cloud');
    }

    final jsonStr = utf8.decode(cloudData);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return await _mergeData(data);
  }

  /// Performs a full two-way sync:
  /// 1. Downloads the latest cloud backup
  /// 2. Merges cloud data into local DB (conflict-aware)
  /// 3. Uploads the merged result back to cloud
  Future<SyncResult> fullSync() async {
    if (!provider.isAuthenticated) {
      throw StateError('Provider not authenticated');
    }

    // Step 1: Download and merge from cloud
    final mergeResult = await syncFromCloud();

    // Step 2: Upload the merged local DB back to cloud
    await backupToCloud();

    return SyncResult(
      membersUploaded: mergeResult.membersDownloaded > 0 ? 1 : 0,
      membersDownloaded: mergeResult.membersDownloaded,
      dailyMembersUploaded: mergeResult.dailyMembersDownloaded > 0 ? 1 : 0,
      dailyMembersDownloaded: mergeResult.dailyMembersDownloaded,
      customTablesUploaded: mergeResult.customTablesDownloaded > 0 ? 1 : 0,
      customTablesDownloaded: mergeResult.customTablesDownloaded,
      conflicts: mergeResult.conflicts,
      errors: mergeResult.errors,
      summary: 'Full sync complete. ${mergeResult.summary}',
    );
  }

  /// Merges cloud backup data into the local database.
  /// Uses conflict-aware strategy:
  /// - For members: match by member_number. If both exist, keep the newer one
  ///   (based on created_at). New records are inserted.
  /// - For daily members: match by daily_member_number. Same strategy.
  /// - For custom tables: match by db_table_name. Merge rows, create tables
  ///   that don't exist locally.
  Future<SyncResult> _mergeData(Map<String, dynamic> cloudData) async {
    final db = DatabaseHelper.instance;
    int membersDownloaded = 0;
    int dailyMembersDownloaded = 0;
    int customTablesDownloaded = 0;
    int conflicts = 0;
    int errors = 0;

    // ─── Merge Members ───
    final cloudMembers = cloudData['members'] as List<dynamic>? ?? [];
    final localMembers = await db.getAllMembers();
    final localMembersByNumber = <int, Member>{};
    for (final m in localMembers) {
      if (m.memberNumber != null) {
        localMembersByNumber[m.memberNumber!] = m;
      }
    }

    for (final raw in cloudMembers) {
      try {
        final map = Map<String, dynamic>.from(raw as Map);
        final cloudMember = Member.fromMap(map);
        final memberNum = cloudMember.memberNumber;

        if (memberNum != null && localMembersByNumber.containsKey(memberNum)) {
          // Conflict: both have this member_number
          final local = localMembersByNumber[memberNum]!;
          final localTime = local.createdAt ?? DateTime(2000);
          final cloudTime = cloudMember.createdAt ?? DateTime(2000);

          if (cloudTime.isAfter(localTime)) {
            // Cloud is newer — update local
            await db.updateMember(cloudMember.copyWith(id: local.id));
            membersDownloaded++;
            conflicts++;
          } else {
            // Local is newer or same — keep local
            conflicts++;
          }
        } else {
          // New member from cloud — insert
          await db.insertMember(cloudMember.copyWith(id: null));
          membersDownloaded++;
        }
      } catch (e) {
        errors++;
      }
    }

    // ─── Merge Daily Members ───
    final cloudDailyMembers = cloudData['daily_members'] as List<dynamic>? ?? [];
    final localDailyMembers = await db.getAllDailyMembers();
    final localDailyByNumber = <int, DailyMember>{};
    for (final m in localDailyMembers) {
      if (m.dailyMemberNumber != null) {
        localDailyByNumber[m.dailyMemberNumber!] = m;
      }
    }

    for (final raw in cloudDailyMembers) {
      try {
        final map = Map<String, dynamic>.from(raw as Map);
        final cloudDM = DailyMember.fromMap(map);
        final dailyNum = cloudDM.dailyMemberNumber;

        if (dailyNum != null && localDailyByNumber.containsKey(dailyNum)) {
          final local = localDailyByNumber[dailyNum]!;
          final localTime = local.createdAt ?? DateTime(2000);
          final cloudTime = cloudDM.createdAt ?? DateTime(2000);

          if (cloudTime.isAfter(localTime)) {
            await db.updateDailyMember(cloudDM.copyWith(id: local.id));
            dailyMembersDownloaded++;
            conflicts++;
          } else {
            conflicts++;
          }
        } else {
          await db.insertDailyMember(cloudDM.copyWith(id: null));
          dailyMembersDownloaded++;
        }
      } catch (e) {
        errors++;
      }
    }

    // ─── Merge Custom Tables ───
    final cloudTables = cloudData['custom_tables'] as List<dynamic>? ?? [];
    final localTables = await db.getCustomTables();
    final localTablesByDbName = <String, CustomTableDef>{};
    for (final t in localTables) {
      localTablesByDbName[t.dbTableName] = t;
    }

    for (final raw in cloudTables) {
      try {
        final tableData = Map<String, dynamic>.from(raw as Map);
        final dbTableName = tableData['db_table_name'] as String;
        final tableName = tableData['table_name'] as String;
        final cloudColumns = (tableData['columns'] as List<dynamic>? ?? [])
            .map((c) => CustomColumnDef.fromMap(Map<String, dynamic>.from(c as Map)))
            .toList();
        final cloudRows = tableData['rows'] as List<dynamic>? ?? [];

        if (localTablesByDbName.containsKey(dbTableName)) {
          // Table exists locally — merge rows
          final localRows = await db.getAllCustomRows(dbTableName);
          final localRowIds = localRows.map((r) => r['id'] as int).toSet();

          for (final rowRaw in cloudRows) {
            final row = Map<String, dynamic>.from(rowRaw as Map);
            final rowId = row['id'] as int?;

            if (rowId != null && localRowIds.contains(rowId)) {
              // Row exists — compare created_at for conflict resolution
              final localRow = localRows.firstWhere((r) => r['id'] == rowId);
              final localTime = DateTime.tryParse(localRow['created_at']?.toString() ?? '') ?? DateTime(2000);
              final cloudTime = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime(2000);

              if (cloudTime.isAfter(localTime)) {
                final updateData = Map<String, dynamic>.from(row);
                updateData.remove('id');
                updateData.remove('created_at');
                await db.updateCustomRow(dbTableName, rowId, updateData);
                customTablesDownloaded++;
                conflicts++;
              } else {
                conflicts++;
              }
            } else {
              // New row from cloud — insert without the original ID
              final insertData = Map<String, dynamic>.from(row);
              insertData.remove('id');
              if (insertData['created_at'] == null) {
                insertData['created_at'] = DateTime.now().toIso8601String();
              }
              await db.insertCustomRow(dbTableName, insertData);
              customTablesDownloaded++;
            }
          }
        } else {
          // Table doesn't exist locally — create it
          final newColumns = cloudColumns.map((c) => CustomColumnDef(
            columnName: c.columnName,
            columnType: c.columnType,
            columnOrder: c.columnOrder,
          )).toList();

          final createdTable = await db.createCustomTable(tableName, newColumns);

          // Insert all rows
          for (final rowRaw in cloudRows) {
            try {
              final row = Map<String, dynamic>.from(rowRaw as Map);
              row.remove('id');
              if (row['created_at'] == null) {
                row['created_at'] = DateTime.now().toIso8601String();
              }
              await db.insertCustomRow(createdTable.dbTableName, row);
              customTablesDownloaded++;
            } catch (_) {
              errors++;
            }
          }
        }
      } catch (e) {
        errors++;
      }
    }

    final summary = StringBuffer();
    if (membersDownloaded > 0) summary.write('$membersDownloaded members merged. ');
    if (dailyMembersDownloaded > 0) summary.write('$dailyMembersDownloaded daily members merged. ');
    if (customTablesDownloaded > 0) summary.write('$customTablesDownloaded custom table rows merged. ');
    if (conflicts > 0) summary.write('$conflicts conflicts resolved. ');
    if (errors > 0) summary.write('$errors errors. ');
    if (summary.isEmpty) summary.write('Already up to date.');

    return SyncResult(
      membersDownloaded: membersDownloaded,
      dailyMembersDownloaded: dailyMembersDownloaded,
      customTablesDownloaded: customTablesDownloaded,
      conflicts: conflicts,
      errors: errors,
      summary: summary.toString().trim(),
    );
  }

  /// Imports data from a specific cloud file into the local database.
  /// The file should be a JSON backup.
  Future<SyncResult> importFromCloudFile(String fileId) async {
    if (!provider.isAuthenticated) {
      throw StateError('Provider not authenticated');
    }

    final data = await provider.downloadFile(fileId);
    final jsonStr = utf8.decode(data);
    final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
    return await _mergeData(parsed);
  }

  // ─── CSV Export/Upload ───

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('dd-MM-yyyy HH:mm:ss').format(dt);
  }

  /// Exports members as CSV and uploads to the connected cloud provider.
  Future<String> exportMembersCsvToCloud() async {
    if (!provider.isAuthenticated) {
      throw StateError('Provider not authenticated');
    }
    final db = DatabaseHelper.instance;
    final members = await db.getAllMembers();

    final rows = <List<dynamic>>[
      ['ID', 'Member Number', 'Name', 'Email', 'Communication', 'Annual Fee', 'Notes', 'Created'],
      ...members.map((m) => [
        m.id,
        m.memberNumber,
        m.name,
        m.email ?? '',
        m.communication ? 'True' : 'False',
        m.annualFee ? 'True' : 'False',
        m.notes,
        _formatDate(m.createdAt),
      ]),
    ];

    final csvData = csv_lib.CsvEncoder().convert(rows);
    final bytes = Uint8List.fromList(utf8.encode(csvData));
    final now = DateTime.now();
    final fileName = 'members_${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}.csv';
    return await provider.uploadFile(fileName, bytes, mimeType: 'text/csv');
  }

  /// Exports daily members as CSV and uploads to the connected cloud provider.
  Future<String> exportDailyMembersCsvToCloud() async {
    if (!provider.isAuthenticated) {
      throw StateError('Provider not authenticated');
    }
    final db = DatabaseHelper.instance;
    final dailyMembers = await db.getAllDailyMembers();

    final rows = <List<dynamic>>[
      ['ID', 'Daily Member Number', 'Name', 'Notes', 'Created'],
      ...dailyMembers.map((m) => [
        m.id,
        m.dailyMemberNumber,
        m.name,
        m.notes,
        _formatDate(m.createdAt),
      ]),
    ];

    final csvData = csv_lib.CsvEncoder().convert(rows);
    final bytes = Uint8List.fromList(utf8.encode(csvData));
    final now = DateTime.now();
    final fileName = 'daily_members_${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}.csv';
    return await provider.uploadFile(fileName, bytes, mimeType: 'text/csv');
  }

  /// Exports all data (members + daily members) as CSV and uploads both files.
  Future<void> exportAllCsvToCloud() async {
    await exportMembersCsvToCloud();
    await exportDailyMembersCsvToCloud();
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
