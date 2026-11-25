import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../services/app_dependencies.dart';
import '../theme/clinical_theme.dart';

/// Optional route arguments when opening [PetCardScreen].
class PetCardRouteArgs {
  const PetCardRouteArgs({
    this.selectedPetId,
    this.initialPets,
  });

  final int? selectedPetId;
  final List<ActivePet>? initialPets;
}

/// Pet Medical Card & Rx screen loading live data with automatic fallback to
/// `OfflineCache` when offline.
class PetCardScreen extends StatefulWidget {
  const PetCardScreen({
    super.key,
    required this.dependencies,
    this.args,
  });

  final AppDependencies dependencies;
  final PetCardRouteArgs? args;

  @override
  State<PetCardScreen> createState() => _PetCardScreenState();
}

class _PetCardScreenState extends State<PetCardScreen> {
  List<OfflinePetMedicalCard> _cards = const <OfflinePetMedicalCard>[];
  List<OfflineRxRecord> _rxRecords = const <OfflineRxRecord>[];
  int? _selectedPetId;
  String? _lastCachedAt;

  bool _isLoading = true;
  bool _isOfflineFallback = false;
  String? _noticeMessage;

  @override
  void initState() {
    super.initState();
    _selectedPetId = widget.args?.selectedPetId;
    _loadCardsAndRx();
  }

