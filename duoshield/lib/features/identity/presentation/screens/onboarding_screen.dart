import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/identity_provider.dart';

/// Onboarding screen flow:
/// 1. Welcome / explanation
/// 2. Display seed phrase (one time only, with red warning)
/// 3. Confirm 3 random words from the phrase
/// 4. Complete - navigate to set PIN
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;
  List<String> _seedPhraseWords = [];
  List<int> _confirmationIndices = [];
  final Map<int, String> _confirmationInputs = {};
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(identityProvider);

    // Handle errors
    if (state.hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.failure!.message),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(identityProvider.notifier).clearError();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: state.isLoading
              ? const _LoadingView()
              : _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _WelcomeStep(onNext: () => setState(() => _currentStep = 1));
      case 1:
        return _GenerateStep(
          onGenerated: (words) {
            setState(() {
              _seedPhraseWords = words;
              _currentStep = 2;
            });
          },
        );
      case 2:
        return _DisplaySeedStep(
          words: _seedPhraseWords,
          onContinue: () {
            setState(() {
              _generateConfirmationIndices();
              _currentStep = 3;
            });
          },
        );
      case 3:
        return _ConfirmSeedStep(
          words: _seedPhraseWords,
          indices: _confirmationIndices,
          inputs: _confirmationInputs,
          formKey: _formKey,
          onConfirm: _verifyConfirmation,
        );
      case 4:
        return _CompleteStep(
          onComplete: () => context.goNamed('setPin'),
        );
      default:
        return const _WelcomeStep(onNext: null);
    }
  }

  void _generateConfirmationIndices() {
    final random = Random.secure();
    final indices = <int>{};
    while (indices.length < 3) {
      indices.add(random.nextInt(24));
    }
    _confirmationIndices = indices.toList()..sort();
  }

  Future<void> _verifyConfirmation() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Check all 3 words are correct
      bool allCorrect = true;
      for (final index in _confirmationIndices) {
        final input = (_confirmationInputs[index] ?? '').toLowerCase().trim();
        if (input != _seedPhraseWords[index].toLowerCase()) {
          allCorrect = false;
          break;
        }
      }

      if (allCorrect) {
        await ref.read(identityProvider.notifier).confirmSeedPhrase();
        await ref.read(identityProvider.notifier).publishIdentity();
        setState(() => _currentStep = 4);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.seedMismatch),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

// ==================== STEP 0: WELCOME ====================

class _WelcomeStep extends StatelessWidget {
  final VoidCallback? onNext;

  const _WelcomeStep({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: AppColors.accent,
            size: 36,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          AppStrings.onboardingTitle,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          AppStrings.onboardingSubtitle,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        _FeatureItem(
          icon: Icons.vpn_key_outlined,
          text: 'Cryptographic identity - no phone or email needed',
        ),
        _FeatureItem(
          icon: Icons.lock_outline,
          text: 'End-to-end encrypted with Signal Protocol',
        ),
        _FeatureItem(
          icon: Icons.delete_forever_outlined,
          text: 'Duress PIN for emergency data wipe',
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onNext,
            child: const Text('Get Started'),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.goNamed('login'),
            child: const Text('Restore Existing Identity'),
          ),
        ),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== STEP 1: GENERATE ====================

class _GenerateStep extends ConsumerStatefulWidget {
  final Function(List<String>) onGenerated;

  const _GenerateStep({required this.onGenerated});

  @override
  ConsumerState<_GenerateStep> createState() => _GenerateStepState();
}

class _GenerateStepState extends ConsumerState<_GenerateStep> {
  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    await ref.read(identityProvider.notifier).generateIdentity();
    final state = ref.read(identityProvider);
    if (state.seedPhrase != null) {
      final words = state.seedPhrase!.split(' ');
      widget.onGenerated(words);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.accent),
          SizedBox(height: 24),
          Text(
            'Generating your secure identity...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ==================== STEP 2: DISPLAY SEED PHRASE ====================

class _DisplaySeedStep extends StatelessWidget {
  final List<String> words;
  final VoidCallback onContinue;

  const _DisplaySeedStep({
    required this.words,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.generateIdentityTitle,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          AppStrings.generateIdentitySubtitle,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        // Red warning banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber, color: AppColors.error),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings.seedPhraseWarning,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.error,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Seed phrase grid
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.seedPhraseBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.seedPhraseBorder.withOpacity(0.3)),
            ),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: words.length,
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.seedPhraseWordBackground,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${index + 1}.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          words[index],
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Copy button
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {
              final phrase = words.join(' ');
              Clipboard.setData(ClipboardData(text: phrase));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text(AppStrings.copied)),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy to Clipboard'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onContinue,
            child: const Text(AppStrings.iHaveWrittenDown),
          ),
        ),
      ],
    );
  }
}

// ==================== STEP 3: CONFIRM SEED ====================

class _ConfirmSeedStep extends StatelessWidget {
  final List<String> words;
  final List<int> indices;
  final Map<int, String> inputs;
  final GlobalKey<FormState> formKey;
  final VoidCallback onConfirm;

  const _ConfirmSeedStep({
    required this.words,
    required this.indices,
    required this.inputs,
    required this.formKey,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.confirmSeedTitle,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            AppStrings.confirmSeedSubtitle,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ...indices.map((index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: '${AppStrings.wordPosition}${index + 1}',
                  hintText: 'Enter word #${index + 1}',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter this word';
                  }
                  return null;
                },
                onChanged: (value) {
                  inputs[index] = value;
                },
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            );
          }),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              child: const Text(AppStrings.confirm),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== STEP 4: COMPLETE ====================

class _CompleteStep extends StatelessWidget {
  final VoidCallback onComplete;

  const _CompleteStep({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle_outline,
          color: AppColors.accent,
          size: 80,
        ),
        const SizedBox(height: 24),
        const Text(
          AppStrings.seedConfirmed,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Your identity is now secured. Let\'s set up your PIN.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onComplete,
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }
}

// ==================== LOADING VIEW ====================

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
            AppStrings.loading,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
