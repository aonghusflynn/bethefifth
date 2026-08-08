import 'package:bethefifth/models/game.dart';
import 'package:bethefifth/models/series.dart';
import 'package:bethefifth/models/squad.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SquadMember', () {
    test('a member with no account yet is pending', () {
      final member = SquadMember.fromJson({
        'id': 'm1',
        'squad_id': 's1',
        'user_id': null,
        'display_name': 'Barry From Work',
        'invite_email': 'barry@example.com',
        'invite_phone': null,
        'status': 'invited',
        'created_at': '2026-09-01T18:00:00Z',
      });

      expect(member.isPending, isTrue);
      expect(member.displayName, 'Barry From Work');
      expect(member.inviteEmail, 'barry@example.com');
    });

    test('a member linked to a real user is not pending', () {
      final member = SquadMember.fromJson({
        'id': 'm2',
        'squad_id': 's1',
        'user_id': 'u1',
        'display_name': 'Dublin Baller',
        'invite_email': 'dublin@example.com',
        'invite_phone': null,
        'status': 'active',
        'created_at': '2026-09-01T18:00:00Z',
      });

      expect(member.isPending, isFalse);
    });
  });

  group('Squad', () {
    test('counts active and pending members separately', () {
      final squad = Squad.fromJson({
        'id': 's1',
        'organiser_id': 'o1',
        'name': 'Tuesday Regulars',
        'created_at': '2026-09-01T18:00:00Z',
        'members': [
          {
            'id': 'm1',
            'squad_id': 's1',
            'user_id': 'u1',
            'display_name': 'On Board',
            'status': 'active',
            'created_at': '2026-09-01T18:00:00Z',
          },
          {
            'id': 'm2',
            'squad_id': 's1',
            'user_id': null,
            'display_name': 'Awaiting Signup',
            'invite_email': 'barry@example.com',
            'status': 'invited',
            'created_at': '2026-09-01T18:00:00Z',
          },
        ],
      });

      expect(squad.activeCount, 1);
      expect(squad.pendingCount, 1);
    });

    test('handles a squad response with no members list', () {
      final squad = Squad.fromJson({
        'id': 's1',
        'organiser_id': 'o1',
        'name': 'Empty',
        'created_at': '2026-09-01T18:00:00Z',
      });

      expect(squad.members, isEmpty);
      expect(squad.activeCount, 0);
    });
  });

  group('Game', () {
    Map<String, dynamic> gameJson({
      String visibility = 'public',
      int currentPlayers = 0,
      String? seriesId,
    }) =>
        {
          'id': 'g1',
          'organiser_id': 'o1',
          'venue_id': 'v1',
          'series_id': seriesId,
          'title': 'Tuesday Night 5s',
          'description': null,
          'starts_at': '2026-09-01T18:00:00Z',
          'duration_minutes': 60,
          'max_players': 10,
          'current_players': currentPlayers,
          'skill_level': 3,
          'status': 'open',
          'is_recurring': false,
          'is_private': false,
          'visibility': visibility,
          'marketplace_opened_at': null,
          'marketplace_notified_at': null,
          'cost_per_player': null,
          'currency': null,
        };

    test('parses the marketplace fields', () {
      final game = Game.fromJson(gameJson(visibility: 'squad_only'));

      expect(game.visibility, 'squad_only');
      expect(game.isSquadOnly, isTrue);
      expect(game.marketplaceOpenedAt, isNull);
    });

    test('defaults visibility to public when the field is absent', () {
      final json = gameJson()..remove('visibility');

      expect(Game.fromJson(json).visibility, 'public');
    });

    test('parses marketplace timestamps when present', () {
      final json = gameJson()
        ..['marketplace_opened_at'] = '2026-09-01T16:00:00Z'
        ..['marketplace_notified_at'] = '2026-09-01T17:00:00Z';

      final game = Game.fromJson(json);

      expect(game.marketplaceOpenedAt, isNotNull);
      expect(game.marketplaceNotifiedAt, isNotNull);
    });

    test('reports slots left and fullness', () {
      expect(Game.fromJson(gameJson(currentPlayers: 4)).slotsLeft, 6);
      expect(Game.fromJson(gameJson(currentPlayers: 4)).isFull, isFalse);
      expect(Game.fromJson(gameJson(currentPlayers: 10)).isFull, isTrue);
      expect(Game.fromJson(gameJson(currentPlayers: 10)).slotsLeft, 0);
    });

    test('tracks whether it came from a recurring series', () {
      expect(Game.fromJson(gameJson()).seriesId, isNull);
      expect(Game.fromJson(gameJson(seriesId: 'ser1')).seriesId, 'ser1');
    });
  });

  group('RecurrencePattern', () {
    test('maps rrules back to the pattern the UI offers', () {
      expect(RecurrencePattern.fromRrule('FREQ=WEEKLY'),
          RecurrencePattern.weekly);
      expect(RecurrencePattern.fromRrule('FREQ=WEEKLY;INTERVAL=2'),
          RecurrencePattern.fortnightly);
      expect(RecurrencePattern.fromRrule('FREQ=MONTHLY'),
          RecurrencePattern.monthly);
    });

    test('falls back to weekly for a rule the picker cannot express', () {
      // Series created via the API can carry richer rules than the UI offers.
      expect(RecurrencePattern.fromRrule('FREQ=WEEKLY;BYDAY=TU,TH'),
          RecurrencePattern.weekly);
    });
  });

  group('GameSeries', () {
    test('parses a series with a squad attached', () {
      final series = GameSeries.fromJson({
        'id': 'ser1',
        'organiser_id': 'o1',
        'venue_id': 'v1',
        'squad_id': 'sq1',
        'title': 'Tuesday Night 5s',
        'description': null,
        'starts_at': '2026-09-01T18:00:00Z',
        'rrule': 'FREQ=WEEKLY;BYDAY=TU',
        'duration_minutes': 60,
        'max_players': 10,
        'skill_level': 3,
        'is_active': true,
      });

      expect(series.squadId, 'sq1');
      expect(series.isActive, isTrue);
      expect(series.rrule, 'FREQ=WEEKLY;BYDAY=TU');
    });

    test('a series with no squad fills from the marketplace instead', () {
      final series = GameSeries.fromJson({
        'id': 'ser2',
        'organiser_id': 'o1',
        'venue_id': 'v1',
        'squad_id': null,
        'title': 'Open Kickabout',
        'starts_at': '2026-09-01T18:00:00Z',
        'rrule': 'FREQ=WEEKLY',
        'is_active': false,
      });

      expect(series.squadId, isNull);
      expect(series.isActive, isFalse);
    });
  });
}
