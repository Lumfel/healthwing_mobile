import 'json_parsers.dart';

/// Owner summary inside `GET /api/mobile/owner_dashboard.php`.
class OwnerProfile {
  const OwnerProfile({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.contact,
  });

  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String contact;

  String get fullName => '$firstName $lastName'.trim();

  factory OwnerProfile.fromJson(Map<String, dynamic> json) {
    return OwnerProfile(
      id: JsonParsers.parseInt(json['id']),
      username: JsonParsers.parseString(json['username']),
      firstName: JsonParsers.parseString(json['first_name']),
      lastName: JsonParsers.parseString(json['last_name']),
      email: JsonParsers.parseString(json['email']),
      contact: JsonParsers.parseString(json['contact']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'contact': contact,
    };
  }
}

/// Active pet record inside `active_pets` on owner dashboard.
class ActivePet {
  const ActivePet({
    required this.petId,
    required this.petName,
    required this.petType,
    this.species,
    this.age,
    this.weightKg,
    this.photoPath,
    required this.createdAt,
  });

  final int petId;
  final String petName;
  final String petType;
  final String? species;
  final int? age;
  final double? weightKg;
  final String? photoPath;
  final String createdAt;

  factory ActivePet.fromJson(Map<String, dynamic> json) {
    return ActivePet(
      petId: JsonParsers.parseInt(json['pet_id']),
      petName: JsonParsers.parseString(json['pet_name']),
      petType: JsonParsers.parseString(json['pet_type']),
      species: JsonParsers.parseNullableString(json['species']),
      age: JsonParsers.parseNullableInt(json['age']),
      weightKg: JsonParsers.parseNullableDouble(json['weight_kg']),
      photoPath: JsonParsers.parseNullableString(json['photo_path']),
      createdAt: JsonParsers.parseString(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pet_id': petId,
      'pet_name': petName,
      'pet_type': petType,
      'species': species,
      'age': age,
      'weight_kg': weightKg,
      'photo_path': photoPath,
      'created_at': createdAt,
    };
  }
}

/// Upcoming appointment inside `upcoming_schedules` on owner dashboard.
class UpcomingSchedule {
  const UpcomingSchedule({
    required this.scheduleId,
    this.petId,
    this.petName,
    required this.services,
    required this.appointmentTime,
    this.endTime,
    required this.durationMinutes,
    required this.status,
    this.roomId,
    this.roomName,
    this.veterinarianId,
    this.veterinarianName,
    this.veterinarianPrcLicenseNo,
    this.notes,
    this.preemptedByEmergencyId,
    this.previousAppointmentTime,
  });

  final int scheduleId;
  final int? petId;
  final String? petName;
  final String services;
  final String appointmentTime;
  final String? endTime;
  final int durationMinutes;
  final String status;
  final int? roomId;
  final String? roomName;
  final int? veterinarianId;
  final String? veterinarianName;
  final String? veterinarianPrcLicenseNo;
  final String? notes;
  final int? preemptedByEmergencyId;
  final String? previousAppointmentTime;

