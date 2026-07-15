import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/core/services/auth_service.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/invoice_list_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/dashboard_stats_provider.dart';
import 'package:hscode_auditor/core/constants/app_constants.dart';
import 'package:go_router/go_router.dart';
import 'package:hscode_auditor/config/routes/app_routes.dart';

/// Premium UI Engineer: Corporate Profile & Account Security.
/// Displays authenticated user metadata and historical sync telemetry.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure invoice list is fresh when entering profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(invoiceListProvider.notifier).fetchInvoices();
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('User ID copied to clipboard'),
        backgroundColor: TariffColors.navyElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TariffColors.navyMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(color: TariffColors.textPrimary)),
        content: const Text('Are you sure you want to terminate the current session?',
            style: TextStyle(color: TariffColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('CANCEL', style: TextStyle(color: TariffColors.textMuted)),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: const Text('SIGN OUT',
                style: TextStyle(color: TariffColors.crimsonRisk, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authServiceProvider).signOut();
      // The AuthGatekeeper in main.dart handles the primary swap automatically.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String email = user?.email ?? 'OPERATOR SESSION';
    final String uid = user?.uid ?? 'N/A';
    final String created = user?.metadata.creationTime?.toString().split(' ').first ?? 'Unknown';

    return Scaffold(
      backgroundColor: TariffColors.navyDeep,
      appBar: AppBar(
        backgroundColor: TariffColors.navyMid,
        elevation: 0,
        centerTitle: true,
        title: const Text('Operator Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        // No leading button as this is a primary tab destination
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. BRANDED HEADER
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (context, snapshot) {
                String fullName = 'OPERATOR';
                
                if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                  final data = snapshot.data!.data();
                  if (data != null && data.containsKey('fullName')) {
                    fullName = data['fullName'] ?? 'OPERATOR';
                  }
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: const BoxDecoration(
                    color: TariffColors.navyMid,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: TariffColors.amberPending, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: TariffColors.amberPending.withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.account_circle_rounded,
                          size: 100,
                          color: TariffColors.amberPending,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        fullName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: TariffColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: TariffColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'VERIFIED SYSTEM OPERATOR',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: TariffColors.greenVerified,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                );
              }
            ),

            // 2. ACCOUNT METADATA
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('SECURITY CREDENTIALS'),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    'User Unique Identifier',
                    uid,
                    Icons.fingerprint_rounded,
                    onTrailingTap: () => _copyToClipboard(uid),
                    trailingIcon: Icons.copy_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    'Account Enrollment Date',
                    created,
                    Icons.calendar_today_rounded,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  _buildSectionLabel('SYSTEM TELEMETRY'),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    'Total Synced Audit Reports',
                    ref.watch(dashboardStatsProvider).synced.toString(),
                    Icons.analytics_outlined,
                  ),
                  
                  const SizedBox(height: 32),

                  _buildSectionLabel('LEGAL & COMPLIANCE'),
                  const SizedBox(height: 16),
                  _buildClickableCard(
                    'Platform Terms of Service',
                    'Review legal protocols and disclaimers',
                    Icons.gavel_rounded,
                    onTap: () => context.push(AppRoutes.terms),
                  ),
                  
                  const SizedBox(height: 48),

                  // 3. ACTION FOOTER
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _handleSignOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TariffColors.crimsonRisk.withValues(alpha: 0.1),
                        foregroundColor: TariffColors.crimsonRisk,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: TariffColors.crimsonRisk, width: 1.5),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text(
                        'TERMINATE SESSION',
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      '${AppConstants.appName} Enterprise ${AppConstants.appVersion}\nSecure Operator Protocol Active',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: TariffColors.textMuted, fontSize: 11, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 100), // Spacing for BottomNav
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: TariffColors.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildClickableCard(String title, String subtitle, IconData icon, {required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: TariffColors.navySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TariffColors.cardBorder, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TariffColors.navyDeep.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: TariffColors.amberPending, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: TariffColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: TariffColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: TariffColors.textMuted, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, {VoidCallback? onTrailingTap, IconData? trailingIcon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TariffColors.navySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TariffColors.cardBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: TariffColors.navyDeep.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: TariffColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: TariffColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: TariffColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          if (trailingIcon != null)
            IconButton(
              onPressed: onTrailingTap,
              icon: Icon(trailingIcon, color: TariffColors.textMuted, size: 18),
            ),
        ],
      ),
    );
  }
}
