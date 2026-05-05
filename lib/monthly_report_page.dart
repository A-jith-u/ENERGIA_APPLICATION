import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class MonthlyReportPage extends StatefulWidget {
  final String reportType;
  final bool autoDownload;

  const MonthlyReportPage({
    Key? key,
    this.reportType = 'simple',
    this.autoDownload = false,
  }) : super(key: key);

  @override
  State<MonthlyReportPage> createState() => _MonthlyReportPageState();
}

class _MonthlyReportPageState extends State<MonthlyReportPage> {
  late Map<String, dynamic>? _reportData;
  bool _isLoading = true;
  String? _error;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final List<String> _apiCandidates = [
    'http://localhost:5000',
    'http://127.0.0.1:5000',
  ];

  @override
  void initState() {
    super.initState();
    _reportData = null;
    _loadReport();
  }

  Future<void> _loadReport() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    Exception? lastError;

    for (final base in _apiCandidates) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token') ?? '';
        final headers = {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        };

        final uri = Uri.parse(
          '$base/reports/monthly-report?month=$_selectedMonth&year=$_selectedYear&report_type=${widget.reportType}',
        );

        final response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = _parseJsonHelper(response.body);

          if (mounted) {
            setState(() {
              _reportData = data;
              _isLoading = false;
            });

            if (widget.autoDownload && mounted) {
              _downloadPDF();
            }
          }
          return;
        }
      } catch (e) {
        lastError = e as Exception;
      }
    }

    if (mounted) {
      setState(() {
        _error =
            'Unable to connect to backend. Please check your connection.\nError: ${lastError.toString()}';
        _isLoading = false;
      });
    }
  }

  static Map<String, dynamic> _parseJsonHelper(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<dynamic, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<Directory?> _resolveDownloadsDir() async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        return await getDownloadsDirectory();
      } else if (Platform.isIOS) {
        return await getApplicationDocumentsDirectory();
      } else if (Platform.isAndroid) {
        return await getDownloadsDirectory();
      }
    } catch (_) {}
    return null;
  }

  String _reportFileName() {
    final now = DateTime.now();
    return 'energy_report_${_reportData?['report_period']['month_name']}_${_reportData?['report_period']['year']}_${now.millisecondsSinceEpoch}.pdf';
  }

  Future<Uint8List> _buildFormattedPdfBytes() async {
    final pdf = pw.Document();
    final period = (_reportData!['report_period'] ?? {}) as Map<String, dynamic>;
    final selected = _reportData ?? {};
    final stats = Map<String, dynamic>.from(_reportData!['overall_statistics'] as Map? ?? {});
    final reportKind = (selected['report_kind'] ?? widget.reportType).toString().toLowerCase();
    final isTechnical = reportKind == 'technical';
    final accent = isTechnical ? PdfColors.blueGrey900 : PdfColors.indigo900;
    final title = (selected['title'] ?? (isTechnical ? 'Technical Energy Audit Report' : 'Monthly Energy Report')).toString();
    final subtitle = isTechnical
        ? 'Detailed operational analysis based on live electrical readings.'
        : 'Plain-language monthly summary built from live electrical readings.';

    pw.Widget sectionTitle(String text, {String? subtitleText}) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(text, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: accent)),
          if (subtitleText != null) ...[
            pw.SizedBox(height: 3),
            pw.Text(subtitleText, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ],
      );
    }

    pw.Widget infoPanel(String heading, String body, {PdfColor? panelColor}) {
      return pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: panelColor ?? PdfColors.grey50,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(heading, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(body, style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      );
    }

    pw.Widget keyValueTable(List<List<String>> rows) {
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
        columnWidths: const {0: pw.FlexColumnWidth(1.2), 1: pw.FlexColumnWidth(2.2)},
        children: rows
            .map((row) => pw.TableRow(children: [
                  pw.Container(
                    color: PdfColors.grey100,
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(row[0], style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(row[1], style: const pw.TextStyle(fontSize: 9)),
                  ),
                ]))
            .toList(),
      );
    }

    // Cover page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (_) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('GECI ENERGIA', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: accent)),
              pw.SizedBox(height: 12),
              pw.Text(title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: isTechnical ? PdfColors.blueGrey100 : PdfColors.indigo50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                ),
                child: pw.Text(subtitle, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: accent)),
              ),
              pw.SizedBox(height: 24),
              pw.Text('${period['month_name']} ${period['year']}', style: pw.TextStyle(fontSize: 16, color: PdfColors.grey800)),
              pw.SizedBox(height: 8),
              pw.Text('Generated: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              pw.SizedBox(height: 22),
              pw.Container(width: 120, height: 2, color: accent),
              pw.SizedBox(height: 8),
              pw.Text('Based on real sensor readings only', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
        ),
      ),
    );

    // Simple snapshot section
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (_) => pw.Column(
          children: [
            sectionTitle('Overall Statistics'),
            pw.SizedBox(height: 12),
            keyValueTable([
              ['Total Energy', '${stats['total_energy']?.toStringAsFixed(2) ?? '-'} kWh'],
              ['Average Power', '${stats['avg_power']?.toStringAsFixed(2) ?? '-'} W'],
              ['Peak Power', '${stats['peak_power']?.toStringAsFixed(2) ?? '-'} W'],
              ['Active Sensors', '${stats['active_sensors'] ?? '-'}'],
              ['Power Factor', '${stats['avg_power_factor']?.toStringAsFixed(3) ?? '-'}'],
            ]),
            pw.SizedBox(height: 20),
            sectionTitle('Month Comparison'),
            pw.SizedBox(height: 8),
            infoPanel(
              'Change from previous month',
              '${(_reportData!['month_over_month_change'] as num).abs().toStringAsFixed(1)}% ${(_reportData!['month_over_month_change'] as num) >= 0 ? 'increase' : 'decrease'}',
              panelColor: PdfColors.yellow50,
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> _buildReportPdfBytes() async {
    return _buildFormattedPdfBytes();
  }

  String _reportModeLabel() {
    return widget.reportType == 'technical' ? 'Technical' : 'Simple';
  }

  Future<void> _generatePDF() async {
    if (_reportData == null) return;

    try {
      _showLoadingDialog('Generating PDF...');

      final bytes = await _buildReportPdfBytes().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('PDF generation timed out'),
      );

      if (mounted) Navigator.pop(context);

      await Printing.sharePdf(bytes: bytes, filename: _reportFileName());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF ready for printing/sharing'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) _showErrorDialog('PDF Generation Failed', e.toString());
    }
  }

  Future<void> _downloadPDF() async {
    if (_reportData == null) return;

    try {
      _showLoadingDialog('Building and downloading PDF...');

      final bytes = await _buildReportPdfBytes().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('PDF generation timed out'),
      );

      final dir = await _resolveDownloadsDir();

      if (dir == null) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          await Printing.sharePdf(bytes: bytes, filename: _reportFileName());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Downloads directory not found. Opening share dialog instead.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final file = File('${dir.path}/${_reportFileName()}');
      await file.writeAsBytes(bytes);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Saved to Downloads'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                if (Platform.isWindows) {
                  Process.run('explorer.exe', [dir.path]);
                } else if (Platform.isMacOS) {
                  Process.run('open', [dir.path]);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog('Download Failed', e.toString());
      }
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
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
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent() {
    if (_reportData == null) return const SizedBox();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reportMode = _reportModeLabel();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$reportMode Monthly Report', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                const SizedBox(height: 6),
                Text('${_reportData!['report_period']['month_name']} ${_reportData!['report_period']['year']}', style: theme.textTheme.titleLarge),
                const SizedBox(height: 10),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  Chip(label: Text(reportMode), backgroundColor: reportMode == 'Technical' ? Colors.blue.shade100 : Colors.indigo.shade100),
                  ElevatedButton.icon(icon: const Icon(Icons.download), label: const Text('Download PDF'), onPressed: _downloadPDF),
                  OutlinedButton.icon(icon: const Icon(Icons.print), label: const Text('Print/Share'), onPressed: _generatePDF),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildStatisticsGrid(),
        const SizedBox(height: 40),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.reportType == 'technical' ? 'Technical' : 'Simple'} Report'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadReport,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
            : _buildReportContent(),
      ),
    );
  }
}
