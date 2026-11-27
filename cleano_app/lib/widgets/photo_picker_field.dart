import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import 'language_picker_sheet.dart';

/// Komponen pemilih foto bukti cucian dengan kompresi otomatis di bawah 2MB.
class PhotoPickerField extends StatefulWidget {
  const PhotoPickerField({
    super.key,
    required this.selectedFile,
    required this.selectedBytes,
    required this.onPhotoSelected,
    required this.onPhotoRemoved,
  });

  final XFile? selectedFile;
  final Uint8List? selectedBytes;
  final void Function(XFile file, Uint8List bytes) onPhotoSelected;
  final VoidCallback onPhotoRemoved;

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  final ImagePicker _picker = ImagePicker();
  bool _isPicking = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isPicking = true);
      // Kompres foto resolusi optimal dan quality 70 agar ukuran tetap ringan.
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        widget.onPhotoSelected(picked, bytes);
      }
    } catch (e) {
      if (mounted) {
        final isEn = context.l10n.localeName == 'en';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn ? 'Failed to take photo: $e' : 'Gagal mengambil foto: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _showSourcePicker() {
    final isEn = context.l10n.localeName == 'en';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEn ? 'Capture Clothing Condition Proof' : 'Ambil Bukti Kondisi Pakaian',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
                title: Text(isEn ? 'Direct Camera' : 'Kamera Langsung'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppTheme.secondary),
                title: Text(isEn ? 'Choose from Gallery' : 'Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEn = l10n.localeName == 'en';
    final hasPhoto = widget.selectedBytes != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPhoto ? AppTheme.success : AppTheme.border,
          width: hasPhoto ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    isEn ? 'Clothing Condition Photo' : 'Foto Kondisi Pakaian',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isEn ? '*Required' : '*Wajib',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.danger,
                    ),
                  ),
                ],
              ),
              if (hasPhoto)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        isEn ? 'Photo Attached' : 'Foto Terlampir',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isPicking)
            Container(
              height: 120,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            )
          else if (hasPhoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.memory(
                    widget.selectedBytes!,
                    cacheWidth: 600, // Downscale decode untuk efisiensi memori RAM
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        tooltip: isEn ? 'Remove Photo' : 'Hapus Foto',
                        onPressed: widget.onPhotoRemoved,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: ElevatedButton.icon(
                      onPressed: _showSourcePicker,
                      icon: const Icon(Icons.photo_camera_rounded, size: 16),
                      label: Text(isEn ? 'Change Photo' : 'Ganti Foto', style: const TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        foregroundColor: AppTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            InkWell(
              onTap: _showSourcePicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.add_a_photo_outlined,
                      size: 36,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.takeClothingPhoto,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEn
                          ? 'Photo of clothes before washing as cashier handover proof'
                          : 'Foto pakaian sebelum dicuci untuk bukti serah-terima kasir',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
