import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/machine_model.dart';
import '../../models/reward_model.dart';
import '../../models/service_model.dart';
import '../../services/api_service.dart';
import '../../services/master_service.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/frosted_glass_card.dart';
import '../../widgets/language_picker_sheet.dart';
import 'master/machines_tab.dart';
import 'master/master_form_dialogs.dart';
import 'master/rewards_tab.dart';
import 'master/services_tab.dart';

/// Layar Master Data Outlet (M6) dengan tab Layanan, Mesin, dan Rewards.
class KasirMasterScreen extends StatefulWidget {
  const KasirMasterScreen({
    super.key,
    this.masterService,
    this.initialTab = 0,
  });

  final MasterService? masterService;
  final int initialTab;

  @override
  State<KasirMasterScreen> createState() => _KasirMasterScreenState();
}

class _KasirMasterScreenState extends State<KasirMasterScreen> {
  MasterService get _masterService => widget.masterService ?? MasterService.instance;

  late int _currentTab; // 0: Layanan, 1: Mesin, 2: Rewards

  // State Layanan
  List<ServiceModel> _services = [];
  bool _isLoadingServices = true;
  String? _servicesError;

  // State Mesin
  List<MachineModel> _machines = [];
  bool _isLoadingMachines = true;
  String? _machinesError;

