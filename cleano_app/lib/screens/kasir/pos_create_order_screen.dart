import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_model.dart';
import '../../models/service_model.dart';
import '../../models/user_model.dart';
import '../../models/voucher_model.dart';
import '../../services/api_service.dart';
import '../../services/master_service.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../widgets/member_card.dart';
import '../../widgets/photo_picker_field.dart';
import '../../widgets/service_dropdown.dart';
import '../../widgets/voucher_field.dart';
import '../../widgets/weight_input.dart';

/// Layar POS Kasir — Pembuatan Transaksi Pesanan Baru Cleano:
/// - Langkah 1: Lookup Pelanggan via QR Member Scanner atau Nomor HP
/// - Langkah 2: Pilih Layanan, Berat Cucian (kg), dan Unggah Foto Wajib Bukti Pakaian
/// - Langkah 3: Terapkan Voucher Diskon & Kalkulasi Total
/// - Langkah 4: Pembayaran (Tunai atau Midtrans Snap WebView) & Sinkronisasi Status
class PosCreateOrderScreen extends StatefulWidget {
  const PosCreateOrderScreen({
    super.key,
    this.userService,
    this.masterService,
    this.orderService,
    this.onOrderCreated,
  });

  final UserService? userService;
  final MasterService? masterService;
  final OrderService? orderService;
  final ValueChanged<OrderModel>? onOrderCreated;

  @override
  State<PosCreateOrderScreen> createState() => _PosCreateOrderScreenState();
}

class _PosCreateOrderScreenState extends State<PosCreateOrderScreen> {
  UserService get _userService => widget.userService ?? UserService.instance;
  MasterService get _masterService => widget.masterService ?? MasterService.instance;
  OrderService get _orderService => widget.orderService ?? OrderService.instance;

  // Controller
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // State Pelanggan
  UserModel? _customer;
  List<VoucherModel> _customerVouchers = [];
  bool _isSearchingCustomer = false;

  // State Layanan & Berat
  List<ServiceModel> _services = [];
  ServiceModel? _selectedService;
  bool _isLoadingServices = false;
  double _weight = 0.0;

  // State Foto
  XFile? _selectedPhoto;
  Uint8List? _photoBytes;

