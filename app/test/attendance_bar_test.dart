import 'package:bethefifth/l10n/app_localizations.dart';
import 'package:bethefifth/models/booking.dart';
import 'package:bethefifth/screens/games/widgets/attendance_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Booking bookingWith(String status) => Booking(
      id: 'b1',
      gameId: 'g1',
      playerId: 'p1',
      status: status,
      createdAt: DateTime.utc(2026, 9, 1),
    );

Future<void> pumpBar(
  WidgetTester tester, {
  required Booking? booking,
  bool isFull = false,
  ValueChanged<bool>? onRespond,
  VoidCallback? onCancel,
  VoidCallback? onJoin,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AttendanceBar(
          booking: booking,
          isFull: isFull,
          onRespond: onRespond ?? (_) {},
          onCancel: onCancel ?? () {},
          onJoin: onJoin ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('an invited player', () {
    testWidgets('is asked yes or no, not offered a cancel button', (t) async {
      await pumpBar(t, booking: bookingWith('invited'));

      expect(find.text("I'm in"), findsOneWidget);
      expect(find.text("Can't make it"), findsOneWidget);
      // The bug this replaced: an invitation rendered as "CANCEL BOOKING".
      expect(find.text('CANCEL BOOKING'), findsNothing);
      expect(find.text('BE THE 5TH!'), findsNothing);
    });

    testWidgets('accepting reports attending = true', (t) async {
      bool? answer;
      await pumpBar(
        t,
        booking: bookingWith('invited'),
        onRespond: (v) => answer = v,
      );

      await t.tap(find.text("I'm in"));
      expect(answer, isTrue);
    });

    testWidgets('declining reports attending = false', (t) async {
      bool? answer;
      await pumpBar(
        t,
        booking: bookingWith('invited'),
        onRespond: (v) => answer = v,
      );

      await t.tap(find.text("Can't make it"));
      expect(answer, isFalse);
    });
  });

  group('a confirmed player', () {
    testWidgets('can cancel', (t) async {
      await pumpBar(t, booking: bookingWith('confirmed'));

      expect(find.text('CANCEL BOOKING'), findsOneWidget);
      expect(find.text("I'm in"), findsNothing);
    });

    testWidgets('cancelling fires the callback', (t) async {
      var cancelled = false;
      await pumpBar(
        t,
        booking: bookingWith('confirmed'),
        onCancel: () => cancelled = true,
      );

      await t.tap(find.text('CANCEL BOOKING'));
      expect(cancelled, isTrue);
    });
  });

  group('a waitlisted player', () {
    testWidgets('is told they will be promoted automatically', (t) async {
      await pumpBar(t, booking: bookingWith('waitlisted'));

      expect(
        find.textContaining('promoted automatically'),
        findsOneWidget,
      );
      expect(find.text('CANCEL BOOKING'), findsOneWidget);
    });
  });

  group('a player with no booking', () {
    testWidgets('is invited to join an open game', (t) async {
      await pumpBar(t, booking: null);

      expect(find.text('BE THE 5TH!'), findsOneWidget);
      expect(find.text('CANCEL BOOKING'), findsNothing);
    });

    testWidgets('is offered the waitlist when the game is full', (t) async {
      await pumpBar(t, booking: null, isFull: true);

      expect(find.text('JOIN WAITLIST QUEUE'), findsOneWidget);
      expect(find.text('BE THE 5TH!'), findsNothing);
    });

    testWidgets('joining fires the callback', (t) async {
      var joined = false;
      await pumpBar(t, booking: null, onJoin: () => joined = true);

      await t.tap(find.text('BE THE 5TH!'));
      expect(joined, isTrue);
    });

    testWidgets('a declined booking reads as no booking, so they can rejoin',
        (t) async {
      // The API hides declined bookings, so the screen sees null and offers
      // the join button again — which the backend now handles by reviving the
      // existing row rather than inserting a duplicate.
      await pumpBar(t, booking: null);

      expect(find.text('BE THE 5TH!'), findsOneWidget);
    });
  });
}
