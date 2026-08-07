import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

final String apiBaseUrl = kIsWeb
    ? 'http://localhost:8000/api/v1/'
    : (defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000/api/v1/'
        : 'http://localhost:8000/api/v1/');

const List<Locale> supportedLocales = [
  Locale('en'),
  Locale('fr'),
  Locale('nl'),
  Locale('es'),
  Locale('it'),
  Locale('de'),
];

const Map<int, String> skillLevelLabels = {
  1: 'Beginner',
  2: 'Casual',
  3: 'Intermediate',
  4: 'Competitive',
  5: 'Elite',
};

const Map<String, String> positionLabels = {
  'goalkeeper': 'Goalkeeper',
  'defender': 'Defender',
  'midfielder': 'Midfielder',
  'forward': 'Forward',
  'any': 'Any Position',
};

const Map<String, String> gameStatusLabels = {
  'open': 'Open',
  'full': 'Full',
  'cancelled': 'Cancelled',
  'completed': 'Completed',
};

const Map<String, String> bookingStatusLabels = {
  'confirmed': 'Confirmed',
  'waitlisted': 'Waitlisted',
  'cancelled': 'Cancelled',
};
