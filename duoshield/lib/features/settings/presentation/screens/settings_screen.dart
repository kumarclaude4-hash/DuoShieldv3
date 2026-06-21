import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/firestore_constants.dart';
import '../../../identity/presentation/providers/identity_provider.dart';
import '../providers/lock_provider.dart';

/// Settings screen - displays app settings, PIN management, and logout.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityState = ref.watch(identityProvider);
    final publicKey = identityState.identity?.publicKey ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.settingsTitle),
      ),
      body: ListView(
        children: [
          // Public Key Section
          _SectionHeader(title: AppStrings.appInfoSection),
          ListTile(
            leading: const Icon(
              Icons.vpn_key_outlined,
              color: AppColors.accent,
            ),
            title: const Text(
              AppStrings.yourPublicKey,
              style: TextStyle(color: AppColors.textPrimary),
            ),
            subtitle: publicKey.isNotEmpty
                ? Text(
                    '${publicKey.substring(0, 16)}...${publicKey.substring(publicKey.length - 8)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  )
                : const Text(
                    'Not available',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
            trailing: IconButton(
              icon: const Icon(Icons.copy, color: AppColors.accent, size: 20),
              onPressed: publicKey.isNotEmpty
                  ? () {
                      Clipboard.setData(ClipboardData(text: publicKey));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(AppStrings.publicKeyCopied),
                        ),
                      );
                    }
                  : null,
            ),
          ),

          const Divider(color: AppColors.divider),

          // Security Section
          _SectionHeader(title: AppStrings.securitySection),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: AppColors.accent),
            title: const Text(
              AppStrings.changePin,
              style: TextStyle(color: AppColors.textPrimary),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
            onTap: () => context.pushNamed('setPin'),
          ),

          const Divider(color: AppColors.divider),

          // Danger Zone
          _SectionHeader(
            title: AppStrings.dangerSection,
            color: AppColors.error,
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text(
              AppStrings.logout,
              style: TextStyle(color: AppColors.error),
            ),
            onTap: () => _showLogoutDialog(context, ref),
          ),

          const SizedBox(height: 32),

          // App Version
          Center(
            child: Text(
              '${AppStrings.appName} v${AppStrings.appVersion}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          AppStrings.logoutConfirmTitle,
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          AppStrings.logoutConfirmMessage,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Perform logout - wipe local data
              final lockNotifier = ref.read(appLockProvider.notifier);
              await lockNotifier.clearPins();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text(AppStrings.logoutSuccess)),
                );
                context.goNamed('onboarding');
              }
            },
            child: const Text(
              AppStrings.logoutButton,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== SECTION HEADER ====================

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionHeader({
    required this.title,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
