import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/reward_model.dart';
import '../../../models/service_model.dart';
import '../../../services/api_service.dart';
import '../../../services/locale_service.dart';
import '../../../services/master_service.dart';

/// Form tambah/ubah layanan; panggil onSaved setelah server menyimpan data.
void showServiceFormDialog(
  BuildContext context, {
  required MasterService masterService,
  ServiceModel? existing,
  required VoidCallback onSaved,
}) {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final priceCtrl = TextEditingController(text: existing != null ? '${existing.pricePerKg}' : '');
  final washDurCtrl = TextEditingController(text: existing != null ? '${existing.washDurationMinutes}' : '45');
  final estHoursCtrl = TextEditingController(text: existing != null ? '${existing.estimatedHours}' : '24');
  final descCtrl = TextEditingController(text: existing?.description ?? '');
  bool reqMachine = existing?.requiresMachine ?? true;
  final isEn = LocaleService.instance.locale.value.languageCode == 'en';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (modalContext, setModalState) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existing == null
                            ? (isEn ? 'Add New Service' : 'Tambah Layanan Baru')
                            : (isEn ? 'Edit Service' : 'Edit Layanan'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Service Name *' : 'Nama Layanan *',
                      hintText: isEn ? 'Example: Express Wash' : 'Contoh: Cuci Komplit Kilat',
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isEn ? 'Rate / kg (Rp) *' : 'Tarif / kg (Rp) *',
                            hintText: '7000',
                            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: estHoursCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isEn ? 'Est. Time (Hours) *' : 'Estimasi (Jam) *',
                            hintText: '24',
                            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: washDurCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isEn ? 'Wash Duration (Min)' : 'Durasi Cuci (Menit)',
                            hintText: '45',
                            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              isEn ? 'Needs Machine' : 'Butuh Mesin',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            value: reqMachine,
                            onChanged: (val) => setModalState(() => reqMachine = val),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Short Description' : 'Deskripsi Singkat',
                      hintText: isEn ? 'Optional: service notes' : 'Opsional: keterangan layanan',
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                      final washDur = int.tryParse(washDurCtrl.text.trim()) ?? 45;
                      final estHours = int.tryParse(estHoursCtrl.text.trim()) ?? 24;

                      if (name.isEmpty || price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isEn
                                  ? 'Service name and valid rate are required.'
                                  : 'Nama layanan dan tarif valid wajib diisi.',
                            ),
                          ),
                        );
                        return;
                      }

                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);

                      try {
                        if (existing == null) {
                          await masterService.createService(
                            name: name,
                            pricePerKg: price,
                            washDurationMinutes: washDur,
                            estimatedHours: estHours,
                            requiresMachine: reqMachine,
                            description: descCtrl.text.trim(),
                          );
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(isEn ? 'Service added successfully.' : 'Layanan berhasil ditambahkan.'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        } else {
                          await masterService.updateService(
                            existing.id,
                            name: name,
                            pricePerKg: price,
                            washDurationMinutes: washDur,
                            estimatedHours: estHours,
                            requiresMachine: reqMachine,
                            description: descCtrl.text.trim(),
                          );
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(isEn ? 'Service updated successfully.' : 'Layanan berhasil diperbarui.'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                        onSaved();
                      } on ApiException catch (e) {
                        if (!context.mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      existing == null
                          ? (isEn ? 'Save Service' : 'Simpan Layanan')
                          : (isEn ? 'Update Service' : 'Perbarui Layanan'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Form tambah unit mesin baru; status dikelola lewat tombol kartu.
void showMachineFormDialog(
  BuildContext context, {
  required MasterService masterService,
  required VoidCallback onSaved,
}) {
  final codeCtrl = TextEditingController();
  final capCtrl = TextEditingController(text: '7.0');
  final isEn = LocaleService.instance.locale.value.languageCode == 'en';

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isEn ? 'Add Washing Machine Unit' : 'Tambah Unit Mesin Cuci',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: codeCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: isEn ? 'Machine Code (MC-XX) *' : 'Kode Mesin (MC-XX) *',
              hintText: 'MC-05',
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: capCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: isEn ? 'Capacity (kg) *' : 'Kapasitas (kg) *',
              hintText: '7.0',
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEn ? 'Cancel' : 'Batal')),
        ElevatedButton(
          onPressed: () async {
            final code = codeCtrl.text.trim().toUpperCase();
            final cap = double.tryParse(capCtrl.text.trim()) ?? 0.0;
            if (code.isEmpty || cap <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isEn
                        ? 'Machine code and valid capacity are required.'
                        : 'Kode mesin dan kapasitas valid wajib diisi.',
                  ),
                ),
              );
              return;
            }

            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(ctx);
            try {
              await masterService.createMachine(machineCode: code, capacityKg: cap);
              if (!context.mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(isEn ? 'Machine $code added successfully.' : 'Mesin $code berhasil ditambahkan.'),
                  backgroundColor: AppTheme.success,
                ),
              );
              onSaved();
            } on ApiException catch (e) {
              if (!context.mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          child: Text(isEn ? 'Save Machine' : 'Simpan Mesin'),
        ),
      ],
    ),
  );
}

