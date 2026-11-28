import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../services/app_dependencies.dart';
import '../theme/clinical_theme.dart';

/// Optional route arguments when opening [ReceiptViewerScreen].
class ReceiptViewerRouteArgs {
  const ReceiptViewerRouteArgs({
    this.initialReceiptCode,
    this.recentBlocks = const <ReceiptBlockSummary>[],
  });

  final String? initialReceiptCode;
  final List<ReceiptBlockSummary> recentBlocks;
}

/// Encrypted blockchain receipt viewer enabling `FLAG_SECURE` in `initState`
/// and clearing `FLAG_SECURE` in `dispose`.
///
/// Displays attending clinician name, PRC license (RA 9268), and SHA-256 /
/// Merkle verification hashes.
class ReceiptViewerScreen extends StatefulWidget {
  const ReceiptViewerScreen({
    super.key,
    required this.dependencies,
    this.args,
  });

  final AppDependencies dependencies;
  final ReceiptViewerRouteArgs? args;

  @override
  State<ReceiptViewerScreen> createState() => _ReceiptViewerScreenState();
}

class _ReceiptViewerScreenState extends State<ReceiptViewerScreen> {
  late final TextEditingController _codeController;

  VerifiedReceipt? _verifiedReceipt;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    widget.dependencies.screenSecurity.setSecureScreen(true);

    final initialCode = widget.args?.initialReceiptCode ??
        (widget.args != null && widget.args!.recentBlocks.isNotEmpty
            ? widget.args!.recentBlocks.first.receiptCode
            : '');
    _codeController = TextEditingController(text: initialCode);

    if (initialCode.trim().isNotEmpty) {
      _verifyCode(initialCode.trim());
    }
  }

  @override
  void dispose() {
    widget.dependencies.screenSecurity.setSecureScreen(false);
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode([String? explicitCode]) async {
    final code = (explicitCode ?? _codeController.text).trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Enter a receipt code (for example RCPT-...) to verify.';
      });
      return;
    }

    _codeController.text = code;
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.dependencies.apiClient.verifyReceipt(code);
      if (!mounted) return;
      setState(() {
        _verifiedReceipt = response.receipt;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifiedReceipt = null;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifiedReceipt = null;
        _errorMessage =
            'Unable to verify receipt right now. Live connection is required for encrypted receipt decryption.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentBlocks = widget.args?.recentBlocks ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Encrypted Receipt Verification'),
      ),
      body: ResponsiveClinicalBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ClinicalBanner(
              key: Key('receipt_secure_screen_banner'),
              tone: BannerTone.info,
              title: 'RA 10173 Anti-Screenshot Shield Active',
              message:
                  'Screen capture is disabled while viewing decrypted AES-256-GCM receipt records.',
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const Key('receipt_code_input'),
                      controller: _codeController,
                      enabled: !_isLoading,
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: _verifyCode,
                      decoration: const InputDecoration(
                        labelText: 'Receipt Code',
                        hintText: 'RCPT-20261201-...',
                        prefixIcon: Icon(Icons.qr_code_2_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      key: const Key('receipt_verify_button'),
                      onPressed: _isLoading ? null : () => _verifyCode(),
                      child: _isLoading
                          ? const ClinicalLoadingView(compact: true)
                          : const Text('Decrypt & Verify Blockchain Receipt'),
                    ),
                    if (recentBlocks.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: recentBlocks.take(6).map((b) {
                          return ActionChip(
                            label: Text(
                              b.receiptCode,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            onPressed: _isLoading
                                ? null
                                : () => _verifyCode(b.receiptCode),
                          );
                        }).toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_errorMessage != null) ...[
              ClinicalBanner(
                tone: BannerTone.danger,
                message: _errorMessage!,
              ),
              const SizedBox(height: 12),
            ],
            if (_isLoading && _verifiedReceipt == null)
              const ClinicalLoadingView()
            else if (_verifiedReceipt != null)
              _buildVerifiedReceiptCard(_verifiedReceipt!),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifiedReceiptCard(VerifiedReceipt receipt) {
    final chainOk = receipt.chain.verified;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        receipt.receiptCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: ClinicalPalette.deepSlate,
                        ),
                      ),
                    ),
                    ClinicalBadge(
                      key: const Key('receipt_chain_status_badge'),
                      label: chainOk ? 'CHAIN VERIFIED' : 'HASH MISMATCH',
                      backgroundColor: chainOk
                          ? ClinicalPalette.successBg
                          : ClinicalPalette.emergencyBg,
                      foregroundColor: chainOk
                          ? ClinicalPalette.successGreen
                          : ClinicalPalette.emergencyRed,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${receipt.currency} ${receipt.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ClinicalPalette.primaryTeal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  receipt.payload.serviceSummary.isNotEmpty
                      ? receipt.payload.serviceSummary
                      : receipt.serviceSummary,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ClinicalPalette.deepSlate,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _ReceiptField(
                  label: 'Owner Name',
                  value: receipt.payload.ownerName,
                ),
                _ReceiptField(
                  label: 'Patient (Pet)',
                  value: receipt.payload.petName,
                ),
                if (receipt.payload.notes.trim().isNotEmpty)
                  _ReceiptField(
                    label: 'Clinical Notes',
                    value: receipt.payload.notes,
                  ),
                _ReceiptField(label: 'Status', value: receipt.status),
                _ReceiptField(label: 'Issued At', value: receipt.createdAt),
                _ReceiptField(
                  label: '365-Day Retention Until',
                  value: receipt.expiresAt,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attending Clinician Attribution (RA 9268)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: ClinicalPalette.deepSlate,
                  ),
                ),
                const SizedBox(height: 10),
                _ReceiptField(
                  label: 'Attending Veterinarian',
                  value: receipt.attendingVet.name,
                ),
                _ReceiptField(
                  label: 'PRC License Number',
                  value: receipt.attendingVet.prcLicenseNo,
                ),
                _ReceiptField(label: 'Issued By', value: receipt.issuedBy),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cryptographic Chain Verification',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: ClinicalPalette.deepSlate,
                  ),
                ),
                const SizedBox(height: 10),
                _ReceiptField(
                  label: 'Block Index',
                  value: '#${receipt.blockIndex} (ID ${receipt.blockId})',
                ),
                _HashField(
                  label: 'Block Hash (SHA-256)',
                  hash: receipt.chain.blockHash,
                ),
                _HashField(
                  label: 'Previous Block Hash',
                  hash: receipt.chain.prevHash,
                ),
                _HashField(
                  label: 'Payload Merkle Root',
                  hash: receipt.chain.merkleRoot,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiptField extends StatelessWidget {
  const _ReceiptField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 144,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: ClinicalPalette.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 13,
                color: ClinicalPalette.deepSlate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HashField extends StatelessWidget {
  const _HashField({
    required this.label,
    required this.hash,
  });

  final String label;
  final String hash;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ClinicalPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ClinicalPalette.mutedSurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              hash,
              style: const TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                color: ClinicalPalette.deepSlate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
