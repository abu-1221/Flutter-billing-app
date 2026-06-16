import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:billing_app/core/data/hive_database.dart';

class PdfInvoiceGenerator {
  static Future<File> generate({
    required String shopName,
    required String address1,
    required String address2,
    required String phone,
    required String invoiceNumber,
    required String receiptNumber,
    required String date,
    required String time,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    required double total,
    required String footer,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Group
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        shopName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(address1, style: const pw.TextStyle(fontSize: 10)),
                      if (address2.isNotEmpty)
                        pw.Text(address2, style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Phone: $phone', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey700,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Invoice #: $invoiceNumber', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text('Receipt #: $receiptNumber', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Time: $time', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 32),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 16),

              // Billing Details
              pw.Text('Bill To: Counter Customer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              pw.Text('Payment Mode: Cash / UPI', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 24),

              // Items Table
              pw.Table(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildHeaderCell('Product Name'),
                      _buildHeaderCell('Qty', align: pw.TextAlign.center),
                      _buildHeaderCell('Unit Price (₹)', align: pw.TextAlign.right),
                      _buildHeaderCell('Total (₹)', align: pw.TextAlign.right),
                    ],
                  ),
                  // Table Rows
                  ...items.map((item) {
                    final name = item['name'] ?? 'N/A';
                    final qty = item['qty'] ?? 1;
                    final price = item['price'] as double? ?? 0.0;
                    final totalVal = item['total'] as double? ?? 0.0;

                    return pw.TableRow(
                      children: [
                        _buildDataCell(name.toString()),
                        _buildDataCell(qty.toString(), align: pw.TextAlign.center),
                        _buildDataCell(price.toStringAsFixed(2), align: pw.TextAlign.right),
                        _buildDataCell(totalVal.toStringAsFixed(2), align: pw.TextAlign.right),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 24),

              // Total Calculation Layout
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Terms & Conditions:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        pw.Bullet(text: 'Goods once sold will not be taken back.', style: const pw.TextStyle(fontSize: 8)),
                        pw.Bullet(text: 'Please check invoices before leaving.', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                         _buildTotalRow('Subtotal', subtotal.toStringAsFixed(2)),
                        pw.SizedBox(height: 4),
                        ...(() {
                          final List? stored = HiveDatabase.settingsBox.get('taxes_config') as List?;
                          if (stored == null) {
                            return [
                              _buildTotalRow('Tax (18% GST)', tax.toStringAsFixed(2)),
                              pw.SizedBox(height: 4),
                            ];
                          }
                          final List<pw.Widget> widgets = [];
                          for (var t in stored) {
                            if (t is Map && t['isActive'] == true) {
                              final name = t['name'] ?? 'Tax';
                              final pct = double.tryParse(t['percentage'].toString()) ?? 0.0;
                              final amount = subtotal * (pct / 100.0);
                              widgets.add(_buildTotalRow('Tax ($name)', amount.toStringAsFixed(2)));
                              widgets.add(pw.SizedBox(height: 4));
                            }
                          }
                          if (widgets.isEmpty) {
                            widgets.add(_buildTotalRow('Tax (0%)', '0.00'));
                            widgets.add(pw.SizedBox(height: 4));
                          }
                          return widgets;
                        })(),
                        pw.Divider(thickness: 1, color: PdfColors.grey300),
                        pw.SizedBox(height: 8),
                        _buildTotalRow(
                          'GRAND TOTAL',
                          '₹${total.toStringAsFixed(2)}',
                          isBold: true,
                          fontSize: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 12),

              // Footer thank you note
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(footer, style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                    pw.SizedBox(height: 4),
                    pw.Text('Generated by Offline Billing POS System', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/$invoiceNumber.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> shareInvoice(File file, String invoiceNumber) async {
    final xFile = XFile(file.path);
    await Share.shareXFiles([xFile], text: 'Invoice $invoiceNumber generated successfully.');
  }

  static pw.Widget _buildHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      ),
    );
  }

  static pw.Widget _buildDataCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  static pw.Widget _buildTotalRow(String label, String value, {bool isBold = false, double fontSize = 10}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
