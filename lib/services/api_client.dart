import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/models.dart';
import 'auth_storage.dart';

/// Typed HTTP client for all endpoints defined in `docs/MOBILE_API_CONTRACT.md`.
class ApiClient {
  ApiClient({
    this._config,
    AuthStorage? authStorage,
    http.Client? httpClient,
  })  : _authStorage = authStorage ?? AuthStorage(),
        _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null;

  final ApiConfig? _config;
  final AuthStorage _authStorage;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  ApiConfig get config => _config ?? ApiConfig.current;
  AuthStorage get authStorage => _authStorage;

  /// `POST /api/mobile/auth.php?action=login`
  ///
  /// Authenticates an `owner`, `vet_staff`, or `head_vet` account and returns
  /// Bearer token, `ws_token`, and user profile. When [persistSession] is true,
  /// the returned session is automatically saved to [AuthStorage].
  Future<LoginResponse> login(
    LoginRequest request, {
    bool persistSession = true,
  }) async {
    final json = await _postJson(
      '/auth.php',
      queryParameters: const {'action': 'login'},
      body: request.toJson(),
      requireAuth: false,
    );
    final response = LoginResponse.fromJson(json);
    if (persistSession) {
      await _authStorage.saveFromLoginResponse(response);
    }
    return response;
  }

  /// `POST /api/mobile/auth.php?action=register`
  ///
  /// Registers an `owner` or `vet_staff` account with RA 10173 `privacy_consent`.
  Future<RegisterResponse> register(RegisterRequest request) async {
    final json = await _postJson(
      '/auth.php',
      queryParameters: const {'action': 'register'},
      body: request.toJson(),
      requireAuth: false,
    );
    return RegisterResponse.fromJson(json);
  }

  /// `GET /api/mobile/owner_dashboard.php`
  ///
  /// Requires `owner` role Bearer token.
  Future<OwnerDashboardResponse> getOwnerDashboard({
    String? bearerToken,
  }) async {
    final json = await _getJson(
      '/owner_dashboard.php',
      requireAuth: true,
      bearerToken: bearerToken,
    );
    return OwnerDashboardResponse.fromJson(json);
  }

  /// `POST /api/mobile/booking.php?action=book`
  ///
  /// Requires `owner` role Bearer token.
  Future<BookAppointmentResponse> bookAppointment(
    BookAppointmentRequest request, {
    String? bearerToken,
  }) async {
    final json = await _postJson(
      '/booking.php',
      queryParameters: const {'action': 'book'},
      body: request.toJson(),
      requireAuth: true,
      bearerToken: bearerToken,
    );
    return BookAppointmentResponse.fromJson(json);
  }

  /// `POST /api/mobile/booking.php?action=emergency`
  ///
  /// Requires `owner` role Bearer token.
  Future<EmergencyBookingResponse> submitEmergency(
    EmergencyBookingRequest request, {
    String? bearerToken,
  }) async {
    final json = await _postJson(
      '/booking.php',
      queryParameters: const {'action': 'emergency'},
      body: request.toJson(),
      requireAuth: true,
      bearerToken: bearerToken,
    );
    return EmergencyBookingResponse.fromJson(json);
  }

  /// `GET /api/mobile/receipt.php?code=...`
  ///
  /// Allowed roles: `owner`, `vet_staff`, `head_vet`.
  Future<ReceiptVerificationResponse> verifyReceipt(
    String code, {
    String? bearerToken,
  }) async {
    final json = await _getJson(
      '/receipt.php',
      queryParameters: {'code': code.trim()},
      requireAuth: true,
      bearerToken: bearerToken,
    );
    return ReceiptVerificationResponse.fromJson(json);
  }

  /// `GET /api/mobile/vet_clinical.php?action=overview`
  ///
  /// Allowed roles: `vet_staff`, `head_vet`.
  Future<VetClinicalOverviewResponse> getVetClinicalOverview({
    String? bearerToken,
  }) async {
    final json = await _getJson(
      '/vet_clinical.php',
      queryParameters: const {'action': 'overview'},
      requireAuth: true,
      bearerToken: bearerToken,
    );
    return VetClinicalOverviewResponse.fromJson(json);
  }

