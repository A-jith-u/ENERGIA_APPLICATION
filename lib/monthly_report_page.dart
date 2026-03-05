import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'dart:io' show File, Platform, Directory;
import 'package:path_provider/path_provider.dart';
import 'services/api.dart';

/// API endpoint candidates - same pattern as api.dart
const String _envBase = String.fromEnvironment('ENERGIA_API_BASE');
final List<String> _apiCandidates = [
  if (_envBase.isNotEmpty) _envBase,
  'http://10.0.2.2:5000',
  'http://192.168.160.1:5000',
  'http://localhost:5000',
  'http://127.0.0.1:5000',
];

class MonthlyReportPage extends StatefulWidget {
  const MonthlyReportPage({super.key});

  @override
  State<MonthlyReportPage> createState() => _MonthlyReportPageState();
}

class _MonthlyReportPageState extends State<MonthlyReportPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _reportData;
  String? _error;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    Exception? lastError;
    
    for (final base in _apiCandidates) {
      try {
        final uri = Uri.parse('$base/reports/monthly-report?month=$_selectedMonth&year=$_selectedYear');
        print('[MonthlyReport] Trying: $uri');
        
        final response = await http.get(uri).timeout(const Duration(seconds: 10));
        print('[MonthlyReport] Response from $base: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _reportData = data;
            _isLoading = false;
            _error = null;
          });
          print('[MonthlyReport] Successfully loaded report');
          return;
        } else if (response.statusCode >= 500) {
          print('[MonthlyReport] Backend error: ${response.statusCode}');
          lastError = Exception('Backend error: ${response.statusCode}');
          continue;
        } else {
          print('[MonthlyReport] HTTP error: ${response.statusCode}');
          lastError = Exception('Failed to load report: ${response.statusCode}');
          continue;
        }
      } catch (e) {
        print('[MonthlyReport] Connection error with $base: $e');
        lastError = e as Exception;
        continue;
      }
    }
    
    setState(() {
      _error = 'Unable to connect to backend. Please check your connection.\nError: ${lastError.toString()}';
      _isLoading = false;
    });
    print('[MonthlyReport] All candidates failed. Last error: $lastError');
  }

  String _reportFileName() => 'Monthly_Report_${_reportData!['report_period']['month_name']}_${_reportData!['report_period']['year']}.pdf';

  Future<Directory?> _resolveDownloadsDir() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (dirs != null && dirs.isNotEmpty) return dirs.first;
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isIOS) {
      return getDownloadsDirectory();
    }
    return null;
  }

  Future<Uint8List> _buildReportPdfBytes() async {
    final pdf = pw.Document();
    final period = _reportData!['report_period'];
    final stats = _reportData!['overall_statistics'];
    final departments = (_reportData!['department_breakdown'] as List?) ?? [];
    final recommendations = (_reportData!['recommendations'] as List?) ?? [];
    final peakEvents = (_reportData!['peak_usage_analysis']?['top_peak_events'] as List?) ?? [];
    final sensorStatus = _reportData!['sensor_status'] ?? {};
    final change = _reportData!['month_over_month_change'];
    final accent = PdfColors.indigo900;

    pw.Widget _headerLine(String left, String right) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(left, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: accent)),
            pw.Text(right, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          ],
        );

    pw.Widget _metricsTable() {
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        columnWidths: const {
          0: pw.FlexColumnWidth(2),
          1: pw.FlexColumnWidth(1.3),
          2: pw.FlexColumnWidth(1.3),
          3: pw.FlexColumnWidth(1.3),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Metric', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Unit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ],
          ),
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total Energy')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(stats['total_energy'].toStringAsFixed(2))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('kWh')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Aggregated for period')),
          ]),
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Average Power')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(stats['avg_power'].toStringAsFixed(2))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('W')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Mean across all sensors')),
          ]),
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Peak Power')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(stats['peak_power'].toStringAsFixed(2))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('W')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Highest recorded')),
          ]),
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Active Sensors')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${stats['active_sensors']}')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('count')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Reporting during period')),
          ]),
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Power Factor')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(stats['avg_power_factor'].toStringAsFixed(3))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('pf')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Average efficiency')), 
          ]),
        ],
      );
    }

    pw.Widget _peakTable() {
      if (peakEvents.isEmpty) {
        return pw.Text('No peak events recorded in this period.', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 11));
      }
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        columnWidths: const {
          0: pw.FlexColumnWidth(2),
          1: pw.FlexColumnWidth(1.2),
          2: pw.FlexColumnWidth(1.2),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Device / Location', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Power (W)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ],
          ),
          ...peakEvents.take(6).map((e) => pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${e['device_id']}')),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(e['power'].toStringAsFixed(2))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Peak incident')),
                ],
              )),
        ],
      );
    }

    pw.Widget _recommendationsList() {
      if (recommendations.isEmpty) {
        return pw.Text('No recommendations recorded for this period.', style: const pw.TextStyle(color: PdfColors.grey700));
      }
      return pw.Column(
        children: recommendations.take(6).map((rec) {
          final color = rec['priority'] == 'high'
              ? PdfColors.red700
              : rec['priority'] == 'medium'
                  ? PdfColors.orange700
                  : PdfColors.green700;
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(color: color, width: 3)),
              color: PdfColors.grey50,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(rec['title'], style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
                pw.SizedBox(height: 4),
                pw.Text(rec['description'], style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 3),
                pw.Text('Action: ${rec['action']}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue900)),
              ],
            ),
          );
        }).toList(),
      );
    }

    pw.Widget _systemHealthBlock() {
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Health Metric', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ],
          ),
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Active Sensors')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${sensorStatus['active_sensors'] ?? '-'}')),
          ]),
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Inactive Sensors')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${sensorStatus['inactive_sensors'] ?? '-'}')),
          ]),
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total Readings')),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${stats['total_readings']}')),
          ]),
        ],
      );
    }

    pw.Widget _signOff() {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          color: PdfColors.grey50,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Prepared by: _______________________', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 6),
            pw.Text('Reviewed by: _______________________', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 6),
            pw.Text('Date: ______________________________', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      );
    }

    // Cover page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (_) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('GECI ENERGIA', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: accent)),
                pw.SizedBox(height: 12),
                pw.Text('Monthly Energy Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 24),
                pw.Text('${period['month_name']} ${period['year']}', style: pw.TextStyle(fontSize: 16, color: PdfColors.grey800)),
                pw.SizedBox(height: 8),
                pw.Text('Generated: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                pw.SizedBox(height: 30),
                pw.Container(width: 120, height: 2, color: accent),
                pw.SizedBox(height: 6),
                pw.Text('Confidential – Internal Use Only', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
          );
        },
      ),
    );

    // Content pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        header: (ctx) => _headerLine('Monthly Energy Report', '${period['month_name']} ${period['year']}'),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          pw.Text('Executive Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: accent)),
          pw.SizedBox(height: 8),
          _metricsTable(),
          pw.SizedBox(height: 16),
          pw.Text('Month-over-Month Change', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _buildPdfComparison(),
          pw.SizedBox(height: 16),
          pw.Text('Department Consumption Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _buildPdfDepartmentTable(),
          pw.SizedBox(height: 16),
          pw.Text('Peak Usage & Incidents', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _peakTable(),
          pw.SizedBox(height: 16),
          pw.Text('Recommendations', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _recommendationsList(),
          pw.SizedBox(height: 16),
          pw.Text('System Health', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _systemHealthBlock(),
          pw.SizedBox(height: 18),
          pw.Text('Sign-off', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _signOff(),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _generatePDF() async {
    if (_reportData == null) return;
    final bytes = await _buildReportPdfBytes();
    await Printing.sharePdf(bytes: bytes, filename: _reportFileName());
  }

  Future<void> _downloadPDF() async {
    if (_reportData == null) return;
    final bytes = await _buildReportPdfBytes();
    final dir = await _resolveDownloadsDir();

    if (dir == null) {
      await Printing.sharePdf(bytes: bytes, filename: _reportFileName());
      return;
    }

    final outPath = '${dir.path}/${_reportFileName()}';
    final file = File(outPath);
    await file.writeAsBytes(bytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to $outPath')),
      );
    }
  }

  pw.Widget _buildPdfStatGrid() {
    final stats = _reportData!['overall_statistics'];
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfStatItem('Total Energy', '${stats['total_energy'].toStringAsFixed(2)} kWh'),
              _buildPdfStatItem('Active Sensors', '${stats['active_sensors']}'),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfStatItem('Average Power', '${stats['avg_power'].toStringAsFixed(2)} W'),
              _buildPdfStatItem('Peak Power', '${stats['peak_power'].toStringAsFixed(2)} W'),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfStatItem('Avg Voltage', '${stats['avg_voltage'].toStringAsFixed(2)} V'),
              _buildPdfStatItem('Power Factor', '${stats['avg_power_factor'].toStringAsFixed(3)}'),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfStatItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _buildPdfComparison() {
    final change = _reportData!['month_over_month_change'];
    final isIncrease = change > 0;
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: isIncrease ? PdfColors.red50 : PdfColors.green50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            isIncrease ? '↑' : '↓',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: isIncrease ? PdfColors.red700 : PdfColors.green700,
            ),
          ),
          pw.SizedBox(width: 15),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${change.abs().toStringAsFixed(1)}% ${isIncrease ? 'Increase' : 'Decrease'}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Compared to previous month',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfDepartmentTable() {
    final departments = _reportData!['department_breakdown'] as List;
    
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue700),
          children: [
            _buildPdfTableCell('Department', isHeader: true),
            _buildPdfTableCell('Energy (kWh)', isHeader: true),
            _buildPdfTableCell('Avg Power (W)', isHeader: true),
            _buildPdfTableCell('Peak (W)', isHeader: true),
          ],
        ),
        // Rows
        ...departments.take(6).map((dept) => pw.TableRow(
          children: [
            _buildPdfTableCell(dept['department']),
            _buildPdfTableCell(dept['total_energy'].toStringAsFixed(2)),
            _buildPdfTableCell(dept['avg_power'].toStringAsFixed(2)),
            _buildPdfTableCell(dept['peak_power'].toStringAsFixed(2)),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildPdfTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget _buildPdfPeakAnalysis() {
    final peakEvents = _reportData!['peak_usage_analysis']['top_peak_events'] as List;
    
    if (peakEvents.isEmpty) {
      return pw.Text('No peak events recorded', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600));
    }
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Top 5 Peak Power Events:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        ...peakEvents.take(5).map((event) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 4),
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(event['device_id'], style: const pw.TextStyle(fontSize: 9)),
              pw.Text('${event['power'].toStringAsFixed(2)} W', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        )),
      ],
    );
  }

  pw.Widget _buildPdfRecommendations() {
    final recommendations = _reportData!['recommendations'] as List;
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: recommendations.take(5).map((rec) {
        PdfColor priorityColor = PdfColors.blue;
        if (rec['priority'] == 'high') priorityColor = PdfColors.red;
        if (rec['priority'] == 'medium') priorityColor = PdfColors.orange;
        
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: priorityColor, width: 3)),
            color: PdfColors.grey50,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: priorityColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Text(
                      rec['priority'].toUpperCase(),
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.white),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Text(
                      rec['title'],
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(rec['description'], style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 3),
              pw.Text('Action: ${rec['action']}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _buildPdfSystemHealth() {
    final sensorStatus = _reportData!['sensor_status'];
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildPdfHealthItem('Active Sensors', '${sensorStatus['active_sensors']}', PdfColors.green),
          _buildPdfHealthItem('Inactive Sensors', '${sensorStatus['inactive_sensors']}', PdfColors.orange),
          _buildPdfHealthItem('Total Readings', '${_reportData!['overall_statistics']['total_readings']}', PdfColors.blue),
        ],
      ),
    );
  }

  pw.Widget _buildPdfHealthItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
        pw.SizedBox(height: 2),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Energy Report'),
        actions: [
          if (_reportData != null)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Save PDF',
              onPressed: _downloadPDF,
            ),
          if (_reportData != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Download PDF',
              onPressed: _generatePDF,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReport,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildReportContent(),
    );
  }

  Widget _buildReportContent() {
    if (_reportData == null) return const SizedBox();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Report Header Card
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Energy Report',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_reportData!['report_period']['month_name']} ${_reportData!['report_period']['year']}',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Month selector
                        DropdownButton<int>(
                          value: _selectedMonth,
                          items: List.generate(12, (index) {
                            return DropdownMenuItem(
                              value: index + 1,
                              child: Text(DateFormat.MMMM().format(DateTime(2000, index + 1))),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedMonth = value);
                              _loadReport();
                            }
                          },
                        ),
                        DropdownButton<int>(
                          value: _selectedYear,
                          items: List.generate(5, (index) {
                            final year = DateTime.now().year - index;
                            return DropdownMenuItem(
                              value: year,
                              child: Text('$year'),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedYear = value);
                              _loadReport();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Save PDF'),
                      onPressed: _reportData == null ? null : _downloadPDF,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Share/Print PDF'),
                      onPressed: _reportData == null ? null : _generatePDF,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Overall Statistics
        _buildStatisticsGrid(),
        
        const SizedBox(height: 20),
        
        // Month-over-Month Comparison
        _buildComparisonCard(),
        
        const SizedBox(height: 20),
        
        // Daily Trends Chart
        _buildDailyTrendsChart(),
        
        const SizedBox(height: 20),
        
        // Department Breakdown
        _buildDepartmentBreakdown(),
        
        const SizedBox(height: 20),
        
        // Hourly Pattern Chart
        _buildHourlyPatternChart(),
        
        const SizedBox(height: 20),
        
        // Recommendations
        _buildRecommendations(),
        
        const SizedBox(height: 20),
        
        // System Health
        _buildSystemHealth(),
        
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStatisticsGrid() {
    final stats = _reportData!['overall_statistics'];
    
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Total Energy', '${stats['total_energy'].toStringAsFixed(2)} kWh', Icons.energy_savings_leaf, Colors.green),
        _buildStatCard('Active Sensors', '${stats['active_sensors']}', Icons.sensors, Colors.blue),
        _buildStatCard('Total Readings', '${stats['total_readings']}', Icons.timeline, Colors.purple),
        _buildStatCard('Avg Power', '${stats['avg_power'].toStringAsFixed(2)} W', Icons.bolt, Colors.orange),
        _buildStatCard('Peak Power', '${stats['peak_power'].toStringAsFixed(2)} W', Icons.trending_up, Colors.red),
        _buildStatCard('Power Factor', '${stats['avg_power_factor'].toStringAsFixed(3)}', Icons.speed, Colors.teal),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard() {
    final change = _reportData!['month_over_month_change'];
    final isIncrease = change > 0;
    
    return Card(
      elevation: 2,
      color: isIncrease ? Colors.red.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              isIncrease ? Icons.trending_up : Icons.trending_down,
              size: 48,
              color: isIncrease ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${change.abs().toStringAsFixed(1)}% ${isIncrease ? 'Increase' : 'Decrease'}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isIncrease ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Compared to previous month',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTrendsChart() {
    final trends = _reportData!['daily_trends'] as List;
    
    if (trends.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No daily trend data available'),
        ),
      );
    }
    
    final spots = trends.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value['daily_energy'].toDouble());
    }).toList();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Energy Consumption Trends',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      axisNameWidget: const Text('Energy (kWh)', style: TextStyle(fontSize: 12)),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < trends.length) {
                            final date = DateTime.parse(trends[value.toInt()]['date']);
                            return Text('${date.day}', style: const TextStyle(fontSize: 10));
                          }
                          return const Text('');
                        },
                      ),
                      axisNameWidget: const Text('Day of Month', style: TextStyle(fontSize: 12)),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentBreakdown() {
    final departments = _reportData!['department_breakdown'] as List;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Department-wise Breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Energy (kWh)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Avg Power (W)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Peak (W)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Sensors', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: departments.map((dept) {
                  return DataRow(cells: [
                    DataCell(Text(dept['department'])),
                    DataCell(Text(dept['total_energy'].toStringAsFixed(2))),
                    DataCell(Text(dept['avg_power'].toStringAsFixed(2))),
                    DataCell(Text(dept['peak_power'].toStringAsFixed(2))),
                    DataCell(Text('${dept['sensor_count']}')),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyPatternChart() {
    final hourlyPattern = _reportData!['peak_usage_analysis']['hourly_pattern'] as List;
    
    if (hourlyPattern.isEmpty) {
      return const SizedBox();
    }
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hourly Usage Pattern',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: hourlyPattern.map((h) => h['avg_power'].toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      axisNameWidget: const Text('Power (W)', style: TextStyle(fontSize: 12)),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < hourlyPattern.length) {
                            return Text('${hourlyPattern[value.toInt()]['hour']}h', style: const TextStyle(fontSize: 9));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                  barGroups: hourlyPattern.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value['avg_power'].toDouble(),
                          color: Colors.orange,
                          width: 12,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations() {
    final recommendations = _reportData!['recommendations'] as List;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.orange.shade700, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Recommendations for Improvement',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...recommendations.map((rec) => _buildRecommendationCard(rec)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> recommendation) {
    Color priorityColor = Colors.blue;
    if (recommendation['priority'] == 'high') priorityColor = Colors.red;
    if (recommendation['priority'] == 'medium') priorityColor = Colors.orange;
    if (recommendation['priority'] == 'low') priorityColor = Colors.green;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: priorityColor, width: 4)),
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    recommendation['priority'].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation['title'],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              recommendation['description'],
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.arrow_forward, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Action: ${recommendation['action']}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemHealth() {
    final sensorStatus = _reportData!['sensor_status'];
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Health Status',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHealthIndicator(
                  'Active Sensors',
                  '${sensorStatus['active_sensors']}',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildHealthIndicator(
                  'Inactive Sensors',
                  '${sensorStatus['inactive_sensors']}',
                  Icons.warning,
                  Colors.orange,
                ),
                _buildHealthIndicator(
                  'Total Readings',
                  '${_reportData!['overall_statistics']['total_readings']}',
                  Icons.article,
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIndicator(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 48, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }
}
