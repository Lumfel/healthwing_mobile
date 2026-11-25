import 'json_parsers.dart';
import 'owner_dashboard_models.dart';

/// Offline prescription / checkup entry cached for owner access without network.
class OfflineRxRecord {
  const OfflineRxRecord({
    required this.checkupId,
    required this.petId,
    required this.petName,
    required this.checkupDate,
    this.diagnosis,
    this.prescription,
    this.notes,
    this.attendingVetName,
    this.attendingVetPrc,
  });

  final int checkupId;
  final int petId;
  final String petName;
  final String checkupDate;
  final String? diagnosis;
  final String? prescription;
  final String? notes;
  final String? attendingVetName;
  final String? attendingVetPrc;

  factory OfflineRxRecord.fromJson(Map<String, dynamic> json) {
    return OfflineRxRecord(
      checkupId: JsonParsers.parseInt(json['checkup_id']),
      petId: JsonParsers.parseInt(json['pet_id']),
      petName: JsonParsers.parseString(json['pet_name']),
      checkupDate: JsonParsers.parseString(json['checkup_date']),
      diagnosis: JsonParsers.parseNullableString(json['diagnosis']),
      prescription: JsonParsers.parseNullableString(json['prescription']),
      notes: JsonParsers.parseNullableString(json['notes']),
      attendingVetName:
          JsonParsers.parseNullableString(json['attending_vet_name']),
      attendingVetPrc:
          JsonParsers.parseNullableString(json['attending_vet_prc']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'checkup_id': checkupId,
      'pet_id': petId,
      'pet_name': petName,
      'checkup_date': checkupDate,
      'diagnosis': diagnosis,
      'prescription': prescription,
      'notes': notes,
      'attending_vet_name': attendingVetName,
      'attending_vet_prc': attendingVetPrc,
    };
  }
}

/// Offline Pet Medical Card combining pet profile, clinical notes, and Rx entries.
class OfflinePetMedicalCard {
  const OfflinePetMedicalCard({
    required this.pet,
    this.description,
    this.pastConditions,
    this.currentAilment,
    this.currentMedications,
    this.prescriptions = const <OfflineRxRecord>[],
    required this.cachedAt,
  });

  final ActivePet pet;
  final String? description;
  final String? pastConditions;
  final String? currentAilment;
  final String? currentMedications;
  final List<OfflineRxRecord> prescriptions;
  final String cachedAt;

  factory OfflinePetMedicalCard.fromJson(Map<String, dynamic> json) {
    return OfflinePetMedicalCard(
      pet: ActivePet.fromJson(JsonParsers.parseMap(json['pet'])),
      description: JsonParsers.parseNullableString(json['description']),
      pastConditions: JsonParsers.parseNullableString(json['past_conditions']),
      currentAilment: JsonParsers.parseNullableString(json['current_ailment']),
      currentMedications:
          JsonParsers.parseNullableString(json['current_medications']),
      prescriptions: JsonParsers.parseList(json['prescriptions'])
          .map((item) => OfflineRxRecord.fromJson(JsonParsers.parseMap(item)))
          .toList(growable: false),
      cachedAt: JsonParsers.parseString(json['cached_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pet': pet.toJson(),
      'description': description,
      'past_conditions': pastConditions,
      'current_ailment': currentAilment,
      'current_medications': currentMedications,
      'prescriptions':
          prescriptions.map((e) => e.toJson()).toList(growable: false),
      'cached_at': cachedAt,
    };
  }
}