  /// `POST /api/mobile/vet_clinical.php?action=save_clinical_note`
  ///
  /// Allowed roles: `vet_staff`, `head_vet`.
  Future<SaveClinicalNoteResponse> saveClinicalNote(
    SaveClinicalNoteRequest request, {
    String? bearerToken,
  }) async {
    final json = await _postJson(
      '/vet_clinical.php',
      queryParameters: const {'action': 'save_clinical_note'},
      body: request.toJson(),
      requireAuth: true,
      bearerToken: bearerToken,
    );
    return SaveClinicalNoteResponse.fromJson(json);
  }

  /// `POST /api/mobile/vet_clinical.php?action=update_room`
  ///
  /// Allowed roles: `vet_staff` (assigned rooms only) and `head_vet` (any room).
  Future<RoomStatusResponse> setRoomStatus(
    RoomStatusRequest request, {
    String? bearerToken,
  }) async {
    final json = await _postJson(
      '/vet_clinical.php',
      queryParameters: const {'action': 'update_room'},
      body: request.toJson(),
      requireAuth: true,
      bearerToken: bearerToken,
    );
    return RoomStatusResponse.fromJson(json);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? queryParameters,
    required bool requireAuth,
    String? bearerToken,
  }) async {
    final headers = await _buildHeaders(
      includeJsonContentType: false,
      requireAuth: requireAuth,
      bearerToken: bearerToken,
    );
    final uri = config.endpointUri(path, queryParameters);

    try {
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(config.requestTimeout);
      return await _handleResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        statusCode: 0,
        error: ApiErrorCodes.networkError,
        message: 'Request timed out while contacting the HealthWing server.',
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        statusCode: 0,
        error: ApiErrorCodes.networkError,
        message: e.message.isNotEmpty
            ? e.message
            : 'Unable to reach the HealthWing server.',
      );
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        error: ApiErrorCodes.networkError,
        message: 'Network error: $e',
      );
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    Map<String, String>? queryParameters,
    required Map<String, dynamic> body,
    required bool requireAuth,
    String? bearerToken,
  }) async {
    final headers = await _buildHeaders(
      includeJsonContentType: true,
      requireAuth: requireAuth,
      bearerToken: bearerToken,
    );
    final uri = config.endpointUri(path, queryParameters);

    try {
      final response = await _httpClient
          .post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(config.requestTimeout);
      return await _handleResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        statusCode: 0,
        error: ApiErrorCodes.networkError,
        message: 'Request timed out while contacting the HealthWing server.',
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        statusCode: 0,
        error: ApiErrorCodes.networkError,
        message: e.message.isNotEmpty
            ? e.message
            : 'Unable to reach the HealthWing server.',
      );
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        error: ApiErrorCodes.networkError,
        message: 'Network error: $e',
      );
    }
  }

  Future<Map<String, String>> _buildHeaders({
    required bool includeJsonContentType,
    required bool requireAuth,
    String? bearerToken,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (includeJsonContentType) 'Content-Type': 'application/json',
    };

    if (requireAuth) {
      final token = (bearerToken?.trim().isNotEmpty ?? false)
          ? bearerToken!.trim()
          : await _authStorage.readToken();
      if (token == null || token.isEmpty) {
        throw const ApiException(
          statusCode: 401,
          error: ApiErrorCodes.authenticationRequired,
          message: 'Missing Authorization Bearer token.',
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    if (response.statusCode == 401) {
      await _authStorage.clear();
    }

    final decoded = _tryDecodeJsonObject(response.body);
    final isHttpSuccess =
        response.statusCode >= 200 && response.statusCode < 300;

    if (decoded == null) {
      throw ApiException(
        statusCode: response.statusCode,
        error: ApiErrorCodes.unexpectedResponse,
        message: 'Invalid JSON response from server (HTTP ${response.statusCode}).',
      );
    }

    final successFlag = decoded['success'];
    if (!isHttpSuccess || successFlag == false) {
      throw ApiException.fromJson(response.statusCode, decoded);
    }

    return decoded;
  }

  Map<String, dynamic>? _tryDecodeJsonObject(String rawBody) {
    final trimmed = rawBody.trim();
    if (trimmed.isEmpty) return null;
    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
      if (parsed is Map) {
        return parsed.map((key, val) => MapEntry(key.toString(), val));
      }
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Releases the internal HTTP client if owned by this [ApiClient].
  void close() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}
