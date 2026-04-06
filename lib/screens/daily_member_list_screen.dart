import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../models.dart';
import '../export_helper.dart';
import '../l10n.dart';
import '../theme.dart';

/// Screen that displays a paginated, sortable DataTable of all [DailyMember] records.
///
/// Supports multi-select, bulk delete, CSV/PDF export, and CSV import.
/// Unlike [MemberListScreen], this screen has no search bar.
class DailyMemberListScreen extends StatefulWidget {
  const DailyMemberListScreen({super.key});

  @override
  State<DailyMemberListScreen> createState() => _DailyMemberListScreenState();
}

/// State for [DailyMemberListScreen]. Manages pagination, sorting, and
/// row selection for the daily members DataTable.
class _DailyMemberListScreenState extends State<DailyMemberListScreen> {
  /// Current page of daily members returned from the database.
  List<DailyMember> _members = [];

  /// Total daily member count (for pagination calculation).
  int _totalCount = 0;

  /// Zero-based current page index.
  int _currentPage = 0;

  /// Number of rows per page.
  int _pageSize = 25;
  bool _loading = true;

  /// IDs of rows currently selected via checkboxes (for bulk actions).
  final Set<int> _selectedIds = {};

  /// Index of the DataColumn currently sorted (maps to [_columnDbNames]).
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  /// Database column name used in the ORDER BY clause.
  String _sortColumn = 'daily_member_number';

