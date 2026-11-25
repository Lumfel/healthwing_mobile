/// Safe JSON conversion helpers for HealthWing API payloads.
///
/// PHP `mysqli` endpoints such as `vet_clinical.php?action=overview` can return
/// numeric DB columns as strings or numbers depending on driver settings.
class JsonParsers {
  const JsonParsers._();

  static int parseInt(Object? value, {int fallback = 0}) {
    return parseNullableInt(value) ?? fallback;
  }

  static int? parseNullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt();
    }
    return null;
  }

  static double parseDouble(Object? value, {double fallback = 0.0}) {
    return parseNullableDouble(value) ?? fallback;
  }

  static double? parseNullableDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
  }

  static bool parseBool(Object? value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return fallback;
  }

  static String parseString(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  static String? parseNullableString(Object? value) {
    if (value == null) return null;
    return value.toString();
  }

  static Map<String, dynamic> parseMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  static List<dynamic> parseList(Object? value) {
    if (value is List) {
      return value;
    }
    return const <dynamic>[];
  }
}
