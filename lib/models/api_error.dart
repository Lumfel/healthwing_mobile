import 'json_parsers.dart';

/// Standard API error code constants matching `docs/MOBILE_API_CONTRACT.md`.
class ApiErrorCodes {
  const ApiErrorCodes._();

  static const String invalidJson = 'invalid_json';
  static const String invalidAction = 'invalid_action';
  static const String missingCredentials = 'missing_credentials';
  static const String missingAppointmentTime = 'missing_appointment_time';
  static const String missingPet = 'missing_pet';
  static const String missingCode = 'missing_code';
  static const String missingAction = 'missing_action';
  static const String invalidInput = 'invalid_input';
  static const String invalidRole = 'invalid_role';
  static const String privacyConsentRequired = 'privacy_consent_required';
  static const String weakPassword = 'weak_password';
  static const String prcLicenseRequired = 'prc_license_required';
  static const String authenticationRequired = 'authentication_required';
  static const String invalidOrExpiredToken = 'invalid_or_expired_token';
  static const String invalidCredentials = 'invalid_credentials';
  static const String forbidden = 'forbidden';
  static const String accountPending = 'account_pending';
  static const String accountRejected = 'account_rejected';
  static const String accountNotApproved = 'account_not_approved';
  static const String ownerNotFound = 'owner_not_found';
  static const String veterinarianNotFound = 'veterinarian_not_found';
  static const String petNotFound = 'pet_not_found';
  static const String receiptNotFound = 'receipt_not_found';
  static const String methodNotAllowed = 'method_not_allowed';
  static const String accountExists = 'account_exists';
  static const String prcLicenseExists = 'prc_license_exists';
  static const String activeEmergencyExists = 'active_emergency_exists';
  static const String bookingFailed = 'booking_failed';
  static const String rateLimited = 'rate_limited';
  static const String databaseUnavailable = 'database_unavailable';
  static const String registrationFailed = 'registration_failed';
  static const String receiptDecryptFailed = 'receipt_decrypt_failed';
  static const String saveFailed = 'save_failed';
  static const String updateFailed = 'update_failed';
  static const String emergencySubmissionFailed = 'emergency_submission_failed';
  static const String registrationBusy = 'registration_busy';
  static const String schedulerBusy = 'scheduler_busy';
  static const String triageBusy = 'triage_busy';
  static const String networkError = 'network_error';
  static const String unexpectedResponse = 'unexpected_response';
}

/// Typed exception thrown by the HealthWing API client on HTTP or JSON errors.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.error,
    required this.message,
    this.retryAfter,
    this.details,
  });

  final int statusCode;
  final String error;
  final String message;
  final int? retryAfter;
  final Map<String, dynamic>? details;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isRateLimited => statusCode == 429;
  bool get isServiceBusy => statusCode == 503;

  factory ApiException.fromJson(int statusCode, Map<String, dynamic> json) {
    final retryAfter = JsonParsers.parseNullableInt(json['retry_after']);
    final errorCode = JsonParsers.parseNullableString(json['error'])?.trim();
    final resolvedError = (errorCode != null && errorCode.isNotEmpty)
        ? errorCode
        : (statusCode == 429
            ? ApiErrorCodes.rateLimited
            : ApiErrorCodes.unexpectedResponse);
    final rawMessage = JsonParsers.parseNullableString(json['message'])?.trim();
    final resolvedMessage = (rawMessage != null && rawMessage.isNotEmpty)
        ? rawMessage
        : 'Request failed with HTTP status $statusCode.';

    return ApiException(
      statusCode: statusCode,
      error: resolvedError,
      message: resolvedMessage,
      retryAfter: retryAfter,
      details: json,
    );
  }

  @override
  String toString() {
    final retryPart = retryAfter != null ? ', retry_after: $retryAfter' : '';
    return 'ApiException(statusCode: $statusCode, error: $error, message: $message$retryPart)';
  }
}
