import 'package:flutter/material.dart';

/// Centralized color constants for the DuoShield application.
/// All UI colors are defined here to ensure visual consistency.
class AppColors {
  // Prevent instantiation
  const AppColors._();

  // Background
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceElevated = Color(0xFF222222);

  // Accent / Primary
  static const Color accent = Color(0xFF00E5FF);
  static const Color accentDark = Color(0xFF00B8CC);

  // Error
  static const Color error = Color(0xFFFF4444);
  static const Color errorLight = Color(0xFFFF6666);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textMuted = Color(0xFF555555);

  // Message bubbles
  static const Color sentMessageBubble = Color(0xFF00E5FF);
  static const Color sentMessageText = Color(0xFF0D0D0D);
  static const Color receivedMessageBubble = Color(0xFF1E1E1E);
  static const Color receivedMessageText = Color(0xFFFFFFFF);

  // Status indicators
  static const Color statusSending = Color(0xFF888888);
  static const Color statusSent = Color(0xFF00E5FF);
  static const Color statusDelivered = Color(0xFF00E5FF);
  static const Color statusRead = Color(0xFF00B8CC);

  // PIN pad
  static const Color pinPadBackground = Color(0xFF1A1A1A);
  static const Color pinPadButton = Color(0xFF2A2A2A);
  static const Color pinPadButtonPressed = Color(0xFF333333);

  // Dividers and borders
  static const Color divider = Color(0xFF2A2A2A);
  static const Color border = Color(0xFF333333);

  // Seed phrase display
  static const Color seedPhraseBackground = Color(0xFF1A0A0A);
  static const Color seedPhraseBorder = Color(0xFFFF4444);
  static const Color seedPhraseWordBackground = Color(0xFF2A1A1A);

  // QR code
  static const Color qrBackground = Color(0xFFFFFFFF);
  static const Color qrForeground = Color(0xFF0D0D0D);

  // Overlay
  static const Color overlay = Color(0xB3000000);

  /// Get status color based on message status
  static Color getStatusColor(String status) {
    switch (status) {
      case 'sending':
        return statusSending;
      case 'sent':
        return statusSent;
      case 'delivered':
        return statusDelivered;
      case 'read':
        return statusRead;
      default:
        return statusSending;
    }
  }
}
