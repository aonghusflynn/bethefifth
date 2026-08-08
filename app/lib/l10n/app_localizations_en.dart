// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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

  @override
  String get mySquads => 'My Squads';

  @override
  String get recurringGames => 'Recurring Games';

  @override
  String get organiserTools => 'Organiser Tools';

  @override
  String get newSquad => 'New Squad';

  @override
  String get squadName => 'Squad name';

  @override
  String get squadNameHint => 'e.g. Tuesday Regulars';

  @override
  String get noSquadsTitle => 'No squads yet';

  @override
  String get noSquadsBody =>
      'A squad is your pool of regular players. It can be bigger than the game — everyone gets invited and the first to accept play.';

  @override
  String get createSquad => 'Create squad';

  @override
  String get squadMembersHeading => 'Members';

  @override
  String get addMember => 'Add player';

  @override
  String get memberName => 'Name';

  @override
  String get memberEmail => 'Email';

  @override
  String get memberEmailHint =>
      'Used to invite them if they\'re not on BeTheFifth yet';

  @override
  String memberCountSummary(int active, int pending) {
    return '$active on board, $pending awaiting sign-up';
  }

  @override
  String get pendingInvite => 'Invite sent';

  @override
  String get squadEmptyMembers =>
      'No players yet. Add your regulars — they don\'t need an account.';

  @override
  String get removePlayer => 'Remove player';

  @override
  String removePlayerConfirm(String name) {
    return 'Remove $name from this squad?';
  }

  @override
  String get deleteSquad => 'Delete squad';

  @override
  String get deleteSquadConfirm =>
      'Delete this squad? Recurring games using it will stop inviting anyone.';

  @override
  String get renameSquad => 'Rename squad';

  @override
  String get pendingMemberNote =>
      'Waiting for them to sign up. They\'ll join automatically and start getting match invites.';

  @override
  String get newRecurringGame => 'New Recurring Game';

  @override
  String get noSeriesTitle => 'No recurring games';

  @override
  String get noSeriesBody =>
      'Set up a fixture that repeats, and your squad gets invited to every instance automatically.';

  @override
  String get repeats => 'Repeats';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get repeatFortnightly => 'Every 2 weeks';

  @override
  String get repeatMonthly => 'Monthly';

  @override
  String get firstMatch => 'First match';

  @override
  String get inviteSquad => 'Invite squad';

  @override
  String get noSquadOption => 'No squad — fill from the marketplace';

  @override
  String get seriesPaused => 'Paused';

  @override
  String get pauseSeries => 'Pause';

  @override
  String get resumeSeries => 'Resume';

  @override
  String get pauseSeriesNote =>
      'Pausing stops new matches being scheduled. Matches already on the calendar are unaffected.';

  @override
  String get deleteSeries => 'Delete series';

  @override
  String get deleteSeriesConfirm =>
      'Delete this recurring game? Matches already scheduled will stay, as one-offs.';

  @override
  String get createRecurringGame => 'Create recurring game';

  @override
  String get seriesCreated =>
      'Recurring game created. Matches are scheduled automatically.';

  @override
  String get attendanceQuestion => 'Are you playing?';

  @override
  String get attendancePrompt => 'Your organiser needs to know who\'s in.';

  @override
  String get imIn => 'I\'m in';

  @override
  String get cantMakeIt => 'Can\'t make it';

  @override
  String get statusConfirmed => 'You\'re in';

  @override
  String get statusWaitlisted => 'On the waitlist';

  @override
  String get statusDeclined => 'You said no';

  @override
  String get declinedBody =>
      'Changed your mind? You can still grab a spot if there\'s room.';

  @override
  String get changeToAttending => 'Actually, I\'m in';

  @override
  String get waitlistedBody =>
      'The game is full. You\'ll be promoted automatically if someone drops out.';

  @override
  String get visibilitySquadOnly => 'Squad only';

  @override
  String get visibilityPublic => 'On the marketplace';

  @override
  String get openToMarketplace => 'Open to marketplace';

  @override
  String get removeFromMarketplace => 'Remove from marketplace';

  @override
  String get marketplaceHint =>
      'Short on players? Open it up and anyone nearby can claim a spot.';

  @override
  String get marketplaceAutoHint =>
      'This opens automatically 2 hours before kick-off if you\'re still short.';

  @override
  String get marketplaceOpenedNote => 'Anyone can claim a spot in this game.';

  @override
  String get marketplaceCloseBlocked =>
      'Someone outside your squad has already joined, so this can\'t be pulled back.';

  @override
  String get inviteSquadToGame => 'Invite a squad';

  @override
  String squadInvited(int count) {
    return '$count players invited';
  }

  @override
  String get retry => 'Try Again';

  @override
  String get remove => 'Remove';

  @override
  String get delete => 'Delete';

  @override
  String get add => 'Add';

  @override
  String get rename => 'Rename';

  @override
  String get requiredField => 'Required';

  @override
  String get invalidEmail => 'Enter a valid email';
}
