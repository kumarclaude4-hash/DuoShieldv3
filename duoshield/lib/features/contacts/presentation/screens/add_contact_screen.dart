import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/contacts_provider.dart';

/// Add contact screen with two tabs: manual entry and QR scan.
class AddContactScreen extends ConsumerStatefulWidget {
  const AddContactScreen({super.key});

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.addContactTitle),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.keyboard), text: 'Manual'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ManualEntryTab(),
          _QrScanTab(),
        ],
      ),
    );
  }
}

// ==================== MANUAL ENTRY TAB ====================

class _ManualEntryTab extends ConsumerStatefulWidget {
  const _ManualEntryTab();

  @override
  ConsumerState<_ManualEntryTab> createState() => _ManualEntryTabState();
}

class _ManualEntryTabState extends ConsumerState<_ManualEntryTab> {
  final _nameController = TextEditingController();
  final _publicKeyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isAdding = false;

  @override
  void dispose() {
    _nameController.dispose();
    _publicKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.addContactSubtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: AppStrings.contactName,
                hintText: 'e.g., Alice',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _publicKeyController,
              decoration: const InputDecoration(
                labelText: AppStrings.publicKey,
                hintText: 'Paste 64-character hex public key',
              ),
              maxLines: 3,
              minLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a public key';
                }
                final clean = value.trim().replaceAll(RegExp(r'\s+'), '');
                if (clean.length != 64) {
                  return 'Public key must be 64 hex characters';
                }
                final hexRegex = RegExp(r'^[0-9a-fA-F]+$');
                if (!hexRegex.hasMatch(clean)) {
                  return 'Invalid hex format';
                }
                return null;
              },
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isAdding ? null : _addContact,
                child: state.isAdding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : const Text('Add Contact'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addContact() async {
    if (_formKey.currentState?.validate() ?? false) {
      final success = await ref.read(contactsProvider.notifier).addContact(
        name: _nameController.text.trim(),
        publicKey: _publicKeyController.text.trim().replaceAll(RegExp(r'\s+'), ''),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.contactAdded)),
        );
        context.pop();
      }
    }
  }
}

// ==================== QR SCAN TAB ====================

class _QrScanTab extends ConsumerStatefulWidget {
  const _QrScanTab();

  @override
  ConsumerState<_QrScanTab> createState() => _QrScanTabState();
}

class _QrScanTabState extends ConsumerState<_QrScanTab> {
  bool _scanned = false;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: MobileScanner(
            onDetect: (capture) {
              if (_scanned) return;

              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final value = barcode.rawValue;
                if (value != null && value.isNotEmpty) {
                  setState(() => _scanned = true);
                  _showAddScannedContact(context, value);
                  break;
                }
              }
            },
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  color: AppColors.textSecondary,
                  size: 32,
                ),
                const SizedBox(height: 12),
                const Text(
                  AppStrings.scanQrSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddScannedContact(BuildContext context, String publicKey) {
    _nameController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Public Key: ${publicKey.length > 16 ? "${publicKey.substring(0, 8)}...${publicKey.substring(publicKey.length - 8)}" : publicKey}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: AppStrings.contactName,
                hintText: 'Enter a display name',
              ),
              style: const TextStyle(color: AppColors.textPrimary),
              autofocus: true,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _scanned = false);
                      Navigator.pop(context);
                    },
                    child: const Text(AppStrings.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_nameController.text.trim().isEmpty) return;

                      final success = await ref
                          .read(contactsProvider.notifier)
                          .addContact(
                            name: _nameController.text.trim(),
                            publicKey: publicKey,
                          );

                      if (success && mounted) {
                        Navigator.pop(context);
                        context.pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(AppStrings.contactAdded),
                          ),
                        );
                      }
                    },
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      setState(() => _scanned = false);
    });
  }
}