/// Form tambah/ubah kupon reward tanpa is_active karena dikelola tombol toggle.
void showRewardFormDialog(
  BuildContext context, {
  required MasterService masterService,
  RewardModel? existing,
  required VoidCallback onSaved,
}) {
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final descCtrl = TextEditingController(text: existing?.description ?? '');
  final pointsCtrl = TextEditingController(text: existing != null ? '${existing.pointsRequired}' : '50');
  final discountCtrl = TextEditingController(text: existing != null ? '${existing.discountAmount}' : '5000');
  final isEn = LocaleService.instance.locale.value.languageCode == 'en';

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        existing == null
            ? (isEn ? 'Create New Reward Voucher' : 'Buat Kupon Reward Baru')
            : (isEn ? 'Edit Reward Voucher' : 'Edit Kupon Reward'),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: isEn ? 'Promo Voucher Title *' : 'Judul Kupon Promo *',
                hintText: isEn ? 'Example: Discount Rp 5,000' : 'Contoh: Diskon Hemat Rp 5.000',
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: isEn ? 'Short Description' : 'Deskripsi Singkat',
                hintText: isEn ? 'Promo notes' : 'Keterangan promo',
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pointsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Points Required *' : 'Poin Tukar *',
                      hintText: '50',
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: discountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Discount Value (Rp) *' : 'Nilai Potongan (Rp) *',
                      hintText: '5000',
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEn ? 'Cancel' : 'Batal')),
        ElevatedButton(
          onPressed: () async {
            final title = titleCtrl.text.trim();
            final points = int.tryParse(pointsCtrl.text.trim()) ?? 0;
            final discount = int.tryParse(discountCtrl.text.trim()) ?? 0;

            if (title.isEmpty || points <= 0 || discount <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isEn
                        ? 'All fields marked * must be filled properly.'
                        : 'Semua field bertanda * wajib diisi dengan benar.',
                  ),
                ),
              );
              return;
            }

            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(ctx);
            try {
              if (existing == null) {
                await masterService.createReward(
                  title: title,
                  description: descCtrl.text.trim(),
                  pointsRequired: points,
                  discountAmount: discount,
                  isActive: true,
                );
                if (!context.mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(isEn ? 'Reward voucher added successfully.' : 'Kupon reward berhasil ditambahkan.'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              } else {
                await masterService.updateReward(
                  existing.id,
                  title: title,
                  description: descCtrl.text.trim(),
                  pointsRequired: points,
                  discountAmount: discount,
                );
                if (!context.mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(isEn ? 'Reward voucher updated successfully.' : 'Kupon reward berhasil diperbarui.'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
              onSaved();
            } on ApiException catch (e) {
              if (!context.mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          child: Text(
            existing == null
                ? (isEn ? 'Save Reward' : 'Simpan Reward')
                : (isEn ? 'Update Reward' : 'Perbarui Reward'),
          ),
        ),
      ],
    ),
  );
}
