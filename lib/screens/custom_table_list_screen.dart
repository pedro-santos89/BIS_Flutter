import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';

/// Lists all user-created custom tables with options to view data,
/// edit structure, or delete each table.
class CustomTableListScreen extends StatefulWidget {
  const CustomTableListScreen({super.key});

  @override
  State<CustomTableListScreen> createState() => _CustomTableListScreenState();
}

class _CustomTableListScreenState extends State<CustomTableListScreen> {
  /// All custom table definitions fetched from the database.
  List<CustomTableDef> _tables = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  /// Reloads the list of custom tables from the database.
  Future<void> _loadTables() async {
    setState(() => _loading = true);
    final tables = await DatabaseHelper.instance.getCustomTables();
    setState(() {
      _tables = tables;
      _loading = false;
    });
  }

  /// Navigates to the design screen to create a new custom table.
  Future<void> _createTable() async {
    final result = await Navigator.pushNamed(context, '/admin/custom-tables/design');
    if (result == true) _loadTables();
  }

  /// Navigates to the design screen to edit an existing table's structure.
  Future<void> _editTable(CustomTableDef table) async {
    final result = await Navigator.pushNamed(
      context,
      '/admin/custom-tables/design',
      arguments: table,
    );
    if (result == true) _loadTables();
  }

  /// Prompts for confirmation, then deletes the table and its data.
  Future<void> _deleteTable(CustomTableDef table) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l.tr('deleteTableTitle')),
          content: Text(
            l.trArgs('deleteTableConfirm', {'name': table.tableName}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l.tr('delete')),
            ),
          ],
        );
      },
    );

    if (confirm == true && table.id != null) {
      await DatabaseHelper.instance.deleteCustomTable(table.id!);
      _loadTables();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hoverColor = AppTheme.hoverColor(isDark);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('customTables')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTable,
        tooltip: l.tr('createTable'),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tables.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.table_chart_outlined,
                          size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(l.tr('noCustomTables'),
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(l.tr('noCustomTablesHint')),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tables.length,
                  itemBuilder: (context, index) {
                    final table = _tables[index];
                    return _TableTile(
                      table: table,
                      hoverColor: hoverColor,
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/admin/custom-tables/data',
                        arguments: table,
                      ),
                      onEdit: () => _editTable(table),
                      onDelete: () => _deleteTable(table),
                    );
                  },
                ),
    );
  }
}

/// A single list tile representing a custom table, with hover effects
/// and action buttons for edit and delete.
class _TableTile extends StatefulWidget {
  final CustomTableDef table;
  final Color hoverColor;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TableTile({
    required this.table,
    required this.hoverColor,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_TableTile> createState() => _TableTileState();
}

class _TableTileState extends State<_TableTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _hovering
                ? primary.withValues(alpha: 0.1)
                : theme.cardTheme.color,
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.table_chart, size: 32,
                    color: _hovering ? widget.hoverColor : primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.table.tableName,
                        style: TextStyle(
                          color: _hovering ? widget.hoverColor : primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context).trArgs('columnsDetail', {
                          'count': widget.table.columns.length.toString(),
                          'names': widget.table.columns.map((c) => c.columnName).join(', '),
                        }),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: AppLocalizations.of(context).tr('editStructure'),
                  child: GestureDetector(
                    onTap: widget.onEdit,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.edit, size: 20),
                    ),
                  ),
                ),
                Tooltip(
                  message: AppLocalizations.of(context).tr('deleteTable'),
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.delete, size: 20, color: Colors.red),
                    ),
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: _hovering ? widget.hoverColor : null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
