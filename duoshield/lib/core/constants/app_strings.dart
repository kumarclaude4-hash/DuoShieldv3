/// Centralized string constants for the DuoShield application.
/// All user-facing text is defined here for consistency and internationalization support.
class AppStrings {
  // Prevent instantiation
  const AppStrings._();

  // App info
  static const String appName = 'DuoShield';
  static const String appVersion = '1.0.0';
  static const String tagline = 'Secure. Private. Yours.';

  // General
  static const String ok = 'OK';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String continue_ = 'Continue';
  static const String back = 'Back';
  static const String next = 'Next';
  static const String done = 'Done';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String close = 'Close';
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String retry = 'Retry';
  static const String empty = 'Nothing here yet';
  static const String copied = 'Copied to clipboard';

  // Splash
  static const String splashLoading = 'Initializing secure environment...';

  // Onboarding
  static const String onboardingTitle = 'Welcome to DuoShield';
  static const String onboardingSubtitle =
      'Privacy-first secure messaging. No phone number. No email. No accounts. Just you and your words.';
  static const String generateIdentityTitle = 'Your Secret Key';
  static const String generateIdentitySubtitle =
      'This is your unique identity. Write these 24 words down on paper and store them somewhere safe. Never share them with anyone.';
  static const String seedPhraseWarning =
      'WARNING: This is the ONLY time you will see these words. If you lose them, your identity and messages cannot be recovered.';
  static const String seedPhraseWarningShort = 'Never share your seed phrase';
  static const String iHaveWrittenDown = 'I have written these down';
  static const String confirmSeedTitle = 'Verify Your Seed Phrase';
  static const String confirmSeedSubtitle =
      'Enter the words at the requested positions to confirm you saved them correctly.';
  static const String wordPosition = 'Word #';
  static const String seedConfirmed = 'Seed phrase verified!';
  static const String seedMismatch = 'Incorrect word. Please check your backup and try again.';

  // Login
  static const String loginTitle = 'Restore Identity';
  static const String loginSubtitle =
      'Enter your 24-word seed phrase to restore your identity and access your messages.';
  static const String enterSeedPhrase = 'Enter seed phrase';
  static const String invalidSeedPhrase = 'Invalid seed phrase. Please check your words.';
  static const String restoreButton = 'Restore Identity';
  static const String restoring = 'Restoring...';
  static const String restoreSuccess = 'Identity restored successfully!';
  static const String publicKeyMismatch =
      'This seed phrase does not match your stored identity. Please verify your words.';

  // PIN Lock
  static const String enterPin = 'Enter PIN';
  static const String enterDuressPin = 'Enter PIN'; // Intentionally same as normal
  static const String wrongPin = 'Incorrect PIN';
  static const String pinLocked =
      'Too many failed attempts. Please wait before trying again.';
  static const String pinLockedTimer = 'Try again in';
  static const String pinAttemptsRemaining = 'attempts remaining';

  // Set PIN
  static const String setPinTitle = 'Set Your PIN';
  static const String setPinSubtitle =
      'Create a 6-digit PIN to secure your app. You will need this every time you open DuoShield.';
  static const String confirmPinTitle = 'Confirm PIN';
  static const String confirmPinSubtitle = 'Re-enter your PIN to confirm.';
  static const String pinsDoNotMatch = 'PINs do not match. Please try again.';
  static const String pinSetSuccess = 'PIN set successfully!';

  // Duress PIN
  static const String setDuressPinTitle = 'Set Duress PIN (Optional)';
  static const String setDuressPinSubtitle =
      'A duress PIN appears to unlock the app normally but secretly wipes all local data. Set a different 6-digit PIN. Leave empty to skip.';
  static const String duressPinSameAsNormal =
      'Duress PIN cannot be the same as your normal PIN.';
  static const String duressPinSet = 'Duress PIN set.';
  static const String duressPinSkipped = 'Duress PIN setup skipped.';
  static const String duressPinWarning =
      'WARNING: Using the duress PIN will permanently delete all local data. Your Firestore data remains.';

