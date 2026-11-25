import 'json_parsers.dart';
import 'user_role.dart';

/// Request payload for `POST /api/mobile/booking.php?action=book`.
class BookAppointmentRequest {
  const BookAppointmentRequest({
    required this.appointmentTime,
    this.service = 'Wellness Care',
    this.petId,
    this.petName,
    this.petSpecies,
    this.preferredVetId,
    this.details,
  });

  final String service;
  final String appointmentTime;
  final int? petId;
  final String? petName;
  final String? petSpecies;
  final int? preferredVetId;
  final String? details;

  Map<String, dynamic> toJson() {
    return {
      'service': service,
      'appointment_time': appointmentTime,
      if (petId != null) 'pet_id': petId,
      if (petName != null) 'pet_name': petName,
      if (petSpecies != null) 'pet_species': petSpecies,
      if (preferredVetId != null) 'preferred_vet_id': preferredVetId,
      if (details != null) 'details': details,
    };
  }
}

/// Booking details returned by `POST /api/mobile/booking.php?action=book`.
class BookedAppointment {
  const BookedAppointment({
    required this.scheduleId,
    required this.ownerId,
    required this.petId,
    required this.petName,
    required this.service,
    required this.appointmentTime,
    required this.endTime,
    required this.durationMinutes,
    required this.status,
    required this.wasShifted,
    required this.requestedTime,
    required this.veterinarianId,
    required this.veterinarianName,
    required this.veterinarianSpecialty,
    required this.roomId,
    required this.roomName,
    required this.notes,
  });

  final int scheduleId;
  final int ownerId;
  final int petId;
  final String petName;
  final String service;
  final String appointmentTime;
  final String endTime;
  final int durationMinutes;
  final String status;
  final bool wasShifted;
  final String requestedTime;
  final int veterinarianId;
  final String veterinarianName;
  final String veterinarianSpecialty;
  final int roomId;
  final String roomName;
  final String notes;

  factory BookedAppointment.fromJson(Map<String, dynamic> json) {
    return BookedAppointment(
      scheduleId: JsonParsers.parseInt(json['schedule_id']),
      ownerId: JsonParsers.parseInt(json['owner_id']),
      petId: JsonParsers.parseInt(json['pet_id']),
      petName: JsonParsers.parseString(json['pet_name']),
      service: JsonParsers.parseString(json['service']),
      appointmentTime: JsonParsers.parseString(json['appointment_time']),
      endTime: JsonParsers.parseString(json['end_time']),
      durationMinutes: JsonParsers.parseInt(json['duration_minutes']),
      status: JsonParsers.parseString(json['status']),
      wasShifted: JsonParsers.parseBool(json['was_shifted']),
      requestedTime: JsonParsers.parseString(json['requested_time']),
      veterinarianId: JsonParsers.parseInt(json['veterinarian_id']),
      veterinarianName: JsonParsers.parseString(json['veterinarian_name']),
      veterinarianSpecialty:
          JsonParsers.parseString(json['veterinarian_specialty']),
      roomId: JsonParsers.parseInt(json['room_id']),
      roomName: JsonParsers.parseString(json['room_name']),
      notes: JsonParsers.parseString(json['notes']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schedule_id': scheduleId,
      'owner_id': ownerId,
      'pet_id': petId,
      'pet_name': petName,
      'service': service,
      'appointment_time': appointmentTime,
      'end_time': endTime,
      'duration_minutes': durationMinutes,
      'status': status,
      'was_shifted': wasShifted,
      'requested_time': requestedTime,
      'veterinarian_id': veterinarianId,
      'veterinarian_name': veterinarianName,
      'veterinarian_specialty': veterinarianSpecialty,
      'room_id': roomId,
      'room_name': roomName,
      'notes': notes,
    };
  }
}

/// Response payload for `POST /api/mobile/booking.php?action=book`.
class BookAppointmentResponse {
  const BookAppointmentResponse({
    required this.success,
    required this.message,
    required this.booking,
  });

  final bool success;
  final String message;
  final BookedAppointment booking;

