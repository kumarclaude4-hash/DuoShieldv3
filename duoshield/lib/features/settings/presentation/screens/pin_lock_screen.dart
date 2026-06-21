import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/lock_provider.dart';

/// PIN lock screen - displayed when app is locked.
/// Requires 6-digit PIN to unlock. Supports duress PIN.
class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  final List<String> _pinDigits = [];
  String? _errorMessage;
  bool _isUnlocking = false;

  void _onDigitPressed(String digit) {
    if (_pinDigits.length >= 6) return;
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
    setState(() => _pinDigits.add(digit));

    if (_pinDigits.length == 6) {
      _attemptUnlock();
    }
  }

  void _onBackspace() {
    if (_pinDigits.isEmpty) return;
    setState(() => _pinDigits.removeLast());
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _attemptUnlock() async {
    setState(() => _isUnlocking = true);

    final pin = _pinDigits.join();
    final lockNotifier = ref.read(appLockProvider.notifier);

    final success = await lockNotifier.unlockWithPin(pin);

    if (success) {
      // Check if duress was activated
      final lockState = ref.read(appLockProvider);
      if (lockState.isDuressActivated) {
        // Duress PIN was used - navigate to onboarding
        if (mounted) {
          context.goNamed('onboarding');
        }
        return;
      }

      // Normal unlock - navigate to chats
      if (mounted) {
        context.goNamed('chats');
      }
    } else {
      // Failed
      final lockState = ref.read(appLockProvider);
      setState(() {
        _isUnlocking = false;
        _pinDigits.clear();
        _errorMessage = lockState.failure?.message ?? AppStrings.wrongPin;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockProvider);

    // Handle time lock
    if (lockState.isTimeLocked) {
      final remaining = lockState.remainingLockDuration;
      if (remaining != null) {
        return _TimeLockView(remainingSeconds: remaining.inSeconds);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Lock icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppColors.accent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 32),
              // Title
              const Text(
                AppStrings.enterPin,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                'Attempts remaining: ${math.max(0, 5 - lockState.failedAttempts)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final filled = index < _pinDigits.length;
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
              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 40),
              // Loading indicator
              if (_isUnlocking)
                const CircularProgressIndicator(color: AppColors.accent)
              else
                // PIN pad
                _PinPad(
                  onDigitPressed: _onDigitPressed,
                  onBackspace: _onBackspace,
                ),
              const Spacer(),
              // Restore option
              TextButton(
                onPressed: () => context.goNamed('login'),
                child: const Text(
                  'Restore Identity',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== TIME LOCK VIEW ====================

class _TimeLockView extends StatefulWidget {
  final int remainingSeconds;

  const _TimeLockView({required this.remainingSeconds});

  @override
  State<_TimeLockView> createState() => _TimeLockViewState();
}

class _TimeLockViewState extends State<_TimeLockView> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.remainingSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remaining / 60).floor();
    final seconds = _remaining % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.timer,
                color: AppColors.error,
                size: 64,
              ),
              const SizedBox(height: 24),
              const Text(
                AppStrings.pinLocked,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${AppStrings.pinLockedTimer}\n$timeStr',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
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
