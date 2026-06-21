import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/identity_provider.dart';

/// Login screen for restoring identity from a BIP39 seed phrase.
/// Accepts 24 words, validates the mnemonic, and regenerates the keypair.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isRestoring = false;
  String? _errorMessage;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(identityProvider);

    // Listen for successful restore
    if (state.hasIdentity && state.seedConfirmed && !_isRestoring) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.goNamed('chats');
      });
    }

    // Listen for errors
    if (state.hasError && _errorMessage == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _errorMessage = state.failure!.message;
          _isRestoring = false;
        });
        ref.read(identityProvider.notifier).clearError();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.goNamed('onboarding'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.vpn_key_outlined,
                    color: AppColors.accent,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  AppStrings.loginTitle,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  AppStrings.loginSubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _textController,
                  decoration: InputDecoration(
                    labelText: AppStrings.enterSeedPhrase,
                    hintText:
                        'word1 word2 word3 ... word24',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  minLines: 3,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.6,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your seed phrase';
                    }
                    final words = value.trim().split(RegExp(r'\s+'));
                    if (words.length != 24) {
                      return 'Expected 24 words, found ${words.length}';
                    }
                    return null;
                  },
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isRestoring || state.isLoading
                        ? null
                        : _onRestore,
                    child: _isRestoring || state.isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.background,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(AppStrings.restoring),
                            ],
                          )
                        : const Text(AppStrings.restoreButton),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => context.goNamed('onboarding'),
                    child: const Text('Create New Identity'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onRestore() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isRestoring = true;
        _errorMessage = null;
      });

      final mnemonic = _textController.text.trim();
      await ref.read(identityProvider.notifier).restoreIdentity(mnemonic);

      final currentState = ref.read(identityProvider);
      if (currentState.hasIdentity) {
        // Restore successful - publish to Firestore
        await ref.read(identityProvider.notifier).publishIdentity();
      }
    }
  }
}
