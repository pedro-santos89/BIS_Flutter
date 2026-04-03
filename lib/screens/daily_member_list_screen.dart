import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../models.dart';
import '../export_helper.dart';
import '../theme.dart';

class DailyMemberListScreen extends StatefulWidget {
  const DailyMemberListScreen({super.key});

  @override
  State<DailyMemberListScreen> createState() => _DailyMemberListScreenState();
}

class _DailyMemberListScreenState extends State<DailyMemberListScreen> {
  List<DailyMember> _members = [];
  int _totalCount = 0;
  int _currentPage = 0;
  int _pageSize = 25;
  bool _loading = true;
  final Set<int> _selectedIds = {};
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    final members = await DatabaseHelper.instance.getDailyMembers(
      limit: _pageSize,
      offset: _currentPage * _pageSize,
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

  void _sort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _members.sort((a, b) {
        Comparable aVal, bVal;
        switch (columnIndex) {
          case 0: aVal = a.dailyMemberNumber ?? 0; bVal = b.dailyMemberNumber ?? 0;
          case 1: aVal = a.name.toLowerCase(); bVal = b.name.toLowerCase();
          case 2: aVal = a.notes.toLowerCase(); bVal = b.notes.toLowerCase();
          case 3: aVal = a.id ?? 0; bVal = b.id ?? 0;
          case 4: aVal = a.createdAt ?? DateTime(1970); bVal = b.createdAt ?? DateTime(1970);
          default: aVal = a.id ?? 0; bVal = b.id ?? 0;
        }
        return ascending ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
      });
    });
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('dd-MM-yyyy HH:mm:ss').format(dt);
  }

  Future<void> _exportCsv({bool allRecords = false}) async {
    final List<DailyMember> toExport;
    if (allRecords) {
      toExport = await DatabaseHelper.instance.getAllDailyMembers();
    } else if (_selectedIds.isNotEmpty) {
      toExport =
          _members.where((m) => _selectedIds.contains(m.id)).toList();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No daily members selected for export')),
      );
      return;
    }

    final path = await ExportHelper.exportDailyMembersCsv(toExport);
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${toExport.length} daily members to $path')),
      );
    }
  }

  Future<void> _exportPdf({bool allRecords = false}) async {
    final List<DailyMember> toExport;
    if (allRecords) {
      toExport = await DatabaseHelper.instance.getAllDailyMembers();
    } else if (_selectedIds.isNotEmpty) {
      toExport =
          _members.where((m) => _selectedIds.contains(m.id)).toList();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No daily members selected for export')),
      );
      return;
    }
    final path = await ExportHelper.exportDailyMembersPdf(toExport);
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF exported to $path')),
      );
    }
  }

  Future<void> _importCsv() async {
    final dataRows = await ExportHelper.pickAndParseCsv();
    if (dataRows == null) return;

    final counts =
        await DatabaseHelper.instance.importDailyMembersFromCsv(dataRows);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'CSV import: ${counts['created']} created, ${counts['updated']} updated, ${counts['errors']} errors',
        ),
      ),
    );
    _loadMembers();
  }

  Future<void> _deleteMember(DailyMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Daily Member'),
        content: Text(
          'Delete "${member.name}" (Daily #${member.dailyMemberNumber})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && member.id != null) {
      await DatabaseHelper.instance.deleteDailyMember(member.id!);
      _loadMembers();
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No daily members selected')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Daily Members'),
        content: Text('Delete ${_selectedIds.length} selected daily member(s)? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final count = await DatabaseHelper.instance.deleteDailyMembers(_selectedIds.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $count daily member(s)')),
      );
      _loadMembers();
    }
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete ALL Daily Members'),
        content: const Text('This will permanently delete ALL daily members from the database. This cannot be undone.\n\nAre you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final count = await DatabaseHelper.instance.deleteAllDailyMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $count daily member(s)')),
      );
      _loadMembers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Members'),
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
              const PopupMenuItem(
                value: 'export_selected',
                child: Text('Export selected to CSV'),
              ),
              const PopupMenuItem(
                value: 'export_all',
                child: Text('Export ALL to CSV'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'pdf_selected',
                child: Text('Export selected to PDF'),
              ),
              const PopupMenuItem(
                value: 'pdf_all',
                child: Text('Export ALL to PDF'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'import',
                child: Text('Import from CSV'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete_selected',
                child: Text('Delete selected', style: TextStyle(color: Colors.red)),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: Text('Delete ALL', style: TextStyle(color: Colors.red)),
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
        tooltip: 'Add Daily Member',
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
                  '$_totalCount daily member${_totalCount != 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                if (_selectedIds.isNotEmpty)
                  Text(
                    '${_selectedIds.length} selected',
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
                    ? const Center(child: Text('No daily members found'))
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
                              DataColumn(label: _HoverHeader(text: 'Daily #'), onSort: _sort, numeric: true),
                              DataColumn(label: _HoverHeader(text: 'Name'), onSort: _sort),
                              DataColumn(label: _HoverHeader(text: 'Notes'), onSort: _sort),
                              DataColumn(label: _HoverHeader(text: 'ID'), onSort: _sort, numeric: true),
                              DataColumn(label: _HoverHeader(text: 'Created (Lisbon)'), onSort: _sort),
                              const DataColumn(label: Text('Actions')),
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
                                          tooltip: 'Edit',
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
                                          tooltip: 'Delete',
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
                const Text('Rows per page: '),
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
                Text('Page ${_currentPage + 1} of ${_totalPages < 1 ? 1 : _totalPages}'),
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

class DailyMemberEditScreen extends StatefulWidget {
  final DailyMember? member;

  const DailyMemberEditScreen({super.key, this.member});

  @override
  State<DailyMemberEditScreen> createState() => _DailyMemberEditScreenState();
}

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

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
          content: Text(_isNew ? 'Daily member created' : 'Daily member saved'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add Daily Member' : 'Edit Daily Member'),
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
                      'Daily #${_member!.dailyMemberNumber} (ID: ${_member!.id})',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dailyNumberController,
                    decoration: const InputDecoration(
                      labelText:
                          'Daily member number (auto-assigned if empty)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
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
                              : Text(_isNew ? 'Create' : 'Save'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
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
