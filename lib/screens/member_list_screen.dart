import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../models.dart';
import '../export_helper.dart';
import '../l10n.dart';
import '../theme.dart';

/// Screen that displays a paginated, sortable DataTable of all [Member] records.
///
/// Supports server-side search (by name, email, or member number), multi-select,
/// bulk delete, CSV/PDF export, and CSV import.
class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

/// State for [MemberListScreen]. Manages pagination, sorting, search, and
/// row selection for the members DataTable.
class _MemberListScreenState extends State<MemberListScreen> {
  final _searchController = TextEditingController();

  /// Which DB column to filter on: 'name', 'email', or 'member_number'.
  String _searchBy = 'name';

  /// Current page of members returned from the database.
  List<Member> _members = [];

  /// Total matching member count (for pagination calculation).
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
  String _sortColumn = 'member_number';

  /// Maps DataColumn display index to the corresponding DB column name.
  static const _columnDbNames = [
    'member_number', 'name', 'email', 'communication', 'annual_fee', 'id', 'created_at',
  ];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches one page of members from the database using the current search,
  /// sort, and pagination state. Clears selection after loading.
  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    final search = _searchController.text.trim();
    final members = await DatabaseHelper.instance.getMembers(
      search: search.isEmpty ? null : search,
      searchBy: _searchBy,
      limit: _pageSize,
      offset: _currentPage * _pageSize,
      orderBy: _sortColumn,
      ascending: _sortAscending,
    );
    final count = await DatabaseHelper.instance.getMemberCount(
      search: search.isEmpty ? null : search,
      searchBy: _searchBy,
    );
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

