import 'package:flutter_test/flutter_test.dart';
import 'package:duoshield/core/utils/conversation_id_utils.dart';

void main() {
  group('ConversationIdUtils', () {
    group('generateConversationId', () {
      test('should generate consistent ID for same pair', () {
        final id1 = ConversationIdUtils.generateConversationId('uidA', 'uidB');
        final id2 = ConversationIdUtils.generateConversationId('uidA', 'uidB');
        expect(id1, equals(id2));
      });

      test('should generate same ID regardless of order', () {
        final id1 = ConversationIdUtils.generateConversationId('uidA', 'uidB');
        final id2 = ConversationIdUtils.generateConversationId('uidB', 'uidA');
        expect(id1, equals(id2));
      });

      test('should contain both UIDs separated by underscore', () {
        final id = ConversationIdUtils.generateConversationId('uidA', 'uidB');
        expect(id.contains('_'), isTrue);
        expect(id.contains('uidA'), isTrue);
        expect(id.contains('uidB'), isTrue);
      });

      test('should throw for empty UID', () {
        expect(
          () => ConversationIdUtils.generateConversationId('', 'uidB'),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw for same UID', () {
        expect(
          () => ConversationIdUtils.generateConversationId('uidA', 'uidA'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('parseConversationId', () {
      test('should parse valid conversation ID', () {
        final participants = ConversationIdUtils.parseConversationId('uidA_uidB');
        expect(participants.length, equals(2));
        expect(participants, contains('uidA'));
        expect(participants, contains('uidB'));
      });

      test('should throw for empty string', () {
        expect(
          () => ConversationIdUtils.parseConversationId(''),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw for invalid format', () {
        expect(
          () => ConversationIdUtils.parseConversationId('invalid'),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw for multiple underscores', () {
        expect(
          () => ConversationIdUtils.parseConversationId('a_b_c'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getOtherParticipantUid', () {
      test('should return the other participant', () {
        final other = ConversationIdUtils.getOtherParticipantUid(
          'uidA_uidB',
          'uidA',
        );
        expect(other, equals('uidB'));
      });

      test('should throw if not a participant', () {
        expect(
          () => ConversationIdUtils.getOtherParticipantUid(
            'uidA_uidB',
            'uidC',
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('isValidConversationId', () {
      test('should return true for valid ID', () {
        expect(
          ConversationIdUtils.isValidConversationId('uidA_uidB'),
          isTrue,
        );
      });

      test('should return false for empty string', () {
        expect(ConversationIdUtils.isValidConversationId(''), isFalse);
      });

      test('should return false for single UID', () {
        expect(ConversationIdUtils.isValidConversationId('uidA'), isFalse);
      });

      test('should return false for duplicate UIDs', () {
        expect(
          ConversationIdUtils.isValidConversationId('uidA_uidA'),
          isFalse,
        );
      });
    });

    group('getParticipantCount', () {
      test('should return 2 for valid ID', () {
        expect(
          ConversationIdUtils.getParticipantCount('uidA_uidB'),
          equals(2),
        );
      });

      test('should return 0 for invalid ID', () {
        expect(
          ConversationIdUtils.getParticipantCount('invalid'),
          equals(0),
        );
      });
    });
  });
}
