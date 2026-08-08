import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_nl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('nl'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'BeTheFifth'**
  String get appTitle;

  /// No description provided for @games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get games;

  /// No description provided for @openGames.
  ///
  /// In en, this message translates to:
  /// **'Open Games'**
  String get openGames;

  /// No description provided for @joinGame.
  ///
  /// In en, this message translates to:
  /// **'Join Game'**
  String get joinGame;

  /// No description provided for @createGame.
  ///
  /// In en, this message translates to:
  /// **'Create Game'**
  String get createGame;

  /// No description provided for @players.
  ///
  /// In en, this message translates to:
  /// **'{count} players'**
  String players(int count);

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get login;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInWithApple.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get signInWithApple;

  /// No description provided for @noGamesFound.
  ///
  /// In en, this message translates to:
  /// **'No open games nearby'**
  String get noGamesFound;

  /// No description provided for @gameDetails.
  ///
  /// In en, this message translates to:
  /// **'Game Details'**
  String get gameDetails;

  /// No description provided for @skill.
  ///
  /// In en, this message translates to:
  /// **'Skill Level'**
  String get skill;

  /// No description provided for @venue.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get venue;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @mySquads.
  ///
  /// In en, this message translates to:
  /// **'My Squads'**
  String get mySquads;

  /// No description provided for @recurringGames.
  ///
  /// In en, this message translates to:
  /// **'Recurring Games'**
  String get recurringGames;

  /// No description provided for @organiserTools.
  ///
  /// In en, this message translates to:
  /// **'Organiser Tools'**
  String get organiserTools;

  /// No description provided for @newSquad.
  ///
  /// In en, this message translates to:
  /// **'New Squad'**
  String get newSquad;

  /// No description provided for @squadName.
  ///
  /// In en, this message translates to:
  /// **'Squad name'**
  String get squadName;

  /// No description provided for @squadNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Tuesday Regulars'**
  String get squadNameHint;

  /// No description provided for @noSquadsTitle.
  ///
  /// In en, this message translates to:
  /// **'No squads yet'**
  String get noSquadsTitle;

  /// No description provided for @noSquadsBody.
  ///
  /// In en, this message translates to:
  /// **'A squad is your pool of regular players. It can be bigger than the game — everyone gets invited and the first to accept play.'**
  String get noSquadsBody;

  /// No description provided for @createSquad.
  ///
  /// In en, this message translates to:
  /// **'Create squad'**
  String get createSquad;

  /// No description provided for @squadMembersHeading.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get squadMembersHeading;

  /// No description provided for @addMember.
  ///
  /// In en, this message translates to:
  /// **'Add player'**
  String get addMember;

  /// No description provided for @memberName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get memberName;

  /// No description provided for @memberEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get memberEmail;

  /// No description provided for @memberEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Used to invite them if they\'re not on BeTheFifth yet'**
  String get memberEmailHint;

  /// No description provided for @memberCountSummary.
  ///
  /// In en, this message translates to:
  /// **'{active} on board, {pending} awaiting sign-up'**
  String memberCountSummary(int active, int pending);

  /// No description provided for @pendingInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite sent'**
  String get pendingInvite;

  /// No description provided for @squadEmptyMembers.
  ///
  /// In en, this message translates to:
  /// **'No players yet. Add your regulars — they don\'t need an account.'**
  String get squadEmptyMembers;

  /// No description provided for @removePlayer.
  ///
  /// In en, this message translates to:
  /// **'Remove player'**
  String get removePlayer;

  /// No description provided for @removePlayerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this squad?'**
  String removePlayerConfirm(String name);

  /// No description provided for @deleteSquad.
  ///
  /// In en, this message translates to:
  /// **'Delete squad'**
  String get deleteSquad;

  /// No description provided for @deleteSquadConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this squad? Recurring games using it will stop inviting anyone.'**
  String get deleteSquadConfirm;

  /// No description provided for @renameSquad.
  ///
  /// In en, this message translates to:
  /// **'Rename squad'**
  String get renameSquad;

  /// No description provided for @pendingMemberNote.
  ///
  /// In en, this message translates to:
  /// **'Waiting for them to sign up. They\'ll join automatically and start getting match invites.'**
  String get pendingMemberNote;

  /// No description provided for @newRecurringGame.
  ///
  /// In en, this message translates to:
  /// **'New Recurring Game'**
  String get newRecurringGame;

  /// No description provided for @noSeriesTitle.
  ///
  /// In en, this message translates to:
  /// **'No recurring games'**
  String get noSeriesTitle;

  /// No description provided for @noSeriesBody.
  ///
  /// In en, this message translates to:
  /// **'Set up a fixture that repeats, and your squad gets invited to every instance automatically.'**
  String get noSeriesBody;

  /// No description provided for @repeats.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get repeats;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get repeatWeekly;

  /// No description provided for @repeatFortnightly.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get repeatFortnightly;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get repeatMonthly;

  /// No description provided for @firstMatch.
  ///
  /// In en, this message translates to:
  /// **'First match'**
  String get firstMatch;

  /// No description provided for @inviteSquad.
  ///
  /// In en, this message translates to:
  /// **'Invite squad'**
  String get inviteSquad;

  /// No description provided for @noSquadOption.
  ///
  /// In en, this message translates to:
  /// **'No squad — fill from the marketplace'**
  String get noSquadOption;

  /// No description provided for @seriesPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get seriesPaused;

  /// No description provided for @pauseSeries.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseSeries;

  /// No description provided for @resumeSeries.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeSeries;

  /// No description provided for @pauseSeriesNote.
  ///
  /// In en, this message translates to:
  /// **'Pausing stops new matches being scheduled. Matches already on the calendar are unaffected.'**
  String get pauseSeriesNote;

  /// No description provided for @deleteSeries.
  ///
  /// In en, this message translates to:
  /// **'Delete series'**
  String get deleteSeries;

  /// No description provided for @deleteSeriesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this recurring game? Matches already scheduled will stay, as one-offs.'**
  String get deleteSeriesConfirm;

  /// No description provided for @createRecurringGame.
  ///
  /// In en, this message translates to:
  /// **'Create recurring game'**
  String get createRecurringGame;

  /// No description provided for @seriesCreated.
  ///
  /// In en, this message translates to:
  /// **'Recurring game created. Matches are scheduled automatically.'**
  String get seriesCreated;

  /// No description provided for @attendanceQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you playing?'**
  String get attendanceQuestion;

  /// No description provided for @attendancePrompt.
  ///
  /// In en, this message translates to:
  /// **'Your organiser needs to know who\'s in.'**
  String get attendancePrompt;

  /// No description provided for @imIn.
  ///
  /// In en, this message translates to:
  /// **'I\'m in'**
  String get imIn;

  /// No description provided for @cantMakeIt.
  ///
  /// In en, this message translates to:
  /// **'Can\'t make it'**
  String get cantMakeIt;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'You\'re in'**
  String get statusConfirmed;

  /// No description provided for @statusWaitlisted.
  ///
  /// In en, this message translates to:
  /// **'On the waitlist'**
  String get statusWaitlisted;

  /// No description provided for @statusDeclined.
  ///
  /// In en, this message translates to:
  /// **'You said no'**
  String get statusDeclined;

  /// No description provided for @declinedBody.
  ///
  /// In en, this message translates to:
  /// **'Changed your mind? You can still grab a spot if there\'s room.'**
  String get declinedBody;

  /// No description provided for @changeToAttending.
  ///
  /// In en, this message translates to:
  /// **'Actually, I\'m in'**
  String get changeToAttending;

  /// No description provided for @waitlistedBody.
  ///
  /// In en, this message translates to:
  /// **'The game is full. You\'ll be promoted automatically if someone drops out.'**
  String get waitlistedBody;

  /// No description provided for @visibilitySquadOnly.
  ///
  /// In en, this message translates to:
  /// **'Squad only'**
  String get visibilitySquadOnly;

  /// No description provided for @visibilityPublic.
  ///
  /// In en, this message translates to:
  /// **'On the marketplace'**
  String get visibilityPublic;

  /// No description provided for @openToMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Open to marketplace'**
  String get openToMarketplace;

  /// No description provided for @removeFromMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Remove from marketplace'**
  String get removeFromMarketplace;

  /// No description provided for @marketplaceHint.
  ///
  /// In en, this message translates to:
  /// **'Short on players? Open it up and anyone nearby can claim a spot.'**
  String get marketplaceHint;

  /// No description provided for @marketplaceAutoHint.
  ///
  /// In en, this message translates to:
  /// **'This opens automatically 2 hours before kick-off if you\'re still short.'**
  String get marketplaceAutoHint;

  /// No description provided for @marketplaceOpenedNote.
  ///
  /// In en, this message translates to:
  /// **'Anyone can claim a spot in this game.'**
  String get marketplaceOpenedNote;

  /// No description provided for @marketplaceCloseBlocked.
  ///
  /// In en, this message translates to:
  /// **'Someone outside your squad has already joined, so this can\'t be pulled back.'**
  String get marketplaceCloseBlocked;

  /// No description provided for @inviteSquadToGame.
  ///
  /// In en, this message translates to:
  /// **'Invite a squad'**
  String get inviteSquadToGame;

  /// No description provided for @squadInvited.
  ///
  /// In en, this message translates to:
  /// **'{count} players invited'**
  String squadInvited(int count);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get retry;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get invalidEmail;

  /// No description provided for @matchName.
  ///
  /// In en, this message translates to:
  /// **'Match name'**
  String get matchName;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'it',
    'nl',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'nl':
      return AppLocalizationsNl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
