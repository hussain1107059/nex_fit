import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/utils/date_helpers.dart';

void main() {
  group('dayStart', () {
    test('normalizes to local midnight', () {
      final DateTime noon = DateTime(2026, 8, 2, 14, 30, 45);
      expect(
        dayStart(noon),
        DateTime(2026, 8, 2),
      );
    });

    test('is idempotent', () {
      final DateTime midnight = DateTime(2026, 1, 15);
      expect(dayStart(midnight), midnight);
    });
  });

  group('weekStart', () {
    test('returns Monday for a date in the middle of the week', () {
      final DateTime wednesday = DateTime(2026, 8, 5);
      expect(weekStart(wednesday), DateTime(2026, 8, 3));
    });

    test('returns the same Monday for Sunday', () {
      final DateTime sunday = DateTime(2026, 8, 9);
      expect(weekStart(sunday), DateTime(2026, 8, 3));
    });

    test('returns the date itself for a Monday', () {
      final DateTime monday = DateTime(2026, 8, 10);
      expect(weekStart(monday), monday);
    });
  });

  group('currentStreak', () {
    final DateTime today = DateTime(2026, 8, 2);

    test('is zero for an empty set', () {
      expect(currentStreak(<DateTime>{}, today), 0);
    });

    test('counts consecutive days ending today', () {
      final Set<DateTime> days = {
        DateTime(2026, 7, 31),
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 2),
      };
      expect(currentStreak(days, today), 3);
    });

    test('counts from yesterday when today is missing', () {
      final Set<DateTime> days = {
        DateTime(2026, 7, 30),
        DateTime(2026, 7, 31),
        DateTime(2026, 8, 1),
      };
      expect(currentStreak(days, today), 3);
    });

    test('stops at the first gap', () {
      final Set<DateTime> days = {
        DateTime(2026, 7, 29),
        DateTime(2026, 7, 31),
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 2),
      };
      expect(currentStreak(days, today), 3);
    });
  });

  group('longestStreak', () {
    test('is zero for an empty list', () {
      expect(longestStreak(<DateTime>[]), 0);
    });

    test('counts the longest run of consecutive days', () {
      final List<DateTime> days = [
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 2),
        DateTime(2026, 7, 3),
        DateTime(2026, 7, 6),
        DateTime(2026, 7, 7),
        DateTime(2026, 7, 8),
        DateTime(2026, 7, 9),
      ];
      expect(longestStreak(days), 4);
    });

    test('counts the longest run when there are gaps', () {
      final List<DateTime> days = [
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 2),
        DateTime(2026, 7, 3),
        DateTime(2026, 7, 8),
        DateTime(2026, 7, 9),
      ];
      expect(longestStreak(days), 3);
    });
  });

  group('cleanNote', () {
    test('trims surrounding whitespace', () {
      expect(cleanNote('  note  '), 'note');
    });

    test('returns null for a blank value', () {
      expect(cleanNote('   '), isNull);
      expect(cleanNote(''), isNull);
    });

    test('returns null for a null value', () {
      expect(cleanNote(null), isNull);
    });
  });
}
