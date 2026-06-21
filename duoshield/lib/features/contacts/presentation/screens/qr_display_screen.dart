import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../identity/presentation/providers/identity_provider.dart';

/// QR Display screen - shows the user's public key as a scannable QR code.
/// Other users can scan this to add the current user as a contact.
class QrDisplayScreen extends ConsumerWidget {
  const QrDisplayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(identityProvider);

    // Get public key
    final publicKey = identityAsync.identity?.publicKey;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.yourQrTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: publicKey == null || publicKey.isEmpty
              ? const _LoadingView()
              : _QrContentView(publicKey: publicKey),
        ),
      ),
    );
  }
}

// ==================== QR CONTENT ====================

class _QrContentView extends StatelessWidget {
  final String publicKey;

  const _QrContentView({required this.publicKey});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          AppStrings.yourQrSubtitle,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 32),
        // QR Code
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.qrBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(
            data: publicKey,
            version: QrVersions.auto,
            size: 240,
            backgroundColor: AppColors.qrBackground,
            foregroundColor: AppColors.qrForeground,
            errorStateBuilder: (context, error) {
              return const Center(
                child: Text(
                  'Error generating QR',
                  style: TextStyle(color: AppColors.error),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),
        // Public key display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text(
                'Your Public Key',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                publicKey,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontFamily: 'DuoShieldMono',
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Copy button
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: publicKey));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(AppStrings.publicKeyCopied)),
            );
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text(AppStrings.copyPublicKey),
        ),
        const Spacer(),
        // Security note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.accent.withOpacity(0.2),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.accent,
                size: 16,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Only your public key is shown. Your private key never leaves your device.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==================== LOADING ====================

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.accent),
          SizedBox(height: 16),
          Text(
            'Loading your public key...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
