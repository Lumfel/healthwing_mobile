import 'package:flutter/foundation.dart';

/// Configuration for HealthWing mobile REST API and WebSocket endpoints.
class ApiConfig {
  /// Default REST API base URL for Android Emulator reaching Laragon on host.
  ///
  /// For a physical device on the same LAN as Laragon, replace `10.0.2.2` with
  /// your host machine's Laragon LAN IP (for example:
  /// `http://192.168.1.10/HealthWing/api/mobile` or
  /// `http://192.168.1.10/VetSystem/api/mobile` depending on your Laragon folder).
  /// Use `https://` in production deployments.
  static const String defaultBaseUrl = String.fromEnvironment(
    'HW_API_BASE_URL',
    defaultValue: 'http://10.0.2.2/HealthWing/api/mobile',
  );

  /// Default WebSocket URL for Android Emulator reaching `ws_server.php`.
  ///
  /// For a physical device on the same LAN as Laragon, replace `10.0.2.2` with
  /// your host machine's Laragon LAN IP (for example: `ws://192.168.1.10:8080`).
  /// Use `wss://` behind a TLS reverse proxy in production.
  static const String defaultWsUrl = String.fromEnvironment(
    'HW_WS_URL',
    defaultValue: 'ws://10.0.2.2:8080',
  );

  /// Emits a release warning for cleartext REST or WebSocket endpoints.
  ///
  /// Assertions also guard debug/profile builds, where enabled.
  static void validateEndpointSecurity([ApiConfig? config]) {
    final baseUrl = config?.baseUrl ?? current.baseUrl;
    final wsUrl = config?.wsUrl ?? current.wsUrl;
    final hasCleartextEndpoint =
        baseUrl.toLowerCase().startsWith('http://') ||
        wsUrl.toLowerCase().startsWith('ws://');
    assert(
      !hasCleartextEndpoint,
      'HW_API_BASE_URL/HW_WS_URL must use HTTPS/WSS in release builds.',
    );
    if (kReleaseMode && hasCleartextEndpoint) {
      debugPrint(
        'HealthWing security warning: cleartext HTTP/WS endpoint configured.',
      );
    }
  }

  /// Standard loading label required across the HealthWing mobile client.
  static const String loadingLabel = 'Loading...';

  static ApiConfig _current = const ApiConfig();

  /// Active configuration used when no custom [ApiConfig] is injected.
  static ApiConfig get current => _current;

  /// Replaces the active global [ApiConfig].
  static void configure({
    String? baseUrl,
    String? wsUrl,
    String? wsOrigin,
    Duration? requestTimeout,
  }) {
    _current = _current.copyWith(
      baseUrl: baseUrl,
      wsUrl: wsUrl,
      wsOrigin: wsOrigin,
      requestTimeout: requestTimeout,
    );
  }

  /// Resets the global configuration back to default emulator values.
  static void reset() {
    _current = const ApiConfig();
  }

  const ApiConfig({
    this.baseUrl = defaultBaseUrl,
    this.wsUrl = defaultWsUrl,
    this.wsOrigin,
    this.requestTimeout = const Duration(seconds: 20),
  });

  /// Base URL for `/api/mobile` endpoints (without trailing slash).
  final String baseUrl;

  /// WebSocket hub URL (for example `ws://10.0.2.2:8080`).
  final String wsUrl;

  /// Optional explicit `Origin` header sent during the WebSocket handshake.
  ///
  /// When omitted, an origin matching the `wsUrl` host and port is derived so
  /// `ws_server.php` origin checks succeed.
  final String? wsOrigin;

  /// Timeout applied to HTTP requests.
  final Duration requestTimeout;

  /// Base URL normalized without any trailing slash.
  String get normalizedBaseUrl {
    var trimmed = baseUrl.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Builds a full endpoint [Uri] relative to [baseUrl].
  Uri endpointUri(String path, [Map<String, String>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBaseUrl$cleanPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        ...queryParameters,
      },
    );
  }

  /// Parsed WebSocket [Uri].
  Uri get wsUri => Uri.parse(wsUrl.trim());

  /// Resolves the `Origin` header value for the WebSocket handshake.
  String resolveWsOrigin() {
    final explicit = wsOrigin?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final uri = wsUri;
    final scheme = uri.scheme == 'wss' ? 'https' : 'http';
    final hasPort = uri.hasPort && uri.port > 0;
    return hasPort
        ? '$scheme://${uri.host}:${uri.port}'
        : '$scheme://${uri.host}';
  }

  ApiConfig copyWith({
    String? baseUrl,
    String? wsUrl,
    String? wsOrigin,
    Duration? requestTimeout,
  }) {
    return ApiConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      wsUrl: wsUrl ?? this.wsUrl,
      wsOrigin: wsOrigin ?? this.wsOrigin,
      requestTimeout: requestTimeout ?? this.requestTimeout,
    );
  }
}
