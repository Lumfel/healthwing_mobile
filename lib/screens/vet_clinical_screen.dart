import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../services/app_dependencies.dart';
import '../services/ws_client.dart';
import '../theme/clinical_theme.dart';

enum _VetSection { triage, notes, rooms }

/// Clinical workstation for `vet_staff` and `head_vet` showing live triage
/// queue, AES-256-GCM clinical note form, and room status controls (surfacing
/// HTTP 403 boundary messages cleanly when `vet_staff` selects unassigned rooms).
class VetClinicalScreen extends StatefulWidget {
  const VetClinicalScreen({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<VetClinicalScreen> createState() => _VetClinicalScreenState();
}

class _VetClinicalScreenState extends State<VetClinicalScreen> {
  final _noteFormKey = GlobalKey<FormState>();
  final _checkupDateController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _prescriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _triageBroadcastController = TextEditingController();

  WsClient? _wsClient;
  StreamSubscription<WsConnectionState>? _wsStateSub;
  StreamSubscription<WsTriageBroadcastEvent>? _wsTriageSub;
  StreamSubscription<WsChatMessageEvent>? _wsChatSub;

  VetClinicalOverviewResponse? _overview;
  _VetSection _activeSection = _VetSection.triage;
  WsConnectionState _wsState = WsConnectionState.disconnected;

  int? _selectedPetId;
  bool _syncPetChart = true;

  bool _isLoadingOverview = true;
  bool _isSavingNote = false;
  int? _savingRoomId;

  String? _bannerMessage;
  String? _bannerTitle;
  BannerTone _bannerTone = BannerTone.info;

  final List<String> _liveTriageLog = <String>[];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _checkupDateController.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _loadOverview();
    _initWebSocket();
  }

  @override
  void dispose() {
    _checkupDateController.dispose();
    _diagnosisController.dispose();
    _prescriptionController.dispose();
    _notesController.dispose();
    _triageBroadcastController.dispose();
    _wsStateSub?.cancel();
    _wsTriageSub?.cancel();
    _wsChatSub?.cancel();
    _wsClient?.dispose();
    super.dispose();
  }

  Future<void> _initWebSocket() async {
    final ws = widget.dependencies.createWsClient();
    _wsClient = ws;

    _wsStateSub = ws.stateStream.listen((nextState) {
      if (!mounted) return;
      setState(() => _wsState = nextState);
    });

    _wsTriageSub = ws.triageBroadcasts.listen((event) {
      if (!mounted) return;
      setState(() {
        _liveTriageLog.insert(
          0,
          'Triage broadcast (${event.timestamp}): ${event.summary ?? 'Queue recalculated'}',
        );
      });
      _loadOverview(silent: true);
    });

    _wsChatSub = ws.chatMessages.listen((event) {
      if (!mounted) return;
      setState(() {
        _liveTriageLog.insert(
          0,
          '[${event.channelKey}] ${event.message.senderName}: ${event.message.messageText}',
        );
      });
    });

    try {
      await ws.connect();
    } catch (_) {
      // REST clinical workstation remains available when WS hub is offline.
    }
  }

  Future<void> _loadOverview({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoadingOverview = true;
      });
    }

    try {
      final data = await widget.dependencies.apiClient.getVetClinicalOverview();
      if (!mounted) return;
      setState(() {
        _overview = data;
        if (data.pets.isNotEmpty &&
            !data.pets.any((p) => p.petId == _selectedPetId)) {
          _selectedPetId = data.pets.first.petId;
        }
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _signOut();
        return;
      }
      if (!mounted || silent) return;
      setState(() {
        _bannerTitle = 'Clinical Workstation Notice';
        _bannerMessage = e.message;
        _bannerTone = BannerTone.danger;
      });
    } catch (_) {
      if (!mounted || silent) return;
      setState(() {
        _bannerTitle = 'Connection Error';
        _bannerMessage = 'Unable to load clinical workstation records.';
        _bannerTone = BannerTone.danger;
      });
    } finally {
      if (mounted && !silent) {
        setState(() {
          _isLoadingOverview = false;
        });
      }
    }
  }

