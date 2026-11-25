/// Strict 3-role RBAC model for HealthWing (`owner`, `vet_staff`, `head_vet`).
enum UserRole {
  owner('owner'),
  vetStaff('vet_staff'),
  headVet('head_vet');

  const UserRole(this.wireValue);

  /// Exact role identifier used in the HealthWing API contract and JWT claims.
  final String wireValue;

  bool get isOwner => this == UserRole.owner;
  bool get isVetStaff => this == UserRole.vetStaff;
  bool get isHeadVet => this == UserRole.headVet;
  bool get isVeterinarian =>
      this == UserRole.vetStaff || this == UserRole.headVet;

  /// Parses an exact wire role string, returning null for unsupported roles.
  static UserRole? tryFromWire(String? value) {
    if (value == null) return null;
    switch (value.trim().toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'vet_staff':
        return UserRole.vetStaff;
      case 'head_vet':
        return UserRole.headVet;
      default:
        return null;
    }
  }

  /// Parses a wire role string or throws a [FormatException].
  static UserRole fromWire(String? value) {
    final parsed = tryFromWire(value);
    if (parsed == null) {
      throw FormatException(
        'Unsupported HealthWing role: "$value". Expected owner, vet_staff, or head_vet.',
      );
    }
    return parsed;
  }
}

/// Allowed clinical room statuses in `vet_clinical.php?action=update_room`.
enum RoomStatus {
  idle('idle'),
  ongoing('ongoing'),
  booked('booked');

  const RoomStatus(this.wireValue);

  final String wireValue;

  static RoomStatus? tryFromWire(String? value) {
    if (value == null) return null;
    switch (value.trim().toLowerCase()) {
      case 'idle':
        return RoomStatus.idle;
      case 'ongoing':
        return RoomStatus.ongoing;
      case 'booked':
        return RoomStatus.booked;
      default:
        return null;
    }
  }
}

/// Allowed emergency severity levels in `booking.php?action=emergency`.
enum EmergencySeverity {
  critical('Critical'),
  emergent('Emergent'),
  urgent('Urgent'),
  semiUrgent('Semi-Urgent');

  const EmergencySeverity(this.wireValue);

  final String wireValue;

  static EmergencySeverity? tryFromWire(String? value) {
    if (value == null) return null;
    switch (value.trim().toLowerCase()) {
      case 'critical':
        return EmergencySeverity.critical;
      case 'emergent':
        return EmergencySeverity.emergent;
      case 'urgent':
        return EmergencySeverity.urgent;
      case 'semi-urgent':
        return EmergencySeverity.semiUrgent;
      default:
        return null;
    }
  }
}
