import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../services/app_dependencies.dart';
import '../theme/clinical_theme.dart';

/// Appointment booking screen selecting pet, preferred veterinarian, room/slot,
/// and handling transactional scheduler conflict responses cleanly.
class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.dependencies,
    this.initialPets,
  });

  final AppDependencies dependencies;
  final List<ActivePet>? initialPets;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _SlotOption {
  const _SlotOption({
    required this.time24,
    required this.displayLabel,
    required this.roomLabel,
  });

  final String time24;
  final String displayLabel;
  final String roomLabel;
}

class _VetOption {
  const _VetOption({
    required this.id,
    required this.label,
  });

  final int? id;
  final String label;
}

class _BookingScreenState extends State<BookingScreen> {
  static const List<String> _services = <String>[
    'Wellness Care',
    'Vaccination',
    'Dental Care',
    'Grooming',
    'Surgical Consultation',
  ];

  static const List<_VetOption> _vetOptions = <_VetOption>[
    _VetOption(id: null, label: 'Auto-Assign Optimal Veterinarian'),
    _VetOption(id: 1, label: 'Dr. Camille Reyes (Wellness & Internal Med)'),
    _VetOption(id: 2, label: 'Dr. Marco Santos (Surgery & Dental)'),
    _VetOption(id: 3, label: 'Dr. Elena Cruz (Preventive & Vaccination)'),
  ];

  static const List<_SlotOption> _slotOptions = <_SlotOption>[
    _SlotOption(
      time24: '09:00:00',
      displayLabel: '09:00 AM',
      roomLabel: 'Main Consultation Room',
    ),
    _SlotOption(
      time24: '10:00:00',
      displayLabel: '10:00 AM',
      roomLabel: 'Main Consultation Room',
    ),
    _SlotOption(
      time24: '11:00:00',
      displayLabel: '11:00 AM',
      roomLabel: 'Preventive Wellness Suite',
    ),
    _SlotOption(
      time24: '13:30:00',
      displayLabel: '01:30 PM',
      roomLabel: 'Dental & Diagnostics Room',
    ),
    _SlotOption(
      time24: '15:00:00',
      displayLabel: '03:00 PM',
      roomLabel: 'Main Consultation Room',
    ),
    _SlotOption(
      time24: '16:00:00',
      displayLabel: '04:00 PM',
      roomLabel: 'Surgical Evaluation Suite',
    ),
  ];

  final _formKey = GlobalKey<FormState>();
  final _newPetNameController = TextEditingController();
  final _newPetSpeciesController = TextEditingController(text: 'Dog');
  final _notesController = TextEditingController();

  List<ActivePet> _pets = const <ActivePet>[];
  int? _selectedPetId;
  bool _registerNewPet = false;
  String _selectedService = _services.first;
  int? _preferredVetId;
  late DateTime _selectedDate;
  _SlotOption _selectedSlot = _slotOptions[1];

