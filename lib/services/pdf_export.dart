import 'dart:typed_data';
import 'dart:io' show File, Platform;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

/// Exports a table (headers + rows) as a PDF and opens the platform share/save dialog.
///
/// - On Windows/macOS/Linux it opens a Save dialog.
/// - On Android/iOS it opens the Share sheet to save/share the PDF.
/// - On web it triggers a file download.
Future<void> exportTablePdf(
  String title,
  List<String> headers,
  List<List<String>> rows, {
  String? subtitle,
}) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ),
      build: (context) {
        return [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
          pw.SizedBox(height: 16),
          if (headers.isNotEmpty)
            pw.Table.fromTextArray(
              headers: headers,
              data: rows,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              border: null,
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            )
          else
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: rows
                  .map((r) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(r.join('  •  ')),
                      ))
                  .toList(),
            ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated: ${DateTime.now()}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Text(
                'Total rows: ${rows.length}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ];
      },
    ),
  );

  final Uint8List bytes = await doc.save();
  final safeTitle = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final fileName = '${safeTitle.isEmpty ? 'export' : safeTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';

  await Printing.sharePdf(bytes: bytes, filename: fileName);
}

/// Convenience helper to export a simple 1-column list.
Future<void> exportSimpleListPdf(String title, List<String> items) async {
  final headers = <String>['Item'];
  final rows = items.map((e) => [e]).toList();
  await exportTablePdf(title, headers, rows);
}

/// Export and auto-save the PDF to the user's Downloads folder on desktop.
/// Falls back to share dialog on mobile/web.
Future<String?> exportTablePdfAutoSave(
  String title,
  List<String> headers,
  List<List<String>> rows, {
  String? subtitle,
}) async {
  // Build document
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        if (subtitle != null) ...[pw.SizedBox(height: 6), pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10))],
        pw.SizedBox(height: 16),
        pw.Table.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellStyle: const pw.TextStyle(fontSize: 10),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
        ),
      ],
    ),
  );
  final bytes = await doc.save();

  final safeTitle = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final fileName = '${safeTitle.isEmpty ? 'export' : safeTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';

  // Desktop platforms: try to save to Downloads
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      final outPath = '${downloadsDir.path}/$fileName';
      final file = File(outPath);
      await file.writeAsBytes(bytes);
      return outPath;
    }
  }

  // Fallback: open share/save dialog
  await Printing.sharePdf(bytes: bytes, filename: fileName);
  return null;
}
