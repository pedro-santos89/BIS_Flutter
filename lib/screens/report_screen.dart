import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../l10n.dart';

/// Displays registration count reports for members and daily members
/// within a user-selected date range, with quick-range shortcut presets.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  /// Start of the report date range (defaults to today at midnight).
  DateTime _from = DateTime.now().copyWith(hour: 0, minute: 0, second: 0);

  /// End of the report date range (defaults to now).
  DateTime _to = DateTime.now();
  bool _loading = false;

  /// Per-date registration counts for members and daily members.
  List<Map<String, dynamic>> _memberReport = [];
  List<Map<String, dynamic>> _dailyMemberReport = [];

  /// Aggregated totals across the selected date range.
  int _memberTotal = 0;
  int _dailyMemberTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  /// Fetches registration reports for both members and daily members
  /// from the database for the current [_from]..[_to] range.
  Future<void> _loadReport() async {
    setState(() => _loading = true);
    final memberData = await DatabaseHelper.instance.getRegistrationReport(
      table: 'members',
      from: _from,
      to: _to,
    );
    final dailyData = await DatabaseHelper.instance.getRegistrationReport(
      table: 'daily_members',
      from: _from,
      to: _to,
    );
    setState(() {
      _memberReport = memberData;
      _dailyMemberReport = dailyData;
      _memberTotal = memberData.fold<int>(
        0,
        (sum, row) => sum + (row['count'] as int? ?? 0),
      );
      _dailyMemberTotal = dailyData.fold<int>(
        0,
        (sum, row) => sum + (row['count'] as int? ?? 0),
      );
      _loading = false;
    });
  }

  /// Opens a date picker to update either the start or end of the range.
  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFmt = DateFormat('dd-MM-yyyy');
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('registrationsReport'),
            style: const TextStyle(fontFamily: 'Oswald')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date range picker row
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text('${l.tr('period')}: ',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontFamily: 'Oswald',
                                fontWeight: FontWeight.w600,
                              )),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(dateFmt.format(_from)),
                            onPressed: () => _pickDate(true),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(l.tr('to'),
                                style: theme.textTheme.bodyMedium),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(dateFmt.format(_to)),
                            onPressed: () => _pickDate(false),
                          ),
                          const SizedBox(width: 12),
                          // Quick presets
                          PopupMenuButton<String>(
                            tooltip: l.tr('quickRange'),
                            icon: const Icon(Icons.tune, size: 20),
                            onSelected: (value) {
                              final now = DateTime.now();
                              setState(() {
                                switch (value) {
                                  case 'today':
                                    _from = DateTime(now.year, now.month, now.day);
                                    _to = now;
                                  case 'week':
                                    _from = now.subtract(const Duration(days: 7));
                                    _to = now;
                                  case 'month':
                                    _from = DateTime(now.year, now.month, 1);
                                    _to = now;
                                  case 'year':
                                    _from = DateTime(now.year, 1, 1);
                                    _to = now;
                                  case 'all':
                                    _from = DateTime(2020);
                                    _to = now;
                                }
                              });
                              _loadReport();
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'today', child: Text(l.tr('today'))),
                              PopupMenuItem(value: 'week', child: Text(l.tr('last7Days'))),
                              PopupMenuItem(value: 'month', child: Text(l.tr('thisMonth'))),
                              PopupMenuItem(value: 'year', child: Text(l.tr('thisYear'))),
                              PopupMenuItem(value: 'all', child: Text(l.tr('allTime'))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Members report
                  _buildReportSection(
                    l: l,
                    theme: theme,
                    isDark: isDark,
                    title: l.tr('members'),
                    total: _memberTotal,
                    data: _memberReport,
                  ),
                  const SizedBox(height: 24),

                  // Daily members report
                  _buildReportSection(
                    l: l,
                    theme: theme,
                    isDark: isDark,
                    title: l.tr('dailyMembers'),
                    total: _dailyMemberTotal,
                    data: _dailyMemberReport,
                  ),
                ],
              ),
            ),
    );
  }

  /// Builds a titled section showing a DataTable of date/count rows
  /// for a given report category (members or daily members).
  Widget _buildReportSection({
    required AppLocalizations l,
    required ThemeData theme,
    required bool isDark,
    required String title,
    required int total,
    required List<Map<String, dynamic>> data,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.trArgs('registrationsTitle', {'title': title, 'total': '$total'}),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFamily: 'Oswald',
          ),
        ),
        const SizedBox(height: 8),
        if (data.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.tr('noRegistrations'),
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          Card(
            child: DataTable(
              columns: [
                DataColumn(label: Text(l.tr('date'))),
                DataColumn(label: Text(l.tr('newRegistrations')), numeric: true),
              ],
              rows: data.map((row) {
                return DataRow(
                  cells: [
                    DataCell(Text(row['date']?.toString() ?? '')),
                    DataCell(Text('${row['count']}')),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