  factory BookAppointmentResponse.fromJson(Map<String, dynamic> json) {
    return BookAppointmentResponse(
      success: JsonParsers.parseBool(json['success']),
      message: JsonParsers.parseString(json['message']),
      booking: BookedAppointment.fromJson(JsonParsers.parseMap(json['booking'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'booking': booking.toJson(),
    };
  }
}

/// Request payload for `POST /api/mobile/booking.php?action=emergency`.
class EmergencyBookingRequest {
  const EmergencyBookingRequest({
    this.details,
    this.petId,
    this.severityLevel = EmergencySeverity.urgent,
    this.allowConcurrent = false,
  });

  final String? details;
  final int? petId;
  final EmergencySeverity severityLevel;
  final bool allowConcurrent;

  Map<String, dynamic> toJson() {
    return {
      if (details != null) 'details': details,
      if (petId != null) 'pet_id': petId,
      'severity_level': severityLevel.wireValue,
      'allow_concurrent': allowConcurrent,
    };
  }
}

/// Triage allocation metadata inside emergency booking response.
class EmergencyTriageAllocation {
  const EmergencyTriageAllocation({
    required this.bookingId,
    this.queuePosition,
    required this.priorityScore,
    required this.severityLevel,
    this.assignedRoomName,
    this.assignedVetName,
    this.rationale,
  });

  final int bookingId;
  final int? queuePosition;
  final double priorityScore;
  final String severityLevel;
  final String? assignedRoomName;
  final String? assignedVetName;
  final String? rationale;

  factory EmergencyTriageAllocation.fromJson(Map<String, dynamic> json) {
    return EmergencyTriageAllocation(
      bookingId: JsonParsers.parseInt(json['booking_id']),
      queuePosition: JsonParsers.parseNullableInt(json['queue_position']),
      priorityScore: JsonParsers.parseDouble(json['priority_score']),
      severityLevel: JsonParsers.parseString(json['severity_level']),
      assignedRoomName:
          JsonParsers.parseNullableString(json['assigned_room_name']),
      assignedVetName:
          JsonParsers.parseNullableString(json['assigned_vet_name']),
      rationale: JsonParsers.parseNullableString(json['rationale']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'queue_position': queuePosition,
      'priority_score': priorityScore,
      'severity_level': severityLevel,
      'assigned_room_name': assignedRoomName,
      'assigned_vet_name': assignedVetName,
      'rationale': rationale,
    };
  }
}

/// Emergency payload returned by `POST /api/mobile/booking.php?action=emergency`.
class EmergencyBookingData {
  const EmergencyBookingData({
    required this.bookingId,
    required this.ownerId,
    this.petId,
    required this.status,
    required this.severityLevel,
    this.triage,
    required this.preemptedSchedules,
  });

  final int bookingId;
  final int ownerId;
  final int? petId;
  final String status;
  final String severityLevel;
  final EmergencyTriageAllocation? triage;
  final List<Map<String, dynamic>> preemptedSchedules;

  factory EmergencyBookingData.fromJson(Map<String, dynamic> json) {
    final rawTriage = json['triage'];
    final triage = rawTriage is Map
        ? EmergencyTriageAllocation.fromJson(JsonParsers.parseMap(rawTriage))
        : null;

    return EmergencyBookingData(
      bookingId: JsonParsers.parseInt(json['booking_id']),
      ownerId: JsonParsers.parseInt(json['owner_id']),
      petId: JsonParsers.parseNullableInt(json['pet_id']),
      status: JsonParsers.parseString(json['status']),
      severityLevel: JsonParsers.parseString(json['severity_level']),
      triage: triage,
      preemptedSchedules: JsonParsers.parseList(json['preempted_schedules'])
          .map(JsonParsers.parseMap)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'owner_id': ownerId,
      'pet_id': petId,
      'status': status,
      'severity_level': severityLevel,
      'triage': triage?.toJson(),
      'preempted_schedules': preemptedSchedules,
    };
  }
}

/// Response payload for `POST /api/mobile/booking.php?action=emergency`.
class EmergencyBookingResponse {
  const EmergencyBookingResponse({
    required this.success,
    required this.message,
    required this.emergency,
  });

  final bool success;
  final String message;
  final EmergencyBookingData emergency;

  factory EmergencyBookingResponse.fromJson(Map<String, dynamic> json) {
    return EmergencyBookingResponse(
      success: JsonParsers.parseBool(json['success']),
      message: JsonParsers.parseString(json['message']),
      emergency:
          EmergencyBookingData.fromJson(JsonParsers.parseMap(json['emergency'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'emergency': emergency.toJson(),
    };
  }
}
