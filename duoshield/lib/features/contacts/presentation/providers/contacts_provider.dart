import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../services/firebase_service.dart';
import '../../../../services/storage_service.dart';
import '../../../identity/domain/repositories/identity_repository.dart';
import '../../../identity/presentation/providers/identity_provider.dart';
import '../../data/datasources/contact_local_datasource.dart';
import '../../data/datasources/contact_remote_datasource.dart';
import '../../data/repositories/contact_repository_impl.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/repositories/contact_repository.dart';
import '../../domain/usecases/add_contact_usecase.dart';
import '../../domain/usecases/get_contacts_usecase.dart';

// ==================== SERVICE PROVIDERS ====================

final _firebaseServiceForContactsProvider = Provider<FirebaseService>((ref) {
  return ref.watch(firebaseServiceProvider);
});

// ==================== DATASOURCE PROVIDERS ====================

final contactLocalDatasourceProvider = Provider<ContactLocalDatasource>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ContactLocalDatasource(storage: storage);
});

final contactRemoteDatasourceProvider = Provider<ContactRemoteDatasource>((ref) {
  final firebaseService = ref.watch(_firebaseServiceForContactsProvider);
  return ContactRemoteDatasource(firebaseService: firebaseService);
});

// ==================== REPOSITORY PROVIDER ====================

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  final localDatasource = ref.watch(contactLocalDatasourceProvider);
  final remoteDatasource = ref.watch(contactRemoteDatasourceProvider);
  final identityRepository = ref.watch(identityRepositoryProvider);
  return ContactRepositoryImpl(
    localDatasource: localDatasource,
    remoteDatasource: remoteDatasource,
    identityRepository: identityRepository,
  );
});

// ==================== USE CASE PROVIDERS ====================

final addContactUseCaseProvider = Provider<AddContactUseCase>((ref) {
  final repository = ref.watch(contactRepositoryProvider);
  return AddContactUseCase(repository);
});

final getContactsUseCaseProvider = Provider<GetContactsUseCase>((ref) {
  final repository = ref.watch(contactRepositoryProvider);
  return GetContactsUseCase(repository);
});

// ==================== STATE ====================

/// Contacts state for UI consumption
class ContactsState {
  final bool isLoading;
  final List<ContactEntity> contacts;
  final Failure? failure;
  final bool isAdding;

  const ContactsState({
    this.isLoading = false,
    this.contacts = const [],
    this.failure,
    this.isAdding = false,
  });

  ContactsState copyWith({
    bool? isLoading,
    List<ContactEntity>? contacts,
    Failure? failure,
    bool? isAdding,
  }) {
    return ContactsState(
      isLoading: isLoading ?? this.isLoading,
      contacts: contacts ?? this.contacts,
      failure: failure,
      isAdding: isAdding ?? this.isAdding,
    );
  }

  bool get hasError => failure != null;
  bool get isEmpty => contacts.isEmpty && !isLoading;
}

// ==================== STATE NOTIFIER ====================

class ContactsNotifier extends StateNotifier<ContactsState> {
  final AddContactUseCase _addContactUseCase;
  final GetContactsUseCase _getContactsUseCase;
  final ContactRepository _repository;

  ContactsNotifier({
    required AddContactUseCase addContactUseCase,
    required GetContactsUseCase getContactsUseCase,
    required ContactRepository repository,
  })  : _addContactUseCase = addContactUseCase,
        _getContactsUseCase = getContactsUseCase,
        _repository = repository,
        super(const ContactsState()) {
    // Load contacts on init
    loadContacts();
  }

  /// Load all contacts
  Future<void> loadContacts() async {
    state = state.copyWith(isLoading: true, failure: null);

    final result = await _getContactsUseCase.call();

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          failure: failure,
        );
      },
      (contacts) {
        state = state.copyWith(
          isLoading: false,
          contacts: contacts,
        );
      },
    );
  }

  /// Add a new contact
  Future<bool> addContact({
    required String name,
    required String publicKey,
  }) async {
    state = state.copyWith(isAdding: true, failure: null);

    final result = await _addContactUseCase.call(
      name: name,
      publicKey: publicKey,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isAdding: false, failure: failure);
        return false;
      },
      (contact) {
        final updatedContacts = [contact, ...state.contacts];
        state = state.copyWith(
          isAdding: false,
          contacts: updatedContacts,
        );
        return true;
      },
    );
  }

  /// Delete a contact
  Future<void> deleteContact(String id) async {
    final result = await _getContactsUseCase.delete(id);

    result.fold(
      (failure) {
        developer.log('Failed to delete contact: ${failure.message}');
      },
      (_) {
        final updated = state.contacts.where((c) => c.id != id).toList();
        state = state.copyWith(contacts: updated);
      },
    );
  }

  /// Check if a contact exists
  Future<bool> contactExists(String publicKey) async {
    return await _addContactUseCase.contactExists(publicKey);
  }

  /// Restore contacts from Firestore backup
  Future<void> restoreContacts() async {
    state = state.copyWith(isLoading: true);

    final result = await _repository.restoreContacts();

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false);
      },
      (contacts) {
        // Reload from local storage after restore
        loadContacts();
      },
    );
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(failure: null);
  }
}

// ==================== STATE NOTIFIER PROVIDER ====================

final contactsProvider =
    StateNotifierProvider<ContactsNotifier, ContactsState>((ref) {
  final addUseCase = ref.watch(addContactUseCaseProvider);
  final getUseCase = ref.watch(getContactsUseCaseProvider);
  final repository = ref.watch(contactRepositoryProvider);
  return ContactsNotifier(
    addContactUseCase: addUseCase,
    getContactsUseCase: getUseCase,
    repository: repository,
  );
});
