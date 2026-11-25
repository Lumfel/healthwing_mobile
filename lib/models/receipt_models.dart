import 'json_parsers.dart';

/// Hash chain verification metadata inside `GET /api/mobile/receipt.php`.
class ReceiptChain {
  const ReceiptChain({
    required this.blockHash,
    required this.prevHash,
    required this.merkleRoot,
    required this.verified,
  });

  final String blockHash;
  final String prevHash;
  final String merkleRoot;
  final bool verified;

  factory ReceiptChain.fromJson(Map<String, dynamic> json) {
    return ReceiptChain(
      blockHash: JsonParsers.parseString(json['block_hash']),
      prevHash: JsonParsers.parseString(json['prev_hash']),
      merkleRoot: JsonParsers.parseString(json['merkle_root']),
      verified: JsonParsers.parseBool(json['verified']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'block_hash': blockHash,
      'prev_hash': prevHash,
      'merkle_root': merkleRoot,
      'verified': verified,
    };
  }
}

/// Attending clinician RA 9268 metadata on a verified receipt.
class ReceiptAttendingVet {
  const ReceiptAttendingVet({
    required this.veterinarianId,
    required this.name,
    required this.prcLicenseNo,
  });

  final int veterinarianId;
  final String name;
  final String prcLicenseNo;

  factory ReceiptAttendingVet.fromJson(Map<String, dynamic> json) {
    return ReceiptAttendingVet(
      veterinarianId: JsonParsers.parseInt(json['veterinarian_id']),
      name: JsonParsers.parseString(json['name']),
      prcLicenseNo: JsonParsers.parseString(json['prc_license_no']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'veterinarian_id': veterinarianId,
      'name': name,
      'prc_license_no': prcLicenseNo,
    };
  }
}

/// Decrypted receipt payload inside `GET /api/mobile/receipt.php`.
class ReceiptPayload {
  const ReceiptPayload({
    required this.receiptCode,
    required this.ownerName,
    required this.petName,
    required this.serviceSummary,
    required this.amount,
    required this.notes,
    required this.issuedBy,
    this.raw = const <String, dynamic>{},
  });

  final String receiptCode;
  final String ownerName;
  final String petName;
  final String serviceSummary;
  final double amount;
  final String notes;
  final String issuedBy;
  final Map<String, dynamic> raw;

  factory ReceiptPayload.fromJson(Map<String, dynamic> json) {
    return ReceiptPayload(
      receiptCode: JsonParsers.parseString(json['receipt_code']),
      ownerName: JsonParsers.parseString(json['owner_name']),
      petName: JsonParsers.parseString(json['pet_name']),
      serviceSummary: JsonParsers.parseString(json['service_summary']),
      amount: JsonParsers.parseDouble(json['amount']),
      notes: JsonParsers.parseString(json['notes']),
      issuedBy: JsonParsers.parseString(json['issued_by']),
      raw: Map<String, dynamic>.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...raw,
      'receipt_code': receiptCode,
      'owner_name': ownerName,
      'pet_name': petName,
      'service_summary': serviceSummary,
      'amount': amount,
      'notes': notes,
      'issued_by': issuedBy,
    };
  }
}

/// Full verified receipt returned by `GET /api/mobile/receipt.php?code=...`.
class VerifiedReceipt {
  const VerifiedReceipt({
    required this.blockId,
    required this.blockIndex,
    required this.receiptCode,
    this.ownerId,
    required this.referenceType,
    this.referenceId,
    required this.serviceSummary,
    required this.amount,
    required this.currency,
    required this.status,
    required this.issuedBy,
    required this.createdAt,
    required this.expiresAt,
    required this.chain,
    required this.attendingVet,
    required this.payload,
  });

  final int blockId;
  final int blockIndex;
  final String receiptCode;
  final int? ownerId;
  final String referenceType;
  final int? referenceId;
  final String serviceSummary;
  final double amount;
  final String currency;
  final String status;
  final String issuedBy;
  final String createdAt;
  final String expiresAt;
  final ReceiptChain chain;
  final ReceiptAttendingVet attendingVet;
  final ReceiptPayload payload;

  factory VerifiedReceipt.fromJson(Map<String, dynamic> json) {
    return VerifiedReceipt(
      blockId: JsonParsers.parseInt(json['block_id']),
      blockIndex: JsonParsers.parseInt(json['block_index']),
      receiptCode: JsonParsers.parseString(json['receipt_code']),
      ownerId: JsonParsers.parseNullableInt(json['owner_id']),
      referenceType: JsonParsers.parseString(json['reference_type']),
      referenceId: JsonParsers.parseNullableInt(json['reference_id']),
      serviceSummary: JsonParsers.parseString(json['service_summary']),
      amount: JsonParsers.parseDouble(json['amount']),
      currency: JsonParsers.parseString(json['currency'], fallback: 'PHP'),
      status: JsonParsers.parseString(json['status']),
      issuedBy: JsonParsers.parseString(json['issued_by']),
      createdAt: JsonParsers.parseString(json['created_at']),
      expiresAt: JsonParsers.parseString(json['expires_at']),
      chain: ReceiptChain.fromJson(JsonParsers.parseMap(json['chain'])),
      attendingVet: ReceiptAttendingVet.fromJson(
        JsonParsers.parseMap(json['attending_vet']),
      ),
      payload: ReceiptPayload.fromJson(JsonParsers.parseMap(json['payload'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'block_id': blockId,
      'block_index': blockIndex,
      'receipt_code': receiptCode,
      'owner_id': ownerId,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'service_summary': serviceSummary,
      'amount': amount,
      'currency': currency,
      'status': status,
      'issued_by': issuedBy,
      'created_at': createdAt,
      'expires_at': expiresAt,
      'chain': chain.toJson(),
      'attending_vet': attendingVet.toJson(),
      'payload': payload.toJson(),
    };
  }
}

/// Response envelope for `GET /api/mobile/receipt.php?code=...`.
class ReceiptVerificationResponse {
  const ReceiptVerificationResponse({
    required this.success,
    required this.receipt,
  });

  final bool success;
  final VerifiedReceipt receipt;

  factory ReceiptVerificationResponse.fromJson(Map<String, dynamic> json) {
    return ReceiptVerificationResponse(
      success: JsonParsers.parseBool(json['success']),
      receipt: VerifiedReceipt.fromJson(JsonParsers.parseMap(json['receipt'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'receipt': receipt.toJson(),
    };
  }
}
