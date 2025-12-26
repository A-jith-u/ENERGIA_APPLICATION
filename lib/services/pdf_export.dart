import 'dart:typed_data';
import 'dart:io' show File, Platform, Directory;
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
  Future<Directory?> _resolveDownloadsDir() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (dirs != null && dirs.isNotEmpty) return dirs.first;
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return getDownloadsDirectory();
    }
    return null;
  }

  final doc = pw.Document();

  String _fmtStamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(_fmtStamp(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
          if (subtitle != null) pw.Text(subtitle!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey500, thickness: 0.5),
          pw.SizedBox(height: 8),
        ],
      ),
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
          if (headers.isNotEmpty)
            pw.Table.fromTextArray(
              headers: headers,
              data: rows,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.symmetric(inside: const pw.BorderSide(color: PdfColors.grey400, width: 0.3)),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            )
          else
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: rows
                  .map((r) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(r.join('  •  '), style: const pw.TextStyle(fontSize: 11)),
                      ))
                  .toList(),
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
  String _fmtFileStamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y$m$d-$hh$mm';
  }
  final fileName = '${safeTitle.isEmpty ? 'export' : safeTitle}_${_fmtFileStamp(DateTime.now())}.pdf';

  // Try saving to Downloads when available (Android + desktop)
  final downloadsDir = await _resolveDownloadsDir();
  if (downloadsDir != null) {
    final outPath = '${downloadsDir.path}/$fileName';
    final file = File(outPath);
    await file.writeAsBytes(bytes);
  }

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
  Future<Directory?> _resolveDownloadsDir() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (dirs != null && dirs.isNotEmpty) return dirs.first;
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return getDownloadsDirectory();
    }
    return null;
  }

  // Build document with standardized header & footer
  final doc = pw.Document();
  String _fmtStamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(_fmtStamp(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
          if (subtitle != null) pw.Text(subtitle!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey500, thickness: 0.5),
          pw.SizedBox(height: 8),
        ],
      ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        pw.Table.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignment: pw.Alignment.centerLeft,
          border: pw.TableBorder.symmetric(inside: const pw.BorderSide(color: PdfColors.grey400, width: 0.3)),
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
  String _fmtFileStamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y$m$d-$hh$mm';
  }
  final fileName = '${safeTitle.isEmpty ? 'export' : safeTitle}_${_fmtFileStamp(DateTime.now())}.pdf';

  final downloadsDir = await _resolveDownloadsDir();
  if (downloadsDir != null) {
    final outPath = '${downloadsDir.path}/$fileName';
    final file = File(outPath);
    await file.writeAsBytes(bytes);
    return outPath;
  }

  // Fallback: open share/save dialog
  await Printing.sharePdf(bytes: bytes, filename: fileName);
  return null;
}
