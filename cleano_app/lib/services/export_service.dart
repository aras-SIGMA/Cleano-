import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils/formatters.dart';
import '../models/dashboard_summary_model.dart';
import '../models/order_model.dart';

typedef ShareFileCallback = Future<bool> Function({
  required Uint8List bytes,
  required String filename,
});

/// Service manajemen ekspor laporan operasional kasir (CSV & PDF) dengan fitur share sheet (M10).
class ExportService {
  ExportService({ShareFileCallback? shareCallback})
      : _shareCallback = shareCallback ?? Printing.sharePdf;

  static final ExportService instance = ExportService();
  final ShareFileCallback _shareCallback;

  /// Menghasilkan representasi biner file CSV dari ringkasan dashboard dan daftar pesanan.
  Future<Uint8List> generateCsv({
    required DashboardSummaryModel summary,
    List<OrderModel>? orders,
  }) async {
    final now = DateTime.now();
    final List<List<dynamic>> rows = [
      ['CLEANO SMART LAUNDRY - REKAP LAPORAN OPERASIONAL'],
      ['Waktu Ekspor', '${Formatters.tanggal(now)} ${Formatters.jam(now)}'],
      [],
      ['RINGKASAN METRIK OPERASIONAL'],
      ['Metrik', 'Nilai'],
      ['Omzet Hari Ini', summary.todayRevenue],
      ['Pesanan Aktif', summary.activeOrders],
      ['Siap Diambil', summary.readyOrders],
      ['Kapasitas Mesin Tersedia', summary.availableMachines],
      ['Total Mesin Operasional', summary.totalOperationalMachines],
      [],
    ];

    if (summary.revenue7Days.isNotEmpty) {
      rows.add(['TREN OMZET 7 HARI TERAKHIR']);
      rows.add(['Tanggal', 'Omzet (Rp)', 'Jumlah Transaksi', 'Total Berat (kg)']);
      for (final r in summary.revenue7Days) {
        rows.add([r.orderDate, r.dailyRevenue, r.totalTransactions, r.totalWeightKg]);
      }
      rows.add([]);
    }

    if (orders != null && orders.isNotEmpty) {
      rows.add(['DAFTAR TRANSAKSI PESANAN']);
      rows.add([
        'Kode Order',
        'Tanggal',
        'Nama Pelanggan',
        'Layanan',
        'Berat (kg)',
        'Subtotal (Rp)',
        'Diskon (Rp)',
        'Total (Rp)',
        'Status Order',
        'Status Pembayaran',
        'Metode Pembayaran',
      ]);
      for (final o in orders) {
        rows.add([
          o.orderCode,
          Formatters.tanggal(o.createdAt),
          o.customerName,
          o.serviceName,
          o.weight,
          o.subtotalPrice,
          o.discountAmount,
          o.totalPrice,
          o.status,
          o.paymentStatus,
          o.paymentMethod,
        ]);
      }
    }

    // csv 8.0.0: `ListToCsvConverter` dihapus, encoder sekarang `Csv.encode`.
    // `Csv()` = koma, tanpa BOM, `\r\n` — sama dengan default v6 sebelumnya.
    final csvString = Csv().encode(rows);
    return Uint8List.fromList(utf8.encode(csvString));
  }

  /// Menghasilkan representasi biner file PDF dari ringkasan dashboard dan daftar pesanan.
  Future<Uint8List> generatePdf({
    required DashboardSummaryModel summary,
    List<OrderModel>? orders,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CLEANO SMART LAUNDRY',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.Text(
                      'Sistem Manajemen POS & Pelacakan Cucian Modern',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Text(
                  'LAPORAN OPERASIONAL',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Dicetak pada: ${Formatters.tanggal(now)} ${Formatters.jam(now)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) => [
          // 1. Ringkasan Metrik
          pw.Text('Ringkasan Hari Ini', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Metrik Operasional', 'Nilai Rekap'],
            data: [
              ['Omzet Hari Ini', Formatters.rupiah(summary.todayRevenue)],
              ['Pesanan Aktif', '${summary.activeOrders} Pesanan'],
              ['Siap Diambil', '${summary.readyOrders} Pesanan'],
              ['Kapasitas Mesin Cuci', '${summary.availableMachines} / ${summary.totalOperationalMachines} Tersedia'],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          ),
          pw.SizedBox(height: 16),

          // 2. Daftar Transaksi jika ada
          if (orders != null && orders.isNotEmpty) ...[
            pw.Text('Daftar Transaksi Pesanan', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['Kode', 'Pelanggan', 'Layanan', 'Berat', 'Total', 'Status', 'Bayar'],
              data: orders.map((o) => [
                o.orderCode,
                o.customerName,
                o.serviceName,
                Formatters.berat(o.weight),
                Formatters.rupiah(o.totalPrice),
                o.status.toUpperCase(),
                o.paymentStatus.toUpperCase(),
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            ),
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total Nilai: ${Formatters.rupiah(orders.fold(0, (sum, o) => sum + o.totalPrice))}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  /// Melakukan ekspor laporan (CSV / PDF) dan membuka dialog share sheet sistem.
  Future<void> exportReport({
    required String format,
    required DashboardSummaryModel summary,
    List<OrderModel>? orders,
  }) async {
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final isCsv = format.trim().toUpperCase() == 'CSV';

    final Uint8List bytes = isCsv
        ? await generateCsv(summary: summary, orders: orders)
        : await generatePdf(summary: summary, orders: orders);

    final filename = isCsv
        ? 'laporan_cleano_$timestamp.csv'
        : 'laporan_cleano_$timestamp.pdf';

    await _shareCallback(bytes: bytes, filename: filename);
  }
}
