import '../config/api_config.dart';
import 'api_client.dart';
import 'auth_storage.dart';
import 'offline_cache.dart';
import 'screen_security.dart';
import 'ws_client.dart';

/// Shared service container injected into HealthWing mobile screens and routes.
class AppDependencies {
  AppDependencies({
    this._config,
    AuthStorage? authStorage,
    this._apiClient,
    OfflineCache? offlineCache,
    ScreenSecurity? screenSecurity,
    this._wsClientBuilder,
  }) : authStorage = authStorage ?? AuthStorage(),
       offlineCache = offlineCache ?? OfflineCache(),
       screenSecurity = screenSecurity ?? ScreenSecurity();

  final ApiConfig? _config;
  final AuthStorage authStorage;
  final OfflineCache offlineCache;
  final ScreenSecurity screenSecurity;
  ApiClient? _apiClient;
  final WsClient Function()? _wsClientBuilder;

  ApiClient get apiClient =>
      _apiClient ??= ApiClient(config: _config, authStorage: authStorage);

  WsClient createWsClient() {
    if (_wsClientBuilder != null) {
      return _wsClientBuilder();
    }
    return WsClient(config: _config, authStorage: authStorage);
  }
}

/// Named route constants for HealthWing role-based navigation.
class AppRoutes {
  const AppRoutes._();

  static const String root = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String ownerHome = '/owner/home';
  static const String emergencyTriage = '/owner/emergency';
  static const String booking = '/owner/booking';
  static const String petCard = '/owner/pet-card';
  static const String receiptViewer = '/receipt';
  static const String vetClinical = '/vet/clinical';
}
