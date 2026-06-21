import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/lock_provider.dart';

/// Set PIN screen - allows user to set normal PIN and optional duress PIN.
/// Two-step process: set normal PIN → confirm normal PIN → set duress PIN (optional).
class SetPinScreen extends ConsumerStatefulWidget {
  const SetPinScreen({super.key});

  @override
  ConsumerState<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends ConsumerState<SetPinScreen> {
  int _currentStep = 0;
  String _normalPin = '';
  String _confirmPin = '';
  String _duressPin = '';
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockProvider);

    // Handle errors
    if (lockState.failure != null && _errorMessage == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _errorMessage = lockState.failure!.message;
        });
        ref.read(appLockProvider.notifier).clearError();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentStep--),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildStep(),
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentStep) {
      case 0:
        return AppStrings.setPinTitle;
      case 1:
        return AppStrings.confirmPinTitle;
      case 2:
        return AppStrings.setDuressPinTitle;
      default:
        return AppStrings.setPinTitle;
    }
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _PinEntryStep(
          title: AppStrings.setPinTitle,
          subtitle: AppStrings.setPinSubtitle,
          pin: _normalPin,
          errorMessage: _errorMessage,
          onDigitPressed: (digit) => _onDigitPressed(0, digit),
          onBackspace: () => _onBackspace(0),
          onPinComplete: _onNormalPinComplete,
        );
      case 1:
        return _PinEntryStep(
          title: AppStrings.confirmPinTitle,
          subtitle: AppStrings.confirmPinSubtitle,
          pin: _confirmPin,
          errorMessage: _errorMessage,
          onDigitPressed: (digit) => _onDigitPressed(1, digit),
          onBackspace: () => _onBackspace(1),
          onPinComplete: _onConfirmPinComplete,
        );
      case 2:
        return _DuressPinStep(
          duressPin: _duressPin,
          errorMessage: _errorMessage,
          onDigitPressed: (digit) => _onDigitPressed(2, digit),
          onBackspace: () => _onBackspace(2),
          onPinComplete: _onDuressPinComplete,
          onSkip: _onSkipDuress,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _onDigitPressed(int step, String digit) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }

    setState(() {
      switch (step) {
        case 0:
          if (_normalPin.length < 6) _normalPin += digit;
          break;
        case 1:
          if (_confirmPin.length < 6) _confirmPin += digit;
          break;
        case 2:
          if (_duressPin.length < 6) _duressPin += digit;
          break;
      }
    });
  }

  void _onBackspace(int step) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }

    setState(() {
      switch (step) {
        case 0:
          if (_normalPin.isNotEmpty) {
            _normalPin = _normalPin.substring(0, _normalPin.length - 1);
          }
          break;
        case 1:
          if (_confirmPin.isNotEmpty) {
            _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
          }
          break;
        case 2:
          if (_duressPin.isNotEmpty) {
            _duressPin = _duressPin.substring(0, _duressPin.length - 1);
          }
          break;
      }
    });
  }

  void _onNormalPinComplete() {
    if (_normalPin.length == 6) {
      setState(() {
        _currentStep = 1;
        _errorMessage = null;
      });
    }
  }

  void _onConfirmPinComplete() {
    if (_confirmPin.length == 6) {
      if (_normalPin != _confirmPin) {
        setState(() {
          _errorMessage = AppStrings.pinsDoNotMatch;
          _confirmPin = '';
        });
        return;
      }

      // Normal PIN confirmed, proceed to duress PIN
      setState(() {
        _currentStep = 2;
        _errorMessage = null;
      });
    }
  }

  Future<void> _onDuressPinComplete() async {
    if (_duressPin.length == 6) {
      if (_duressPin == _normalPin) {
        setState(() {
          _errorMessage = AppStrings.duressPinSameAsNormal;
          _duressPin = '';
        });
        return;
      }

      // Save both PINs
      final lockNotifier = ref.read(appLockProvider.notifier);

      final normalSet = await lockNotifier.setPin(_normalPin);
      if (!normalSet) {
        setState(() {
          _errorMessage = 'Failed to set normal PIN';
        });
        return;
      }

      if (_duressPin.isNotEmpty) {
        final duressSet = await lockNotifier.setDuressPin(_duressPin, _normalPin);
        if (!duressSet) {
          setState(() {
            _errorMessage = 'Failed to set duress PIN';
          });
          return;
        }
      }

      // Success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.pinSetSuccess)),
        );
        context.goNamed('chats');
      }
    }
  }

  Future<void> _onSkipDuress() async {
    // Save only normal PIN
    final lockNotifier = ref.read(appLockProvider.notifier);
    final success = await lockNotifier.setPin(_normalPin);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.duressPinSkipped)),
      );
      context.goNamed('chats');
    }
  }
}