  /// Maps DataColumn display index to the corresponding DB column name.
  static const _columnDbNames = [
    'daily_member_number', 'name', 'notes', 'id', 'created_at',
  ];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  /// Fetches one page of daily members from the database using the current
  /// sort and pagination state. Clears selection after loading.
  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    final members = await DatabaseHelper.instance.getDailyMembers(
      limit: _pageSize,
      offset: _currentPage * _pageSize,
      orderBy: _sortColumn,
      ascending: _sortAscending,
    );
    final count = await DatabaseHelper.instance.getDailyMemberCount();
    setState(() {
      _members = members;
      _totalCount = count;
      _loading = false;
      _selectedIds.clear();
    });
  }

  int get _totalPages => (_totalCount / _pageSize).ceil();

  /// Callback for DataColumn.onSort — updates sort state and reloads from page 0.
  void _sort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _sortColumn = _columnDbNames[columnIndex];
      _currentPage = 0;
    });
    _loadMembers();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('dd-MM-yyyy HH:mm:ss').format(dt);
  }

  /// Exports daily members to a CSV file. Exports all records or only selected rows.
  Future<void> _exportCsv({bool allRecords = false}) async {
    final l = AppLocalizations.of(context);
    final List<DailyMember> toExport;
    if (allRecords) {
      toExport = await DatabaseHelper.instance.getAllDailyMembers();
    } else if (_selectedIds.isNotEmpty) {
      toExport =
          _members.where((m) => _selectedIds.contains(m.id)).toList();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.tr('noDailyMembersSelectedExport'))),
      );
      return;
    }

    final path = await ExportHelper.exportDailyMembersCsv(toExport);
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.trArgs('exportedDailyMembersCsv', {'count': '${toExport.length}', 'path': path}))),
      );
    }
  }

  /// Exports daily members to a PDF file. Exports all records or only selected rows.
  Future<void> _exportPdf({bool allRecords = false}) async {
    final l = AppLocalizations.of(context);
    final List<DailyMember> toExport;
    if (allRecords) {
      toExport = await DatabaseHelper.instance.getAllDailyMembers();
    } else if (_selectedIds.isNotEmpty) {
      toExport =
          _members.where((m) => _selectedIds.contains(m.id)).toList();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.tr('noDailyMembersSelectedExport'))),
      );
      return;
    }
    final path = await ExportHelper.exportDailyMembersPdf(toExport);
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.trArgs('pdfExported', {'path': path}))),
      );
    }
  }

  /// Opens a file picker for a CSV file, parses it, and upserts daily members.
  /// Shows a snackbar with created/updated/error counts.
  Future<void> _importCsv() async {
    final dataRows = await ExportHelper.pickAndParseCsv();
    if (dataRows == null) return;

    final counts =
        await DatabaseHelper.instance.importDailyMembersFromCsv(dataRows);

    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l.trArgs('csvImportResult', {'created': '${counts['created']}', 'updated': '${counts['updated']}', 'errors': '${counts['errors']}'}),
        ),
      ),
    );
    _loadMembers();
  }

  /// Deletes a single daily member after a confirmation dialog.
  Future<void> _deleteMember(DailyMember member) async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('deleteDailyMember')),
        content: Text(
          l.trArgs('deleteDailyMemberConfirm', {'name': member.name, 'number': '${member.dailyMemberNumber}'}),
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
      ),
    );

    if (confirm == true && member.id != null) {
      await DatabaseHelper.instance.deleteDailyMember(member.id!);
      _loadMembers();
    }
  }

  /// Deletes all currently selected daily members after a confirmation dialog.
  Future<void> _deleteSelected() async {
    final l = AppLocalizations.of(context);
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.tr('noDailyMembersSelected'))),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('deleteSelectedDailyMembers')),
        content: Text(l.trArgs('deleteSelectedDailyMembersConfirm', {'count': '${_selectedIds.length}'})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.tr('delete')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final count = await DatabaseHelper.instance.deleteDailyMembers(_selectedIds.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.trArgs('deletedDailyMembers', {'count': '$count'}))),
      );
      _loadMembers();
    }
  }

  /// Deletes every daily member in the database after a confirmation dialog.
  Future<void> _deleteAll() async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('deleteAllDailyMembers')),
        content: Text(l.tr('deleteAllDailyMembersConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.tr('deleteAll')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final count = await DatabaseHelper.instance.deleteAllDailyMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.trArgs('deletedDailyMembers', {'count': '$count'}))),
      );
      _loadMembers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('dailyMembers')),
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
                child: Text(l.tr('exportSelectedCsv')),
              ),
              PopupMenuItem(
                value: 'export_all',
                child: Text(l.tr('exportAllCsv')),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'pdf_selected',
                child: Text(l.tr('exportSelectedPdf')),
              ),
              PopupMenuItem(
                value: 'pdf_all',
                child: Text(l.tr('exportAllPdf')),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'import',
                child: Text(l.tr('importFromCsv')),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete_selected',
                child: Text(l.tr('deleteSelected'), style: const TextStyle(color: Colors.red)),
              ),
              PopupMenuItem(
                value: 'delete_all',
                child: Text(l.tr('deleteAllCaps'), style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/admin/daily-members/add');
          _loadMembers();
        },
        tooltip: l.tr('addDailyMemberTitle'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Results info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  l.trArgs('dailyMembersCount', {'count': '$_totalCount'}),
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                if (_selectedIds.isNotEmpty)
                  Text(
                    l.trArgs('selected', {'count': '${_selectedIds.length}'}),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Data table
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _members.isEmpty
                    ? Center(child: Text(l.tr('noDailyMembersFound')))
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
                            headingRowColor: WidgetStateProperty.resolveWith(
                              (_) => Theme.of(context).dataTableTheme.headingRowColor?.resolve({}) ?? Theme.of(context).scaffoldBackgroundColor,
                            ),
                            dataRowColor: Theme.of(context).dataTableTheme.dataRowColor,
                            columns: [
                              DataColumn(label: _HoverHeader(text: l.tr('dailyNumber')), onSort: _sort, numeric: true),
                              DataColumn(label: _HoverHeader(text: l.tr('name')), onSort: _sort),
                              DataColumn(label: _HoverHeader(text: l.tr('notes')), onSort: _sort),
                              DataColumn(label: _HoverHeader(text: l.tr('id')), onSort: _sort, numeric: true),
                              DataColumn(label: _HoverHeader(text: l.tr('createdLisbon')), onSort: _sort),
                              DataColumn(label: Text(l.tr('actions'))),
                            ],
                            rows: _members.map((m) {
                              final selected = _selectedIds.contains(m.id);
                              return DataRow(
                                selected: selected,
                                onSelectChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedIds.add(m.id!);
                                    } else {
                                      _selectedIds.remove(m.id);
                                    }
                                  });
                                },
                                cells: [
                                  DataCell(
                                    InkWell(
                                      onTap: () async {
                                        await Navigator.pushNamed(
                                          context,
                                          '/admin/daily-members/edit',
                                          arguments: m,
                                        );
                                        _loadMembers();
                                      },
                                      child: Text(
                                        '${m.dailyMemberNumber ?? ""}',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    InkWell(
                                      onTap: () async {
                                        await Navigator.pushNamed(
                                          context,
                                          '/admin/daily-members/edit',
                                          arguments: m,
                                        );
                                        _loadMembers();
                                      },
                                      child: Text(
                                        m.name,
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(m.notes)),
                                  DataCell(Text('${m.id}')),
                                  DataCell(Text(_formatDate(m.createdAt))),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              size: 18),
                                          tooltip: l.tr('edit'),
                                          onPressed: () async {
                                            await Navigator.pushNamed(
                                              context,
                                              '/admin/daily-members/edit',
                                              arguments: m,
                                            );
                                            _loadMembers();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              size: 18, color: Colors.red),
                                          tooltip: l.tr('delete'),
                                          onPressed: () =>
                                              _deleteMember(m),
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
                Text('${l.tr('rowsPerPage')}: '),
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
                    _loadMembers();
                  },
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0
                      ? () {
                          setState(() => _currentPage--);
                          _loadMembers();
                        }
                      : null,
                ),
                Text(l.trArgs('pageOf', {'current': '${_currentPage + 1}', 'total': '${_totalPages < 1 ? 1 : _totalPages}'})),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < _totalPages - 1
                      ? () {
                          setState(() => _currentPage++);
                          _loadMembers();
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

/// Form screen for creating or editing a [DailyMember].
///
/// When [member] is null the form is in "create" mode; otherwise it pre-fills
/// fields for editing the existing daily member.
class DailyMemberEditScreen extends StatefulWidget {
  final DailyMember? member;

  const DailyMemberEditScreen({super.key, this.member});

  @override
  State<DailyMemberEditScreen> createState() => _DailyMemberEditScreenState();
}

/// State for [DailyMemberEditScreen]. Holds form controllers and submission logic.
class _DailyMemberEditScreenState extends State<DailyMemberEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dailyNumberController;
  late TextEditingController _notesController;
  bool _isSubmitting = false;

  bool get _isNew => widget.member == null;
  DailyMember? get _member => widget.member;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _member?.name ?? '');
    _dailyNumberController = TextEditingController(
      text: _member?.dailyMemberNumber?.toString() ?? '',
    );
    _notesController = TextEditingController(text: _member?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dailyNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Validates the form, then inserts a new daily member or updates the existing one.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final l = AppLocalizations.of(context);
    setState(() => _isSubmitting = true);

    try {
      final dailyNumber = _dailyNumberController.text.trim().isNotEmpty
          ? int.tryParse(_dailyNumberController.text.trim())
          : null;

      if (_isNew) {
        final member = DailyMember(
          name: _nameController.text.trim(),
          notes: _notesController.text.trim(),
          dailyMemberNumber: dailyNumber,
        );
        await DatabaseHelper.instance.insertDailyMember(member);
      } else {
        final updated = _member!.copyWith(
          name: _nameController.text.trim(),
          notes: _notesController.text.trim(),
          dailyMemberNumber: dailyNumber ?? _member!.dailyMemberNumber,
        );
        await DatabaseHelper.instance.updateDailyMember(updated);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isNew ? l.tr('dailyMemberCreated') : l.tr('dailyMemberSaved')),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.trArgs('errorPrefix', {'error': '$e'}))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if member was passed as route argument
    final routeMember =
        ModalRoute.of(context)?.settings.arguments as DailyMember?;
    if (routeMember != null && _isNew) {
      return DailyMemberEditScreen(member: routeMember);
    }

    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l.tr('addDailyMemberTitle') : l.tr('editDailyMember')),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isNew) ...[
                    Text(
                      l.trArgs('dailyMemberInfo', {'number': '${_member!.dailyMemberNumber}', 'id': '${_member!.id}'}),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: InputDecoration(labelText: l.tr('name')),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? l.tr('nameRequired') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dailyNumberController,
                    decoration: InputDecoration(
                      labelText:
                          l.tr('dailyMemberNumberLabel'),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: l.tr('notesOptional'),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _save,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : Text(_isNew ? l.tr('create') : l.tr('save')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l.tr('cancel')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A DataColumn header label that highlights on mouse hover.
/// Uses [AppTheme.hoverColor] adapting to light/dark mode.
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
    final accent = AppTheme.hoverColor(isDark);
    final defaultColor = Theme.of(context).dataTableTheme.headingTextStyle?.color
        ?? Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        color: (!isDark && _hovering) ? accent : Colors.transparent,
        child: Text(
          widget.text,
          style: TextStyle(
            color: isDark ? (_hovering ? accent : defaultColor) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
