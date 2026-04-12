import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MeetingPdfExportService {
  Future<void> exportSummary({
    required String meetingTitle,
    required String summary,
    required List<String> decisions,
    required List<String> tasks,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(meetingTitle, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Text(summary),
          pw.SizedBox(height: 16),
          pw.Text('Decisions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ...decisions.map((d) => pw.Bullet(text: d)),
          pw.SizedBox(height: 16),
          pw.Text('Tasks', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ...tasks.map((t) => pw.Bullet(text: t)),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'meeting_summary.pdf',
    );
  }
}
