import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/conversation_id_utils.dart';
import '../../../../services/firebase_service.dart';
import '../providers/contacts_provider.dart';

/// Contacts screen - displays list of all contacts with actions.
class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contactsProvider);

    // Show error messages
    if (state.hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.failure!.message),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(contactsProvider.notifier).clearError();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.contactsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: AppColors.accent),
            onPressed: () => context.pushNamed('qrDisplay'),
            tooltip: 'Show my QR code',
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : state.isEmpty
              ? _EmptyContactsView(
                  onAddContact: () => context.pushNamed('addContact'),
                )
              : _ContactsListView(
                  state: state,
                  onDelete: (id) => _showDeleteDialog(context, ref, id),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed('addContact'),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.background,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String contactId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete Contact',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to delete this contact?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(contactsProvider.notifier).deleteContact(contactId);
              Navigator.pop(context);
            },
            child: const Text(
              AppStrings.delete,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== EMPTY STATE ====================

class _EmptyContactsView extends StatelessWidget {
  final VoidCallback onAddContact;

  const _EmptyContactsView({required this.onAddContact});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              AppStrings.noContacts,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              AppStrings.noContactsSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddContact,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Contact'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== CONTACTS LIST ====================

class _ContactsListView extends StatelessWidget {
  final ContactsState state;
  final Function(String) onDelete;

  const _ContactsListView({
    required this.state,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.contacts.length,
      itemBuilder: (context, index) {
        final contact = state.contacts[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: AppColors.accent.withOpacity(0.15),
            child: Text(
              contact.name.isNotEmpty
                  ? contact.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            contact.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            contact.shortPublicKey,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(
              Icons.chat_bubble_outline,
              color: AppColors.accent,
              size: 20,
            ),
            onPressed: () {
              // Navigate to chat - need conversation ID
              // This would typically get the contact's Firebase UID
              // For now, show a snackbar indicating feature flow
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening conversation...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          onLongPress: () => onDelete(contact.id),
        );
      },
    );
  }
}
