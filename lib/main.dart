import 'package:material_ui/material_ui.dart';

import 'models/models.dart';
import 'screens/screens.dart';
import 'services/services.dart';
import 'theme/clinical_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiConfig.validateEndpointSecurity();
  runApp(HealthWingApp(dependencies: AppDependencies()));
}

/// Root HealthWing Flutter application with strict 3-role RBAC routing
/// (`owner`, `vet_staff`, `head_vet`).
class HealthWingApp extends StatelessWidget {
  const HealthWingApp({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.root:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => _SessionBootstrapGate(dependencies: dependencies),
        );

      case AppRoutes.login:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => LoginScreen(dependencies: dependencies),
        );

      case AppRoutes.register:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => RegisterScreen(dependencies: dependencies),
        );

      case AppRoutes.ownerHome:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => _RoleGuard(
            dependencies: dependencies,
            allowedRoles: const <UserRole>{UserRole.owner},
            builder: () => OwnerHomeScreen(dependencies: dependencies),
          ),
        );

      case AppRoutes.emergencyTriage:
        final initialDash = settings.arguments is OwnerDashboardResponse
            ? settings.arguments as OwnerDashboardResponse
            : null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => _RoleGuard(
            dependencies: dependencies,
            allowedRoles: const <UserRole>{UserRole.owner},
            builder: () => EmergencyTriageScreen(
              dependencies: dependencies,
              initialDashboard: initialDash,
            ),
          ),
        );

      case AppRoutes.booking:
        final initialPets = settings.arguments is List<ActivePet>
            ? settings.arguments as List<ActivePet>
            : null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => _RoleGuard(
            dependencies: dependencies,
            allowedRoles: const <UserRole>{UserRole.owner},
            builder: () => BookingScreen(
              dependencies: dependencies,
              initialPets: initialPets,
            ),
          ),
        );

      case AppRoutes.petCard:
        final args = settings.arguments is PetCardRouteArgs
            ? settings.arguments as PetCardRouteArgs
            : null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => _RoleGuard(
            dependencies: dependencies,
            allowedRoles: const <UserRole>{UserRole.owner},
            builder: () => PetCardScreen(
              dependencies: dependencies,
              args: args,
            ),
          ),
        );

      case AppRoutes.receiptViewer:
        final ReceiptViewerRouteArgs? args = switch (settings.arguments) {
          ReceiptViewerRouteArgs r => r,
          String code => ReceiptViewerRouteArgs(initialReceiptCode: code),
          _ => null,
        };
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => _RoleGuard(
            dependencies: dependencies,
            allowedRoles: const <UserRole>{
              UserRole.owner,
              UserRole.vetStaff,
              UserRole.headVet,
            },
            builder: () => ReceiptViewerScreen(
              dependencies: dependencies,
              args: args,
            ),
          ),
        );

      case AppRoutes.vetClinical:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => _RoleGuard(
            dependencies: dependencies,
            allowedRoles: const <UserRole>{
              UserRole.vetStaff,
              UserRole.headVet,
            },
            builder: () => VetClinicalScreen(dependencies: dependencies),
          ),
        );

      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => LoginScreen(dependencies: dependencies),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthWing Mobile',
      debugShowCheckedModeBanner: false,
      theme: buildClinicalTheme(),
      initialRoute: AppRoutes.root,
      onGenerateRoute: _onGenerateRoute,
    );
  }
}

/// Startup gate reading stored credentials and dispatching by strict 3-role RBAC.
class _SessionBootstrapGate extends StatefulWidget {
  const _SessionBootstrapGate({
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<_SessionBootstrapGate> createState() => _SessionBootstrapGateState();
}

class _SessionBootstrapGateState extends State<_SessionBootstrapGate> {
  @override
  void initState() {
    super.initState();
    _resolveSession();
  }

  Future<void> _resolveSession() async {
    final session = await widget.dependencies.authStorage.readSession();
    if (!mounted) return;

    if (session == null || !session.isValid) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }

    final targetRoute = session.role.isOwner
        ? AppRoutes.ownerHome
        : AppRoutes.vetClinical;
    Navigator.of(context).pushReplacementNamed(targetRoute);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: ClinicalLoadingView(),
    );
  }
}

/// Enforces strict 3-role RBAC boundaries before building protected screens.
class _RoleGuard extends StatefulWidget {
  const _RoleGuard({
    required this.dependencies,
    required this.allowedRoles,
    required this.builder,
  });

  final AppDependencies dependencies;
  final Set<UserRole> allowedRoles;
  final Widget Function() builder;

  @override
  State<_RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<_RoleGuard> {
  bool _checking = true;
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    _verifyRole();
  }

  Future<void> _verifyRole() async {
    final session = await widget.dependencies.authStorage.readSession();
    if (!mounted) return;

    if (session == null || !session.isValid) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      return;
    }

    if (!widget.allowedRoles.contains(session.role)) {
      final fallback = session.role.isOwner
          ? AppRoutes.ownerHome
          : AppRoutes.vetClinical;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(fallback, (route) => false);
      return;
    }

    setState(() {
      _authorized = true;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || !_authorized) {
      return const Scaffold(
        body: ClinicalLoadingView(),
      );
    }
    return widget.builder();
  }
}