  factory UpcomingSchedule.fromJson(Map<String, dynamic> json) {
    return UpcomingSchedule(
      scheduleId: JsonParsers.parseInt(json['schedule_id']),
      petId: JsonParsers.parseNullableInt(json['pet_id']),
      petName: JsonParsers.parseNullableString(json['pet_name']),
      services: JsonParsers.parseString(json['services']),
      appointmentTime: JsonParsers.parseString(json['appointment_time']),
      endTime: JsonParsers.parseNullableString(json['end_time']),
      durationMinutes: JsonParsers.parseInt(json['duration_minutes']),
      status: JsonParsers.parseString(json['status']),
      roomId: JsonParsers.parseNullableInt(json['room_id']),
      roomName: JsonParsers.parseNullableString(json['room_name']),
      veterinarianId: JsonParsers.parseNullableInt(json['veterinarian_id']),
      veterinarianName:
          JsonParsers.parseNullableString(json['veterinarian_name']),
      veterinarianPrcLicenseNo: JsonParsers.parseNullableString(
        json['veterinarian_prc_license_no'],
      ),
      notes: JsonParsers.parseNullableString(json['notes']),
      preemptedByEmergencyId:
          JsonParsers.parseNullableInt(json['preempted_by_emergency_id']),
      previousAppointmentTime: JsonParsers.parseNullableString(
        json['previous_appointment_time'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schedule_id': scheduleId,
      'pet_id': petId,
      'pet_name': petName,
      'services': services,
      'appointment_time': appointmentTime,
      'end_time': endTime,
      'duration_minutes': durationMinutes,
      'status': status,
      'room_id': roomId,
      'room_name': roomName,
      'veterinarian_id': veterinarianId,
      'veterinarian_name': veterinarianName,
      'veterinarian_prc_license_no': veterinarianPrcLicenseNo,
      'notes': notes,
      'preempted_by_emergency_id': preemptedByEmergencyId,
      'previous_appointment_time': previousAppointmentTime,
    };
  }
}

/// Active emergency triage item inside `active_emergency_triage_status`.
class ActiveEmergencyTriage {
  const ActiveEmergencyTriage({
    required this.bookingId,
    this.petId,
    this.petName,
    required this.status,
    required this.severityLevel,
    required this.priorityScore,
    this.queuePosition,
    this.assignedVetId,
    this.assignedVetName,
    this.assignedVetPrcLicenseNo,
    this.assignedRoomId,
    this.assignedRoomName,
    this.triageRationale,
    required this.callEnabled,
    required this.createdAt,
  });

  final int bookingId;
  final int? petId;
  final String? petName;
  final String status;
  final String severityLevel;
  final double priorityScore;
  final int? queuePosition;
  final int? assignedVetId;
  final String? assignedVetName;
  final String? assignedVetPrcLicenseNo;
  final int? assignedRoomId;
  final String? assignedRoomName;
  final String? triageRationale;
  final bool callEnabled;
  final String createdAt;

  factory ActiveEmergencyTriage.fromJson(Map<String, dynamic> json) {
    return ActiveEmergencyTriage(
      bookingId: JsonParsers.parseInt(json['booking_id']),
      petId: JsonParsers.parseNullableInt(json['pet_id']),
      petName: JsonParsers.parseNullableString(json['pet_name']),
      status: JsonParsers.parseString(json['status']),
      severityLevel: JsonParsers.parseString(json['severity_level']),
      priorityScore: JsonParsers.parseDouble(json['priority_score']),
      queuePosition: JsonParsers.parseNullableInt(json['queue_position']),
      assignedVetId: JsonParsers.parseNullableInt(json['assigned_vet_id']),
      assignedVetName:
          JsonParsers.parseNullableString(json['assigned_vet_name']),
      assignedVetPrcLicenseNo: JsonParsers.parseNullableString(
        json['assigned_vet_prc_license_no'],
      ),
      assignedRoomId: JsonParsers.parseNullableInt(json['assigned_room_id']),
      assignedRoomName:
          JsonParsers.parseNullableString(json['assigned_room_name']),
      triageRationale:
          JsonParsers.parseNullableString(json['triage_rationale']),
      callEnabled: JsonParsers.parseBool(json['call_enabled']),
      createdAt: JsonParsers.parseString(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'pet_id': petId,
      'pet_name': petName,
      'status': status,
      'severity_level': severityLevel,
      'priority_score': priorityScore,
      'queue_position': queuePosition,
      'assigned_vet_id': assignedVetId,
      'assigned_vet_name': assignedVetName,
      'assigned_vet_prc_license_no': assignedVetPrcLicenseNo,
      'assigned_room_id': assignedRoomId,
      'assigned_room_name': assignedRoomName,
      'triage_rationale': triageRationale,
      'call_enabled': callEnabled,
      'created_at': createdAt,
    };
  }
}

/// Receipt block summary inside `active_receipt_blocks`.
class ReceiptBlockSummary {
  const ReceiptBlockSummary({
    required this.blockId,
    required this.blockIndex,
    required this.receiptCode,
    required this.referenceType,
    this.referenceId,
    required this.serviceSummary,
    required this.amount,
    required this.currency,
    required this.status,
    required this.blockHash,
    required this.prevHash,
    required this.merkleRoot,
    required this.issuedBy,
    required this.attendingVetId,
    required this.attendingVetName,
    required this.attendingClinicianPrc,
    required this.createdAt,
    required this.expiresAt,
  });

  final int blockId;
  final int blockIndex;
  final String receiptCode;
  final String referenceType;
  final int? referenceId;
  final String serviceSummary;
  final double amount;
  final String currency;
  final String status;
  final String blockHash;
  final String prevHash;
  final String merkleRoot;
  final String issuedBy;
  final int attendingVetId;
  final String attendingVetName;
  final String attendingClinicianPrc;
  final String createdAt;
  final String expiresAt;

  factory ReceiptBlockSummary.fromJson(Map<String, dynamic> json) {
    return ReceiptBlockSummary(
      blockId: JsonParsers.parseInt(json['block_id']),
      blockIndex: JsonParsers.parseInt(json['block_index']),
      receiptCode: JsonParsers.parseString(json['receipt_code']),
      referenceType: JsonParsers.parseString(json['reference_type']),
      referenceId: JsonParsers.parseNullableInt(json['reference_id']),
      serviceSummary: JsonParsers.parseString(json['service_summary']),
      amount: JsonParsers.parseDouble(json['amount']),
      currency: JsonParsers.parseString(json['currency'], fallback: 'PHP'),
      status: JsonParsers.parseString(json['status']),
      blockHash: JsonParsers.parseString(json['block_hash']),
      prevHash: JsonParsers.parseString(json['prev_hash']),
      merkleRoot: JsonParsers.parseString(json['merkle_root']),
      issuedBy: JsonParsers.parseString(json['issued_by']),
      attendingVetId: JsonParsers.parseInt(json['attending_vet_id']),
      attendingVetName: JsonParsers.parseString(json['attending_vet_name']),
      attendingClinicianPrc:
          JsonParsers.parseString(json['attending_clinician_prc']),
      createdAt: JsonParsers.parseString(json['created_at']),
      expiresAt: JsonParsers.parseString(json['expires_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'block_id': blockId,
      'block_index': blockIndex,
      'receipt_code': receiptCode,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'service_summary': serviceSummary,
      'amount': amount,
      'currency': currency,
      'status': status,
      'block_hash': blockHash,
      'prev_hash': prevHash,
      'merkle_root': merkleRoot,
      'issued_by': issuedBy,
      'attending_vet_id': attendingVetId,
      'attending_vet_name': attendingVetName,
      'attending_clinician_prc': attendingClinicianPrc,
      'created_at': createdAt,
      'expires_at': expiresAt,
    };
  }
}

/// Metadata block inside `GET /api/mobile/owner_dashboard.php`.
class OwnerDashboardMeta {
  const OwnerDashboardMeta({
    required this.purgedExpiredReceipts,
    required this.serverTime,
  });

  final int purgedExpiredReceipts;
  final String serverTime;

  factory OwnerDashboardMeta.fromJson(Map<String, dynamic> json) {
    return OwnerDashboardMeta(
      purgedExpiredReceipts:
          JsonParsers.parseInt(json['purged_expired_receipts']),
      serverTime: JsonParsers.parseString(json['server_time']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'purged_expired_receipts': purgedExpiredReceipts,
      'server_time': serverTime,
    };
  }
}

/// Full response payload for `GET /api/mobile/owner_dashboard.php`.
class OwnerDashboardResponse {
  const OwnerDashboardResponse({
    required this.success,
    required this.owner,
    required this.activePets,
    required this.upcomingSchedules,
    required this.activeEmergencyTriageStatus,
    required this.activeReceiptBlocks,
    required this.meta,
  });

  final bool success;
  final OwnerProfile owner;
  final List<ActivePet> activePets;
  final List<UpcomingSchedule> upcomingSchedules;
  final List<ActiveEmergencyTriage> activeEmergencyTriageStatus;
  final List<ReceiptBlockSummary> activeReceiptBlocks;
  final OwnerDashboardMeta meta;

  factory OwnerDashboardResponse.fromJson(Map<String, dynamic> json) {
    return OwnerDashboardResponse(
      success: JsonParsers.parseBool(json['success']),
      owner: OwnerProfile.fromJson(JsonParsers.parseMap(json['owner'])),
      activePets: JsonParsers.parseList(json['active_pets'])
          .map((item) => ActivePet.fromJson(JsonParsers.parseMap(item)))
          .toList(growable: false),
      upcomingSchedules: JsonParsers.parseList(json['upcoming_schedules'])
          .map((item) => UpcomingSchedule.fromJson(JsonParsers.parseMap(item)))
          .toList(growable: false),
      activeEmergencyTriageStatus:
          JsonParsers.parseList(json['active_emergency_triage_status'])
              .map(
                (item) =>
                    ActiveEmergencyTriage.fromJson(JsonParsers.parseMap(item)),
              )
              .toList(growable: false),
      activeReceiptBlocks: JsonParsers.parseList(json['active_receipt_blocks'])
          .map(
            (item) => ReceiptBlockSummary.fromJson(JsonParsers.parseMap(item)),
          )
          .toList(growable: false),
      meta: OwnerDashboardMeta.fromJson(JsonParsers.parseMap(json['meta'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'owner': owner.toJson(),
      'active_pets': activePets.map((e) => e.toJson()).toList(growable: false),
      'upcoming_schedules':
          upcomingSchedules.map((e) => e.toJson()).toList(growable: false),
      'active_emergency_triage_status': activeEmergencyTriageStatus
          .map((e) => e.toJson())
          .toList(growable: false),
      'active_receipt_blocks':
          activeReceiptBlocks.map((e) => e.toJson()).toList(growable: false),
      'meta': meta.toJson(),
    };
  }
}
