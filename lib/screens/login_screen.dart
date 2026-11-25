import 'package:material_ui/material_ui.dart';

import '../config/api_config.dart';
import '../models/models.dart';
import '../services/app_dependencies.dart';
import '../theme/clinical_theme.dart';

/// Username/password login screen routing `owner` to Owner Home and
/// `vet_staff` / `head_vet` to Vet Clinical.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.dependencies.apiClient.login(
        LoginRequest(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        ),
      );
      if (!mounted) return;

      final targetRoute = response.user.role.isOwner
          ? AppRoutes.ownerHome
          : AppRoutes.vetClinical;

      Navigator.of(context).pushNamedAndRemoveUntil(
        targetRoute,
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final retryHint = e.retryAfter != null
          ? ' Retry after ${e.retryAfter} seconds.'
          : '';
      setState(() {
        _errorMessage = '${e.message}$retryHint';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to sign in right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openServerDialog() async {
    final baseCtrl = TextEditingController(text: ApiConfig.current.baseUrl);
    final wsCtrl = TextEditingController(text: ApiConfig.current.wsUrl);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Server Endpoint Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: baseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'REST Base URL',
                    hintText: 'http://10.0.2.2/HealthWing/api/mobile',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: wsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'WebSocket Hub URL',
                    hintText: 'ws://10.0.2.2:8080',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ApiConfig.reset();
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Reset Default'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                ApiConfig.configure(
                  baseUrl: baseCtrl.text.trim(),
                  wsUrl: wsCtrl.text.trim(),
                );
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    baseCtrl.dispose();
    wsCtrl.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Endpoint configuration saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HealthWing Veterinary Portal'),
        actions: [
          IconButton(
            tooltip: 'Endpoint Settings',
            onPressed: _openServerDialog,
            icon: const Icon(Icons.dns_outlined, size: 20),
          ),
        ],
      ),
      body: ResponsiveClinicalBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ClinicalPalette.primaryTeal,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_hospital_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'HealthWing Clinical Mobile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Secure access for Pet Owners, Veterinarian Staff, and Head Veterinarians.',
                    style: TextStyle(
                      color: Color(0xFFD9EEF0),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_errorMessage != null) ...[
              ClinicalBanner(
                tone: BannerTone.danger,
                title: 'Sign-In Failed',
                message: _errorMessage!,
                onDismiss: () => setState(() => _errorMessage = null),
              ),
              const SizedBox(height: 14),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Account Sign In',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: ClinicalPalette.deepSlate,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter your registered username or email address.',
                        style: TextStyle(
                          fontSize: 13,
                          color: ClinicalPalette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('login_username_field'),
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enabled: !_isLoading,
                        decoration: const InputDecoration(
                          labelText: 'Username or Email',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Username or email is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('login_password_field'),
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        enabled: !_isLoading,
                        onFieldSubmitted: (_) => _submitLogin(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        key: const Key('login_submit_button'),
                        onPressed: _isLoading ? null : _submitLogin,
                        child: _isLoading
                            ? const ClinicalLoadingView(compact: true)
                            : const Text('Sign In'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const Key('login_go_register_button'),
              onPressed: _isLoading
                  ? null
                  : () => Navigator.of(context).pushNamed(AppRoutes.register),
              child: const Text('Create Owner or Vet Staff Account'),
            ),
            const SizedBox(height: 18),
            const Text(
              'Protected under RA 10173 (Data Privacy Act of 2012) and RA 9268 (Philippine Veterinary Medicine Act).',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ClinicalPalette.textSecondary,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
