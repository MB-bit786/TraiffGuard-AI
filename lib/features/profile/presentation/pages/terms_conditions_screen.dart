import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/auth/presentation/providers/auth_providers.dart';
import 'package:hscode_auditor/core/constants/app_constants.dart';
import 'package:go_router/go_router.dart';

/// Features high-fidelity legal documentation with interactive acceptance workflows.
class TermsConditionsScreen extends ConsumerStatefulWidget {
  final bool isGatekeeperMode;

  const TermsConditionsScreen({
    super.key,
    this.isGatekeeperMode = false,
  });

  @override
  ConsumerState<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends ConsumerState<TermsConditionsScreen> {
  bool _isProcessing = false;

  /// Handles the formal decline of terms.
  /// Terminates the session and redirects the user to the gateway.
  Future<void> _handleDecline() async {
    await ref.read(authUseCasesProvider).signOut();
    // Re-verification SnackBar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terms must be accepted to use platform.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Handles formal acceptance of terms.
  /// Updates the cloud profile and unlocks platform access.
  Future<void> _handleAccept() async {
    setState(() => _isProcessing = true);

    try {
      final authUseCases = ref.read(authUseCasesProvider);
      final user = ref.read(authUseCasesProvider).currentUser;
      if (user != null) {
        await authUseCases.acceptTerms(user.uid);
        
        // Invalidate the provider to trigger a reactive rebuild in TermsGatekeeper.
        // This will automatically switch the root view to the Dashboard layout 
        // managed by AuthGatekeeper in main.dart.
        ref.invalidate(userAcceptedTermsProvider(user.uid));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? TariffColors.navyMid : const Color(0xFF1565C0),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: !widget.isGatekeeperMode,
        title: Column(
          children: [
            const Text(
              'Terms & Conditions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'LEGAL PROTOCOL ${AppConstants.legalProtocolVersion.toUpperCase()}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        leading: !widget.isGatekeeperMode 
          ? IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            )
          : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegalHeader(),
                  const SizedBox(height: 32),
                  
                  _buildLegalSection(
                    title: '1. AI CLASSIFICATION DISCLAIMER',
                    content: 'The Harmonized System (HS) code recommendations, tariff rates, and duty estimations provided by TariffGuard AI are generated via advanced artificial intelligence models. These outputs are strictly advisory in nature. Users are expressly informed that AI-generated classifications are not a substitute for professional customs brokerage advice or official rulings from national customs authorities. All data must be manually verified against the current WCO nomenclature before formal customs filing.',
                  ),
                  
                  _buildLegalSection(
                    title: '2. LIMITATION OF LIABILITY',
                    content: 'TariffGuard AI, its parent entities, and its developers shall not be held liable for any direct or indirect damages arising from the use of this platform. This includes, but is not limited to: port demurrage fees, administrative fines, customs seizures, cargo delays, or variances in duty/tax calculations enforced by border protection officials. Use of this intelligence platform constitutes acceptance of all commercial risks associated with automated data extraction.',
                  ),
                  
                  _buildLegalSection(
                    title: '3. DATA SECURITY & CLOUD SYNCHRONIZATION',
                    content: 'To ensure operational continuity, cargo manifests and audit reports are archived in a secure local SQLite vault on the device. When connectivity is available, these records are synchronized using AES-256 equivalent encryption to our secure cloud infrastructure powered by Firebase. TariffGuard AI employs multi-tenant data isolation to ensure that operator records remain strictly private and accessible only via verified authentication credentials.',
                  ),

                  _buildLegalSection(
                    title: '4. OPERATIONAL CONDUCT',
                    content: 'Operators agree to use the platform solely for lawful trade intelligence purposes. Any attempt to reverse-engineer the classification engine or bypass security protocols will result in immediate termination of the operator session and revocation of system access.',
                  ),

                  const SizedBox(height: 48),
                  _buildFooterSignature(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // STICKY BOTTOM ACTION BAR (Gatekeeper Mode Only)
          if (widget.isGatekeeperMode) _buildActionBlock(),
        ],
      ),
    );
  }

  Widget _buildLegalHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: TariffColors.amberPending.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: TariffColors.amberPending.withValues(alpha: 0.3)),
          ),
          child: const Text(
            'ENFORCEMENT DATE: JAN 2026',
            style: TextStyle(
              color: TariffColors.amberPending,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Operator Service Agreement',
          style: TextStyle(
            color: isDark ? TariffColors.textPrimary : Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please review the following regulatory protocols governing the use of the TariffGuard AI intelligence platform.',
          style: TextStyle(
            color: isDark ? TariffColors.textSecondary : Colors.black54,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLegalSection({required String title, required String content}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: TariffColors.amberPending,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              color: isDark ? TariffColors.textSecondary : Colors.black87,
              fontSize: 13,
              height: 1.7,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSignature() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        children: [
          Icon(
            Icons.shield_outlined,
            color: isDark ? TariffColors.textMuted : Colors.grey[400],
            size: 32,
          ),
          const SizedBox(height: 16),
          Text(
            'END OF OFFICIAL PROTOCOL',
            style: TextStyle(
              color: (isDark ? TariffColors.textMuted : Colors.grey[400]!).withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBlock() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: isDark ? TariffColors.navyMid : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? TariffColors.divider : Colors.grey[200]!, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isProcessing ? null : _handleDecline,
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? TariffColors.textSecondary : Colors.black54,
                side: BorderSide(color: isDark ? TariffColors.textMuted.withValues(alpha: 0.4) : Colors.grey[300]!, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'DECLINE',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.0),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handleAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: TariffColors.amberPending,
                foregroundColor: isDark ? TariffColors.navyDeep : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isProcessing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(isDark ? TariffColors.navyDeep : Colors.white),
                      ),
                    )
                  : const Text(
                      'ACCEPT & CONTINUE',
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
