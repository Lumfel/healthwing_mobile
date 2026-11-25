import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../services/app_dependencies.dart';
import '../services/ws_client.dart';
import '../theme/clinical_theme.dart';

/// One-tap Emergency SOS submission and live WebSocket triage queue tracker.
class EmergencyTriageScreen extends StatefulWidget {
  const EmergencyTriageScreen({
    super.key,
    required this.dependencies,
    this.initialDashboard,
  });

  final AppDependencies dependencies;
  final OwnerDashboardResponse? initialDashboard;

  @override
  State<EmergencyTriageScreen> createState() => _EmergencyTriageScreenState();
}

class _EmergencyTriageScreenState extends State<EmergencyTriageScreen> {
  final _detailsController = TextEditingController();
  final _chatInputController = TextEditingController();

  WsClient? _wsClient;
  StreamSubscription<WsConnectionState>? _wsStateSub;
  StreamSubscription<WsTriageBroadcastEvent>? _wsTriageSub;
  StreamSubscription<WsChatMessageEvent>? _wsChatSub;

  List<ActivePet> _pets = const <ActivePet>[];
  List<ActiveEmergencyTriage> _activeCases = const <ActiveEmergencyTriage>[];
  final List<String> _liveStreamFeed = <String>[];
  final List<WsChatMessage> _chatFeed = <WsChatMessage>[];

  int? _selectedPetId;
  EmergencySeverity _severity = EmergencySeverity.urgent;
  WsConnectionState _wsState = WsConnectionState.disconnected;