  Future<void> _loadCardsAndRx() async {
    setState(() {
      _isLoading = true;
      _noticeMessage = null;
    });

    final storedUserId = await widget.dependencies.authStorage.readUserId();

    try {
      final dashboard = await widget.dependencies.apiClient.getOwnerDashboard();
      final ownerId = dashboard.owner.id;

      await widget.dependencies.offlineCache.saveOwnerDashboard(
        ownerId,
        dashboard,
      );

      final cachedCards = await widget.dependencies.offlineCache
          .readPetMedicalCards(ownerId);
      final cachedRx = await widget.dependencies.offlineCache.readRxRecords(
        ownerId,
      );

      // Merge any upcoming schedule clinical notes into baseline Rx/visit items
      // if no standalone Rx history is cached yet for that schedule.
      final mergedRx = <OfflineRxRecord>[...cachedRx];
      final existingIds = mergedRx.map((e) => e.checkupId).toSet();
      for (final sched in dashboard.upcomingSchedules) {
        final syntheticId = 100000 + sched.scheduleId;
        if (sched.petId != null && !existingIds.contains(syntheticId)) {
          mergedRx.add(
            OfflineRxRecord(
              checkupId: syntheticId,
              petId: sched.petId!,
              petName: sched.petName ?? 'Pet',
              checkupDate: sched.appointmentTime,
              diagnosis: sched.services,
              prescription:
                  sched.notes != null && sched.notes!.trim().isNotEmpty
                  ? sched.notes
                  : 'Scheduled ${sched.services} (${sched.status})',
              notes: sched.roomName != null ? 'Room: ${sched.roomName}' : null,
              attendingVetName: sched.veterinarianName,
              attendingVetPrc: sched.veterinarianPrcLicenseNo,
            ),
          );
        }
      }

      await widget.dependencies.offlineCache.saveRxRecords(ownerId, mergedRx);
      final savedAt = await widget.dependencies.offlineCache.lastSavedAt(
        ownerId,
      );

      if (!mounted) return;
      setState(() {
        _cards = cachedCards;
        _rxRecords = mergedRx;
        _lastCachedAt = savedAt;
        _isOfflineFallback = false;
        _ensureValidSelection();
      });
    } catch (error) {
      final ownerId = storedUserId ?? 1;
      final cachedCards = await widget.dependencies.offlineCache
          .readPetMedicalCards(ownerId);
      final cachedRx = await widget.dependencies.offlineCache.readRxRecords(
        ownerId,
      );
      final savedAt = await widget.dependencies.offlineCache.lastSavedAt(
        ownerId,
      );

      // If no cached cards exist yet but initialPets were passed, build baseline cards.
      final resolvedCards = cachedCards.isNotEmpty
          ? cachedCards
          : (widget.args?.initialPets ?? const <ActivePet>[])
                .map(
                  (pet) => OfflinePetMedicalCard(
                    pet: pet,
                    cachedAt: savedAt ?? 'Session memory',
                  ),
                )
                .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _cards = resolvedCards;
        _rxRecords = cachedRx;
        _lastCachedAt = savedAt;
        _isOfflineFallback = true;
        _noticeMessage = error is ApiException
            ? '${error.message} Showing offline cached Pet Medical Cards & Rx.'
            : 'Network unavailable. Showing offline cached Pet Medical Cards & Rx.';
        _ensureValidSelection();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _ensureValidSelection() {
    if (_cards.isEmpty) {
      _selectedPetId = null;
      return;
    }
    final hasSelected = _cards.any((c) => c.pet.petId == _selectedPetId);
    if (!hasSelected) {
      _selectedPetId = _cards.first.pet.petId;
    }
  }

  OfflinePetMedicalCard? get _activeCard {
    for (final card in _cards) {
      if (card.pet.petId == _selectedPetId) {
        return card;
      }
    }
    return _cards.isNotEmpty ? _cards.first : null;
  }

  List<OfflineRxRecord> _rxForActivePet(OfflinePetMedicalCard card) {
    final combined = <int, OfflineRxRecord>{
      for (final item in card.prescriptions) item.checkupId: item,
      for (final item in _rxRecords)
        if (item.petId == card.pet.petId) item.checkupId: item,
    };
    return combined.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final activeCard = _activeCard;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pet Medical Card & Rx'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(
              child: ClinicalBadge(
                key: const Key('pet_card_sync_badge'),
                label: _isOfflineFallback ? 'Offline Cache' : 'Live Sync',
                backgroundColor: _isOfflineFallback
                    ? ClinicalPalette.warningBg
                    : ClinicalPalette.successBg,
                foregroundColor: _isOfflineFallback
                    ? ClinicalPalette.warningAmber
                    : ClinicalPalette.successGreen,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Reload Medical Cards',
            onPressed: _isLoading ? null : _loadCardsAndRx,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
      ),
      body: _isLoading
          ? const ClinicalLoadingView()
          : ResponsiveClinicalBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_noticeMessage != null) ...[
                    ClinicalBanner(
                      key: const Key('pet_card_offline_banner'),
                      tone: _isOfflineFallback
                          ? BannerTone.warning
                          : BannerTone.info,
                      title: _isOfflineFallback
                          ? 'Offline Medical Card Archive'
                          : 'Clinical Notice',
                      message: _noticeMessage!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_cards.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'No pet medical cards available yet. Connect online once so your pet charts and prescriptions cache for offline access.',
                          style: TextStyle(
                            color: ClinicalPalette.textSecondary,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    )
                  else if (activeCard != null) ...[
                    if (_cards.length > 1) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _cards.map((card) {
                          return ChoiceChip(
                            label: Text(card.pet.petName),
                            selected: card.pet.petId == activeCard.pet.petId,
                            onSelected: (_) {
                              setState(() {
                                _selectedPetId = card.pet.petId;
                              });
                            },
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildMedicalSummaryCard(activeCard),
                    const SizedBox(height: 18),
                    const ClinicalSectionHeader(
                      title: 'Prescriptions (Rx) & Clinical Entries',
                    ),
                    const SizedBox(height: 8),
                    _buildRxList(_rxForActivePet(activeCard)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildMedicalSummaryCard(OfflinePetMedicalCard card) {
    final pet = card.pet;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: ClinicalPalette.primaryTeal,
                  foregroundColor: Colors.white,
                  child: Text(
                    pet.petName.isNotEmpty
                        ? pet.petName.substring(0, 1).toUpperCase()
                        : 'P',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.petName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: ClinicalPalette.deepSlate,
                        ),
                      ),
                      Text(
                        '${pet.petType}${pet.species != null ? ' • ${pet.species}' : ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: ClinicalPalette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ClinicalBadge(label: 'Pet #${pet.petId}'),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Age',
              value: pet.age != null ? '${pet.age} years' : 'Not recorded',
            ),
            _InfoRow(
              label: 'Weight',
              value: pet.weightKg != null
                  ? '${pet.weightKg!.toStringAsFixed(1)} kg'
                  : 'Not recorded',
            ),
            _InfoRow(
              label: 'Active Ailment',
              value: (card.currentAilment?.trim().isNotEmpty ?? false)
                  ? card.currentAilment!
                  : 'None reported on active chart',
            ),
            _InfoRow(
              label: 'Current Medications',
              value: (card.currentMedications?.trim().isNotEmpty ?? false)
                  ? card.currentMedications!
                  : 'No active daily medications listed',
            ),
            if (card.pastConditions != null &&
                card.pastConditions!.trim().isNotEmpty)
              _InfoRow(label: 'Past Conditions', value: card.pastConditions!),
            if (card.description != null && card.description!.trim().isNotEmpty)
              _InfoRow(label: 'Clinical Notes', value: card.description!),
            if (_lastCachedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Offline Cache Saved: $_lastCachedAt',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: ClinicalPalette.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRxList(List<OfflineRxRecord> records) {
    if (records.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No prescriptions or clinical visit notes recorded for this pet yet.',
            style: TextStyle(
              color: ClinicalPalette.textSecondary,
              fontSize: 13.5,
            ),
          ),
        ),
      );
    }

    return Column(
      children: records.map((rx) {
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
                          rx.checkupDate,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: ClinicalPalette.primaryTeal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const ClinicalBadge(label: 'Rx / Chart'),
                    ],
                  ),
                  if (rx.diagnosis != null && rx.diagnosis!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Diagnosis: ${rx.diagnosis}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: ClinicalPalette.deepSlate,
                      ),
                    ),
                  ],
                  if (rx.prescription != null &&
                      rx.prescription!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Rx: ${rx.prescription}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: ClinicalPalette.textPrimary,
                      ),
                    ),
                  ],
                  if (rx.notes != null && rx.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      rx.notes!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: ClinicalPalette.textSecondary,
                      ),
                    ),
                  ],
                  if (rx.attendingVetName != null &&
                      rx.attendingVetName!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Attending Clinician: ${rx.attendingVetName}'
                      '${rx.attendingVetPrc != null ? ' (${rx.attendingVetPrc})' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ClinicalPalette.textSecondary,
                      ),
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
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: ClinicalPalette.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: ClinicalPalette.deepSlate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