  Future<void> _submitClinicalNote() async {
    FocusScope.of(context).unfocus();
    if (!(_noteFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final petId = _selectedPetId;
    if (petId == null) {
      setState(() {
        _bannerTitle = 'Patient Required';
        _bannerMessage = 'Select a patient before saving a clinical note.';
        _bannerTone = BannerTone.warning;
      });
      return;
    }

    setState(() {
      _isSavingNote = true;
      _bannerMessage = null;
    });

    try {
      final res = await widget.dependencies.apiClient.saveClinicalNote(
        SaveClinicalNoteRequest(
          petId: petId,
          checkupDate: _checkupDateController.text.trim(),
          diagnosis: _diagnosisController.text.trim(),
          prescription: _prescriptionController.text.trim(),
          notes: _notesController.text.trim(),
          updatePetRecord: _syncPetChart,
        ),
      );
      if (!mounted) return;

      _diagnosisController.clear();
      _prescriptionController.clear();
      _notesController.clear();

      setState(() {
        _bannerTitle = 'Clinical Record Saved (${res.cipher})';
        _bannerMessage = '${res.message} Checkup #${res.checkupId}.';
        _bannerTone = BannerTone.success;
      });
      await _loadOverview(silent: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _bannerTitle = 'Save Failed';
        _bannerMessage = e.message;
        _bannerTone = BannerTone.danger;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bannerTitle = 'Save Failed';
        _bannerMessage = 'Could not save encrypted clinical note.';
        _bannerTone = BannerTone.danger;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSavingNote = false;
        });
      }
    }
  }