  bool _isLoadingQueue = true;
  bool _isSubmittingSos = false;
  String? _statusBanner;
  BannerTone _bannerTone = BannerTone.info;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDashboard;
    if (initial != null) {
      _pets = initial.activePets;
      _activeCases = initial.activeEmergencyTriageStatus;
      if (_pets.isNotEmpty) {
        _selectedPetId = _pets.first.petId;
      }
      _isLoadingQueue = false;
    }
    _refreshQueue();
    _initWebSocket();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _chatInputController.dispose();
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
      setState(() {
        _wsState = nextState;
      });
    });

    _wsTriageSub = ws.triageBroadcasts.listen((broadcast) {
      if (!mounted) return;
      setState(() {
        _liveStreamFeed.insert(
          0,
          'Live triage queue broadcast received (${broadcast.timestamp}).',
        );
      });
      _refreshQueue(silent: true);
    });

    _wsChatSub = ws.chatMessages.listen((chatEvent) {
      if (!mounted) return;
      setState(() {
        _chatFeed.insert(0, chatEvent.message);
      });
      if (chatEvent.message.messageType == 'triage_notice') {
        _refreshQueue(silent: true);
      }
    });

    try {
      final channels = _activeCases
          .map((item) => 'booking_${item.bookingId}')
          .toList(growable: false);
      await ws.connect(initialChannels: channels);
    } catch (_) {
      // Offline or WS hub stopped; REST triage polling remains functional.
    }
  }

  Future<void> _refreshQueue({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoadingQueue = true;
      });
    }

    try {
      final dashboard = await widget.dependencies.apiClient.getOwnerDashboard();
      await widget.dependencies.offlineCache.saveOwnerDashboard(
        dashboard.owner.id,
        dashboard,
      );
      if (!mounted) return;

      setState(() {
        _pets = dashboard.activePets;
        _activeCases = dashboard.activeEmergencyTriageStatus;
        if (_selectedPetId == null && _pets.isNotEmpty) {
          _selectedPetId = _pets.first.petId;
        }
      });

      final ws = _wsClient;
      if (ws != null && ws.isAuthenticated) {
        for (final item in dashboard.activeEmergencyTriageStatus) {
          ws.subscribe('booking_${item.bookingId}');
        }
      }
    } on ApiException catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _statusBanner = e.message;
        _bannerTone = BannerTone.danger;
      });
    } finally {
      if (mounted && !silent) {
        setState(() {
          _isLoadingQueue = false;
        });
      }
    }
  }

  Future<void> _submitEmergencySos() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmittingSos = true;
      _statusBanner = null;
    });

    try {
      final response = await widget.dependencies.apiClient.submitEmergency(
        EmergencyBookingRequest(
          petId: _selectedPetId,
          severityLevel: _severity,
          details: _detailsController.text.trim().isEmpty
              ? 'Immediate Emergency SOS dispatch requested from mobile client.'
              : _detailsController.text.trim(),
        ),
      );
      if (!mounted) return;

      final bookingId = response.emergency.bookingId;
      _wsClient?.subscribe('booking_$bookingId');
      _detailsController.clear();

      setState(() {
        _statusBanner = response.message;
        _bannerTone = BannerTone.success;
      });
      await _refreshQueue(silent: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusBanner = e.message;
        _bannerTone = e.isConflict || e.isServiceBusy
            ? BannerTone.warning
            : BannerTone.danger;
      });
      if (e.error == ApiErrorCodes.activeEmergencyExists) {
        await _refreshQueue(silent: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusBanner = 'Could not submit emergency request. Please retry.';
        _bannerTone = BannerTone.danger;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingSos = false;
        });
      }
    }
  }

  void _sendChannelMessage() {
    final ws = _wsClient;
    final text = _chatInputController.text.trim();
    if (ws == null || !ws.isAuthenticated || _activeCases.isEmpty || text.isEmpty) {
      return;
    }
    final channelKey = 'booking_${_activeCases.first.bookingId}';
    ws.sendChatMessage(channelKey: channelKey, messageText: text);
    _chatInputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final wsBadgeLabel = switch (_wsState) {
      WsConnectionState.authenticated => 'WS Live Connected',
      WsConnectionState.connecting ||
      WsConnectionState.authenticating =>
        'WS Connecting',
      WsConnectionState.error => 'WS Offline',
      WsConnectionState.disconnected => 'WS Standby',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS & Live Triage'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: ClinicalBadge(
                label: wsBadgeLabel,
                backgroundColor: _wsState == WsConnectionState.authenticated
                    ? ClinicalPalette.successBg
                    : ClinicalPalette.mutedSurface,
                foregroundColor: _wsState == WsConnectionState.authenticated
                    ? ClinicalPalette.successGreen
                    : ClinicalPalette.textSecondary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Reload Triage Queue',
            onPressed: _isLoadingQueue ? null : _refreshQueue,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
      ),
      body: ResponsiveClinicalBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_statusBanner != null) ...[
              ClinicalBanner(
                tone: _bannerTone,
                message: _statusBanner!,
                onDismiss: () => setState(() => _statusBanner = null),
              ),
              const SizedBox(height: 12),
            ],
            _buildOneTapSosCard(),
            const SizedBox(height: 18),
            const ClinicalSectionHeader(title: 'Live Triage Queue Tracker'),
            const SizedBox(height: 8),
            if (_isLoadingQueue)
              const ClinicalLoadingView()
            else
              _buildActiveQueueSection(),
            if (_activeCases.isNotEmpty) ...[
              const SizedBox(height: 18),
              const ClinicalSectionHeader(title: 'Live Triage Channel Feed'),
              const SizedBox(height: 8),
              _buildLiveChatSection(),
            ],
            if (_liveStreamFeed.isNotEmpty) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _liveStreamFeed.take(4).map((line) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ClinicalPalette.textSecondary,
                          ),
                        ),
                      );
                    }).toList(growable: false),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOneTapSosCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClinicalPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClinicalPalette.emergencyBorder, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'One-Tap Priority Dispatch',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ClinicalPalette.emergencyRed,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap below immediately for urgent dispatch, or refine pet and severity first.',
            style: TextStyle(
              fontSize: 12.5,
              color: ClinicalPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (_pets.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _pets.map((pet) {
                final isSelected = _selectedPetId == pet.petId;
                return ChoiceChip(
                  label: Text(pet.petName),
                  selected: isSelected,
                  onSelected: _isSubmittingSos
                      ? null
                      : (_) => setState(() => _selectedPetId = pet.petId),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: EmergencySeverity.values.map((sev) {
              return ChoiceChip(
                label: Text(sev.wireValue),
                selected: _severity == sev,
                onSelected: _isSubmittingSos
                    ? null
                    : (_) => setState(() => _severity = sev),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailsController,
            enabled: !_isSubmittingSos,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Optional Symptoms / Trauma Notes',
              hintText: 'Labored breathing, acute bleeding, toxin ingestion...',
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            key: const Key('emergency_sos_submit_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ClinicalPalette.emergencyRed,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _isSubmittingSos ? null : _submitEmergencySos,
            icon: _isSubmittingSos
                ? const SizedBox.shrink()
                : const Icon(Icons.emergency_share_outlined, size: 20),
            label: _isSubmittingSos
                ? const ClinicalLoadingView(compact: true)
                : const Text('DISPATCH EMERGENCY SOS NOW'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveQueueSection() {
    if (_activeCases.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No active emergency triage request right now.',
            style: TextStyle(
              color: ClinicalPalette.textSecondary,
              fontSize: 13.5,
            ),
          ),
        ),
      );
    }

    return Column(
      children: _activeCases.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Case #${item.bookingId}${item.petName != null ? ' — ${item.petName}' : ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: ClinicalPalette.deepSlate,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ClinicalBadge(
                        label: item.severityLevel,
                        backgroundColor: ClinicalPalette.emergencyBg,
                        foregroundColor: ClinicalPalette.emergencyRed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'Queue Position',
                          value: item.queuePosition != null
                              ? '#${item.queuePosition}'
                              : 'Calculating',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricTile(
                          label: 'Priority Score',
                          value:
                              '${item.priorityScore.toStringAsFixed(1)} / 100',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Status: ${item.status}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ClinicalPalette.deepSlate,
                    ),
                  ),
                  if (item.assignedRoomName != null)
                    Text(
                      'Assigned Trauma Bay: ${item.assignedRoomName}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: ClinicalPalette.textSecondary,
                      ),
                    ),
                  if (item.assignedVetName != null)
                    Text(
                      'Attending Clinician: ${item.assignedVetName}'
                      '${item.assignedVetPrcLicenseNo != null ? ' (${item.assignedVetPrcLicenseNo})' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: ClinicalPalette.textSecondary,
                      ),
                    ),
                  if (item.triageRationale != null &&
                      item.triageRationale!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.triageRationale!,
                      style: const TextStyle(
                        fontSize: 12.5,
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

  Widget _buildLiveChatSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_chatFeed.isEmpty)
              const Text(
                'Connected to triage channel. Live clinician notices will appear here.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: ClinicalPalette.textSecondary,
                ),
              )
            else
              ..._chatFeed.take(6).map((msg) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ClinicalPalette.mutedSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${msg.senderName} (${msg.senderRole})',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: ClinicalPalette.deepSlate,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          msg.messageText,
                          style: const TextStyle(
                            fontSize: 13,
                            color: ClinicalPalette.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInputController,
                    enabled: _wsState == WsConnectionState.authenticated,
                    decoration: InputDecoration(
                      hintText: _wsState == WsConnectionState.authenticated
                          ? 'Message trauma team...'
                          : 'Live socket offline',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _wsState == WsConnectionState.authenticated
                      ? _sendChannelMessage
                      : null,
                  icon: const Icon(Icons.send, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: ClinicalPalette.mutedSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: ClinicalPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: ClinicalPalette.deepSlate,
            ),
          ),
        ],
      ),
    );
  }
}
