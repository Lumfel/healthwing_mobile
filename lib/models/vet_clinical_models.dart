import 'json_parsers.dart';
import 'user_role.dart';

/// Current authenticated veterinarian details in `vet_clinical.php?action=overview`.
class CurrentVetInfo {
  const CurrentVetInfo({
    required this.veterinarianId,
    required this.name,
    required this.role,
    required this.prcLicenseNo,
  });

  final int veterinarianId;
  final String name;
  final UserRole role;
  final String prcLicenseNo;

  factory CurrentVetInfo.fromJson(Map<String, dynamic> json) {
    return CurrentVetInfo(
      veterinarianId: JsonParsers.parseInt(json['veterinarian_id']),
      name: JsonParsers.parseString(json['name']),
      role: UserRole.fromWire(JsonParsers.parseNullableString(json['role'])),
      prcLicenseNo: JsonParsers.parseString(json['prc_license_no']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'veterinarian_id': veterinarianId,
      'name': name,
      'role': role.wireValue,
      'prc_license_no': prcLicenseNo,
    };
  }
}

/// Decrypted pet clinical row returned inside `pets` of `vet_clinical.php?action=overview`.
///
/// Field keys match the DB row convention documented in `MOBILE_API_CONTRACT.md`.
class ClinicalPetRecord {
  const ClinicalPetRecord({
    required this.petId,
    this.ownerId,
    required this.petName,
    this.petType,
    this.species,
    this.age,
    this.weightKg,
    this.photoPath,
    this.ownerFirstName,
    this.ownerLastName,
    this.ownerPhone,
    this.description,
    this.pastConditions,
    this.currentAilment,
    this.currentMedications,
    required this.checkupCount,
    this.lastCheckup,
    this.timeAndDateAdded,
  });

  final int petId;
  final int? ownerId;
  final String petName;
  final String? petType;
  final String? species;
  final int? age;
  final double? weightKg;
  final String? photoPath;
  final String? ownerFirstName;
  final String? ownerLastName;
  final String? ownerPhone;
  final String? description;
  final String? pastConditions;
  final String? currentAilment;
  final String? currentMedications;
  final int checkupCount;
  final String? lastCheckup;
  final String? timeAndDateAdded;

  String get ownerFullName =>
      '${ownerFirstName ?? ''} ${ownerLastName ?? ''}'.trim();

  factory ClinicalPetRecord.fromJson(Map<String, dynamic> json) {
    return ClinicalPetRecord(
      petId: JsonParsers.parseInt(json['Pet_ID']),
      ownerId: JsonParsers.parseNullableInt(json['Owner_ID']),
      petName: JsonParsers.parseString(json['Pet_Name']),
      petType: JsonParsers.parseNullableString(json['Pet_Type']),
      species: JsonParsers.parseNullableString(json['Species']),
      age: JsonParsers.parseNullableInt(json['Age']),
      weightKg: JsonParsers.parseNullableDouble(json['Weight_Kg']),
      photoPath: JsonParsers.parseNullableString(json['Photo_Path']),
      ownerFirstName: JsonParsers.parseNullableString(json['OwnerFirstName']),
      ownerLastName: JsonParsers.parseNullableString(json['OwnerLastName']),
      ownerPhone: JsonParsers.parseNullableString(json['OwnerPhone']),
      description: JsonParsers.parseNullableString(json['Description']),
      pastConditions: JsonParsers.parseNullableString(json['Past_Conditions']),
      currentAilment: JsonParsers.parseNullableString(json['Current_Ailment']),
      currentMedications:
          JsonParsers.parseNullableString(json['Current_Medications']),
      checkupCount: JsonParsers.parseInt(json['CheckupCount']),
      lastCheckup: JsonParsers.parseNullableString(json['LastCheckup']),
      timeAndDateAdded:
          JsonParsers.parseNullableString(json['TimeAndDateAdded']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Pet_ID': petId,
      if (ownerId != null) 'Owner_ID': ownerId,
      'Pet_Name': petName,
      if (petType != null) 'Pet_Type': petType,
      if (species != null) 'Species': species,
      if (age != null) 'Age': age,
      if (weightKg != null) 'Weight_Kg': weightKg,
      if (photoPath != null) 'Photo_Path': photoPath,
      'OwnerFirstName': ownerFirstName,
      'OwnerLastName': ownerLastName,
      if (ownerPhone != null) 'OwnerPhone': ownerPhone,
      'Description': description,
      'Past_Conditions': pastConditions,
      'Current_Ailment': currentAilment,
      'Current_Medications': currentMedications,
      'CheckupCount': checkupCount,
      'LastCheckup': lastCheckup,
      if (timeAndDateAdded != null) 'TimeAndDateAdded': timeAndDateAdded,
    };
  }
}

/// Room row inside `rooms` of `vet_clinical.php?action=overview`.
class ClinicalRoom {
  const ClinicalRoom({
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.status,
    this.veterinarianId,
    this.currentEmergencyId,
    this.currentScheduleId,
  });