  Future<void> _applyRoomStatus(ClinicalRoom room, RoomStatus nextStatus) async {
    if (room.parsedStatus == nextStatus) return;

    setState(() {
      _savingRoomId = room.roomId;
      _bannerMessage = null;
    });

    try {
      final res = await widget.dependencies.apiClient.setRoomStatus(
        RoomStatusRequest(roomId: room.roomId, status: nextStatus),
      );
      if (!mounted) return;
      setState(() {
        _bannerTitle = 'Room Status Saved';
        _bannerMessage = '${room.roomName}: ${res.message}';
        _bannerTone = BannerTone.success;
      });
      await _loadOverview(silent: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _bannerTitle = e.isForbidden
            ? 'Room Permission Restricted (HTTP 403)'
            : 'Room Action Failed';
        _bannerMessage = e.message;
        _bannerTone = e.isForbidden ? BannerTone.warning : BannerTone.danger;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bannerTitle = 'Room Action Failed';
        _bannerMessage = 'Unable to change room status right now.';
        _bannerTone = BannerTone.danger;
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingRoomId = null;
        });
      }
    }
  }

  void _broadcastTriageNotice() {
    final ws = _wsClient;
    if (ws == null || !ws.isAuthenticated) return;
    final text = _triageBroadcastController.text.trim();
    ws.sendTriageBroadcast(
      summary: {
        'clinician': _overview?.currentVet.name ?? 'Clinician',
        'note': text.isEmpty ? 'Triage queue reviewed' : text,
      },
    );
    _triageBroadcastController.clear();
    setState(() {
      _bannerTitle = 'Triage Broadcast Sent';
      _bannerMessage = 'Live triage signal sent to connected clients.';
      _bannerTone = BannerTone.info;
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

  @override
  Widget build(BuildContext context) {
    final overview = _overview;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Veterinary Clinical Workstation'),
        actions: [
          IconButton(
            tooltip: 'Verify Receipt',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.receiptViewer),
            icon: const Icon(Icons.verified_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Reload Workstation',
            onPressed: _isLoadingOverview ? null : _loadOverview,
            icon: const Icon(Icons.refresh, size: 20),
          ),
          IconButton(
            tooltip: 'Sign Out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout, size: 20),
          ),
        ],
      ),
      body: _isLoadingOverview && overview == null
          ? const ClinicalLoadingView()
          : ResponsiveClinicalBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (overview != null) ...[
                    _buildClinicianHeader(overview.currentVet, overview.cipher),
                    const SizedBox(height: 12),
                  ],
                  if (_bannerMessage != null) ...[
                    ClinicalBanner(
                      key: const Key('vet_clinical_banner'),
                      tone: _bannerTone,
                      title: _bannerTitle,
                      message: _bannerMessage!,
                      onDismiss: () => setState(() => _bannerMessage = null),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SegmentedButton<_VetSection>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<_VetSection>(
                        value: _VetSection.triage,
                        label: Text('Triage'),
                      ),
                      ButtonSegment<_VetSection>(
                        value: _VetSection.notes,
                        label: Text('Notes & Rx'),
                      ),
                      ButtonSegment<_VetSection>(
                        value: _VetSection.rooms,
                        label: Text('Rooms'),
                      ),
                    ],
                    selected: <_VetSection>{_activeSection},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _activeSection = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (overview != null)
                    switch (_activeSection) {
                      _VetSection.triage => _buildTriageSection(overview),
                      _VetSection.notes => _buildNotesSection(overview),
                      _VetSection.rooms => _buildRoomsSection(overview),
                    },
                ],
              ),
            ),
    );
  }

  Widget _buildClinicianHeader(CurrentVetInfo vet, String cipher) {
    final roleLabel = vet.role.isHeadVet ? 'HEAD VETERINARIAN' : 'VET STAFF';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClinicalPalette.primaryTeal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.medical_information_outlined,
            color: Colors.white,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vet.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
                Text(
                  'PRC: ${vet.prcLicenseNo} • $cipher',
                  style: const TextStyle(
                    color: Color(0xFFD9EEF0),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ClinicalBadge(
            label: roleLabel,
            backgroundColor: Colors.white,
            foregroundColor: ClinicalPalette.primaryTeal,
          ),
        ],
      ),
    );
  }

  Widget _buildTriageSection(VetClinicalOverviewResponse overview) {
    final activeBays = overview.rooms
        .where(
          (r) =>
              r.currentEmergencyId != null ||
              r.status.toLowerCase() == 'ongoing',
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Live Trauma & Triage Monitor',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: ClinicalPalette.deepSlate,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ClinicalBadge(
                      label: _wsState == WsConnectionState.authenticated
                          ? 'WS Active'
                          : 'WS Standby',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (activeBays.isEmpty)
                  const Text(
                    'All trauma and consultation bays are currently clear of active emergencies.',
                    style: TextStyle(
                      fontSize: 13,
                      color: ClinicalPalette.textSecondary,
                    ),
                  )
                else
                  ...activeBays.map((room) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ClinicalPalette.emergencyBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ClinicalPalette.emergencyBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${room.roomName} (${room.roomType})'
                                '${room.currentEmergencyId != null ? ' — Case #${room.currentEmergencyId}' : ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: ClinicalPalette.emergencyRed,
                                ),
                              ),
                            ),
                            ClinicalBadge(label: room.status.toUpperCase()),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _triageBroadcastController,
                        enabled: _wsState == WsConnectionState.authenticated,
                        decoration: InputDecoration(
                          hintText: _wsState == WsConnectionState.authenticated
                              ? 'Broadcast triage queue notice...'
                              : 'Connect WS hub for live broadcast',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(92, 44),
                      ),
                      onPressed: _wsState == WsConnectionState.authenticated
                          ? _broadcastTriageNotice
                          : null,
                      child: const Text('Send'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const ClinicalSectionHeader(title: 'Live Triage Event Log'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: _liveTriageLog.isEmpty
                ? const Text(
                    'Waiting for live emergency queue broadcasts or patient channel events.',
                    style: TextStyle(
                      fontSize: 13,
                      color: ClinicalPalette.textSecondary,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _liveTriageLog.take(8).map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          entry,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: ClinicalPalette.deepSlate,
                          ),
                        ),
                      );
                    }).toList(growable: false),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(VetClinicalOverviewResponse overview) {
    ClinicalPetRecord? selectedPet;
    for (final p in overview.pets) {
      if (p.petId == _selectedPetId) {
        selectedPet = p;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _noteFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Encrypted Clinical Note & Rx Entry',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: ClinicalPalette.deepSlate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (overview.pets.isEmpty)
                    const Text(
                      'No registered patients found.',
                      style: TextStyle(color: ClinicalPalette.textSecondary),
                    )
                  else ...[
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Select Patient',
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedPetId,
                          isExpanded: true,
                          isDense: true,
                          items: overview.pets.map((p) {
                            final owner = p.ownerFullName.isNotEmpty
                                ? ' — ${p.ownerFullName}'
                                : '';
                            return DropdownMenuItem<int>(
                              value: p.petId,
                              child: Text('${p.petName}$owner'),
                            );
                          }).toList(growable: false),
                          onChanged: _isSavingNote
                              ? null
                              : (val) => setState(() => _selectedPetId = val),
                        ),
                      ),
                    ),
                    if (selectedPet != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ClinicalPalette.mutedSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Active Ailment: ${selectedPet.currentAilment?.isNotEmpty == true ? selectedPet.currentAilment : 'None'}\n'
                          'Medications: ${selectedPet.currentMedications?.isNotEmpty == true ? selectedPet.currentMedications : 'None'}\n'
                          'Checkups: ${selectedPet.checkupCount} (Last: ${selectedPet.lastCheckup ?? 'N/A'})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ClinicalPalette.deepSlate,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _checkupDateController,
                    enabled: !_isSavingNote,
                    decoration: const InputDecoration(
                      labelText: 'Checkup Date (YYYY-MM-DD)',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Checkup date is required.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('vet_note_diagnosis'),
                    controller: _diagnosisController,
                    enabled: !_isSavingNote,
                    decoration: const InputDecoration(
                      labelText: 'Clinical Diagnosis',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('vet_note_prescription'),
                    controller: _prescriptionController,
                    enabled: !_isSavingNote,
                    decoration: const InputDecoration(
                      labelText: 'Prescription (Rx)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('vet_note_body'),
                    controller: _notesController,
                    enabled: !_isSavingNote,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'SOAP / Examination Notes',
                    ),
                  ),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _syncPetChart,
                    onChanged: _isSavingNote
                        ? null
                        : (val) => setState(() => _syncPetChart = val ?? false),
                    title: const Text(
                      'Sync diagnosis and Rx onto active patient chart',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('vet_save_note_button'),
                    onPressed: _isSavingNote ? null : _submitClinicalNote,
                    child: _isSavingNote
                        ? const ClinicalLoadingView(compact: true)
                        : const Text('Encrypt & Save Clinical Note'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const ClinicalSectionHeader(title: 'Recent Decrypted Checkups'),
        const SizedBox(height: 8),
        if (overview.recentCheckups.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'No recent checkups recorded.',
                style: TextStyle(color: ClinicalPalette.textSecondary),
              ),
            ),
          )
        else
          ...overview.recentCheckups.take(10).map((chk) {
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
                              '${chk.petName} — #${chk.checkupId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: ClinicalPalette.deepSlate,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            chk.checkupDate,
                            style: const TextStyle(
                              fontSize: 12,
                              color: ClinicalPalette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (chk.diagnosis != null && chk.diagnosis!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Diagnosis: ${chk.diagnosis}'),
                        ),
                      if (chk.prescription != null &&
                          chk.prescription!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('Rx: ${chk.prescription}'),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRoomsSection(VetClinicalOverviewResponse overview) {
    final isHeadVet = overview.currentVet.role.isHeadVet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClinicalBanner(
          tone: BannerTone.info,
          message: isHeadVet
              ? 'Head Veterinarian access: authorized to control status across all clinic rooms.'
              : 'Vet Staff boundary: you may toggle status only on rooms assigned to you.',
        ),
        const SizedBox(height: 12),
        ...overview.rooms.map((room) {
          final isSavingThis = _savingRoomId == room.roomId;
          final currentStatus = room.parsedStatus ?? RoomStatus.idle;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              key: Key('clinical_room_card_${room.roomId}'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.roomName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: ClinicalPalette.deepSlate,
                                ),
                              ),
                              Text(
                                'Type: ${room.roomType} • Room #${room.roomId}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ClinicalPalette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSavingThis)
                          const ClinicalLoadingView(compact: true)
                        else
                          ClinicalBadge(label: room.status.toUpperCase()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<RoomStatus>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment<RoomStatus>(
                          value: RoomStatus.idle,
                          label: Text('Idle'),
                        ),
                        ButtonSegment<RoomStatus>(
                          value: RoomStatus.ongoing,
                          label: Text('Ongoing'),
                        ),
                        ButtonSegment<RoomStatus>(
                          value: RoomStatus.booked,
                          label: Text('Booked'),
                        ),
                      ],
                      selected: <RoomStatus>{currentStatus},
                      onSelectionChanged: isSavingThis
                          ? null
                          : (selection) =>
                                _applyRoomStatus(room, selection.first),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
