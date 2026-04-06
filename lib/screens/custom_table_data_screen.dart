import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart' as csv_lib;
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'dart:convert';
import '../database_helper.dart';
import '../models.dart';
import '../export_helper.dart';
import '../l10n.dart';
import '../theme.dart';

/// Data management screen for a single custom table.
/// Provides a paginated DataTable with CRUD operations, search,
/// multi-select, sorting, CSV/PDF export, and CSV import.
class CustomTableDataScreen extends StatefulWidget {
  const CustomTableDataScreen({super.key});

  @override
  State<CustomTableDataScreen> createState() => _CustomTableDataScreenState();
}

class _CustomTableDataScreenState extends State<CustomTableDataScreen> {
  final _searchController = TextEditingController();

  /// The DB column name currently used as the search filter target.
  String? _searchColumn;

  /// Current page of rows fetched from the database.
  List<Map<String, dynamic>> _rows = [];

  /// Total row count matching the current search (for pagination).
  int _totalCount = 0;
  int _currentPage = 0;
  int _pageSize = 25;
  bool _loading = true;

  /// IDs of rows selected via checkboxes (used for bulk actions).
  final Set<int> _selectedIds = {};
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  String _sortColumn = 'id';

  /// The table definition passed via route arguments.
  CustomTableDef? _tableDef;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is CustomTableDef) {
        _tableDef = arg;
        if (arg.columns.isNotEmpty) {
          _searchColumn = arg.columns.first.dbColumnName;
        }
        _loadRows();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches a page of rows from the custom table, applying search,
  /// sort, and pagination parameters. Clears selection afterward.
  Future<void> _loadRows() async {
    if (_tableDef == null) return;
    setState(() => _loading = true);
    final search = _searchController.text.trim();
    final rows = await DatabaseHelper.instance.getCustomRows(
      dbTableName: _tableDef!.dbTableName,
      search: search.isEmpty ? null : search,
      searchColumn: _searchColumn,
      limit: _pageSize,
      offset: _currentPage * _pageSize,
      orderBy: _sortColumn,
      ascending: _sortAscending,
    );
    final count = await DatabaseHelper.instance.getCustomRowCount(
      dbTableName: _tableDef!.dbTableName,
      search: search.isEmpty ? null : search,
      searchColumn: _searchColumn,
    );
    setState(() {
      _rows = rows;
      _totalCount = count;
      _loading = false;
      _selectedIds.clear();
    });
  }

  int get _totalPages => (_totalCount / _pageSize).ceil();

  List<CustomColumnDef> get _columns => _tableDef?.columns ?? [];

  /// Formats a [DateTime] as dd-MM-yyyy HH:mm:ss for display.
  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('dd-MM-yyyy HH:mm:ss').format(dt);
  }

  /// Returns a human-readable string for a cell value,
  /// converting booleans to Yes/No.
  String _displayValue(CustomColumnDef col, dynamic value) {
    if (value == null) return '';
    if (col.columnType == 'BOOLEAN') {
      return (value == 1 || value == true) ? 'Yes' : 'No';
    }
    if (col.columnType == 'DATE') {
      final dt = DateTime.tryParse(value.toString());
      if (dt != null) return DateFormat('dd-MM-yyyy').format(dt);
    }
    if (col.columnType == 'DATETIME') {
      final dt = DateTime.tryParse(value.toString());
      if (dt != null) return DateFormat('dd-MM-yyyy HH:mm').format(dt);
    }
    return value.toString();
  }

  /// Updates sort state and reloads rows from page 0.
  void _sort(int columnIndex, bool ascending) {
    String dbCol;
    if (columnIndex == 0) {
      dbCol = 'id';
    } else if (columnIndex <= _columns.length) {
      dbCol = _columns[columnIndex - 1].dbColumnName;
    } else {
      dbCol = 'created_at';
    }
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _sortColumn = dbCol;
      _currentPage = 0;
    });
    _loadRows();
  }

  /// Opens the row dialog for creating a new row, then inserts it.
  Future<void> _addRow() async {
    final result = await _showRowDialog(null);
    if (result != null) {
      await DatabaseHelper.instance.insertCustomRow(
        _tableDef!.dbTableName,
        result,
      );
      _loadRows();
    }
  }

  /// Opens the row dialog pre-filled with [row] data for editing.
  Future<void> _editRow(Map<String, dynamic> row) async {
    final result = await _showRowDialog(row);
    if (result != null) {
      await DatabaseHelper.instance.updateCustomRow(
        _tableDef!.dbTableName,
        row['id'] as int,
        result,
      );
      _loadRows();
    }
  }

  /// Shows a dialog with fields for each column to create or edit a row.
  /// Returns a map of column->value on save, or null on cancel.
  Future<Map<String, dynamic>?> _showRowDialog(
      Map<String, dynamic>? existing) async {
    final controllers = <String, TextEditingController>{};
    final boolValues = <String, bool>{};
    final dateValues = <String, DateTime?>{};

    for (final col in _columns) {
      if (col.columnType == 'BOOLEAN') {
        boolValues[col.dbColumnName] = existing != null &&
            (existing[col.dbColumnName] == 1 ||
                existing[col.dbColumnName] == true);
      } else if (col.columnType == 'DATE' || col.columnType == 'DATETIME') {
        final raw = existing?[col.dbColumnName]?.toString() ?? '';
        dateValues[col.dbColumnName] = raw.isNotEmpty ? DateTime.tryParse(raw) : null;
      } else {
        controllers[col.dbColumnName] = TextEditingController(
          text: existing?[col.dbColumnName]?.toString() ?? '',
        );
      }
    }

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(existing != null ? l.tr('editRow') : l.tr('addRow')),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _columns.map((col) {
                      if (col.columnType == 'BOOLEAN') {
                        return CheckboxListTile(
                          title: Text(col.columnName),
                          value: boolValues[col.dbColumnName] ?? false,
                          onChanged: (v) {
                            setDialogState(
                                () => boolValues[col.dbColumnName] = v ?? false);
                          },
                        );
                      }
                      if (col.columnType == 'DATE' || col.columnType == 'DATETIME') {
                        final current = dateValues[col.dbColumnName];
                        final isDateTime = col.columnType == 'DATETIME';
                        String displayText = '';
                        if (current != null) {
                          displayText = isDateTime
                              ? DateFormat('dd-MM-yyyy HH:mm').format(current)
                              : DateFormat('dd-MM-yyyy').format(current);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: ctx,
                                initialDate: current ?? DateTime.now(),
                                firstDate: DateTime(1900),
                                lastDate: DateTime(2100),
                              );
                              if (pickedDate == null) return;
                              DateTime finalValue = pickedDate;
                              if (isDateTime) {
                                final pickedTime = await showTimePicker(
                                  context: ctx,
                                  initialTime: current != null
                                      ? TimeOfDay.fromDateTime(current)
                                      : TimeOfDay.now(),
                                );
                                if (pickedTime != null) {
                                  finalValue = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  );
                                }
                              }
                              setDialogState(() {
                                dateValues[col.dbColumnName] = finalValue;
                              });
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: col.columnName,
                                isDense: true,
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (current != null)
                                      IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setDialogState(() {
                                            dateValues[col.dbColumnName] = null;
                                          });
                                        },
                                      ),
                                    Icon(isDateTime ? Icons.access_time : Icons.calendar_today, size: 18),
                                  ],
                                ),
                              ),
                              child: Text(
                                displayText.isEmpty ? l.tr(isDateTime ? 'selectDateTime' : 'selectDate') : displayText,
                                style: TextStyle(
                                  color: displayText.isEmpty
                                      ? Theme.of(ctx).hintColor
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: controllers[col.dbColumnName],
                          decoration: InputDecoration(
                            labelText: col.columnName,
                            hintText: col.columnType == 'INTEGER'
                                ? l.tr('enterNumber')
                                : col.columnType == 'REAL'
                                    ? l.tr('enterDecimal')
                                    : l.tr('enterText'),
                          ),
                          keyboardType: col.columnType == 'INTEGER' ||
                                  col.columnType == 'REAL'
                              ? TextInputType.number
                              : TextInputType.text,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? l.tr('required') : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.tr('cancel')),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final data = <String, dynamic>{};
                  for (final col in _columns) {
                    if (col.columnType == 'BOOLEAN') {
                      data[col.dbColumnName] =
                          (boolValues[col.dbColumnName] ?? false) ? 1 : 0;
                    } else if (col.columnType == 'DATE' || col.columnType == 'DATETIME') {
                      final dt = dateValues[col.dbColumnName];
                      data[col.dbColumnName] = dt?.toIso8601String() ?? '';
                    } else {
                      final text =
                          controllers[col.dbColumnName]?.text.trim() ?? '';
                      switch (col.columnType) {
                        case 'INTEGER':
                          data[col.dbColumnName] = int.tryParse(text) ?? 0;
                          break;
                        case 'REAL':
                          data[col.dbColumnName] = double.tryParse(text) ?? 0.0;
                          break;
                        default:
                          data[col.dbColumnName] = text;
                      }
                    }
                  }
                  Navigator.pop(ctx, data);
                },
                child: Text(existing != null ? l.tr('save') : l.tr('add')),
              ),
            ],
          ),
        );
      },
    );

    for (final c in controllers.values) {
      c.dispose();
    }
    return result;
  }

  /// Confirms and deletes a single row by its ID.
  Future<void> _deleteRow(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l.tr('deleteRow')),
          content: Text(l.trArgs('deleteRowConfirm', {'id': row['id'].toString()})),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.tr('cancel'))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l.tr('delete')),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await DatabaseHelper.instance
          .deleteCustomRow(_tableDef!.dbTableName, row['id'] as int);
      _loadRows();
    }
  }

  /// Confirms and deletes all currently selected (checked) rows.
  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l.tr('deleteSelectedRows')),
          content: Text(
              l.trArgs('deleteSelectedRowsConfirm', {'count': _selectedIds.length.toString()})),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.tr('cancel'))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l.tr('delete')),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      final count = await DatabaseHelper.instance
          .deleteCustomRows(_tableDef!.dbTableName, _selectedIds.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).trArgs('deletedRows', {'count': count.toString()}))),
      );
      _loadRows();
    }
  }

  /// Confirms and deletes every row in the custom table.
  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l.tr('deleteAllRows')),
          content: Text(l.tr('deleteAllRowsConfirm')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.tr('cancel'))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l.tr('deleteAll')),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      final count = await DatabaseHelper.instance
          .deleteAllCustomRows(_tableDef!.dbTableName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).trArgs('deletedRows', {'count': count.toString()}))),
      );
      _loadRows();
    }
  }

  /// Exports rows to a CSV file. If [allRecords] is true, exports the
  /// entire table; otherwise exports only selected rows.
  Future<void> _exportCsv({bool allRecords = false}) async {
    final List<Map<String, dynamic>> toExport;
    if (allRecords) {
      toExport =
          await DatabaseHelper.instance.getAllCustomRows(_tableDef!.dbTableName);
    } else if (_selectedIds.isNotEmpty) {
      toExport = _rows.where((r) => _selectedIds.contains(r['id'])).toList();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('noRowsSelectedExport'))),
      );
      return;
    }

    final headers = [
      'ID',
      ..._columns.map((c) => c.columnName),
      'Created',
    ];
    final csvRows = <List<dynamic>>[
      headers,
      ...toExport.map((row) => [
            row['id'],
            ..._columns.map((c) => _displayValue(c, row[c.dbColumnName])),
            row['created_at'] ?? '',
          ]),
    ];

    final csvData = csv_lib.Csv().encode(csvRows);
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV file',
      fileName: '${_tableDef!.tableName.replaceAll(' ', '_')}_export.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (outputPath == null) return;

    final path =
        outputPath.endsWith('.csv') ? outputPath : '$outputPath.csv';
    await File(path).writeAsString(csvData, encoding: utf8);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).trArgs('exportedRowsCsv', {'count': toExport.length.toString(), 'path': path}))),
    );
  }

  /// Exports rows to a paginated landscape PDF file. If [allRecords]
  /// is true, exports the entire table; otherwise exports selected rows.
  Future<void> _exportPdf({bool allRecords = false}) async {
    final List<Map<String, dynamic>> toExport;
    if (allRecords) {
      toExport =
          await DatabaseHelper.instance.getAllCustomRows(_tableDef!.dbTableName);
    } else if (_selectedIds.isNotEmpty) {
      toExport = _rows.where((r) => _selectedIds.contains(r['id'])).toList();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('noRowsSelectedExport'))),
      );
      return;
    }

    final pdf = pw.Document();
    final dateStr = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());
    final title = _tableDef!.tableName;
    final totalPages = toExport.isEmpty ? 1 : (toExport.length / 28).ceil();

    final allHeaders = ['ID', ..._columns.map((c) => c.columnName), 'Created'];
    final colCount = allHeaders.length;
    final columnWidths = <int, pw.TableColumnWidth>{};
    for (int i = 0; i < colCount; i++) {
      columnWidths[i] = const pw.FlexColumnWidth(1);
    }
    // Give ID a smaller width
    columnWidths[0] = const pw.FlexColumnWidth(0.6);
    columnWidths[colCount - 1] = const pw.FlexColumnWidth(2.0);

    if (toExport.isEmpty) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) =>
            pw.Center(child: pw.Text('No records to export')),
      ));
    }

    const rowsPerPage = 28;
    for (int i = 0; i < toExport.length; i += rowsPerPage) {
      final pageRows = toExport.skip(i).take(rowsPerPage).toList();
      final pageNum = (i ~/ rowsPerPage) + 1;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(title,
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text('Exported: $dateStr',
                        style: const pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text('Total: ${toExport.length} records',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey600)),
                pw.SizedBox(height: 8),
                pw.Table(
                  columnWidths: columnWidths,
                  border: pw.TableBorder.all(
                      color: PdfColors.grey400, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                          color: PdfColors.grey300),
                      children: allHeaders
                          .map((h) => pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 2),
                                child: pw.Text(h,
                                    style: pw.TextStyle(
                                        fontSize: 7,
                                        fontWeight: pw.FontWeight.bold)),
                              ))
                          .toList(),
                    ),
                    ...pageRows.map((row) => pw.TableRow(
                          children: [
                            '${row['id']}',
                            ..._columns.map((c) =>
                                _displayValue(c, row[c.dbColumnName])),
                            row['created_at']?.toString() ?? '',
                          ]
                              .map((cell) => pw.Padding(
                                    padding:
                                        const pw.EdgeInsets.symmetric(
                                            horizontal: 3, vertical: 1.5),
                                    child: pw.Text(cell,
                                        style: const pw.TextStyle(
                                            fontSize: 6.5),
                                        maxLines: 2),
                                  ))
                              .toList(),
                        )),
                  ],
                ),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('Page $pageNum of $totalPages',
                      style: const pw.TextStyle(
                          fontSize: 7, color: PdfColors.grey600)),
                ),
              ],
            );
          },
        ),
      );
    }

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF file',
      fileName:
          '${_tableDef!.tableName.replaceAll(' ', '_')}_export.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (outputPath == null) return;
    final path =
        outputPath.endsWith('.pdf') ? outputPath : '$outputPath.pdf';
    await File(path).writeAsBytes(await pdf.save());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF exported to $path')),
    );
  }

  /// Picks a CSV file, parses it, and bulk-imports rows into the table.
  Future<void> _importCsv() async {
    final dataRows = await ExportHelper.pickAndParseCsv();
    if (dataRows == null) return;

    final counts = await DatabaseHelper.instance.importCustomRowsFromCsv(
      _tableDef!.dbTableName,
      _columns,
      dataRows,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).trArgs('csvImportRowsResult', {
            'created': counts['created'].toString(),
            'errors': counts['errors'].toString(),
          }),
        ),
      ),
    );
    _loadRows();
  }

  @override
  Widget build(BuildContext context) {
    if (_tableDef == null) {
      return Scaffold(
        body: Center(child: Text(AppLocalizations.of(context).tr('noTableSelected'))),
      );
    }

    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_tableDef!.tableName),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'export_selected':
                  _exportCsv();
                  break;
                case 'export_all':
                  _exportCsv(allRecords: true);
                  break;
                case 'pdf_selected':
                  _exportPdf();
                  break;
                case 'pdf_all':
                  _exportPdf(allRecords: true);
                  break;
                case 'import':
                  _importCsv();
                  break;
                case 'delete_selected':
                  _deleteSelected();
                  break;
                case 'delete_all':
                  _deleteAll();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                  value: 'export_selected',
                  child: Text(l.tr('exportSelectedCsv'))),
              PopupMenuItem(
                  value: 'export_all', child: Text(l.tr('exportAllCsv'))),
              const PopupMenuDivider(),
              PopupMenuItem(
                  value: 'pdf_selected',
                  child: Text(l.tr('exportSelectedCsv').replaceAll('CSV', 'PDF'))),
              PopupMenuItem(
                  value: 'pdf_all', child: Text(l.tr('exportAllCsv').replaceAll('CSV', 'PDF'))),
              const PopupMenuDivider(),
              PopupMenuItem(
                  value: 'import', child: Text(l.tr('importFromCsv'))),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete_selected',
                child: Text(l.tr('deleteSelected'),
                    style: TextStyle(color: Colors.red)),
              ),
              PopupMenuItem(
                value: 'delete_all',
                child:
                    Text(l.tr('deleteAllCaps'), style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRow,
        tooltip: l.tr('addRow'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l.tr('search'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _currentPage = 0;
                                _loadRows();
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) {
                      _currentPage = 0;
                      _loadRows();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _searchColumn,
                  items: _columns
                      .map((c) => DropdownMenuItem(
                            value: c.dbColumnName,
                            child: Text(c.columnName),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _searchColumn = v);
                    _currentPage = 0;
                    _loadRows();
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    _currentPage = 0;
                    _loadRows();
                  },
                ),
              ],
            ),
          ),

          // Results info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  l.trArgs('rowsCount', {'count': _totalCount.toString()}),
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                if (_selectedIds.isNotEmpty)
                  Text(
                    l.trArgs('selected', {'count': _selectedIds.length.toString()}),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const Divider(),

          // Data table
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? Center(child: Text(l.tr('noRowsFound')))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              hoverColor: Colors.transparent,
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                            child: DataTable(
                              showCheckboxColumn: true,
                              sortColumnIndex: _sortColumnIndex,
                              sortAscending: _sortAscending,
                              headingRowColor:
                                  WidgetStateProperty.resolveWith((_) =>
                                      Theme.of(context)
                                          .dataTableTheme
                                          .headingRowColor
                                          ?.resolve({}) ??
                                      Theme.of(context)
                                          .scaffoldBackgroundColor),
                              dataRowColor: Theme.of(context)
                                  .dataTableTheme
                                  .dataRowColor,
                              columns: [
                                DataColumn(
                                    label: _HoverHeader(text: l.tr('id')),
                                    onSort: _sort,
                                    numeric: true),
                                ..._columns.asMap().entries.map(
                                      (e) => DataColumn(
                                        label: _HoverHeader(
                                            text: e.value.columnName),
                                        onSort: _sort,
                                        numeric:
                                            e.value.columnType == 'INTEGER' ||
                                                e.value.columnType == 'REAL',
                                      ),
                                    ),
                                DataColumn(
                                    label: _HoverHeader(text: 'Created'),
                                    onSort: _sort),
                                DataColumn(label: Text(l.tr('actions'))),
                              ],
                              rows: _rows.map((row) {
                                final id = row['id'] as int;
                                final selected = _selectedIds.contains(id);
                                return DataRow(
                                  selected: selected,
                                  onSelectChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedIds.add(id);
                                      } else {
                                        _selectedIds.remove(id);
                                      }
                                    });
                                  },
                                  cells: [
                                    DataCell(Text('$id')),
                                    ..._columns.map((col) {
                                      final val = row[col.dbColumnName];
                                      if (col.columnType == 'BOOLEAN') {
                                        return DataCell(Icon(
                                          val == 1
                                              ? Icons.check
                                              : Icons.close,
                                          color: val == 1
                                              ? Colors.green
                                              : Colors.red,
                                          size: 18,
                                        ));
                                      }
                                      return DataCell(
                                          Text(val?.toString() ?? ''));
                                    }),
                                    DataCell(Text(_formatDate(
                                        DateTime.tryParse(
                                            row['created_at'] ?? '')))),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                size: 18),
                                            tooltip: l.tr('edit'),
                                            onPressed: () => _editRow(row),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                size: 18,
                                                color: Colors.red),
                                            tooltip: l.tr('delete'),
                                            onPressed: () =>
                                                _deleteRow(row),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),

          // Pagination
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l.tr('rowsPerPage')),
                DropdownButton<int>(
                  value: _pageSize,
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 25, child: Text('25')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                    DropdownMenuItem(value: 100, child: Text('100')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _pageSize = v ?? 25;
                      _currentPage = 0;
                    });
                    _loadRows();
                  },
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0
                      ? () {
                          setState(() => _currentPage--);
                          _loadRows();
                        }
                      : null,
                ),
                Text(
                    l.trArgs('pageOf', {'current': '${_currentPage + 1}', 'total': '${_totalPages < 1 ? 1 : _totalPages}'})),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < _totalPages - 1
                      ? () {
                          setState(() => _currentPage++);
                          _loadRows();
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sortable column header widget with hover color effect.
class _HoverHeader extends StatefulWidget {
  final String text;
  const _HoverHeader({required this.text});

  @override
  State<_HoverHeader> createState() => _HoverHeaderState();
}

class _HoverHeaderState extends State<_HoverHeader> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverColor = AppTheme.hoverColor(isDark);
    final normalColor = Theme.of(context).colorScheme.onSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        color: (!isDark && _hovering) ? hoverColor : Colors.transparent,
        child: Text(
          widget.text,
          style: TextStyle(
            color: isDark ? (_hovering ? hoverColor : normalColor) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
