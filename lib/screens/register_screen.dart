import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../services/app_dependencies.dart';
import '../theme/clinical_theme.dart';

/// Registration screen for `owner` and `vet_staff` accounts enforcing RA 10173
/// `privacy_consent` and RA 9268 `PRC_License_No` requirements.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _prcLicenseController = TextEditingController();
  final _specialtiesController = TextEditingController();

  UserRole _selectedRole = UserRole.owner;
  bool _privacyConsent = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  RegisterResponse? _completedRegistration;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _prcLicenseController.dispose();
    _specialtiesController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (!_privacyConsent) {
      setState(() {
        _errorMessage =
            'Informed consent under the Data Privacy Act (RA 10173) is required to register.';
      });
      return;
    }

    final parsedAge = _ageController.text.trim().isEmpty
        ? null
        : int.tryParse(_ageController.text.trim());

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await widget.dependencies.apiClient.register(
        RegisterRequest(
          privacyConsent: _privacyConsent,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim().toLowerCase(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole,
          age: parsedAge,
          contact: _contactController.text.trim().isEmpty
              ? null
              : _contactController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          prcLicenseNo: _selectedRole == UserRole.vetStaff
              ? _prcLicenseController.text.trim().toUpperCase()
              : null,
          specialties: _selectedRole == UserRole.vetStaff &&
                  _specialtiesController.text.trim().isNotEmpty
              ? _specialtiesController.text.trim()
              : null,
        ),
      );

      if (!mounted) return;
      setState(() {
        _completedRegistration = response;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Registration could not be completed. Please retry.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVetStaff = _selectedRole == UserRole.vetStaff;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create HealthWing Account'),
      ),
      body: ResponsiveClinicalBody(
        child: _completedRegistration != null
            ? _buildSuccessCard(_completedRegistration!)
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      ClinicalBanner(
                        tone: BannerTone.danger,
                        title: 'Registration Error',
                        message: _errorMessage!,
                        onDismiss: () => setState(() => _errorMessage = null),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Account Role',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: ClinicalPalette.deepSlate,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SegmentedButton<UserRole>(
                              segments: const [
                                ButtonSegment<UserRole>(
                                  value: UserRole.owner,
                                  label: Text('Pet Owner'),
                                  icon: Icon(Icons.pets_outlined, size: 18),
                                ),
                                ButtonSegment<UserRole>(
                                  value: UserRole.vetStaff,
                                  label: Text('Vet Staff'),
                                  icon: Icon(
                                    Icons.medical_services_outlined,
                                    size: 18,
                                  ),
                                ),
                              ],
                              selected: <UserRole>{_selectedRole},
                              onSelectionChanged: _isSubmitting
                                  ? null
                                  : (selection) {
                                      setState(() {
                                        _selectedRole = selection.first;
                                      });
                                    },
                            ),
                            if (isVetStaff) ...[
                              const SizedBox(height: 10),
                              const ClinicalBanner(
                                tone: BannerTone.info,
                                message:
                                    'Vet Staff accounts require a valid PRC License Number (RA 9268) and Head Veterinarian approval before clinical login.',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Identity & Contact Details',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: ClinicalPalette.deepSlate,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    key: const Key('register_first_name'),
                                    controller: _firstNameController,
                                    enabled: !_isSubmitting,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'First Name *',
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    key: const Key('register_last_name'),
                                    controller: _lastNameController,
                                    enabled: !_isSubmitting,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Last Name *',
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const Key('register_email'),
                              controller: _emailController,
                              enabled: !_isSubmitting,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email Address *',
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty || !text.contains('@')) {
                                  return 'Enter a valid email address.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const Key('register_username'),
                              controller: _usernameController,
                              enabled: !_isSubmitting,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Username *',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Username is required.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const Key('register_password'),
                              controller: _passwordController,
                              enabled: !_isSubmitting,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password (min 8 characters) *',
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
                                if (value == null || value.length < 8) {
                                  return 'Password must be at least 8 characters.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                SizedBox(
                                  width: 96,
                                  child: TextFormField(
                                    controller: _ageController,
                                    enabled: !_isSubmitting,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Age',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _contactController,
                                    enabled: !_isSubmitting,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                      labelText: 'Contact Number',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressController,
                              enabled: !_isSubmitting,
                              decoration: const InputDecoration(
                                labelText: 'Address',
                              ),
                            ),
                            if (isVetStaff) ...[
                              const SizedBox(height: 14),
                              const Divider(),
                              const SizedBox(height: 10),
                              const Text(
                                'Veterinarian Credentials (RA 9268)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: ClinicalPalette.deepSlate,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                key: const Key('register_prc_license'),
                                controller: _prcLicenseController,
                                enabled: !_isSubmitting,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'PRC_License_No *',
                                  hintText: 'PRC-VET-004821',
                                ),
                                validator: (value) {
                                  if (_selectedRole == UserRole.vetStaff &&
                                      (value == null || value.trim().isEmpty)) {
                                    return 'PRC License Number is required for Vet Staff.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _specialtiesController,
                                enabled: !_isSubmitting,
                                decoration: const InputDecoration(
                                  labelText: 'Clinical Specialties',
                                  hintText: 'Wellness, Surgery, Emergency Care',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RA 10173 Data Privacy Notice',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ClinicalPalette.deepSlate,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'HealthWing collects and encrypts personal, clinical, and professional licensing information strictly for veterinary care, emergency triage, and statutory audit records under Republic Act No. 10173.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: ClinicalPalette.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              key: const Key('register_privacy_consent'),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _privacyConsent,
                              onChanged: _isSubmitting
                                  ? null
                                  : (checked) {
                                      setState(() {
                                        _privacyConsent = checked ?? false;
                                      });
                                    },
                              title: const Text(
                                'I have read the Data Privacy Notice and grant informed consent (RA 10173) *',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ClinicalPalette.deepSlate,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      key: const Key('register_submit_button'),
                      onPressed: _isSubmitting ? null : _submitRegistration,
                      child: _isSubmitting
                          ? const ClinicalLoadingView(compact: true)
                          : Text(
                              isVetStaff
                                  ? 'Submit Vet Staff Registration'
                                  : 'Create Pet Owner Account',
                            ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSuccessCard(RegisterResponse result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClinicalBanner(
              tone: result.user.status == 'Pending'
                  ? BannerTone.warning
                  : BannerTone.success,
              title: 'Registration Recorded',
              message: result.message,
            ),
            const SizedBox(height: 16),
            Text(
              'Username: ${result.user.username}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: ClinicalPalette.deepSlate,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Role: ${result.user.role.wireValue}',
              style: const TextStyle(color: ClinicalPalette.textSecondary),
            ),
            if (result.user.prcLicenseNo != null) ...[
              const SizedBox(height: 4),
              Text(
                'PRC License: ${result.user.prcLicenseNo}',
                style: const TextStyle(color: ClinicalPalette.textSecondary),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Return to Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
