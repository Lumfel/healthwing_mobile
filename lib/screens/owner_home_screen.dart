import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../services/app_dependencies.dart';
import '../theme/clinical_theme.dart';
import 'pet_card_screen.dart';
import 'receipt_viewer_screen.dart';

/// Owner Home dashboard featuring Quick Emergency SOS, upcoming appointments,
/// active pets list, and blockchain receipts shortcut.
class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  OwnerDashboardResponse? _dashboard;
  bool _isLoading = true;
  bool _isOfflineFallback = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final live = await widget.dependencies.apiClient.getOwnerDashboard();
      await widget.dependencies.offlineCache.saveOwnerDashboard(
        live.owner.id,
        live,
      );
      if (!mounted) return;
      setState(() {
        _dashboard = live;
        _isOfflineFallback = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _signOut();
        return;
      }
      await _tryLoadOfflineFallback(e.message);
    } catch (_) {
      await _tryLoadOfflineFallback(
        'Live clinic connection unavailable. Showing cached records if available.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _tryLoadOfflineFallback(String reason) async {
    final userId = await widget.dependencies.authStorage.readUserId();
    OwnerDashboardResponse? cached;
    if (userId != null) {
      cached = await widget.dependencies.offlineCache.readOwnerDashboard(
        userId,
      );
    }
    if (!mounted) return;
    setState(() {
      if (cached != null) {
        _dashboard = cached;
        _isOfflineFallback = true;
        _errorMessage = reason;
      } else {
        _errorMessage = reason;
      }
    });
  }

  Future<void> _signOut() async {
    await Future.wait([
      widget.dependencies.authStorage.clear(),
      widget.dependencies.offlineCache.clearAll(),
    ]);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _openRouteAndReload(String routeName, {Object? arguments}) async {
    await Navigator.of(context).pushNamed(routeName, arguments: arguments);
    if (mounted) {
      await _loadDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          dashboard != null
              ? 'Hello, ${dashboard.owner.firstName}'
              : 'Pet Owner Portal',
        ),
        actions: [
          IconButton(
            tooltip: 'Reload Dashboard',
            onPressed: _isLoading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh, size: 20),
          ),
          IconButton(
            tooltip: 'Sign Out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout, size: 20),
          ),
        ],
      ),
      body: _isLoading && dashboard == null
          ? const ClinicalLoadingView()
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ResponsiveClinicalBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isOfflineFallback && _errorMessage != null) ...[
                      ClinicalBanner(
                        tone: BannerTone.warning,
                        title: 'Offline Cached Mode',
                        message: _errorMessage!,
                      ),
                      const SizedBox(height: 12),
                    ] else if (_errorMessage != null) ...[
                      ClinicalBanner(
                        tone: BannerTone.danger,
                        title: 'Connection Notice',
                        message: _errorMessage!,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildEmergencySosCard(dashboard),
                    const SizedBox(height: 14),
                    _buildQuickShortcutsRow(dashboard),
                    const SizedBox(height: 18),
                    ClinicalSectionHeader(
                      title: 'Upcoming Appointments',
                      actionLabel: 'Book Slot',
                      onAction: () => _openRouteAndReload(
                        AppRoutes.booking,
                        arguments: dashboard?.activePets,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSchedulesSection(dashboard),
                    const SizedBox(height: 18),
                    ClinicalSectionHeader(
                      title: 'My Pets & Medical Cards',
                      actionLabel: 'View Cards',
                      onAction: () => _openRouteAndReload(
                        AppRoutes.petCard,
                        arguments: PetCardRouteArgs(
                          initialPets: dashboard?.activePets,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPetsSection(dashboard),
                    const SizedBox(height: 18),
                    ClinicalSectionHeader(
                      title: 'Blockchain Receipts Archive',
                      actionLabel: 'Verify Code',
                      onAction: () => _openRouteAndReload(
                        AppRoutes.receiptViewer,
                        arguments: ReceiptViewerRouteArgs(
                          recentBlocks:
                              dashboard?.activeReceiptBlocks ?? const [],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildReceiptsShortcutSection(dashboard),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmergencySosCard(OwnerDashboardResponse? dashboard) {
    final activeCases = dashboard?.activeEmergencyTriageStatus ?? const [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClinicalPalette.emergencyBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClinicalPalette.emergencyBorder, width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emergency_outlined,
                color: ClinicalPalette.emergencyRed,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Emergency Triage & SOS',
                  style: TextStyle(
                    color: ClinicalPalette.emergencyRed,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (activeCases.isNotEmpty)
                ClinicalBadge(
                  label: '${activeCases.length} Active',
                  backgroundColor: ClinicalPalette.emergencyRed,
                  foregroundColor: Colors.white,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            activeCases.isNotEmpty
                ? 'Active triage case #${activeCases.first.bookingId} (${activeCases.first.severityLevel}) — Queue #${activeCases.first.queuePosition ?? '-'}.'
                : 'Immediate veterinary trauma priority dispatch and live queue tracking.',
            style: const TextStyle(
              color: ClinicalPalette.deepSlate,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            key: const Key('owner_quick_sos_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ClinicalPalette.emergencyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _openRouteAndReload(
              AppRoutes.emergencyTriage,
              arguments: dashboard,
            ),
            icon: const Icon(Icons.bolt_outlined, size: 19),
            label: Text(
              activeCases.isNotEmpty
                  ? 'Open Live Emergency Triage Tracker'
                  : 'Quick Emergency SOS',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickShortcutsRow(OwnerDashboardResponse? dashboard) {
    return Row(
      children: [
        Expanded(
          child: _ShortcutTile(
            key: const Key('owner_book_shortcut'),
            icon: Icons.calendar_month_outlined,
            label: 'Book Visit',
            onTap: () => _openRouteAndReload(
              AppRoutes.booking,
              arguments: dashboard?.activePets,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ShortcutTile(
            key: const Key('owner_pet_cards_shortcut'),
            icon: Icons.badge_outlined,
            label: 'Pet Cards & Rx',
            onTap: () => _openRouteAndReload(
              AppRoutes.petCard,
              arguments: PetCardRouteArgs(
                initialPets: dashboard?.activePets,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ShortcutTile(
            key: const Key('owner_receipts_shortcut'),
            icon: Icons.verified_outlined,
            fallbackIcon: Icons.verified_outlined,
            label: 'Receipts',
            onTap: () => _openRouteAndReload(
              AppRoutes.receiptViewer,
              arguments: ReceiptViewerRouteArgs(
                recentBlocks: dashboard?.activeReceiptBlocks ?? const [],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSchedulesSection(OwnerDashboardResponse? dashboard) {
    final schedules = dashboard?.upcomingSchedules ?? const [];
    if (schedules.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No upcoming scheduled appointments.',
            style: TextStyle(
              color: ClinicalPalette.textSecondary,
              fontSize: 13.5,
            ),
          ),
        ),
      );
    }

    return Column(
      children: schedules.map((sched) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${sched.services} — ${sched.petName ?? 'Pet'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: ClinicalPalette.deepSlate,
                          ),
                        ),
                      ),
                      ClinicalBadge(label: sched.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Time: ${sched.appointmentTime} (${sched.durationMinutes} mins)',
                    style: const TextStyle(
                      fontSize: 13,
                      color: ClinicalPalette.textSecondary,
                    ),
                  ),
                  if (sched.roomName != null)
                    Text(
                      'Room: ${sched.roomName}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: ClinicalPalette.textSecondary,
                      ),
                    ),
                  if (sched.veterinarianName != null)
                    Text(
                      'Clinician: ${sched.veterinarianName}'
                      '${sched.veterinarianPrcLicenseNo != null ? ' (${sched.veterinarianPrcLicenseNo})' : ''}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: ClinicalPalette.textSecondary,
                      ),
                    ),
                  if (sched.preemptedByEmergencyId != null) ...[
                    const SizedBox(height: 8),
                    ClinicalBanner(
                      tone: BannerTone.warning,
                      message:
                          'Shifted due to priority trauma case #${sched.preemptedByEmergencyId}'
                          '${sched.previousAppointmentTime != null ? ' (previously ${sched.previousAppointmentTime})' : ''}.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildPetsSection(OwnerDashboardResponse? dashboard) {
    final pets = dashboard?.activePets ?? const [];
    if (pets.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No registered pets yet. Book a visit to add your first pet.',
            style: TextStyle(
              color: ClinicalPalette.textSecondary,
              fontSize: 13.5,
            ),
          ),
        ),
      );
    }

    return Column(
      children: pets.map((pet) {
        final metaParts = <String>[
          pet.petType,
          if (pet.species != null && pet.species!.isNotEmpty) pet.species!,
          if (pet.age != null) '${pet.age} yrs',
          if (pet.weightKg != null) '${pet.weightKg} kg',
        ];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              leading: CircleAvatar(
                backgroundColor: ClinicalPalette.mutedSurface,
                foregroundColor: ClinicalPalette.primaryTeal,
                child: Text(
                  pet.petName.isNotEmpty
                      ? pet.petName.substring(0, 1).toUpperCase()
                      : 'P',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(
                pet.petName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: ClinicalPalette.deepSlate,
                ),
              ),
              subtitle: Text(
                metaParts.join(' • '),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ClinicalPalette.textSecondary,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: ClinicalPalette.textSecondary,
              ),
              onTap: () => _openRouteAndReload(
                AppRoutes.petCard,
                arguments: PetCardRouteArgs(
                  selectedPetId: pet.petId,
                  initialPets: pets,
                ),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildReceiptsShortcutSection(OwnerDashboardResponse? dashboard) {
    final receipts = dashboard?.activeReceiptBlocks ?? const [];
    if (receipts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No active 365-day blockchain receipts on file. Tap Verify Code to inspect a receipt code.',
            style: TextStyle(
              color: ClinicalPalette.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return Column(
      children: receipts.take(5).map((block) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              leading: const Icon(
                Icons.receipt_long_outlined,
                color: ClinicalPalette.primaryTeal,
              ),
              title: Text(
                '${block.serviceSummary} (${block.currency} ${block.amount.toStringAsFixed(2)})',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: ClinicalPalette.deepSlate,
                ),
              ),
              subtitle: Text(
                '${block.receiptCode}\n${block.attendingVetName} (${block.attendingClinicianPrc})',
                style: const TextStyle(
                  fontSize: 12,
                  color: ClinicalPalette.textSecondary,
                  height: 1.35,
                ),
              ),
              isThreeLine: true,
              trailing: const Icon(
                Icons.lock_outline,
                size: 18,
                color: ClinicalPalette.primaryTeal,
              ),
              onTap: () => _openRouteAndReload(
                AppRoutes.receiptViewer,
                arguments: ReceiptViewerRouteArgs(
                  initialReceiptCode: block.receiptCode,
                  recentBlocks: receipts,
                ),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    super.key,
    this.icon,
    this.fallbackIcon = Icons.arrow_forward,
    required this.label,
    required this.onTap,
  });

  final IconData? icon;
  final IconData fallbackIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ClinicalPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ClinicalPalette.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(
                icon ?? fallbackIcon,
                color: ClinicalPalette.primaryTeal,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ClinicalPalette.deepSlate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