  // State Rewards
  List<RewardModel> _rewards = [];
  bool _isLoadingRewards = true;
  String? _rewardsError;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _loadAllData(forceRefresh: true);
  }

  Future<void> _loadAllData({bool forceRefresh = false}) async {
    _loadServices(forceRefresh: forceRefresh);
    _loadMachines(forceRefresh: forceRefresh);
    _loadRewards();
  }

  Future<void> _loadServices({bool forceRefresh = false}) async {
    setState(() {
      _isLoadingServices = true;
      _servicesError = null;
    });

    try {
      final list = await _masterService.getServices(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _services = list;
          _isLoadingServices = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _servicesError = e.message;
          _isLoadingServices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final isEn = context.l10n.localeName == 'en';
        setState(() {
          _servicesError = isEn ? 'Failed to load services: $e' : 'Gagal memuat layanan: $e';
          _isLoadingServices = false;
        });
      }
    }
  }

  Future<void> _loadMachines({bool forceRefresh = false}) async {
    setState(() {
      _isLoadingMachines = true;
      _machinesError = null;
    });

    try {
      final list = await _masterService.getMachines(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _machines = list;
          _isLoadingMachines = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _machinesError = e.message;
          _isLoadingMachines = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final isEn = context.l10n.localeName == 'en';
        setState(() {
          _machinesError = isEn ? 'Failed to load machines: $e' : 'Gagal memuat mesin: $e';
          _isLoadingMachines = false;
        });
      }
    }
  }

  Future<void> _loadRewards() async {
    setState(() {
      _isLoadingRewards = true;
      _rewardsError = null;
    });

    try {
      final list = await _masterService.getRewards();
      if (mounted) {
        setState(() {
          _rewards = list;
          _isLoadingRewards = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _rewardsError = e.message;
          _isLoadingRewards = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final isEn = context.l10n.localeName == 'en';
        setState(() {
          _rewardsError = isEn ? 'Failed to load rewards: $e' : 'Gagal memuat rewards: $e';
          _isLoadingRewards = false;
        });
      }
    }
  }

  // ==========================================
  // LOGIKA AKSI LAYANAN
  // ==========================================

  Future<void> _handleDeleteService(ServiceModel service) async {
    final l10n = context.l10n;
    final isEn = l10n.localeName == 'en';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEn ? 'Delete Service?' : 'Hapus Layanan?'),
        content: Text(
          isEn
              ? 'Are you sure you want to delete service "${service.name}"?'
              : 'Apakah Anda yakin ingin menghapus layanan "${service.name}"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _masterService.deleteService(service.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn ? 'Service "${service.name}" deleted successfully.' : 'Layanan "${service.name}" berhasil dihapus.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
      _loadServices(forceRefresh: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Penanganan 409 bila layanan sedang digunakan pada order
      final msg = e.statusCode == 409
          ? (isEn
              ? 'Service cannot be deleted because it is still recorded in customer order transactions.'
              : 'Layanan tidak dapat dihapus karena masih tercatat pada transaksi pesanan pelanggan.')
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Failed to delete service: $e' : 'Gagal menghapus layanan: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  // ==========================================
  // LOGIKA AKSI MESIN
  // ==========================================

  Future<void> _handleToggleMachineStatus(MachineModel machine) async {
    final l10n = context.l10n;
    final isEn = l10n.localeName == 'en';
    if (machine.isDigunakan) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn
                ? 'Machine is currently washing an order and its status cannot be changed manually.'
                : 'Mesin sedang digunakan untuk mencuci pesanan dan tidak dapat diubah statusnya manual.',
          ),
        ),
      );
      return;
    }

    final newStatus = machine.isMaintenance ? 'tersedia' : 'maintenance';
    final actionLabel = newStatus == 'maintenance'
        ? (isEn ? 'Set Maintenance' : 'Set Pemeliharaan (Maintenance)')
        : (isEn ? 'Set Available (Ready)' : 'Set Tersedia (Siap Pakai)');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(actionLabel),
        content: Text(
          isEn
              ? 'Change machine ${machine.machineCode} status to "$newStatus"?'
              : 'Ubah status mesin ${machine.machineCode} menjadi "$newStatus"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'maintenance' ? AppTheme.accent : AppTheme.success,
              foregroundColor: Colors.white,
            ),
            child: Text(isEn ? 'Change Status' : 'Ubah Status'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _masterService.updateMachine(machine.id, status: newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn
                ? 'Machine ${machine.machineCode} status changed to $newStatus.'
                : 'Status mesin ${machine.machineCode} diubah ke $newStatus.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
      _loadMachines(forceRefresh: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger),
      );
    }
  }

  // ==========================================
  // LOGIKA AKSI REWARDS
  // ==========================================

  Future<void> _handleToggleRewardActive(RewardModel reward) async {
    final isEn = context.l10n.localeName == 'en';
    try {
      await _masterService.toggleRewardActive(reward.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn ? 'Coupon "${reward.title}" status updated.' : 'Status kupon "${reward.title}" berhasil diubah.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
      _loadRewards();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          l10n.manageStoreTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimary),
            tooltip: l10n.refreshData,
            onPressed: () => _loadAllData(forceRefresh: true),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AmbientBackground(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _buildTabPills(),
              ),
              Expanded(
                child: IndexedStack(
                  index: _currentTab,
                  children: [
                    ServicesTab(
                      services: _services,
                      isLoading: _isLoadingServices,
                      error: _servicesError,
                      onRefresh: () => _loadServices(forceRefresh: true),
                      onEdit: (service) => showServiceFormDialog(
                        context,
                        masterService: _masterService,
                        existing: service,
                        onSaved: () => _loadServices(forceRefresh: true),
                      ),
                      onDelete: _handleDeleteService,
                    ),
                    MachinesTab(
                      machines: _machines,
                      isLoading: _isLoadingMachines,
                      error: _machinesError,
                      onRefresh: () => _loadMachines(forceRefresh: true),
                      onToggleStatus: _handleToggleMachineStatus,
                    ),
                    RewardsTab(
                      rewards: _rewards,
                      isLoading: _isLoadingRewards,
                      error: _rewardsError,
                      onRefresh: _loadRewards,
                      onEdit: (reward) => showRewardFormDialog(
                        context,
                        masterService: _masterService,
                        existing: reward,
                        onSaved: _loadRewards,
                      ),
                      onToggleActive: _handleToggleRewardActive,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.extended(
          heroTag: 'fab_master_action',
          onPressed: () {
            if (_currentTab == 0) {
              showServiceFormDialog(
                context,
                masterService: _masterService,
                onSaved: () => _loadServices(forceRefresh: true),
              );
            }
            if (_currentTab == 1) {
              showMachineFormDialog(
                context,
                masterService: _masterService,
                onSaved: () => _loadMachines(forceRefresh: true),
              );
            }
            if (_currentTab == 2) {
              showRewardFormDialog(
                context,
                masterService: _masterService,
                onSaved: _loadRewards,
              );
            }
          },
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.add_rounded),
          label: Text(
            switch (_currentTab) {
              0 => l10n.newServiceBtn,
              1 => l10n.newMachineBtn,
              2 => l10n.newRewardBtn,
              _ => l10n.addBtn,
            },
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildTabPills() {
    final isEn = context.l10n.localeName == 'en';
    final tabs = [
      ('${isEn ? 'Services' : 'Layanan'} (${_services.length})', Icons.dry_cleaning_rounded),
      ('${isEn ? 'Machines' : 'Mesin'} (${_machines.length})', Icons.local_laundry_service_rounded),
      ('Rewards (${_rewards.length})', Icons.card_giftcard_rounded),
    ];

    return FrostedGlassCard(
      padding: const EdgeInsets.all(4),
      borderRadius: 24,
      blurSigma: 12,
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final isSelected = _currentTab == idx;
          final tab = tabs[idx];

          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _currentTab = idx),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tab.$2, size: 16, color: isSelected ? Colors.white : AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      tab.$1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
