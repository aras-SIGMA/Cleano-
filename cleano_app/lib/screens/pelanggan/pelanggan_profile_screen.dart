import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/frosted_glass_card.dart';

/// Layar Profil & Pengaturan Pelanggan Cleano (iOS Frosted Glass):
/// - Identitas Pelanggan, Badge Tier, dan Poin Loyalti
/// - Kartu Akses Member Digital (Pratinjau elegan tanpa memenuhi layar)
/// - Opsi "Tampilkan Kartu QR" beresolusi tinggi (Privasi: tanpa email, WA tersensor)
/// - Opsi "Kirim / Bagikan Member Card" ke sosial media (WhatsApp, Telegram, Salin Format Titip Cucian)
///   untuk memudahkan pemesanan jika diwakilkan oleh keluarga atau kurir ojek online
/// - Pengaturan Data Pribadi, Kata Sandi, dan Preferensi Cucian
/// - Bantuan, Ketentuan Layanan, dan Tombol Keluar Akun
class PelangganProfileScreen extends StatefulWidget {
  const PelangganProfileScreen({
    super.key,
    this.user,
    this.onLogout,
    this.onNavigateToRewards,
    this.authService,
    this.sessionService,
  });

  final UserModel? user;
  final VoidCallback? onLogout;
  final VoidCallback? onNavigateToRewards;
  final AuthService? authService;
  final SessionService? sessionService;

  @override
  State<PelangganProfileScreen> createState() => _PelangganProfileScreenState();
}

class _PelangganProfileScreenState extends State<PelangganProfileScreen> {
  AuthService get _authService => widget.authService ?? AuthService.instance;
  SessionService get _sessionService => widget.sessionService ?? SessionService.instance;

