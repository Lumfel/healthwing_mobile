import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_models.dart';
import '../models/user_role.dart';

/// Secure key-value persistence for HealthWing authentication credentials.
///
/// Stores Bearer token, `ws_token`, `user_id`, `username`, `role`, and
/// `prc_license_no` via `flutter_secure_storage`.
class AuthStorage {
  AuthStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String keyToken = 'hw_bearer_token';
  static const String keyWsToken = 'hw_ws_token';
  static const String keyUserId = 'hw_user_id';
  static const String keyUsername = 'hw_username';
  static const String keyRole = 'hw_role';
  static const String keyPrcLicenseNo = 'hw_prc_license_no';

  final FlutterSecureStorage _storage;

  /// Persists a complete [AuthSession] into secure storage.
  Future<void> saveSession(AuthSession session) async {
    await Future.wait([
      _storage.write(key: keyToken, value: session.token),
      _storage.write(key: keyWsToken, value: session.wsToken),
      _storage.write(key: keyUserId, value: session.userId.toString()),
      _storage.write(key: keyUsername, value: session.username),
      _storage.write(key: keyRole, value: session.role.wireValue),
      if (session.prcLicenseNo != null &&
          session.prcLicenseNo!.trim().isNotEmpty)
        _storage.write(
          key: keyPrcLicenseNo,
          value: session.prcLicenseNo!.trim(),
        )
      else
        _storage.delete(key: keyPrcLicenseNo),
    ]);
  }

  /// Convenience helper to persist session fields from a [LoginResponse].
  Future<void> saveFromLoginResponse(LoginResponse response) {
    return saveSession(response.toSession());
  }

  /// Persists only the Bearer token.
  Future<void> writeToken(String token) {
    return _storage.write(key: keyToken, value: token);
  }

  /// Persists only the WebSocket token (`ws_token`).
  Future<void> writeWsToken(String wsToken) {
    return _storage.write(key: keyWsToken, value: wsToken);
  }

  /// Reads the stored Bearer token, or null if absent.
  Future<String?> readToken() async {
    final value = await _storage.read(key: keyToken);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  /// Reads the stored WebSocket authentication token, or null if absent.
  Future<String?> readWsToken() async {
    final value = await _storage.read(key: keyWsToken);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  /// Reads the stored numeric `user_id`, or null if absent or invalid.
  Future<int?> readUserId() async {
    final raw = await _storage.read(key: keyUserId);
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
  }

  /// Reads the stored `username`, or null if absent.
  Future<String?> readUsername() async {
    final value = await _storage.read(key: keyUsername);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  /// Reads the stored strict 3-role RBAC [UserRole], or null if absent/invalid.
  Future<UserRole?> readRole() async {
    final raw = await _storage.read(key: keyRole);
    return UserRole.tryFromWire(raw);
  }

  /// Reads the stored `prc_license_no`, or null if absent (such as for owners).
  Future<String?> readPrcLicenseNo() async {
    final value = await _storage.read(key: keyPrcLicenseNo);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  /// Reads the complete [AuthSession], returning null if any required claim is
  /// missing or invalid.
  Future<AuthSession?> readSession() async {
    final values = await Future.wait<Object?>([
      readToken(),
      readWsToken(),
      readUserId(),
      readUsername(),
      readRole(),
      readPrcLicenseNo(),
    ]);

    final token = values[0] as String?;
    final wsToken = values[1] as String?;
    final userId = values[2] as int?;
    final username = values[3] as String?;
    final role = values[4] as UserRole?;
    final prcLicenseNo = values[5] as String?;

    if (token == null ||
        userId == null ||
        userId <= 0 ||
        username == null ||
        role == null) {
      return null;
    }

    return AuthSession(
      token: token,
      wsToken: wsToken ?? '',
      userId: userId,
      username: username,
      role: role,
      prcLicenseNo: prcLicenseNo,
    );
  }

  /// Returns true when a valid Bearer session is currently stored.
  Future<bool> hasSession() async {
    final session = await readSession();
    return session != null && session.isValid;
  }

  /// Deletes all stored HealthWing authentication keys.
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: keyToken),
      _storage.delete(key: keyWsToken),
      _storage.delete(key: keyUserId),
      _storage.delete(key: keyUsername),
      _storage.delete(key: keyRole),
      _storage.delete(key: keyPrcLicenseNo),
    ]);
  }
}
