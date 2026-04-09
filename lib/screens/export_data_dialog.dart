import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models.dart';
import '../l10n.dart';

/// A dialog that lets the user select which tables to export to cloud storage.
/// Returns a list of export targets or null if cancelled.
class ExportDataDialog extends StatefulWidget {
  const ExportDataDialog({super.key});

  static Future<List<ExportTarget>?> show(BuildContext context) {
    return showDialog<List<ExportTarget>>(
      context: context,
      builder: (_) => const ExportDataDialog(),
    );
  }

  @override
  State<ExportDataDialog> createState() => _ExportDataDialogState();
}

class _ExportDataDialogState extends State<ExportDataDialog> {
  bool _exportAll = false; // Master toggle to export all tables at once
  bool _exportMembers = false; // Export Members table
  bool _exportDailyMembers = false; // Export Daily Members table
  final Map<int, bool> _exportCustomTables = {}; // Map of custom table ID -> export checkbox state
  List<CustomTableDef> _customTables = []; // List of all custom tables from database
  bool _loading = true; // Loading state while fetching custom tables

  @override
  void initState() {
    super.initState();
    _loadCustomTables();
  }

  Future<void> _loadCustomTables() async {
    try {
      final tables = await DatabaseHelper.instance.getCustomTables();
      if (mounted) {
        setState(() {
          _customTables = tables;
          for (final table in tables) {
            _exportCustomTables[table.id!] = false;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Toggles "Export All" checkbox and syncs all individual checkboxes.
  /// When enabled, all table checkboxes are automatically checked.
  void _toggleExportAll(bool? value) {
    setState(() {
      _exportAll = value ?? false;
      _exportMembers = _exportAll;
      _exportDailyMembers = _exportAll;
      for (final key in _exportCustomTables.keys) {
        _exportCustomTables[key] = _exportAll;
      }
    });
  }

  /// Validates selection and returns export targets to caller.
  /// Shows error if no tables are selected.
  void _confirmSelection() {
    final selections = <ExportTarget>[];
    
    if (_exportAll) {
      selections.add(ExportTarget.all());
    } else {
      if (_exportMembers) selections.add(ExportTarget.members());
      if (_exportDailyMembers) selections.add(ExportTarget.dailyMembers());
      
      for (final table in _customTables) {
        if (_exportCustomTables[table.id] == true) {
          selections.add(ExportTarget.customTable(table));
        }
      }
    }

    if (selections.isEmpty) {
      // Show a snackbar or message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).tr('selectAtLeastOne')),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.of(context).pop(selections);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(Icons.cloud_upload, color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.tr('exportDataToCloud'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.onPrimaryContainer),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: l.tr('cancel'),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.tr('selectTablesToExport'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Export All option
                          CheckboxListTile(
                            value: _exportAll,
                            onChanged: _toggleExportAll,
                            title: Text(
                              l.tr('exportAllTables'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(l.tr('exportAllTablesDesc')),
                            secondary: const Icon(Icons.select_all),
                          ),

                          const Divider(),

                          // Members
                          CheckboxListTile(
                            value: _exportMembers,
                            onChanged: (val) => setState(() => _exportMembers = val ?? false),
                            title: Text(l.tr('members')),
                            secondary: const Icon(Icons.person),
                            enabled: !_exportAll,
                          ),

                          // Daily Members
                          CheckboxListTile(
                            value: _exportDailyMembers,
                            onChanged: (val) => setState(() => _exportDailyMembers = val ?? false),
                            title: Text(l.tr('dailyMembers')),
                            secondary: const Icon(Icons.people),
                            enabled: !_exportAll,
                          ),

                          // Custom Tables
                          if (_customTables.isNotEmpty) ...[
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                l.tr('customTables'),
                                style: theme.textTheme.labelLarge,
                              ),
                            ),
                            ..._customTables.map((table) => CheckboxListTile(
                              value: _exportCustomTables[table.id],
                              onChanged: (val) => setState(() {
                                _exportCustomTables[table.id!] = val ?? false;
                              }),
                              title: Text(table.tableName),
                              secondary: const Icon(Icons.table_chart),
                              enabled: !_exportAll,
                            )),
                          ],
                        ],
                      ),
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.tr('cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(l.tr('export')),
                    onPressed: _loading ? null : _confirmSelection,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Represents a target for CSV export operation.
/// Encapsulates which table(s) to export and the export type.
/// Factory constructors provide type-safe creation for each export scenario.
class ExportTarget {
  final ExportType type; // Type of export operation
  final CustomTableDef? customTable; // Custom table definition (only for customTable type)

  /// Export all tables: Members, Daily Members, and all Custom Tables
  ExportTarget.all() : type = ExportType.all, customTable = null;
  
  /// Export only the Members table
  ExportTarget.members() : type = ExportType.members, customTable = null;
  
  /// Export only the Daily Members table
  ExportTarget.dailyMembers() : type = ExportType.dailyMembers, customTable = null;
  
  /// Export a specific Custom Table
  ExportTarget.customTable(this.customTable) : type = ExportType.customTable;
}

/// Defines the type of data export operation.
/// - all: Export all tables (Members + Daily Members + all Custom Tables)
/// - members: Export only Members table
/// - dailyMembers: Export only Daily Members table
/// - customTable: Export a specific Custom Table
enum ExportType { all, members, dailyMembers, customTable }