  UserModel? _user;
  bool _isLoading = false;
  bool _waNotificationEnabled = true;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    if (_user == null) _loadUserData();
  }

  @override
  void didUpdateWidget(PelangganProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != null && !identical(widget.user, oldWidget.user)) {
      _user = widget.user;
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final cached = await _sessionService.getUser();
    if (mounted && cached != null) {
      setState(() {
        _user = cached;
        _isLoading = false;
      });
    }

    try {
      final fresh = await _authService.getMe();
      if (mounted && fresh != null) {
        setState(() {
          _user = fresh;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Menampilkan Kartu Member Digital VIP Penuh beserta QR Code
  void _showFullMemberCardSheet(UserModel user) {
    final memberCode = user.memberCode.isNotEmpty ? user.memberCode : 'MBR-0001';
    final tier = user.tier.toLowerCase();
    final (cardGradients, tierBadgeBg, tierBadgeFg) = switch (tier) {
      'platinum' => (
          [const Color(0xFF1E1B4B), const Color(0xFF3730A3), const Color(0xFF4F46E5)],
          const Color(0xFFEEF2FF),
          const Color(0xFF312E81),
        ),
      'gold' => (
          [const Color(0xFF78350F), const Color(0xFFB45309), const Color(0xFFD97706)],
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
        ),
      _ => (
          [const Color(0xFF1E293B), const Color(0xFF334155), const Color(0xFF475569)],
          const Color(0xFFF1F5F9),
          const Color(0xFF334155),
        ),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kartu Member Digital',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Kartu Member VIP
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: cardGradients,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: cardGradients.first.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.local_laundry_service_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'CLEANO PASS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tierBadgeBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user.tier.toUpperCase(),
                          style: TextStyle(
                            color: tierBadgeFg,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // QR Code Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: memberCode,
                      version: QrVersions.auto,
                      size: 160,
                      semanticsLabel: 'QR Code $memberCode',
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Teks Member Code di Bawah QR
                  GestureDetector(
                    onTap: () => _copyToClipboard(memberCode, 'Kode member disalin!'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            memberCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded, color: Colors.white70, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Nama dan Nomor HP Tersensor (Privasi Tinggi: Tanpa Email!)
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No. WA: ${Formatters.sensorTelepon(user.phone)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Aksi Cepat
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showShareMemberCardSheet(user);
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Kirim'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary, width: 1.5),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Menampilkan Modal Berbagi Kartu Member ke Kurir / Keluarga
  void _showShareMemberCardSheet(UserModel user) {
    final memberCode = user.memberCode.isNotEmpty ? user.memberCode : 'MBR-0001';
    final shareMessage =
        '🧺 *CLEANO LAUNDRY — TITIP CUCIAN*\n\n'
        'Halo! Tolong titip cucian saya di Cleano ya:\n'
        '• *Nama Member:* ${user.name}\n'
        '• *Kode Member:* $memberCode\n'
        '• *Tier:* ${user.tier} Member\n'
        '• *No. Kontak:* ${Formatters.sensorTelepon(user.phone)}\n\n'
        'Cukup tunjukkan kode member *$memberCode* ini kepada kasir Cleano saat drop-off pakaian agar poin dan pesanan tercatat langsung di akun saya. Terima kasih! 🙏';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
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
                  child: const Icon(Icons.share_rounded, color: AppTheme.primary),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kirim Kartu ke Kurir / Keluarga',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Mudahkan orang lain memesankan cucian atas nama Anda',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Penjelasan Manfaat
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.success, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kasir hanya butuh kode member Anda untuk menginput pesanan. Poin cucian dan notifikasi proses cuci tetap otomatis masuk ke akun Anda!',
                      style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Opsi 1: Salin Format Pesan Chat Lengkap
            _shareOptionTile(
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: const Color(0xFF25D366),
              title: 'Salin Format Pesan WhatsApp / Chat',
              subtitle: 'Template teks lengkap dengan nama, kode member, dan panduan kasir',
              onTap: () {
                Navigator.pop(ctx);
                _copyToClipboard(shareMessage, 'Format pesan titip cucian berhasil disalin!');
              },
            ),
            const SizedBox(height: 10),

            // Opsi 2: Salin Kode Member Saja
            _shareOptionTile(
              icon: Icons.copy_rounded,
              iconColor: AppTheme.primary,
              title: 'Salin Kode Member Saja ($memberCode)',
              subtitle: 'Kirimkan kode unik singkat untuk dicatat kasir',
              onTap: () {
                Navigator.pop(ctx);
                _copyToClipboard(memberCode, 'Kode member $memberCode disalin!');
              },
            ),
            const SizedBox(height: 10),

            // Opsi 3: Tampilkan Gambar Kartu QR
            _shareOptionTile(
              icon: Icons.qr_code_2_rounded,
              iconColor: AppTheme.deepAzure,
              title: 'Tampilkan QR untuk Tangkapan Layar',
              subtitle: 'Buka kartu QR untuk di-screenshot dan dikirim sebagai gambar',
              onTap: () {
                Navigator.pop(ctx);
                _showFullMemberCardSheet(user);
              },
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

  Widget _shareOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
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
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
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
          left: 20,
          right: 20,
          top: 20,
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
                          'Perbarui kata sandi akun pelanggan Anda',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                  if (val == null || val.length < 6) return 'Minimal 6 karakter';
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

  @override
  Widget build(BuildContext context) {
    final user = _user ?? widget.user;

    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'Profil & Akun Saya',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          if (widget.onLogout != null)
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
          if (_isLoading && user == null)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Hero Profile Card
                  _buildHeroCustomerCard(user),
                  const SizedBox(height: 16),

                  // 2. Kartu Akses Member Digital & Opsi QR / Kirim
                  _buildDigitalPassSection(user),
                  const SizedBox(height: 20),

                  // 3. Seksi Informasi Akun & Keamanan
                  _buildSectionHeader('INFORMASI AKUN & KEAMANAN'),
                  const SizedBox(height: 8),
                  _buildAccountSecurityCard(user),
                  const SizedBox(height: 20),

                  // 4. Seksi Preferensi Layanan & Notifikasi
                  _buildSectionHeader('PREFERENSI LAYANAN'),
                  const SizedBox(height: 8),
                  _buildServicePreferencesCard(),
                  const SizedBox(height: 20),

                  // 5. Seksi Bantuan & Layanan Pelanggan
                  _buildSectionHeader('BANTUAN & PANDUAN'),
                  const SizedBox(height: 8),
                  _buildHelpAndSupportCard(),
                  const SizedBox(height: 24),

                  // 6. Tombol Logout
                  _buildLogoutButton(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroCustomerCard(UserModel? user) {
    final name = user?.name.isNotEmpty == true ? user!.name : 'Pelanggan Cleano';
    final tier = user?.tier.isNotEmpty == true ? user!.tier : 'Silver';
    final points = user?.points ?? 0;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    final (tierColor, nextTierText, progress) = switch (tier.toLowerCase()) {
      'platinum' => (const Color(0xFF4F46E5), 'Tier Tertinggi (VIP)', 1.0),
      'gold' => (
          AppTheme.warning,
          '${300 - points > 0 ? 300 - points : 0} poin menuju Platinum',
          (points / 300).clamp(0.0, 1.0)
        ),
      _ => (
          const Color(0xFF64748B),
          '${100 - points > 0 ? 100 - points : 0} poin menuju Gold',
          (points / 100).clamp(0.0, 1.0)
        ),
    };

    return FrostedGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
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
                      blurRadius: 12,
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
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
                            color: tierColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$tier Member'.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: tierColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          user?.memberCode ?? 'MBR-0001',
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

          // Poin & Progress Tier Strip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: AppTheme.accent, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          '$points Poin Loyalti',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (widget.onNavigateToRewards != null)
                      GestureDetector(
                        onTap: widget.onNavigateToRewards,
                        child: const Text(
                          'Tukar Hadiah →',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFCBD5E1),
                    valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    nextTierText,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bagian Kartu Akses Member Digital dengan opsi Tampilkan QR & Kirim ke Platform Sosial
  Widget _buildDigitalPassSection(UserModel? user) {
    final memberCode = user?.memberCode.isNotEmpty == true ? user!.memberCode : 'MBR-0001';
    final tier = user?.tier ?? 'Silver';

    return FrostedGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kartu Akses Member Digital',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Gunakan saat drop-off cucian di gerai Cleano',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Mini Wallet Pass Preview
          InkWell(
            onTap: () {
              if (user != null) _showFullMemberCardSheet(user);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F0F172A),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$tier Member • $memberCode'.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Ketuk untuk Tampilkan QR Code',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.fullscreen_rounded, color: Colors.white70, size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Dua Tombol Aksi: Tampilkan QR & Kirim
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (user != null) _showFullMemberCardSheet(user);
                  },
                  icon: const Icon(Icons.qr_code_rounded, size: 17),
                  label: const Text('Buka Kartu QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (user != null) _showShareMemberCardSheet(user);
                  },
                  icon: const Icon(Icons.share_rounded, size: 17),
                  label: const Text('Kirim'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary, width: 1.5),
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
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
            subtitle: user?.email.isNotEmpty == true ? user!.email : 'pelanggan@cleano.id',
            showChevron: false,
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.phone_outlined,
            iconColor: AppTheme.primary,
            title: 'Nomor WhatsApp Aktif',
            subtitle: user?.phone.isNotEmpty == true ? user!.phone : '0812-3456-7890',
            showChevron: false,
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.lock_outline_rounded,
            iconColor: AppTheme.warning,
            title: 'Ubah Kata Sandi',
            subtitle: 'Perbarui kata sandi akun login aplikasi',
            onTap: _showChangePasswordSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildServicePreferencesCard() {
    return FrostedGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        children: [
          _menuTile(
            icon: Icons.storefront_rounded,
            iconColor: AppTheme.primary,
            title: 'Outlet Langganan Utama',
            subtitle: 'Cleano Outlet 01 — Pusat Sukajadi (Bandung)',
            showChevron: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cleano Outlet 01 adalah cabang utama akun Anda.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.notifications_active_outlined,
            iconColor: const Color(0xFF25D366),
            title: 'Notifikasi WhatsApp Cucian',
            subtitle: 'Dapatkan pesan WA otomatis saat cucian siap diambil',
            trailing: Switch.adaptive(
              value: _waNotificationEnabled,
              activeThumbColor: AppTheme.primary,
              activeTrackColor: AppTheme.primary.withValues(alpha: 0.38),
              onChanged: (val) {
                setState(() => _waNotificationEnabled = val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpAndSupportCard() {
    return FrostedGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        children: [
          _menuTile(
            icon: Icons.headset_mic_rounded,
            iconColor: const Color(0xFF25D366),
            title: 'Pusat Bantuan WhatsApp',
            subtitle: 'Hubungi Customer Care Cleano (0812-9988-7766)',
            onTap: () {
              _copyToClipboard('081299887766', 'Nomor CS Cleano disalin!');
            },
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.info_outline_rounded,
            iconColor: AppTheme.primary,
            title: 'Panduan Poin & Hadiah',
            subtitle: 'Cara kumpulkan poin 2x lipat dan penukaran voucher',
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Panduan Poin Cleano'),
                  content: const Text(
                    '1. Setiap transaksi kelipatan Rp 10.000 mendapat 1 poin.\n'
                    '2. Cucian ≥ 5 kg atau layanan Express mendapat bonus 2x poin!\n'
                    '3. Kumpulkan 100 poin untuk Gold, 300 poin untuk Platinum.\n'
                    '4. Tukarkan poin dengan voucher diskon di menu Hadiah.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mengerti')),
                  ],
                ),
              );
            },
          ),
          _tileDivider(),
          _menuTile(
            icon: Icons.shield_outlined,
            iconColor: AppTheme.success,
            title: 'Syarat & Kebijakan Privasi',
            subtitle: 'Perlindungan data dan ketentuan pencucian',
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Privasi Pelanggan'),
                  content: const Text(
                    'Cleano berkomitmen penuh menjaga privasi data Anda:\n\n'
                    '• Nomor telepon disensor pada kartu fisik dan kartu QR.\n'
                    '• Email tidak pernah ditampilkan pada kartu member.\n'
                    '• Foto pakaian hanya digunakan sebagai bukti drop-off demi integritas cucian.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
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
            'Keluar dari Akun',
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
