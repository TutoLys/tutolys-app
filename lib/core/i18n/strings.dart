import 'package:flutter/widgets.dart';

/// Strings, French first.
///
/// The product launches in Quebec, so `fr-CA` is the default and English is the
/// second locale — not the other way round. A missing French string is a bug,
/// not a fallback case.
///
/// Deliberately hand-written rather than generated from ARB: the old desktop
/// client carried 1,329 lines of i18n and the web app 651 keys × 2, and most
/// of it was never read. This grows with the screens that actually exist. The
/// shape (a sealed class per locale) is what a generator would produce anyway,
/// so moving to `slang` or ARB later is mechanical.
abstract class Strings {
  const Strings();

  String get locale;

  // --- pairing -----------------------------------------------------------
  String get pairingTitle;
  String get pairingSubtitle;
  String get pairingHint;
  String get pairingConnect;
  String get pairingConnecting;
  String get pairingCodeInvalid;
  String get pairingOffline;
  String get pairingUnexpectedError;
  String pairingWelcome(String name);

  // --- shared ------------------------------------------------------------
  String get retry;
  String get cancel;
  String get continueLabel;
  String get loading;

  // --- home --------------------------------------------------------------
  String homeGreeting(String name);
  String get homeContinueLearning;
  String get homePlay;
  String get homeStatExercises;
  String get homeStatMinutes;
  String get homeStatStreak;
  String get homeDailyQuestTitle;
  String homeDailyQuestProgress(int progress, int target);
  String get homeDailyQuestCompleted;

  // --- path --------------------------------------------------------------
  String get pathTitle;
  String get pathEmpty;
  String get pathLocked;

  // --- profile -------------------------------------------------------------
  String get profileTitle;
  String profileGrade(int grade);
  String get profileBadgesComingSoon;
  String get profileSignOut;
  String profileSkillsMastered(int count);
  String profileStreakDays(int days);
  String profileFreezesAvailable(int count);

  // --- pin gate ------------------------------------------------------------
  String get pinGateCreateTitle;
  String get pinGateCreateSubtitle;
  String get pinGateEnterTitle;
  String get pinGateEnterSubtitle;
  String get pinGatePinLabel;
  String get pinGateConfirmPinLabel;
  String get pinGateMismatch;
  String get pinGateTooShort;
  String get pinGateWrong;
  String get pinGateCreate;
  String get pinGateConfirmSignOut;

  // --- nav -----------------------------------------------------------------
  String get navHome;
  String get navPath;
  String get navProfile;

  // --- play --------------------------------------------------------------
  String get playBack;

  static const Strings fr = _FrenchStrings();
  static const Strings en = _EnglishStrings();

  /// Resolve from a locale, defaulting to French.
  static Strings of(Locale locale) => locale.languageCode == 'en' ? en : fr;
}

class _FrenchStrings extends Strings {
  const _FrenchStrings();

  @override
  String get locale => 'fr-CA';

  @override
  String get pairingTitle => 'Salut !';

  @override
  String get pairingSubtitle => 'Entre ton code pour commencer';

  @override
  String get pairingHint =>
      'Demande ton code à un adulte. Il a six caractères.';

  @override
  String get pairingConnect => 'Se connecter';

  @override
  String get pairingConnecting => 'Connexion…';

  @override
  String get pairingCodeInvalid =>
      "Ce code ne fonctionne pas. Demande-en un nouveau à un adulte.";

  @override
  String get pairingOffline =>
      "Pas de connexion Internet. Vérifie le Wi-Fi et réessaie.";

  @override
  String get pairingUnexpectedError =>
      "Quelque chose n'a pas fonctionné. Réessaie dans un moment.";

  @override
  String pairingWelcome(String name) => 'Bienvenue, $name !';

  @override
  String get retry => 'Réessayer';

  @override
  String get cancel => 'Annuler';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get loading => 'Un instant…';

  @override
  String homeGreeting(String name) => 'Salut, $name !';

  @override
  String get homeContinueLearning => 'Continue ton apprentissage';

  @override
  String get homePlay => 'Jouer';

  @override
  String get homeStatExercises => "Exercices aujourd'hui";

  @override
  String get homeStatMinutes => "Minutes aujourd'hui";

  @override
  String get homeStatStreak => 'Jours de suite';

  @override
  String get homeDailyQuestTitle => 'Défi du jour';

  @override
  String homeDailyQuestProgress(int progress, int target) =>
      '$progress/$target bonnes réponses de suite';

  @override
  String get homeDailyQuestCompleted => 'Défi complété !';

  @override
  String get pathTitle => 'Mon parcours';

  @override
  String get pathEmpty => "Il n'y a pas encore d'activités. Reviens bientôt !";

  @override
  String get pathLocked => 'Pas encore débloqué';

  @override
  String get profileTitle => 'Mon profil';

  @override
  String profileGrade(int grade) => 'Année $grade';

  @override
  String get profileBadgesComingSoon => 'Les badges arrivent bientôt !';

  @override
  String get profileSignOut => 'Déconnecter cet appareil';

