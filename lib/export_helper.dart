import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart' as csv_lib;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'database_helper.dart';
import 'models.dart';

class ExportHelper {
  static String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('dd-MM-yyyy HH:mm:ss').format(dt);
  }

  // ─── CSV Export ───

  static Future<String?> exportMembersCsv(List<Member> members) async {
    final rows = <List<dynamic>>[
      ['ID', 'member number', 'name', 'email', 'communication', 'annual fee', 'notes', 'Created (Lisbon)'],
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
    return _saveCsvFile(rows, 'members_export.csv');
  }

  static Future<String?> exportDailyMembersCsv(List<DailyMember> members) async {
    final rows = <List<dynamic>>[
      ['ID', 'daily member number', 'name', 'notes', 'Created (Lisbon)'],
      ...members.map((m) => [
        m.id,
        m.dailyMemberNumber,
        m.name,
        m.notes,
        _formatDate(m.createdAt),
      ]),
    ];
    return _saveCsvFile(rows, 'daily_members_export.csv');
  }

  static Future<String?> _saveCsvFile(List<List<dynamic>> rows, String defaultName) async {
    final csvData = csv_lib.Csv().encode(rows);
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV file',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (outputPath == null) return null;

    final path = outputPath.endsWith('.csv') ? outputPath : '$outputPath.csv';
    final file = File(path);
    await file.writeAsString(csvData, encoding: utf8);
    return path;
  }

  // ─── CSV Import ───

  static Future<List<Map<String, dynamic>>?> pickAndParseCsv() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select CSV file',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) return null;

    final filePath = result.files.single.path;
    if (filePath == null) return null;

    final file = File(filePath);
    final content = await file.readAsString(encoding: utf8);
    final rows = csv_lib.Csv().decode(content);

    if (rows.length < 2) return null; // Need header + at least one data row

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    return rows.skip(1).map((row) {
      final map = <String, dynamic>{};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        map[headers[i]] = row[i];
      }
      return map;
    }).toList();
  }

  // ─── Whole Database Export/Import (JSON) ───

  static Future<String?> exportWholeDatabase() async {
    final members = await DatabaseHelper.instance.getAllMembers();
    final dailyMembers = await DatabaseHelper.instance.getAllDailyMembers();

    final data = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'members': members.map((m) => m.toMap()).toList(),
      'daily_members': dailyMembers.map((m) => m.toMap()).toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Database',
      fileName: 'bis_database_backup.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (outputPath == null) return null;

    final path = outputPath.endsWith('.json') ? outputPath : '$outputPath.json';
    final file = File(path);
    await file.writeAsString(jsonStr, encoding: utf8);
    return path;
  }

  static Future<Map<String, int>?> importWholeDatabase() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Database Backup',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;

    final filePath = result.files.single.path;
    if (filePath == null) return null;

    final file = File(filePath);
    final content = await file.readAsString(encoding: utf8);
    final data = jsonDecode(content) as Map<String, dynamic>;

    int membersImported = 0;
    int dailyMembersImported = 0;
    int errors = 0;

    // Import members
    final membersList = data['members'] as List<dynamic>? ?? [];
    for (final raw in membersList) {
      try {
        final map = Map<String, dynamic>.from(raw as Map);
        final member = Member.fromMap(map);
        await DatabaseHelper.instance.insertMember(member);
        membersImported++;
      } catch (_) {
        errors++;
      }
    }

    // Import daily members
    final dailyList = data['daily_members'] as List<dynamic>? ?? [];
    for (final raw in dailyList) {
      try {
        final map = Map<String, dynamic>.from(raw as Map);
        final dm = DailyMember.fromMap(map);
        await DatabaseHelper.instance.insertDailyMember(dm);
        dailyMembersImported++;
      } catch (_) {
        errors++;
      }
    }

    return {
      'members': membersImported,
      'daily_members': dailyMembersImported,
      'errors': errors,
    };
  }

  // ─── PDF Export ───

  static Future<String?> _savePdfFile(pw.Document pdf, String defaultName) async {
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF file',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (outputPath == null) return null;

    final path = outputPath.endsWith('.pdf') ? outputPath : '$outputPath.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    return path;
  }

  static Future<String?> exportMembersPdf(List<Member> members, {String title = 'Members'}) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());
    final totalPages = members.isEmpty ? 1 : (members.length / 28).ceil();

    // Column width ratios for: #, Name, Email, Comm., Fee, ID, Created
    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(0.8),  // #
      1: const pw.FlexColumnWidth(2.5),  // Name
      2: const pw.FlexColumnWidth(3.0),  // Email
      3: const pw.FlexColumnWidth(0.8),  // Comm.
      4: const pw.FlexColumnWidth(0.7),  // Fee
      5: const pw.FlexColumnWidth(0.6),  // ID
      6: const pw.FlexColumnWidth(2.2),  // Created
    };

    if (members.isEmpty) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Center(child: pw.Text('No records to export')),
      ));
    }

    const rowsPerPage = 28;
    for (int i = 0; i < members.length; i += rowsPerPage) {
      final pageMembers = members.skip(i).take(rowsPerPage).toList();
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
                    pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Exported: $dateStr', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text('Total: ${members.length} records', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                pw.SizedBox(height: 8),
                pw.Table(
                  columnWidths: columnWidths,
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: ['#', 'Name', 'Email', 'Comm.', 'Fee', 'ID', 'Created'].map((h) =>
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                          child: pw.Text(h, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        ),
                      ).toList(),
                    ),
                    // Data rows
                    ...pageMembers.map((m) => pw.TableRow(
                      children: [
                        '${m.memberNumber ?? ""}',
                        m.name,
                        m.email ?? '',
                        m.communication ? 'Yes' : 'No',
                        m.annualFee ? 'Yes' : 'No',
                        '${m.id}',
                        _formatDate(m.createdAt),
                      ].map((cell) =>
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
                          child: pw.Text(cell, style: const pw.TextStyle(fontSize: 6.5), maxLines: 1),
                        ),
                      ).toList(),
                    )),
                  ],
                ),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('Page $pageNum of $totalPages', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ),
              ],
            );
          },
        ),
      );
    }

    return _savePdfFile(pdf, 'members_export.pdf');
  }

  static Future<String?> exportDailyMembersPdf(List<DailyMember> members, {String title = 'Daily Members'}) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());
    final totalPages = members.isEmpty ? 1 : (members.length / 32).ceil();

    // Column width ratios for: Daily#, Name, Notes, ID, Created
    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(1.0),  // Daily #
      1: const pw.FlexColumnWidth(3.0),  // Name
      2: const pw.FlexColumnWidth(4.0),  // Notes
      3: const pw.FlexColumnWidth(0.7),  // ID
      4: const pw.FlexColumnWidth(2.2),  // Created
    };

    if (members.isEmpty) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Center(child: pw.Text('No records to export')),
      ));
    }

    const rowsPerPage = 32;
    for (int i = 0; i < members.length; i += rowsPerPage) {
      final pageMembers = members.skip(i).take(rowsPerPage).toList();
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
                    pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Exported: $dateStr', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text('Total: ${members.length} records', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                pw.SizedBox(height: 8),
                pw.Table(
                  columnWidths: columnWidths,
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: ['Daily #', 'Name', 'Notes', 'ID', 'Created'].map((h) =>
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                          child: pw.Text(h, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        ),
                      ).toList(),
                    ),
                    // Data rows
                    ...pageMembers.map((m) => pw.TableRow(
                      children: [
                        '${m.dailyMemberNumber ?? ""}',
                        m.name,
                        m.notes,
                        '${m.id}',
                        _formatDate(m.createdAt),
                      ].map((cell) =>
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
                          child: pw.Text(cell, style: const pw.TextStyle(fontSize: 6.5), maxLines: 2),
                        ),
                      ).toList(),
                    )),
                  ],
                ),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('Page $pageNum of $totalPages', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ),
              ],
            );
          },
        ),
      );
    }

    return _savePdfFile(pdf, 'daily_members_export.pdf');
  }
}
