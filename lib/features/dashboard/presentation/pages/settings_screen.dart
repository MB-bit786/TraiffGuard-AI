import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/core/providers/theme_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/connection_provider.dart';
import 'package:hscode_auditor/features/auth/presentation/providers/auth_providers.dart';
import 'package:hscode_auditor/config/routes/app_routes.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final connectionState = ref.watch(connectionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'PREFERENCES & CONFIGURATION',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? TariffColors.navyMid : const Color(0xFF1565C0),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'APPEARANCE'),
          const SizedBox(height: 12),
          _buildThemeSelector(context, ref, themeMode),
          
          const SizedBox(height: 32),

          _buildSectionHeader(context, 'ACCOUNT'),
          const SizedBox(height: 12),
          _buildClickableCard(
            context,
            'Operator Profile',
            'View your identity and system telemetry',
            Icons.person_outline_rounded,
            onTap: () => context.push(AppRoutes.profile),
          ),
          
          const SizedBox(height: 32),
          
          _buildSectionHeader(context, 'NETWORK MODE'),
          const SizedBox(height: 12),
          _buildConnectionOverride(context, ref, connectionState),
          
          const SizedBox(height: 32),

          _buildSectionHeader(context, 'LEGAL \u0026 COMPLIANCE'),
          const SizedBox(height: 12),
          _buildClickableCard(
            context,
            'Platform Terms of Service',
            'Review legal protocols and disclaimers',
            Icons.gavel_rounded,
            onTap: () => context.push(AppRoutes.terms),
          ),

          const SizedBox(height: 32),

          _buildSectionHeader(context, 'ACCOUNT SESSION'),
          const SizedBox(height: 12),
          _buildSignOutCard(context, ref),
          
          const SizedBox(height: 32),
          
          _buildSectionHeader(context, 'ABOUT'),
          const SizedBox(height: 12),
          _buildAboutInfo(context),
        ],
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? TariffColors.navyMid : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!),
        ),
        title: Text('Sign Out', style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to terminate the current session?',
            style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('CANCEL', style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('SIGN OUT',
                style: TextStyle(color: TariffColors.crimsonRisk, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authUseCasesProvider).signOut();
    }
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
                  color: isDark ? TariffColors.navyDeep.withValues(alpha: 0.5) : const Color(0xFFE3F2FD),
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

  Widget _buildSignOutCard(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? TariffColors.navySurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!, width: 1),
      ),
      child: InkWell(
        onTap: () => _handleSignOut(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TariffColors.crimsonRisk.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.logout_rounded, color: TariffColors.crimsonRisk, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terminate Session',
                      style: TextStyle(color: TariffColors.crimsonRisk, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Log out of your current operator account',
                      style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark 
            ? TariffColors.textMuted 
            : Colors.grey[600],
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? TariffColors.navySurface 
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark 
              ? TariffColors.cardBorder 
              : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [
          _buildThemeOption(
            context,
            ref,
            'System Default',
            Icons.brightness_auto_rounded,
            ThemeMode.system,
            currentMode == ThemeMode.system,
          ),
          const Divider(height: 1, indent: 56),
          _buildThemeOption(
            context,
            ref,
            'Light Mode',
            Icons.light_mode_rounded,
            ThemeMode.light,
            currentMode == ThemeMode.light,
          ),
          const Divider(height: 1, indent: 56),
          _buildThemeOption(
            context,
            ref,
            'Dark Mode',
            Icons.dark_mode_rounded,
            ThemeMode.dark,
            currentMode == ThemeMode.dark,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref,
    String title,
    IconData icon,
    ThemeMode mode,
    bool isSelected,
  ) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: isSelected ? TariffColors.amberPending : TariffColors.textSecondary),
        title: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? TariffColors.textPrimary : Colors.black,
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: isSelected 
            ? const Icon(Icons.check_circle_rounded, color: TariffColors.amberPending) 
            : null,
        onTap: () => ref.read(themeProvider.notifier).setThemeMode(mode),
      ),
    );
  }

  Widget _buildConnectionOverride(BuildContext context, WidgetRef ref, AppConnectionState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSystemOffline = !state.isOnline || !state.hasHandshake;
    final isManualActive = state.isManualOverride;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? TariffColors.navySurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? TariffColors.cardBorder : Colors.grey[300]!,
        ),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              title: const Text('Manual Status', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(isSystemOffline 
                  ? 'Device is disconnected. Manual control disabled.'
                  : (isManualActive 
                      ? 'MANUAL: App is forced to stay OFFLINE.' 
                      : 'AUTOMATIC: App follows system network.')),
              value: isManualActive,
              activeTrackColor: TariffColors.amberPending,
              onChanged: isSystemOffline ? null : (val) {
                // When toggled ON, we set isManual=true and status=false (Force Offline)
                // When toggled OFF, we set isManual=false (Back to Auto)
                ref.read(connectionProvider.notifier).updateManualOverride(
                  isManual: val, 
                  status: false 
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? TariffColors.navySurface 
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark 
              ? TariffColors.cardBorder 
              : Colors.grey[300]!,
        ),
      ),
      child: const Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Version', style: TextStyle(color: TariffColors.textSecondary)),
              Text('1.0.0 (STABLE)', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('AI Engine', style: TextStyle(color: TariffColors.textSecondary)),
              Text('v3.2.1', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
