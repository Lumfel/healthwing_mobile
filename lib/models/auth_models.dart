import 'json_parsers.dart';
import 'user_role.dart';

/// Persisted authentication session stored in secure storage.
class AuthSession {
  const AuthSession({
    required this.token,
    required this.wsToken,
    required this.userId,
    required this.username,
    required this.role,
    this.prcLicenseNo,
  });

  final String token;
  final String wsToken;
  final int userId;
  final String username;
  final UserRole role;
  final String? prcLicenseNo;

  bool get isValid => token.isNotEmpty && userId > 0 && username.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'ws_token': wsToken,
      'user_id': userId,
      'username': username,
      'role': role.wireValue,
      'prc_license_no': prcLicenseNo,
    };
  }
}

/// Authenticated or newly registered HealthWing user model.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.contact,
    this.prcLicenseNo,
    this.specialties,
    this.status,
  });

  final int id;
  final String username;
  final UserRole role;
  final String firstName;
  final String lastName;
  final String email;
  final String contact;
  final String? prcLicenseNo;
  final String? specialties;
  final String? status;

  String get fullName => '$firstName $lastName'.trim();

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawPrc = JsonParsers.parseNullableString(json['prc_license_no']);
    final normalizedPrc =
        (rawPrc != null && rawPrc.trim().isNotEmpty) ? rawPrc.trim() : null;

    return AuthUser(
      id: JsonParsers.parseInt(json['id']),
      username: JsonParsers.parseString(json['username']),
      role: UserRole.fromWire(JsonParsers.parseNullableString(json['role'])),
      firstName: JsonParsers.parseString(json['first_name']),
      lastName: JsonParsers.parseString(json['last_name']),
      email: JsonParsers.parseString(json['email']),
      contact: JsonParsers.parseString(json['contact']),
      prcLicenseNo: normalizedPrc,
      specialties: JsonParsers.parseNullableString(json['specialties']),
      status: JsonParsers.parseNullableString(json['status']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role.wireValue,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'contact': contact,
      'prc_license_no': prcLicenseNo,
      if (specialties != null) 'specialties': specialties,
      if (status != null) 'status': status,
    };
  }
}

/// Request payload for `POST /api/mobile/auth.php?action=login`.
class LoginRequest {
  const LoginRequest({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }
}

/// Response payload for `POST /api/mobile/auth.php?action=login`.
class LoginResponse {
  const LoginResponse({
    required this.success,
    required this.token,
    required this.wsToken,
    required this.user,
  });

  final bool success;
  final String token;
  final String wsToken;
  final AuthUser user;

  AuthSession toSession() {
    return AuthSession(
      token: token,
      wsToken: wsToken,
      userId: user.id,
      username: user.username,
      role: user.role,
      prcLicenseNo: user.prcLicenseNo,
    );
  }

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: JsonParsers.parseBool(json['success']),
      token: JsonParsers.parseString(json['token']),
      wsToken: JsonParsers.parseString(json['ws_token']),
      user: AuthUser.fromJson(JsonParsers.parseMap(json['user'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'token': token,
      'ws_token': wsToken,
      'user': user.toJson(),
    };
  }
}

/// Request payload for `POST /api/mobile/auth.php?action=register`.
///
/// Enforces RA 10173 `privacy_consent` and strict self-registration roles
/// (`owner` or `vet_staff`).
class RegisterRequest {
  const RegisterRequest({
    required this.privacyConsent,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.username,
    required this.password,
    required this.role,
    this.age,
    this.address,
    this.contact,
    this.specialties,
    this.prcLicenseNo,
  });

  final bool privacyConsent;
  final String firstName;
  final String lastName;
  final String email;
  final String username;
  final String password;
  final UserRole role;
  final int? age;
  final String? address;
  final String? contact;
  final String? specialties;
  final String? prcLicenseNo;

  Map<String, dynamic> toJson() {
    return {
      'privacy_consent': privacyConsent,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'username': username,
      'password': password,
      'role': role.wireValue,
      if (age != null) 'age': age,
      if (address != null) 'address': address,
      if (contact != null) 'contact': contact,
      if (specialties != null) 'specialties': specialties,
      if (prcLicenseNo != null) 'prc_license_no': prcLicenseNo,
    };
  }
}

/// Response payload for `POST /api/mobile/auth.php?action=register`.
class RegisterResponse {
  const RegisterResponse({
    required this.success,
    required this.message,
    required this.user,
  });

  final bool success;
  final String message;
  final AuthUser user;

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      success: JsonParsers.parseBool(json['success']),
      message: JsonParsers.parseString(json['message']),
      user: AuthUser.fromJson(JsonParsers.parseMap(json['user'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'user': user.toJson(),
    };
  }
}
