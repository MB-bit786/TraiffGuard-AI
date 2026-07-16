import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import 'package:hscode_auditor/core/providers/theme_provider.dart';
import 'package:hscode_auditor/features/dashboard/presentation/providers/connection_provider.dart';
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
          
          _buildSectionHeader(context, 'NETWORK MODE'),
          const SizedBox(height: 12),
          _buildConnectionOverride(context, ref, connectionState),
          
          const SizedBox(height: 32),
          
          _buildSectionHeader(context, 'ABOUT'),
          const SizedBox(height: 12),
          _buildAboutInfo(context),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              title: const Text('Manual Override', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Ignore system network detection'),
              value: state.isManualOverride,
              activeTrackColor: TariffColors.amberPending,
              onChanged: (val) => ref.read(connectionProvider.notifier).toggleManualOverride(val),
            ),
          ),
          if (state.isManualOverride) ...[
            const Divider(height: 1, indent: 16),
            Material(
              color: Colors.transparent,
              child: ListTile(
                title: const Text('Manual Status', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(state.manualOnlineStatus ? 'Force Online' : 'Force Offline'),
                trailing: Switch(
                  value: state.manualOnlineStatus,
                  activeTrackColor: TariffColors.greenVerified,
                  onChanged: (val) => ref.read(connectionProvider.notifier).setManualStatus(val),
                ),
              ),
            ),
          ],
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