// ==================== PIN ENTRY STEP ====================

class _PinEntryStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final String pin;
  final String? errorMessage;
  final Function(String) onDigitPressed;
  final VoidCallback onBackspace;
  final VoidCallback onPinComplete;

  const _PinEntryStep({
    required this.title,
    required this.subtitle,
    required this.pin,
    this.errorMessage,
    required this.onDigitPressed,
    required this.onBackspace,
    required this.onPinComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (pin.length == 6) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onPinComplete());
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 40),
        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            final filled = index < pin.length;
            return Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? AppColors.accent
                    : AppColors.textMuted.withOpacity(0.3),
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.3),
                  width: 1,
                ),
              ),
            );
          }),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            errorMessage!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 40),
        // PIN pad
        _PinPad(
          onDigitPressed: onDigitPressed,
          onBackspace: onBackspace,
        ),
        const Spacer(),
      ],
    );
  }
}

// ==================== DURESS PIN STEP ====================

class _DuressPinStep extends StatelessWidget {
  final String duressPin;
  final String? errorMessage;
  final Function(String) onDigitPressed;
  final VoidCallback onBackspace;
  final VoidCallback onPinComplete;
  final VoidCallback onSkip;

  const _DuressPinStep({
    required this.duressPin,
    this.errorMessage,
    required this.onDigitPressed,
    required this.onBackspace,
    required this.onPinComplete,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    if (duressPin.length == 6) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onPinComplete());
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        const Text(
          AppStrings.setDuressPinTitle,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            AppStrings.setDuressPinSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Warning
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.error.withOpacity(0.3),
            ),
          ),
          child: const Text(
            AppStrings.duressPinWarning,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.error,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            final filled = index < duressPin.length;
            return Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? AppColors.error
                    : AppColors.textMuted.withOpacity(0.3),
                border: Border.all(
                  color: AppColors.error.withOpacity(0.3),
                  width: 1,
                ),
              ),
            );
          }),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            errorMessage!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 40),
        // PIN pad
        _PinPad(
          onDigitPressed: onDigitPressed,
          onBackspace: onBackspace,
        ),
        const Spacer(),
        // Skip button
        TextButton(
          onPressed: onSkip,
          child: const Text(
            'Skip',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ==================== PIN PAD ====================

class _PinPad extends StatelessWidget {
  final Function(String) onDigitPressed;
  final VoidCallback onBackspace;

  const _PinPad({
    required this.onDigitPressed,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 3; row++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var col = 1; col <= 3; col++)
                _PinButton(
                  digit: '${row * 3 + col}',
                  onPressed: () => onDigitPressed('${row * 3 + col}'),
                ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            _PinButton(
              digit: '0',
              onPressed: () => onDigitPressed('0'),
            ),
            SizedBox(
              width: 80,
              child: IconButton(
                onPressed: onBackspace,
                icon: const Icon(
                  Icons.backspace_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PinButton extends StatelessWidget {
  final String digit;
  final VoidCallback onPressed;

  const _PinButton({
    required this.digit,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.pinPadButton,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                digit,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