  /// Exports members to a CSV file. Exports all records or only selected rows.
  Future<void> _exportCsv({bool allRecords = false}) async {
    final List<Member> toExport;
    if (allRecords) {
      toExport = await DatabaseHelper.instance.getAllMembers();
    } else if (_selectedIds.isNotEmpty) {
      toExport =
          _members.where((m) => _selectedIds.contains(m.id)).toList();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('noMembersSelectedExport'))),
      );
      return;
    }

    final path = await ExportHelper.exportMembersCsv(toExport);
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).trArgs('exportedMembersCsv', {'count': '${toExport.length}', 'path': path}))),
      );
    }
  }

  /// Exports members to a PDF file. Exports all records or only selected rows.
  Future<void> _exportPdf({bool allRecords = false}) async {
    final List<Member> toExport;
    if (allRecords) {
      toExport = await DatabaseHelper.instance.getAllMembers();
    } else if (_selectedIds.isNotEmpty) {
      toExport =
          _members.where((m) => _selectedIds.contains(m.id)).toList();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('noMembersSelectedExport'))),
      );
      return;
    }
    final path = await ExportHelper.exportMembersPdf(toExport);
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).trArgs('pdfExported', {'path': path}))),
      );
    }
  }

  /// Opens a file picker for a CSV file, parses it, and upserts members.
  /// Shows a snackbar with created/updated/error counts.
  Future<void> _importCsv() async {
    final dataRows = await ExportHelper.pickAndParseCsv();
    if (dataRows == null) return;

    final counts =
        await DatabaseHelper.instance.importMembersFromCsv(dataRows);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).trArgs('csvImportResult', {'created': '${counts['created']}', 'updated': '${counts['updated']}', 'errors': '${counts['errors']}'}),
        ),
      ),
    );
    _loadMembers();
  }

  /// Deletes a single member after a confirmation dialog.
  Future<void> _deleteMember(Member member) async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('deleteMember')),
        content: Text(l.trArgs('deleteMemberConfirm', {'name': member.name, 'number': '${member.memberNumber}'})),
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
      await DatabaseHelper.instance.deleteMember(member.id!);
      _loadMembers();
    }
  }

  /// Deletes all currently selected members after a confirmation dialog.
  Future<void> _deleteSelected() async {
    final l = AppLocalizations.of(context);
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.tr('noMembersSelected'))),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('deleteSelectedMembers')),
        content: Text(l.trArgs('deleteSelectedMembersConfirm', {'count': '${_selectedIds.length}'})),
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
      final count = await DatabaseHelper.instance.deleteMembers(_selectedIds.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.trArgs('deletedMembers', {'count': '$count'}))),
      );
      _loadMembers();
    }
  }

  /// Deletes every member in the database after a confirmation dialog.
  Future<void> _deleteAll() async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.tr('deleteAllMembers')),
        content: Text(l.tr('deleteAllMembersConfirm')),
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
      final count = await DatabaseHelper.instance.deleteAllMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.trArgs('deletedMembers', {'count': '$count'}))),
      );
      _loadMembers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('members')),
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
          await Navigator.pushNamed(context, '/admin/members/add');
          _loadMembers();
        },
        tooltip: l.tr('addMember'),
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
                      hintText: l.tr('searchMembers'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _currentPage = 0;
                                _loadMembers();
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) {
                      _currentPage = 0;
                      _loadMembers();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _searchBy,
                  items: [
                    DropdownMenuItem(value: 'name', child: Text(l.tr('name'))),
                    DropdownMenuItem(value: 'email', child: Text(l.tr('email'))),
                    DropdownMenuItem(
                      value: 'member_number',
                      child: Text(l.tr('memberNumber')),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _searchBy = v ?? 'name');
                    _currentPage = 0;
                    _loadMembers();
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    _currentPage = 0;
                    _loadMembers();
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
                  l.trArgs('membersCount', {'count': '$_totalCount'}),
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
          const Divider(),

          // Data table
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _members.isEmpty
                    ? Center(child: Text(l.tr('noMembersFound')))
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
                              DataColumn(label: _HoverHeader(text: l.tr('memberNumber')), onSort: _sort, numeric: true),
                              DataColumn(label: _HoverHeader(text: l.tr('name')), onSort: _sort),
                              DataColumn(label: _HoverHeader(text: l.tr('email')), onSort: _sort),
                              DataColumn(label: _HoverHeader(text: l.tr('communication')), onSort: _sort),
                              DataColumn(label: _HoverHeader(text: l.tr('fee')), onSort: _sort),
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
                                    Text(
                                      '${m.memberNumber ?? ""}',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    InkWell(
                                      onTap: () async {
                                        await Navigator.pushNamed(
                                          context,
                                          '/admin/members/edit',
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
                                  DataCell(Text(m.email ?? '')),
                                  DataCell(Icon(
                                    m.communication
                                        ? Icons.check
                                        : Icons.close,
                                    color: m.communication
                                        ? Colors.green
                                        : Colors.red,
                                    size: 18,
                                  )),
                                  DataCell(Icon(
                                    m.annualFee
                                        ? Icons.check
                                        : Icons.close,
                                    color: m.annualFee
                                        ? Colors.green
                                        : Colors.red,
                                    size: 18,
                                  )),
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
                                              '/admin/members/edit',
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

/// Form screen for creating or editing a [Member].
///
/// When [member] is null the form is in "create" mode; otherwise it pre-fills
/// fields for editing the existing member.
class MemberEditScreen extends StatefulWidget {
  final Member? member;

  const MemberEditScreen({super.key, this.member});

  @override
  State<MemberEditScreen> createState() => _MemberEditScreenState();
}

/// State for [MemberEditScreen]. Holds form controllers and submission logic.
class _MemberEditScreenState extends State<MemberEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _memberNumberController;
  late TextEditingController _notesController;
  late bool _communication;
  late bool _annualFee;
  bool _isSubmitting = false;

  bool get _isNew => widget.member == null;
  Member? get _member => widget.member;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _member?.name ?? '');
    _emailController = TextEditingController(text: _member?.email ?? '');
    _memberNumberController = TextEditingController(
      text: _member?.memberNumber?.toString() ?? '',
    );
    _notesController = TextEditingController(text: _member?.notes ?? '');
    _communication = _member?.communication ?? false;
    _annualFee = _member?.annualFee ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _memberNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Validates the form, then inserts a new member or updates the existing one.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final memberNumber = _memberNumberController.text.trim().isNotEmpty
          ? int.tryParse(_memberNumberController.text.trim())
          : null;

      if (_isNew) {
        final member = Member(
          name: _nameController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          communication: _communication,
          annualFee: _annualFee,
          notes: _notesController.text.trim(),
          memberNumber: memberNumber,
        );
        await DatabaseHelper.instance.insertMember(member);
      } else {
        final updated = _member!.copyWith(
          name: _nameController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          communication: _communication,
          annualFee: _annualFee,
          notes: _notesController.text.trim(),
          memberNumber: memberNumber ?? _member!.memberNumber,
        );
        await DatabaseHelper.instance.updateMember(updated);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isNew ? AppLocalizations.of(context).tr('memberCreated') : AppLocalizations.of(context).tr('memberSaved'))),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).trArgs('errorPrefix', {'error': '$e'}))),
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
        ModalRoute.of(context)?.settings.arguments as Member?;
    if (routeMember != null && _isNew) {
      // We got here via routing with arguments; build new screen
      return MemberEditScreen(member: routeMember);
    }

    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l.tr('addMember') : l.tr('editMember')),
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
                      l.trArgs('memberInfo', {'number': '${_member!.memberNumber}', 'id': '${_member!.id}'}),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: InputDecoration(labelText: l.tr('name')),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? l.tr('required') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration:
                        InputDecoration(labelText: l.tr('emailOptional')),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _memberNumberController,
                    decoration: InputDecoration(
                      labelText: l.tr('memberNumberLabel'),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: Text(l.tr('communicationLabel')),
                    value: _communication,
                    onChanged: (v) =>
                        setState(() => _communication = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    title: Text(l.tr('annualFeePaid')),
                    value: _annualFee,
                    onChanged: (v) =>
                        setState(() => _annualFee = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: l.tr('notes'),
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
