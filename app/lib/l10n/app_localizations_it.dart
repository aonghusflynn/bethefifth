// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'BeTheFifth';

  @override
  String get games => 'Games';

  @override
  String get openGames => 'Open Games';

  @override
  String get joinGame => 'Join Game';

  @override
  String get createGame => 'Create Game';

  @override
  String players(int count) {
    return '$count players';
  }

  @override
  String get profile => 'Profile';

  @override
  String get login => 'Log In';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInWithApple => 'Sign in with Apple';

  @override
  String get noGamesFound => 'No open games nearby';

  @override
  String get gameDetails => 'Game Details';

  @override
  String get skill => 'Skill Level';

  @override
  String get venue => 'Venue';

  @override
  String get time => 'Time';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';
}