  final int roomId;
  final String roomName;
  final String roomType;
  final String status;
  final int? veterinarianId;
  final int? currentEmergencyId;
  final int? currentScheduleId;

  RoomStatus? get parsedStatus => RoomStatus.tryFromWire(status);

  factory ClinicalRoom.fromJson(Map<String, dynamic> json) {
    return ClinicalRoom(
      roomId: JsonParsers.parseInt(json['Room_ID']),
      roomName: JsonParsers.parseString(json['Room_Name']),
      roomType: JsonParsers.parseString(json['Room_Type']),
      status: JsonParsers.parseString(json['Status']),
      veterinarianId: JsonParsers.parseNullableInt(json['Veterinarian_ID']),
      currentEmergencyId:
          JsonParsers.parseNullableInt(json['Current_Emergency_ID']),
      currentScheduleId:
          JsonParsers.parseNullableInt(json['Current_Schedule_ID']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Room_ID': roomId,
      'Room_Name': roomName,
      'Room_Type': roomType,
      'Status': status,
      if (veterinarianId != null) 'Veterinarian_ID': veterinarianId,
      if (currentEmergencyId != null)
        'Current_Emergency_ID': currentEmergencyId,
      if (currentScheduleId != null) 'Current_Schedule_ID': currentScheduleId,
    };
  }
}

/// Decrypted checkup row inside `recent_checkups` of `vet_clinical.php?action=overview`.
class ClinicalCheckup {
  const ClinicalCheckup({
    required this.checkupId,
    required this.petId,
    required this.petName,
    this.veterinarianId,
    this.vetFirst,
    this.vetLast,
    this.diagnosis,
    this.prescription,
    this.notes,
    required this.checkupDate,
  });

  final int checkupId;
  final int petId;
  final String petName;
  final int? veterinarianId;
  final String? vetFirst;
  final String? vetLast;
  final String? diagnosis;
  final String? prescription;
  final String? notes;
  final String checkupDate;

  String get veterinarianFullName {
    final combined = '${vetFirst ?? ''} ${vetLast ?? ''}'.trim();
    return combined.isEmpty ? '' : 'Dr. $combined';
  }

