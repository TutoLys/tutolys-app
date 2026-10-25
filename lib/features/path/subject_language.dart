import 'package:flutter/widgets.dart';

/// Which language a subject's lessons and skill names are in (Hafid,
/// 2026-10-25, app ADR 0023).
///
/// Français and English are *language subjects*: they are always taught in
/// their own language, whatever the app is set to. A translation exercise
/// (an English sentence, French words) is written that way in the lesson
/// content and stays exactly as authored; the app never converts one.
///
/// Every other subject (mathématique, science, univers social, CCQ) follows
/// the app's language: a kid who chose English does maths in English.
const languageSubjects = {'FR': 'fr-CA', 'EN': 'en-CA'};

/// The content locale to ask the backend for, for [subject].
String contentLocaleFor(String subject, Locale appLocale) =>
    languageSubjects[subject] ??
    (appLocale.languageCode == 'en' ? 'en-CA' : 'fr-CA');

/// Whether [subject]'s skill names should be shown in English.
bool showsEnglishLabels(String subject, Locale appLocale) =>
    contentLocaleFor(subject, appLocale).startsWith('en');