  @override
  String profileSkillsMastered(int count) =>
      count == 1 ? 'compétence maîtrisée' : 'compétences maîtrisées';

  @override
  String profileStreakDays(int days) =>
      days == 1 ? 'jour de suite' : 'jours de suite';

  @override
  String profileFreezesAvailable(int count) => count == 1
      ? '1 gel de série disponible'
      : '$count gels de série disponibles';

  @override
  String get pinGateCreateTitle => 'Créer un NIP parent';

  @override
  String get pinGateCreateSubtitle =>
      'Crée un NIP à 4 chiffres pour que seul un adulte puisse déconnecter cet appareil.';

  @override
  String get pinGateEnterTitle => 'NIP parent';

  @override
  String get pinGateEnterSubtitle =>
      'Demande à un adulte d\'entrer le NIP pour déconnecter cet appareil.';

  @override
  String get pinGatePinLabel => 'NIP (4 chiffres)';

  @override
  String get pinGateConfirmPinLabel => 'Confirme le NIP';

  @override
  String get pinGateMismatch => 'Les NIP ne correspondent pas.';

  @override
  String get pinGateTooShort => 'Le NIP doit avoir 4 chiffres.';

  @override
  String get pinGateWrong => 'NIP incorrect.';

  @override
  String get pinGateCreate => 'Créer';

  @override
  String get pinGateConfirmSignOut => 'Déconnecter';

  @override
  String get navHome => 'Accueil';

  @override
  String get navPath => 'Parcours';

  @override
  String get navProfile => 'Profil';

  @override
  String get playBack => 'Retour';
}

class _EnglishStrings extends Strings {
  const _EnglishStrings();

  @override
  String get locale => 'en-CA';

  @override
  String get pairingTitle => 'Hi there!';

  @override
  String get pairingSubtitle => 'Enter your code to get started';

  @override
  String get pairingHint =>
      'Ask a grown-up for your code. It has six characters.';

  @override
  String get pairingConnect => 'Connect';

  @override
  String get pairingConnecting => 'Connecting…';

  @override
  String get pairingCodeInvalid =>
      "That code doesn't work. Ask a grown-up for a new one.";

  @override
  String get pairingOffline => "No internet. Check the Wi-Fi and try again.";

  @override
  String get pairingUnexpectedError =>
      "Something went wrong. Try again in a moment.";

  @override
  String pairingWelcome(String name) => 'Welcome, $name!';

  @override
  String get retry => 'Try again';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueLabel => 'Continue';

  @override
  String get loading => 'One moment…';

  @override
  String homeGreeting(String name) => 'Hi, $name!';

  @override
  String get homeContinueLearning => 'Continue learning';

  @override
  String get homePlay => 'Play';

  @override
  String get homeStatExercises => 'Exercises today';

  @override
  String get homeStatMinutes => 'Minutes today';

  @override
  String get homeStatStreak => 'Day streak';

  @override
  String get homeDailyQuestTitle => 'Daily challenge';

  @override
  String homeDailyQuestProgress(int progress, int target) =>
      '$progress/$target correct in a row';

  @override
  String get homeDailyQuestCompleted => 'Challenge complete!';

  @override
  String get pathTitle => 'My path';

  @override
  String get pathEmpty => "There are no activities yet. Come back soon!";

  @override
  String get pathLocked => 'Not unlocked yet';

  @override
  String get profileTitle => 'My profile';

  @override
  String profileGrade(int grade) => 'Grade $grade';

  @override
  String get profileBadgesComingSoon => 'Badges are coming soon!';

  @override
  String get profileSignOut => 'Sign out this device';

  @override
  String profileSkillsMastered(int count) =>
      count == 1 ? 'skill mastered' : 'skills mastered';

  @override
  String profileStreakDays(int days) => 'day streak';

  @override
  String profileFreezesAvailable(int count) => count == 1
      ? '1 streak freeze available'
      : '$count streak freezes available';

  @override
  String get pinGateCreateTitle => 'Create a parent PIN';

  @override
  String get pinGateCreateSubtitle =>
      'Set a 4-digit PIN so only a grown-up can sign out this device.';

  @override
  String get pinGateEnterTitle => 'Parent PIN';

  @override
  String get pinGateEnterSubtitle =>
      'Ask a grown-up to enter the PIN to sign out this device.';

  @override
  String get pinGatePinLabel => 'PIN (4 digits)';

  @override
  String get pinGateConfirmPinLabel => 'Confirm PIN';

  @override
  String get pinGateMismatch => "PINs don't match.";

  @override
  String get pinGateTooShort => 'PIN must be 4 digits.';

  @override
  String get pinGateWrong => 'Incorrect PIN.';

  @override
  String get pinGateCreate => 'Create';

  @override
  String get pinGateConfirmSignOut => 'Sign out';

  @override
  String get navHome => 'Home';

  @override
  String get navPath => 'Path';

  @override
  String get navProfile => 'Profile';

  @override
  String get playBack => 'Back';
}

/// Lookup from the widget tree.
extension StringsContext on BuildContext {
  Strings get s => Strings.of(Localizations.localeOf(this));
}
