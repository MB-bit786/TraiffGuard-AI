import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/features/auth/presentation/providers/auth_providers.dart';
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
      await ref.read(authUseCasesProvider).signOut();
      // The AuthGatekeeper in main.dart handles the primary swap automatically.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String email = user?.email ?? 'OPERATOR SESSION';
    final String uid = user?.uid ?? 'N/A';
    final String created = user?.metadata.creationTime?.toString().split(' ').first ?? 'Unknown';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? TariffColors.navyMid : const Color(0xFF1565C0),
        elevation: 0,
        centerTitle: true,
        title: const Text('Operator Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
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
                  decoration: BoxDecoration(
                    color: isDark ? TariffColors.navyMid : const Color(0xFF1565C0),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: Icon(
                          Icons.account_circle_rounded,
                          size: 100,
                          color: isDark ? TariffColors.amberPending : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        fullName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'VERIFIED SYSTEM OPERATOR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
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
                  _buildSectionLabel(context, 'ACCOUNT INFORMATION'),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    context,
                    'Account Enrollment Date',
                    created,
                    Icons.calendar_today_rounded,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  _buildSectionLabel(context, 'SYSTEM TELEMETRY'),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    context,
                    'Total Synced Audit Reports',
                    ref.watch(dashboardStatsProvider).synced.toString(),
                    Icons.analytics_outlined,
                  ),
                  
                  const SizedBox(height: 32),

                  _buildSectionLabel(context, 'LEGAL & COMPLIANCE'),
                  const SizedBox(height: 16),
                  _buildClickableCard(
                    context,
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
                      style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[500], fontSize: 11, height: 1.5),
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

  Widget _buildSectionLabel(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: TextStyle(
        color: isDark ? TariffColors.textMuted : Colors.grey[600],
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildClickableCard(BuildContext context, String title, String subtitle, IconData icon, {required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? TariffColors.navySurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!, width: 1),
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
                  color: isDark ? TariffColors.navyDeep.withValues(alpha: 0.5) : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: isDark ? TariffColors.amberPending : const Color(0xFF1565C0), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black87, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: isDark ? TariffColors.textMuted : Colors.grey[400], size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? TariffColors.navySurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? TariffColors.navyDeep.withValues(alpha: 0.5) : Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isDark ? TariffColors.textSecondary : Colors.blueGrey, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? TariffColors.textPrimary : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