  bool _isLoadingPets = false;
  bool _isSubmitting = false;
  String? _conflictOrErrorMessage;
  bool _isConflictWarning = false;
  BookedAppointment? _confirmedBooking;
  String? _confirmationMessage;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _selectedDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);

    if (widget.initialPets != null) {
      _pets = widget.initialPets!;
      if (_pets.isNotEmpty) {
        _selectedPetId = _pets.first.petId;
      } else {
        _registerNewPet = true;
      }
    } else {
      _loadPets();
    }
  }

  @override
  void dispose() {
    _newPetNameController.dispose();
    _newPetSpeciesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPets() async {
    setState(() {
      _isLoadingPets = true;
    });
    try {
      final dash = await widget.dependencies.apiClient.getOwnerDashboard();
      if (!mounted) return;
      setState(() {
        _pets = dash.activePets;
        if (_pets.isNotEmpty) {
          _selectedPetId = _pets.first.petId;
          _registerNewPet = false;
        } else {
          _registerNewPet = true;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_pets.isEmpty) {
          _registerNewPet = true;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPets = false;
        });
      }
    }
  }

  String _formatDateYmd(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 120)),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitBooking() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final useNewPet = _registerNewPet || _pets.isEmpty;
    if (!useNewPet && _selectedPetId == null) {
      setState(() {
        _conflictOrErrorMessage = 'Select a pet or enter a new pet name.';
        _isConflictWarning = false;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _conflictOrErrorMessage = null;
      _confirmedBooking = null;
    });

    final appointmentTime =
        '${_formatDateYmd(_selectedDate)} ${_selectedSlot.time24}';
    final detailNotes = [
      'Preferred room: ${_selectedSlot.roomLabel}',
      if (_notesController.text.trim().isNotEmpty) _notesController.text.trim(),
    ].join(' | ');

    try {
      final response = await widget.dependencies.apiClient.bookAppointment(
        BookAppointmentRequest(
          service: _selectedService,
          appointmentTime: appointmentTime,
          petId: useNewPet ? null : _selectedPetId,
          petName: useNewPet ? _newPetNameController.text.trim() : null,
          petSpecies: useNewPet && _newPetSpeciesController.text.trim().isNotEmpty
              ? _newPetSpeciesController.text.trim()
              : null,
          preferredVetId: _preferredVetId,
          details: detailNotes,
        ),
      );

      if (!mounted) return;
      setState(() {
        _confirmedBooking = response.booking;
        _confirmationMessage = response.message;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      final isSlotConflict = e.isConflict ||
          e.isServiceBusy ||
          e.error == ApiErrorCodes.bookingFailed ||
          e.error == ApiErrorCodes.schedulerBusy;
      final retrySuffix =
          e.retryAfter != null ? ' Retry in ${e.retryAfter}s.' : '';
      setState(() {
        _isConflictWarning = isSlotConflict;
        _conflictOrErrorMessage = '${e.message}$retrySuffix';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isConflictWarning = false;
        _conflictOrErrorMessage =
            'Could not complete booking request. Please select another slot or retry.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Clinical Appointment'),
      ),
      body: _isLoadingPets
          ? const ClinicalLoadingView()
          : ResponsiveClinicalBody(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_conflictOrErrorMessage != null) ...[
                      ClinicalBanner(
                        key: const Key('booking_conflict_banner'),
                        tone: _isConflictWarning
                            ? BannerTone.warning
                            : BannerTone.danger,
                        title: _isConflictWarning
                            ? 'Slot Conflict / Scheduler Notice'
                            : 'Booking Error',
                        message: _conflictOrErrorMessage!,
                        onDismiss: () =>
                            setState(() => _conflictOrErrorMessage = null),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_confirmedBooking != null) ...[
                      _buildConfirmationCard(_confirmedBooking!),
                      const SizedBox(height: 16),
                    ],
                    _buildPetCard(),
                    const SizedBox(height: 14),
                    _buildServiceAndVetCard(),
                    const SizedBox(height: 14),
                    _buildSlotAndRoomCard(),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      key: const Key('booking_submit_button'),
                      onPressed: _isSubmitting ? null : _submitBooking,
                      child: _isSubmitting
                          ? const ClinicalLoadingView(compact: true)
                          : const Text('Confirm Appointment Booking'),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildConfirmationCard(BookedAppointment booking) {
    return Card(
      key: const Key('booking_confirmed_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClinicalBanner(
              tone: booking.wasShifted
                  ? BannerTone.warning
                  : BannerTone.success,
              title: booking.wasShifted
                  ? 'Booked Next Open Slot'
                  : 'Appointment Confirmed',
              message: _confirmationMessage ?? 'Appointment scheduled.',
            ),
            const SizedBox(height: 12),
            Text(
              'Schedule #${booking.scheduleId} — ${booking.petName}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: ClinicalPalette.deepSlate,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Service: ${booking.service} (${booking.durationMinutes} mins)',
              style: const TextStyle(color: ClinicalPalette.textSecondary),
            ),
            Text(
              'Assigned Slot: ${booking.appointmentTime}',
              style: const TextStyle(color: ClinicalPalette.textSecondary),
            ),
            if (booking.wasShifted)
              Text(
                'Requested Slot: ${booking.requestedTime}',
                style: const TextStyle(
                  color: ClinicalPalette.warningAmber,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              'Room: ${booking.roomName}',
              style: const TextStyle(color: ClinicalPalette.textSecondary),
            ),
            Text(
              'Veterinarian: Dr. ${booking.veterinarianName}',
              style: const TextStyle(color: ClinicalPalette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    '1. Patient Selection',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: ClinicalPalette.deepSlate,
                    ),
                  ),
                ),
                if (_pets.isNotEmpty)
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _registerNewPet = !_registerNewPet;
                            });
                          },
                    child: Text(
                      _registerNewPet ? 'Use Existing Pet' : 'Add New Pet',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_registerNewPet && _pets.isNotEmpty)
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Registered Pet'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedPetId,
                    isExpanded: true,
                    isDense: true,
                    items: _pets.map((pet) {
                      return DropdownMenuItem<int>(
                        value: pet.petId,
                        child: Text('${pet.petName} (${pet.petType})'),
                      );
                    }).toList(growable: false),
                    onChanged: _isSubmitting
                        ? null
                        : (val) => setState(() => _selectedPetId = val),
                  ),
                ),
              )
            else ...[
              TextFormField(
                key: const Key('booking_new_pet_name'),
                controller: _newPetNameController,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Pet Name *',
                  hintText: 'Mochi',
                ),
                validator: (value) {
                  if ((_registerNewPet || _pets.isEmpty) &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Pet name is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _newPetSpeciesController,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Species / Breed',
                  hintText: 'Dog',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServiceAndVetCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '2. Service & Preferred Clinician',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: ClinicalPalette.deepSlate,
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Clinical Service'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedService,
                  isExpanded: true,
                  isDense: true,
                  items: _services.map((svc) {
                    return DropdownMenuItem<String>(
                      value: svc,
                      child: Text(svc),
                    );
                  }).toList(growable: false),
                  onChanged: _isSubmitting
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() => _selectedService = val);
                          }
                        },
                ),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Preferred Veterinarian',
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _preferredVetId,
                  isExpanded: true,
                  isDense: true,
                  items: _vetOptions.map((vet) {
                    return DropdownMenuItem<int?>(
                      value: vet.id,
                      child: Text(vet.label),
                    );
                  }).toList(growable: false),
                  onChanged: _isSubmitting
                      ? null
                      : (val) => setState(() => _preferredVetId = val),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotAndRoomCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    '3. Room & Time Slot',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: ClinicalPalette.deepSlate,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isSubmitting ? null : _pickDate,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(_formatDateYmd(_selectedDate)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._slotOptions.map((slot) {
              final selected = _selectedSlot.time24 == slot.time24;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _isSubmitting
                      ? null
                      : () => setState(() => _selectedSlot = slot),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? ClinicalPalette.mutedSurface
                          : ClinicalPalette.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? ClinicalPalette.primaryTeal
                            : ClinicalPalette.border,
                        width: selected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 18,
                          color: selected
                              ? ClinicalPalette.primaryTeal
                              : ClinicalPalette.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slot.displayLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: ClinicalPalette.deepSlate,
                                ),
                              ),
                              Text(
                                slot.roomLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ClinicalPalette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              enabled: !_isSubmitting,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Clinical Visit Notes (Optional)',
                hintText: 'Annual booster, appetite changes, dental scaling...',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