  factory ClinicalCheckup.fromJson(Map<String, dynamic> json) {
    return ClinicalCheckup(
      checkupId: JsonParsers.parseInt(json['Checkup_ID']),
      petId: JsonParsers.parseInt(json['Pet_ID']),
      petName: JsonParsers.parseString(json['Pet_Name']),
      veterinarianId: JsonParsers.parseNullableInt(json['Veterinarian_ID']),
      vetFirst: JsonParsers.parseNullableString(json['VetFirst']),
      vetLast: JsonParsers.parseNullableString(json['VetLast']),
      diagnosis: JsonParsers.parseNullableString(json['Diagnosis']),
      prescription: JsonParsers.parseNullableString(json['Prescription']),
      notes: JsonParsers.parseNullableString(json['Notes']),
      checkupDate: JsonParsers.parseString(json['Checkup_Date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Checkup_ID': checkupId,
      'Pet_ID': petId,
      'Pet_Name': petName,
      'Veterinarian_ID': veterinarianId,
      if (vetFirst != null) 'VetFirst': vetFirst,
      if (vetLast != null) 'VetLast': vetLast,
      'Diagnosis': diagnosis,
      'Prescription': prescription,
      'Notes': notes,
      'Checkup_Date': checkupDate,
    };
  }
}

/// Response payload for `GET /api/mobile/vet_clinical.php?action=overview`.
class VetClinicalOverviewResponse {
  const VetClinicalOverviewResponse({
    required this.success,
    required this.action,
    required this.cipher,
    required this.currentVet,
    required this.pets,
    required this.rooms,
    required this.recentCheckups,
  });

  final bool success;
  final String action;
  final String cipher;
  final CurrentVetInfo currentVet;
  final List<ClinicalPetRecord> pets;
  final List<ClinicalRoom> rooms;
  final List<ClinicalCheckup> recentCheckups;

  factory VetClinicalOverviewResponse.fromJson(Map<String, dynamic> json) {
    return VetClinicalOverviewResponse(
      success: JsonParsers.parseBool(json['success']),
      action: JsonParsers.parseString(json['action']),
      cipher: JsonParsers.parseString(json['cipher']),
      currentVet:
          CurrentVetInfo.fromJson(JsonParsers.parseMap(json['current_vet'])),
      pets: JsonParsers.parseList(json['pets'])
          .map((item) => ClinicalPetRecord.fromJson(JsonParsers.parseMap(item)))
          .toList(growable: false),
      rooms: JsonParsers.parseList(json['rooms'])
          .map((item) => ClinicalRoom.fromJson(JsonParsers.parseMap(item)))
          .toList(growable: false),
      recentCheckups: JsonParsers.parseList(json['recent_checkups'])
          .map((item) => ClinicalCheckup.fromJson(JsonParsers.parseMap(item)))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'action': action,
      'cipher': cipher,
      'current_vet': currentVet.toJson(),
      'pets': pets.map((e) => e.toJson()).toList(growable: false),
      'rooms': rooms.map((e) => e.toJson()).toList(growable: false),
      'recent_checkups':
          recentCheckups.map((e) => e.toJson()).toList(growable: false),
    };
  }
}

/// Request payload for `POST /api/mobile/vet_clinical.php?action=save_clinical_note`.
class SaveClinicalNoteRequest {
  const SaveClinicalNoteRequest({
    required this.petId,
    this.checkupDate,
    this.diagnosis,
    this.prescription,
    this.notes,
    this.updatePetRecord = false,
  });

  final int petId;
  final String? checkupDate;
  final String? diagnosis;
  final String? prescription;
  final String? notes;
  final bool updatePetRecord;

  Map<String, dynamic> toJson() {
    return {
      'pet_id': petId,
      if (checkupDate != null) 'checkup_date': checkupDate,
      if (diagnosis != null) 'diagnosis': diagnosis,
      if (prescription != null) 'prescription': prescription,
      if (notes != null) 'notes': notes,
      'update_pet_record': updatePetRecord,
    };
  }
}

/// Response payload for `POST /api/mobile/vet_clinical.php?action=save_clinical_note`.
class SaveClinicalNoteResponse {
  const SaveClinicalNoteResponse({
    required this.success,
    required this.action,
    required this.message,
    required this.checkupId,
    required this.petId,
    required this.updatedPetRecord,
    required this.cipher,
  });

  final bool success;
  final String action;
  final String message;
  final int checkupId;
  final int petId;
  final bool updatedPetRecord;
  final String cipher;

  factory SaveClinicalNoteResponse.fromJson(Map<String, dynamic> json) {
    return SaveClinicalNoteResponse(
      success: JsonParsers.parseBool(json['success']),
      action: JsonParsers.parseString(json['action']),
      message: JsonParsers.parseString(json['message']),
      checkupId: JsonParsers.parseInt(json['checkup_id']),
      petId: JsonParsers.parseInt(json['pet_id']),
      updatedPetRecord: JsonParsers.parseBool(json['updated_pet_record']),
      cipher: JsonParsers.parseString(json['cipher']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'action': action,
      'message': message,
      'checkup_id': checkupId,
      'pet_id': petId,
      'updated_pet_record': updatedPetRecord,
      'cipher': cipher,
    };
  }
}

/// Request payload for `POST /api/mobile/vet_clinical.php?action=update_room`.
class RoomStatusRequest {
  const RoomStatusRequest({
    required this.roomId,
    required this.status,
  });

  final int roomId;
  final RoomStatus status;

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'status': status.wireValue,
    };
  }
}

/// Response payload for `POST /api/mobile/vet_clinical.php?action=update_room`.
class RoomStatusResponse {
  const RoomStatusResponse({
    required this.success,
    required this.action,
    required this.message,
    required this.roomId,
    required this.status,
    required this.updated,
  });

  final bool success;
  final String action;
  final String message;
  final int roomId;
  final String status;
  final bool updated;

  RoomStatus? get parsedStatus => RoomStatus.tryFromWire(status);

  factory RoomStatusResponse.fromJson(Map<String, dynamic> json) {
    return RoomStatusResponse(
      success: JsonParsers.parseBool(json['success']),
      action: JsonParsers.parseString(json['action']),
      message: JsonParsers.parseString(json['message']),
      roomId: JsonParsers.parseInt(json['room_id']),
      status: JsonParsers.parseString(json['status']),
      updated: JsonParsers.parseBool(json['updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'action': action,
      'message': message,
      'room_id': roomId,
      'status': status,
      'updated': updated,
    };
  }
}