  // State Voucher & Pembayaran
  VoucherModel? _selectedVoucher;
  String _paymentMethod = 'tunai'; // 'tunai' | 'midtrans'
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoadingServices = true);
    try {
      final list = await _masterService.getServices();
      if (mounted) {
        setState(() {
          _services = list;
          if (list.isNotEmpty) _selectedService = list.first;
          _isLoadingServices = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingServices = false);
    }
  }

  Future<void> _searchCustomer(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() => _isSearchingCustomer = true);
    try {
      final res = await _userService.lookup(clean);
      if (mounted) {
        setState(() {
          _customer = res.user;
          _customerVouchers = res.vouchers;
          _selectedVoucher = null;
          _isSearchingCustomer = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isSearchingCustomer = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearchingCustomer = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencari pelanggan: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _showQrScanner() {
    final scannerController = MobileScannerController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        bool hasScanned = false;
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                foregroundColor: Colors.white,
                title: const Text('Pindai QR Member Cleano'),
              ),
              Expanded(
                child: MobileScanner(
                  controller: scannerController,
                  onDetect: (capture) {
                    if (hasScanned) return;
                    for (final barcode in capture.barcodes) {
                      final val = barcode.rawValue;
                      if (val != null && val.trim().isNotEmpty) {
                        hasScanned = true;
                        Navigator.pop(ctx);
                        _searchController.text = val.trim();
                        _searchCustomer(val.trim());
                        break;
                      }
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Arahkan kamera ke QR Code pada kartu pelanggan di aplikasi Cleano',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      scannerController.dispose();
    });
  }

  int get _subtotal {
    if (_selectedService == null || _weight <= 0) return 0;
    return (_weight * _selectedService!.pricePerKg).round();
  }

  int get _discount {
    if (_selectedVoucher == null) return 0;
    final disc = _selectedVoucher!.discountAmount;
    return disc > _subtotal ? _subtotal : disc;
  }

  int get _total => (_subtotal - _discount).clamp(0, 999999999);

  bool get _canSubmit {
    return _customer != null &&
        _selectedService != null &&
        _weight > 0 &&
        _photoBytes != null &&
        !_isSubmitting;
  }

  Future<void> _submitOrder() async {
    if (!_canSubmit) return;

    setState(() => _isSubmitting = true);

    try {
      final order = await _orderService.createOrder(
        userId: _customer!.id,
        serviceId: _selectedService!.id,
        weight: _weight,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        voucherCode: _selectedVoucher?.voucherCode,
        photoBytes: _photoBytes,
        photoFileName: 'order_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      widget.onOrderCreated?.call(order);

      // Jika Midtrans, buka halaman pembayaran Snap
      if (_paymentMethod == 'midtrans' && order.snapRedirectUrl != null) {
        await _openSnapWebView(order);
      } else {
        _showSuccessDialog(order);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses pesanan: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _openSnapWebView(OrderModel order) async {
    final url = Uri.parse(order.snapRedirectUrl!);

    // Web tidak punya implementasi webview_flutter (WebViewPlatform.instance null),
    // jadi Snap dibuka di tab baru dan status dicek manual.
    if (kIsWeb) {
      final opened = await launchUrl(url, webOnlyWindowName: '_blank');
      if (!mounted) return;
      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pop-up diblokir browser. Buka manual: ${order.snapRedirectUrl}'),
            duration: const Duration(minutes: 10),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pembayaran ${order.orderCode} dibuka di tab baru. '
              'Tekan Cek Status setelah selesai membayar.'),
          duration: const Duration(minutes: 10),
          action: SnackBarAction(
            label: 'Cek Status',
            onPressed: () => _checkPaymentStatus(order.id),
          ),
        ),
      );
      return;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(url);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              AppBar(
                title: Text('Pembayaran Online ${order.orderCode}'),
                actions: [
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      _checkPaymentStatus(order.id);
                    },
                    icon: const Icon(Icons.sync_rounded, color: AppTheme.primary),
                    label: const Text('Cek Status', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              Expanded(child: WebViewWidget(controller: controller)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkPaymentStatus(int orderId) async {
    try {
      final updated = await _orderService.syncPayment(orderId);
      if (mounted) {
        _showSuccessDialog(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status pembayaran: $e'), backgroundColor: AppTheme.warning),
        );
      }
    }
  }

  void _showSuccessDialog(OrderModel order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('Pesanan Berhasil Disimpan!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReceiptRow('Nomor Order', order.orderCode, isBold: true),
            const SizedBox(height: 6),
            _buildReceiptRow('Pelanggan', order.customerName),
            const SizedBox(height: 6),
            _buildReceiptRow('Layanan', '${order.serviceName} (${Formatters.berat(order.weight)})'),
            const SizedBox(height: 6),
            _buildReceiptRow('Total Bayar', Formatters.rupiah(order.totalPrice), isBold: true),
            const SizedBox(height: 6),
            _buildReceiptRow(
              'Status Pembayaran',
              order.isLunas ? 'LUNAS' : 'BELUM BAYAR',
              statusColor: order.isLunas ? AppTheme.success : AppTheme.warning,
            ),
            if (order.machineCode != null) ...[
              const SizedBox(height: 6),
              _buildReceiptRow('Mesin Cuci', order.machineCode!),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetForm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cucian Baru'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, Color? statusColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: statusColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  void _resetForm() {
    setState(() {
      _customer = null;
      _customerVouchers = [];
      _searchController.clear();
      _weightController.clear();
      _notesController.clear();
      _weight = 0.0;
      _selectedPhoto = null;
      _photoBytes = null;
      _selectedVoucher = null;
      _paymentMethod = 'tunai';
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Catat Cucian Baru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Reset Form',
            onPressed: _resetForm,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // LANGKAH 1: IDENTIFIKASI PELANGGAN
            // ==========================================
            _buildSectionHeader(number: '1', title: 'Pilih Pelanggan'),
            const SizedBox(height: 10),
            if (_customer == null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Cari Kode MBR-XXXX atau No. HP...',
                              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onSubmitted: _searchCustomer,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () => _searchCustomer(_searchController.text),
                          icon: _isSearchingCustomer
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _showQrScanner,
                      icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary),
                      label: const Text('Scan QR Member Pelanggan'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              )
            else
              MemberCard(
                user: _customer!,
                onReset: () => setState(() {
                  _customer = null;
                  _customerVouchers = [];
                  _selectedVoucher = null;
                }),
              ),
            const SizedBox(height: 24),

            // ==========================================
            // LANGKAH 2: LAYANAN, BERAT & BUKTI FOTO
            // ==========================================
            _buildSectionHeader(number: '2', title: 'Layanan & Berat Cucian'),
            const SizedBox(height: 10),
            ServiceDropdown(
              services: _services,
              selectedService: _selectedService,
              isLoading: _isLoadingServices,
              onChanged: (val) => setState(() => _selectedService = val),
            ),
            const SizedBox(height: 12),
            WeightInput(
              controller: _weightController,
              weight: _weight,
              pricePerKg: _selectedService?.pricePerKg ?? 0,
              onChanged: (w) => setState(() => _weight = w),
            ),
            const SizedBox(height: 12),
            PhotoPickerField(
              selectedFile: _selectedPhoto,
              selectedBytes: _photoBytes,
              onPhotoSelected: (file, bytes) {
                setState(() {
                  _selectedPhoto = file;
                  _photoBytes = bytes;
                });
              },
              onPhotoRemoved: () {
                setState(() {
                  _selectedPhoto = null;
                  _photoBytes = null;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Catatan Khusus (Opsional)',
                hintText: 'Misal: Pisahkan pakaian putih, ada kancing lepas...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // LANGKAH 3: VOUCHER & KALKULASI BIAYA
            // ==========================================
            _buildSectionHeader(number: '3', title: 'Kupon Diskon & Total Biaya'),
            const SizedBox(height: 10),
            VoucherField(
              availableVouchers: _customerVouchers,
              selectedVoucher: _selectedVoucher,
              onVoucherChanged: (v) => setState(() => _selectedVoucher = v),
            ),
            const SizedBox(height: 12),
            _buildSummaryCard(),
            const SizedBox(height: 24),

            // ==========================================
            // LANGKAH 4: METODE PEMBAYARAN & SUBMIT
            // ==========================================
            _buildSectionHeader(number: '4', title: 'Cara Pembayaran'),
            const SizedBox(height: 10),
            _buildPaymentMethodSelector(),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _canSubmit ? _submitOrder : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Simpan & Buat Pesanan • ${Formatters.rupiah(_total)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String number, required String title}) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppTheme.primary,
          child: Text(
            number,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _buildRow('Subtotal Cucian', Formatters.rupiah(_subtotal)),
          if (_discount > 0) ...[
            const SizedBox(height: 6),
            _buildRow('Potongan Voucher', '- ${Formatters.rupiah(_discount)}', color: AppTheme.accent),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Pembayaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(
                Formatters.rupiah(_total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      children: [
        _buildPaymentOption(
          id: 'tunai',
          title: 'Bayar Tunai',
          subtitle: 'Uang tunai diterima langsung di meja kasir',
          icon: Icons.payments_rounded,
          iconColor: AppTheme.primary,
        ),
        const SizedBox(height: 10),
        _buildPaymentOption(
          id: 'midtrans',
          title: 'QRIS / Transfer Digital',
          subtitle: 'Bayar via QRIS, GoPay, OVO, ShopeePay, atau Virtual Account',
          icon: Icons.qr_code_2_rounded,
          iconColor: AppTheme.secondary,
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final isSelected = _paymentMethod == id;

    return InkWell(
      onTap: () => setState(() => _paymentMethod = id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.surfaceSubtle : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isSelected ? AppTheme.primary : iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AppTheme.primary : AppTheme.border,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
