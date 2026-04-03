import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database_helper.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime _from = DateTime.now().copyWith(hour: 0, minute: 0, second: 0);
  DateTime _to = DateTime.now();
  bool _loading = false;

  List<Map<String, dynamic>> _memberReport = [];
  List<Map<String, dynamic>> _dailyMemberReport = [];
  int _memberTotal = 0;
  int _dailyMemberTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

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

    return Scaffold(
      appBar: AppBar(
        title: Text('Registrations Report',
            style: GoogleFonts.oswald()),
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
                          Text('Period: ',
                              style: GoogleFonts.oswald(
                                textStyle: theme.textTheme.bodyLarge,
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
                            child: Text('to',
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
                            tooltip: 'Quick range',
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
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'today', child: Text('Today')),
                              PopupMenuItem(value: 'week', child: Text('Last 7 days')),
                              PopupMenuItem(value: 'month', child: Text('This month')),
                              PopupMenuItem(value: 'year', child: Text('This year')),
                              PopupMenuItem(value: 'all', child: Text('All time')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Members report
                  _buildReportSection(
                    theme: theme,
                    isDark: isDark,
                    title: 'Members',
                    total: _memberTotal,
                    data: _memberReport,
                  ),
                  const SizedBox(height: 24),

                  // Daily members report
                  _buildReportSection(
                    theme: theme,
                    isDark: isDark,
                    title: 'Daily Members',
                    total: _dailyMemberTotal,
                    data: _dailyMemberReport,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildReportSection({
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
          '$title — $total new registration${total != 1 ? 's' : ''}',
          style: GoogleFonts.oswald(
            textStyle: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        if (data.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No registrations in this period.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          Card(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('New Registrations'), numeric: true),
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
