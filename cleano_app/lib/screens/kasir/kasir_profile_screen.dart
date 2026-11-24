import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/frosted_glass_card.dart';

/// Layar Profil & Pengaturan Kasir Cleano dengan desain iOS Frosted Glass:
/// - Hero Card Identitas Staf & Status Shift Aktif
/// - Ringkasan Operasional & Status Konter Kasir
/// - Pengaturan Hardware POS (Printer Thermal Bluetooth & Notifikasi Suara)
/// - Panduan SOP Kasir & Estafet Mesin Cuci
/// - Informasi Akun, Keamanan, dan Bantuan Supervisor
/// - Tombol Tutup Shift & Keluar Akun
class KasirProfileScreen extends StatefulWidget {
  const KasirProfileScreen({
    super.key,
    this.user,
    this.onLogout,
  });

  final UserModel? user;
  final VoidCallback? onLogout;

  @override
  State<KasirProfileScreen> createState() => _KasirProfileScreenState();
}

class _KasirProfileScreenState extends State<KasirProfileScreen> {
  bool _soundNotification = true;
  bool _thermalPrinterConnected = true;

  void _showTestReceiptDialog() {
    final now = DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.print_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Simulasi Struk POS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    const Text(
                      'CLEANO SMART LAUNDRY',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Outlet 01 — Cabang Utama',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const Text(
                      'Jl. Sukajadi No. 42, Bandung',
                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                    const Divider(height: 20, thickness: 1),
                    _receiptRow('Waktu Cetak', '${Formatters.tanggal(now)} ${Formatters.jam(now)}'),
                    _receiptRow('Kasir', widget.user?.name ?? 'Staf Kasir'),
                    _receiptRow('Kode Transaksi', 'CLN-TEST-0001'),
                    _receiptRow('Status', 'UJI COBA THERMAL 58mm'),
                    const Divider(height: 20, thickness: 1),
                    _receiptRow('Cuci Komplit (3.5 kg)', 'Rp 24.500'),
                    _receiptRow('Diskon Voucher', '-Rp 0'),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('TOTAL LUNAS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        Text('Rp 24.500', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                      ],
                    ),
                    const Divider(height: 20, thickness: 1),
                    const Text(
                      '*** STRUK VALIDASI SISTEM ***\nTerima kasih atas kunjungan Anda',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Perintah cetak struk terkirim ke printer Bluetooth (58mm).'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Kirim ke Printer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _receiptRow(String left, String right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              left,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            right,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordSheet() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ubah Kata Sandi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Perbarui kata sandi akun kasir untuk keamanan berkala',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: oldPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi Saat Ini',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => (val == null || val.isEmpty) ? 'Masukkan kata sandi lama' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi Baru (Min. 6 Karakter)',
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.length < 6) return 'Kata sandi minimal 6 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Kata Sandi Baru',
                  prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val != newPasswordController.text) return 'Konfirmasi kata sandi tidak cocok';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kata sandi berhasil diperbarui.'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Simpan Kata Sandi', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSopGuideSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Panduan SOP Kasir & Estafet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Standar operasional kebersihan & pelayanan Cleano',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: const [
                    _SopItem(
                      number: '1',
                      title: 'Identifikasi Pelanggan & Drop-Off',
                      description:
                          'Pindai QR Member atau cari nomor HP pelanggan. Pastikan mengambil foto pakaian fisik yang jelas sebagai bukti drop-off sebelum cucian masuk proses pencucian.',
                      icon: Icons.qr_code_scanner_rounded,
                    ),
                    _SopItem(
                      number: '2',
                      title: 'Penimbangan & Pengecekan Kantong',
                      description:
                          'Timbang cucian secara presisi (desimal 2 digit). Selalu cek saku pakaian dari benda keras, uang, atau barang berharga sebelum memulai cucian.',
                      icon: Icons.scale_rounded,
                    ),
                    _SopItem(
                      number: '3',
                      title: 'Estafet Mesin Cuci Otomatis (FIFO)',
                      description:
                          'Saat cucian ditandai "Siap Diambil", sistem memunculkan konfirmasi estafet untuk cucian antrean berikutnya. Konfirmasi segera agar mesin tidak menganggur.',
                      icon: Icons.sync_alt_rounded,
                    ),
                    _SopItem(
                      number: '4',
                      title: 'Pengambilan & Verifikasi Pembayaran',
                      description:
                          'Pastikan pesanan berstatus "LUNAS" sebelum diserahkan. Jika pembayaran Tunai saat ambil, terima uang sebelum menyelesaikan pesanan di aplikasi.',
                      icon: Icons.verified_user_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupervisorContactSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: AppTheme.primary),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bantuan & Kontak Supervisor',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Hubungi penanggung jawab outlet untuk kendala operasional',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ContactCard(
              title: 'Hendra Saputra (Supervisor Outlet)',
              subtitle: 'Penanggung Jawab Shift & Operasional',
              phone: '0812-8899-7711',
              icon: Icons.person_pin_rounded,
            ),
            const SizedBox(height: 10),
            _ContactCard(
              title: 'Tim IT & Support Cleano',
              subtitle: 'Kendala Sistem POS, Printer & Server',
              phone: '0811-2233-4455',
              icon: Icons.headset_mic_rounded,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'Akun & Pengaturan Kasir',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FrostedGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              borderRadius: 20,
              blurSigma: 12,
              onTap: widget.onLogout,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout_rounded, size: 15, color: AppTheme.danger),
                  SizedBox(width: 4),
                  Text(
                    'Keluar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AmbientBackground(),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Hero Card Profil Kasir
                _buildHeroProfileCard(user),
                const SizedBox(height: 16),

                // 2. Tiga Chip Metrik Shift & Status Konter
                _buildShiftQuickStats(),
                const SizedBox(height: 20),

                // 3. Seksi 1: Informasi Akun & Keamanan
                _buildSectionHeader('INFORMASI AKUN & KEAMANAN'),
                const SizedBox(height: 8),
                _buildAccountSecurityCard(user),
                const SizedBox(height: 20),

                // 4. Seksi 2: Perangkat & Hardware POS
                _buildSectionHeader('PERANGKAT & HARDWARE POS'),
                const SizedBox(height: 8),
                _buildHardwareSettingsCard(),
                const SizedBox(height: 20),

                // 5. Seksi 3: Standar Operasional & Bantuan
                _buildSectionHeader('STANDAR OPERASIONAL & BANTUAN'),
                const SizedBox(height: 8),
                _buildSopAndSupportCard(),
                const SizedBox(height: 20),

                // 6. Seksi 4: Informasi Sistem & Server
                _buildSectionHeader('SISTEM & APLIKASI'),
                const SizedBox(height: 8),
                _buildSystemInfoCard(),
                const SizedBox(height: 24),

                // 7. Tombol Tutup Shift & Keluar Akun
                _buildLogoutButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroProfileCard(UserModel? user) {
    final staffName = user?.name.isNotEmpty == true ? user!.name : 'Kasir Cleano';
    final memberCode = user?.memberCode.isNotEmpty == true ? user!.memberCode : 'STF-KASIR';
    final initial = staffName.isNotEmpty ? staffName[0].toUpperCase() : 'K';

    return FrostedGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        children: [
          Row(
            children: [
              // Avatar dengan Badge Status Online
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.primary, AppTheme.deepAzure],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33007FFF),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Nama & Role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staffName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'STAFF KASIR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          memberCode,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Outlet Info Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Cleano Outlet 01 — Pusat Sukajadi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ONLINE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _quickStatItem(
            icon: Icons.schedule_rounded,
            title: 'Shift Kasir',
            value: 'Pagi (08-16)',
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _quickStatItem(
            icon: Icons.point_of_sale_rounded,
            title: 'Konter POS',
            value: 'Siap Melayani',
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _quickStatItem(
            icon: Icons.sync_rounded,
            title: 'Sinkronisasi',
            value: 'Realtime',
            color: AppTheme.deepAzure,
          ),
        ),
      ],
    );
  }

  Widget _quickStatItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return FrostedGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildAccountSecurityCard(UserModel? user) {
    return FrostedGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        children: [
          _menuTile(
            icon: Icons.mail_outline_rounded,
            iconColor: AppTheme.primary,
            title: 'Email Terdaftar',
            subtitle: user?.email.isNotEmpty == true ? user!.email : 'kasir@cleano.id',
            showChevron: false,
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.phone_outlined,
            iconColor: AppTheme.primary,
            title: 'Nomor WhatsApp',
            subtitle: user?.phone.isNotEmpty == true ? user!.phone : '0812-3456-7890',
            showChevron: false,
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.lock_outline_rounded,
            iconColor: AppTheme.warning,
            title: 'Ganti Kata Sandi',
            subtitle: 'Ubah sandi login untuk keamanan akun',
            onTap: _showChangePasswordSheet,
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.pin_rounded,
            iconColor: AppTheme.deepAzure,
            title: 'PIN Otorisasi Kasir',
            subtitle: 'PIN supervisor untuk pembatalan pesanan',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PIN otorisasi disetel oleh manajer outlet.'),
                  backgroundColor: AppTheme.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareSettingsCard() {
    return FrostedGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        children: [
          _menuTile(
            icon: Icons.print_rounded,
            iconColor: AppTheme.primary,
            title: 'Printer Thermal Bluetooth',
            subtitle: _thermalPrinterConnected
                ? 'Terhubung (ESC/POS 58mm)'
                : 'Terputus (Ketuk untuk scan)',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: _showTestReceiptDialog,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'Uji Cetak',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: _thermalPrinterConnected,
                  activeThumbColor: AppTheme.primary,
                  activeTrackColor: AppTheme.primary.withValues(alpha: 0.38),
                  onChanged: (val) {
                    setState(() => _thermalPrinterConnected = val);
                  },
                ),
              ],
            ),
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.volume_up_rounded,
            iconColor: AppTheme.success,
            title: 'Suara Notifikasi Pesanan',
            subtitle: 'Bunyikan bel saat ada cucian antrean baru',
            trailing: Switch.adaptive(
              value: _soundNotification,
              activeThumbColor: AppTheme.primary,
              activeTrackColor: AppTheme.primary.withValues(alpha: 0.38),
              onChanged: (val) {
                setState(() => _soundNotification = val);
              },
            ),
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.qr_code_scanner_rounded,
            iconColor: AppTheme.deepAzure,
            title: 'Pemindai Kamera POS',
            subtitle: 'Kamera belakang aktif (Fokus otomatis)',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pemindai barcode kamera siap digunakan di menu Catat Cucian.'),
                  backgroundColor: AppTheme.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSopAndSupportCard() {
    return FrostedGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        children: [
          _menuTile(
            icon: Icons.menu_book_rounded,
            iconColor: AppTheme.primary,
            title: 'Panduan SOP Kasir & Estafet',
            subtitle: '4 langkah standar pelayanan & alur mesin',
            onTap: _showSopGuideSheet,
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.support_agent_rounded,
            iconColor: AppTheme.warning,
            title: 'Kontak Supervisor & Bantuan',
            subtitle: 'Nomor penanggung jawab outlet & tim teknis',
            onTap: _showSupervisorContactSheet,
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.shield_outlined,
            iconColor: AppTheme.success,
            title: 'Ketentuan Layanan & Privasi',
            subtitle: 'Perlindungan data pelanggan & aturan laundry',
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Privasi & Ketentuan'),
                  content: const Text(
                    'Cleano menjaga privasi data pelanggan:\n\n'
                    '1. Nomor telepon disensor untuk keamanan.\n'
                    '2. Email pelanggan tidak dibagikan sembarangan.\n'
                    '3. Foto drop-off hanya digunakan sebagai bukti kondisi fisik pakaian.\n'
                    '4. Seluruh transaksi terekam aman dengan audit database.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfoCard() {
    return FrostedGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 20,
      child: Column(
        children: [
          _systemRow('Versi Aplikasi', 'Cleano POS v1.0.0+1 (Build 2026.11)'),
          const SizedBox(height: 8),
          _systemRow('Koneksi Server', 'Aiven Cloud MySQL 8 (TLS 1.3)'),
          const SizedBox(height: 8),
          _systemRow('Gateway Pembayaran', 'Midtrans Snap Sandbox Aktif'),
          const SizedBox(height: 8),
          _systemRow('Penyimpanan Bukti', 'Cloudinary CDN Cloud Storage'),
        ],
      ),
    );
  }

  static Widget _systemRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return FrostedGlassCard(
      onTap: widget.onLogout,
      borderRadius: 18,
      backgroundColor: const Color(0xFFFEF2F2),
      border: Border.all(color: const Color(0xFFFCA5A5)),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout_rounded, color: AppTheme.danger, size: 20),
          SizedBox(width: 8),
          Text(
            'Tutup Shift & Keluar Akun',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (showChevron && onTap != null)
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _tileDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      endIndent: 16,
      color: AppTheme.border.withValues(alpha: 0.7),
    );
  }
}

class _SopItem extends StatelessWidget {
  const _SopItem({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String number;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.title,
    required this.subtitle,
    required this.phone,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String phone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
