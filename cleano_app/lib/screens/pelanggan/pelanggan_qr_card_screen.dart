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
import '../../widgets/state_view.dart';

/// Layar Kartu Member Digital & QR Code Pelanggan (M8).
/// - QR Code (qr_flutter) hanya memuat member_code (mis. MBR-0001).
/// - Menampilkan nama lengkap, tier badge berwarna (Silver/Gold/Platinum), teks MBR-XXXX di bawah QR.
/// - Nomor WhatsApp disensor melalui Formatters.sensorTelepon (0812-****-7890).
/// - Privasi & Keamanan: EMAIL TIDAK DITAMPILKAN SAMA SEKALI.
/// - Desain frosted glass modern ala iOS Wallet Pass.
class PelangganQrCardScreen extends StatefulWidget {
  const PelangganQrCardScreen({
    super.key,
    this.sessionService,
    this.authService,
    this.user,
    this.onLogout,
  });

  final SessionService? sessionService;
  final AuthService? authService;

  /// Profil dari navigasi induk. Bila diisi, layar tidak mengambil `/users/me`
  /// lagi — cukup satu permintaan profil untuk seluruh portal pelanggan.
  final UserModel? user;

  final VoidCallback? onLogout;

  @override
  State<PelangganQrCardScreen> createState() => _PelangganQrCardScreenState();
}

class _PelangganQrCardScreenState extends State<PelangganQrCardScreen> {
  SessionService get _sessionService => widget.sessionService ?? SessionService.instance;
  AuthService get _authService => widget.authService ?? AuthService.instance;

  UserModel? _user;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _isLoading = _user == null;
    if (_user == null) _loadProfile();
  }

  @override
  void didUpdateWidget(PelangganQrCardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Induk memuat ulang profil setelah tab ini terpasang (poin/tier berubah).
    // State dipertahankan oleh IndexedStack, jadi initState tidak jalan lagi.
    // Hanya bereaksi bila induk mengirim objek profil baru, supaya hasil
    // refresh lokal tidak ditimpa saat induk rebuild karena hal lain.
    // Perbandingan pakai identitas: `UserModel ==` hanya melihat id dan email,
    // sehingga perubahan poin/tier tidak terdeteksi olehnya.
    if (widget.user != null && !identical(widget.user, oldWidget.user)) {
      _user = widget.user;
      _isLoading = false;
      _errorMessage = null;
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. Baca data dari sesi lokal untuk render instan
    final cached = await _sessionService.getUser();
    if (mounted && cached != null) {
      setState(() {
        _user = cached;
        _isLoading = false;
      });
    }

    // 2. Ambil data terbaru dari server
    try {
      final fresh = await _authService.getMe();
      if (!mounted) return;
      if (fresh != null) {
        setState(() {
          _user = fresh;
          _isLoading = false;
        });
      } else if (_user == null) {
        // Respons tanpa data bukan kegagalan jaringan: tanpa cabang ini
        // indikator loading berputar tanpa henti.
        setState(() {
          _errorMessage = 'Profil tidak tersedia. Coba lagi.';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && _user == null) {
        setState(() {
          _errorMessage = 'Gagal memuat kartu member. Periksa koneksi Anda.';
          _isLoading = false;
        });
      }
    }
  }

  void _copyMemberCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kode member $code disalin ke clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadProfile,
              color: AppTheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kartu Member Saya',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Cleano Digital Pass',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        if (widget.onLogout != null)
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, color: AppTheme.danger),
                            tooltip: 'Logout',
                            onPressed: widget.onLogout,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Konten Kartu
                    if (_isLoading && _user == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_errorMessage != null && _user == null)
                      _buildErrorState()
                    else
                      _buildMemberPassCard(_user!),

                    const SizedBox(height: 20),

                    // Petunjuk Penggunaan Kasir
                    _buildUsageGuide(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberPassCard(UserModel user) {
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cardGradients,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: cardGradients.first.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Aksen Dekoratif Transparan
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header Kartu: Logo & Tier Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.local_laundry_service_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CLEANO PASS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Text(
                                'Exclusive Member',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: tierBadgeBg,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          user.tier.toUpperCase(),
                          style: TextStyle(
                            color: tierBadgeFg,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. Kontainer QR Code Berlatar Putih Bersih (High Contrast Demi Scan)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // QR Code yang HANYA berisi member_code
                          QrImageView(
                            data: user.memberCode,
                            version: QrVersions.auto,
                            size: 190.0,
                            backgroundColor: Colors.white,
                            semanticsLabel: 'QR Code ${user.memberCode}',
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF0F172A),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Teks MBR-XXXX di bawah QR
                          InkWell(
                            onTap: () => _copyMemberCode(user.memberCode),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    user.memberCode,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 2,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.copy_rounded,
                                    size: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Footer Informasi: Nama, Nomor WA Tersensor, & Poin (TANPA EMAIL)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Nama Lengkap & Nomor WA Tersensor
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'NAMA MEMBER',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.phone_iphone_rounded, color: Colors.white70, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    Formatters.sensorTelepon(user.phone),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Saldo Poin Loyalti
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'SALDO POIN',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${user.points}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'Poin Loyalti',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildUsageGuide() {
    return FrostedGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 22,
      blurSigma: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Cara Pakai di Kasir',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGuideRow(
            step: '1',
            text: 'Tunjukkan QR Code ini ke layar scanner kasir saat menyerahkan pakaian cucian.',
          ),
          const SizedBox(height: 10),
          _buildGuideRow(
            step: '2',
            text: 'Kasir langsung memvalidasi akun tanpa perlu Anda mendiktekan nomor telepon.',
          ),
          const SizedBox(height: 10),
          _buildGuideRow(
            step: '3',
            text: 'Poin loyalti otomatis ditambahkan ke akun Anda setiap kali cucian selesai dikerjakan.',
          ),
        ],
      ),
    );
  }

  Widget _buildGuideRow({required String step, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() => StateErrorView(
        message: _errorMessage ?? 'Terjadi kesalahan saat memuat kartu.',
        onRetry: _loadProfile,
      );
}