  // Contacts
  static const String contactsTitle = 'Contacts';
  static const String noContacts = 'No contacts yet';
  static const String noContactsSubtitle =
      'Add a contact to start a secure conversation.';
  static const String addContactTitle = 'Add Contact';
  static const String addContactSubtitle =
      'Enter a public key manually or scan a QR code.';
  static const String contactName = 'Contact Name';
  static const String contactNameHint = 'Enter a display name';
  static const String publicKey = 'Public Key';
  static const String publicKeyHint = 'Paste public key here (hex string)';
  static const String invalidPublicKey =
      'Invalid public key format. Expected a hex string.';
  static const String duplicateContact = 'A contact with this public key already exists.';
  static const String contactAdded = 'Contact added successfully!';
  static const String scanQrTitle = 'Scan QR Code';
  static const String scanQrSubtitle = 'Point your camera at a DuoShield QR code.';
  static const String qrPermissionDenied =
      'Camera permission is required to scan QR codes.';
  static const String yourQrTitle = 'Your Public Key';
  static const String yourQrSubtitle =
      'Share this QR code so others can add you as a contact.';
  static const String copyPublicKey = 'Copy Public Key';
  static const String shareQr = 'Share QR Code';

  // Messaging
  static const String chatsTitle = 'Messages';
  static const String noChats = 'No conversations yet';
  static const String noChatsSubtitle =
      'Select a contact to start a secure conversation.';
  static const String newMessage = 'New message';
  static const String typeMessage = 'Type a message...';
  static const String messageDeleted = 'Message deleted';
  static const String encrypting = 'Encrypting...';
  static const String decrypting = 'Decrypting...';
  static const String messageSendError =
      'Failed to send message. Please try again.';
  static const String emptyMessage = 'Cannot send an empty message.';

  // Message status
  static const String statusSending = 'Sending';
  static const String statusSent = 'Sent';
  static const String statusDelivered = 'Delivered';
  static const String statusRead = 'Read';
  static const String statusFailed = 'Failed';

  // Settings
  static const String settingsTitle = 'Settings';
  static const String securitySection = 'Security';
  static const String changePin = 'Change PIN';
  static const String setupDuressPin = 'Setup Duress PIN';
  static const String appInfoSection = 'App Info';
  static const String yourPublicKey = 'Your Public Key';
  static const String publicKeyCopied = 'Public key copied to clipboard';
  static const String dangerSection = 'Danger Zone';
  static const String logout = 'Logout';
  static const String logoutConfirmTitle = 'Logout?';
  static const String logoutConfirmMessage =
      'This will remove all local data. Your encrypted messages remain on the server and can be restored with your seed phrase.';
  static const String logoutButton = 'Yes, Logout';
  static const String logoutSuccess = 'Logged out successfully.';

  // Errors
  static const String genericError =
      'Something went wrong. Please try again.';
  static const String networkError =
      'Network connection error. Please check your internet connection.';
  static const String encryptionError =
      'Encryption failed. The message could not be secured.';
  static const String decryptionError =
      'Decryption failed. Unable to read message.';
  static const String storageError =
      'Storage error. Data could not be saved or retrieved.';
  static const String firebaseError =
      'Server communication failed. Please try again.';
  static const String signalError =
      'Secure session error. Please try again.';
  static const String invalidInputError =
      'Invalid input. Please check and try again.';
  static const String unauthorizedError =
      'Unauthorized. Please restore your identity.';
  static const String notFoundError = 'Not found.';
  static const String alreadyExistsError = 'Already exists.';

  // Firebase collection names
  static const String usersCollection = 'users';
  static const String conversationsCollection = 'conversations';
  static const String messagesCollection = 'messages';
  static const String fcmTokensField = 'fcmToken';
  static const String publicKeyField = 'publicKey';
  static const String preKeyBundleField = 'preKeyBundle';
  static const String participantsField = 'participants';
  static const String lastMessageAtField = 'lastMessageAt';
  static const String senderIdField = 'senderId';
  static const String ciphertextField = 'ciphertext';
  static const String timestampField = 'timestamp';
  static const String statusField = 'status';
  static const String messageTypeField = 'messageType';
}
