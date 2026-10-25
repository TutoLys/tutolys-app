import 'package:flutter/widgets.dart';

import '../../features/help/help_screen.dart';

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
  String profileGrade(int grade);
  String get profileBadgesComingSoon;
  String get profileSignOut;
  String profileSkillsMastered(int count);
  String profileStreakDays(int days);
  String profileFreezesAvailable(int count);
  String get profileTotalXp;

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
  String playXpEarned(int xp);


  // --- navigation & settings ---------------------------------------------
  String get navVillage;
  String get navCarte;
  String get navQuetes;
  String get navProgres;
  String get navProfil;
  String get navReglages;
  String get navHelp;
  String get settingsEyebrow;
  String get settingsTitle;
  String get settingsAppearance;
  String get settingsTheme;
  String get settingsThemeSub;
  String get settingsThemeLight;
  String get settingsThemeDark;
  String get settingsSound;
  String get settingsVolume;
  String get settingsMusic;
  String get settingsSfx;
  String get settingsReadAloud;
  String get settingsReadAloudSub;
  String get settingsExperience;
  String get settingsLanguage;
  String get settingsReduceMotion;
  String get settingsReduceMotionSub;
  String get settingsNotifications;
  String get settingsDailyReminders;
  String get settingsDailyRemindersSub;
  String get settingsQuestNotifications;
  String get settingsParentZone;
  String get settingsParentZoneBody;
  String get settingsParentZoneCta;
  String get settingsAbout;
  String get settingsSignOut;
  String get comingSoonTitle;

  String get subjectMath;
  String get subjectFrancais;
  String get subjectAnglais;
  String get subjectScience;
  String get subjectUniversSocial;
  String get subjectCulture;
  String get villageSignTitle;
  String get villageRecommendedLabel;
  String get villageContinuePath;
  String get villageContinueCta;
  String get villageQuestsTitle;
  String get villageNoQuests;
  String get villageGreetingReady;
  String get villageGreetingQuest;
  String get notBuiltYetSuffix;
  String get comingSoonShort;

  /// `Salut <name> !` — the name is interpolated, so the punctuation and
  /// spacing stay inside the locale that owns them (French puts a space
  /// before "!", English does not).
  String greeting(String name);

  /// "3e année" / "Grade 3". Ordinals differ per language, so the whole
  /// phrase belongs to the locale rather than a shared format string.
  String gradeLabel(int grade);

  /// "3 bonnes réponses de suite".
  String streakQuestTitle(int target);

  String get profileEyebrow;
  String get profileTitle;
  String get profileStreakLabel;
  String get profileBySubject;
  String get profileBadges;
  String get profileBadgesSoon;
  String get profileRecent;
  String get profileRecentSoon;
  String get profileNoSubjects;
  String get daysShort;

  String get helpTitle;
  String get helpSubtitle;
  String get helpFaqTitle;
  String get helpParentsTitle;
  String get helpParentsBody;
  String get aboutTagline;
  String get aboutVersion;
  String get aboutCurriculum;
  String get aboutMadeIn;

  /// The FAQ, question and answer, in the reader's own language.
  List<HelpEntry> get helpEntries;

  String get villageYourSubjects;

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
  String get profileTotalXp => 'points XP';

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

  @override
  String playXpEarned(int xp) => '+$xp XP !';

  @override
  String get navVillage => 'Village';

  @override
  String get navCarte => 'Carte';

  @override
  String get navQuetes => 'Quêtes';

  @override
  String get navProgres => 'Progrès';

  @override
  String get navProfil => 'Profil';

  @override
  String get navReglages => 'Réglages';

  @override
  String get navHelp => 'Aide & support';

  @override
  String get settingsEyebrow => 'Ton espace';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsThemeSub => 'Clair ou sombre';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsSound => 'Son et musique';

  @override
  String get settingsVolume => 'Volume général';

  @override
  String get settingsMusic => 'Musique de fond';

  @override
  String get settingsSfx => 'Effets sonores';

  @override
  String get settingsReadAloud => 'Lire les questions à voix haute';

  @override
  String get settingsReadAloudSub => 'Recommandé pour les débuts en lecture';

  @override
  String get settingsExperience => 'Expérience';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsReduceMotion => 'Réduire les animations';

  @override
  String get settingsReduceMotionSub => 'Pour un affichage plus calme';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsDailyReminders => 'Rappels quotidiens';

  @override
  String get settingsDailyRemindersSub => 'Un petit coucou si tu n\'as pas joué';

  @override
  String get settingsQuestNotifications => 'Nouvelles quêtes';

  @override
  String get settingsParentZone => 'Zone parent';

  @override
  String get settingsParentZoneBody => 'Certains réglages (compte, abonnement, confidentialité) se font sur le site web, avec un parent.';

  @override
  String get settingsParentZoneCta => 'Ouvrir le site';

  @override
  String get settingsAbout => 'À propos de TutoLys';

  @override
  String get settingsSignOut => 'Se déconnecter';

  @override
  String get comingSoonTitle => 'Cette page arrive bientôt.';

  @override
  String get subjectMath => 'Mathématiques';

  @override
  String get subjectFrancais => 'Français';

  @override
  String get subjectAnglais => 'Anglais';

  @override
  String get subjectScience => 'Science et techno.';

  @override
  String get subjectUniversSocial => 'Univers social';

  @override
  String get subjectCulture => 'Culture québécoise';

  @override
  String get villageSignTitle => '🍁 Village des Érables';

  @override
  String get villageRecommendedLabel => 'ACTIVITÉ RECOMMANDÉE';

  @override
  String get villageContinuePath => 'Continue ton parcours';

  @override
  String get villageContinueCta => 'Continuer →';

  @override
  String get villageQuestsTitle => 'Quêtes du jour';

  @override
  String get villageNoQuests => 'Aucune quête aujourd\'hui.';

  @override
  String get villageGreetingReady => 'Prêt à jouer ? 🎯';

  @override
  String get villageGreetingQuest => 'Ton défi du jour t\'attend 🎯';

  @override
  String get notBuiltYetSuffix => 'pas encore construit';

  @override
  String get comingSoonShort => 'bientôt';
  @override
  String greeting(String name) => name.isEmpty ? 'Salut !' : 'Salut $name !';

  @override
  String gradeLabel(int grade) => '${grade}e année';

  @override
  String streakQuestTitle(int target) => '$target bonnes réponses de suite';

  @override
  String get profileEyebrow => 'Ton profil';

  @override
  String get profileStreakLabel => 'Série en cours';

  @override
  String get profileBySubject => 'Progression par matière';

  @override
  String get profileBadges => 'Badges';

  @override
  String get profileBadgesSoon => 'Les badges arrivent bientôt. Rien n\'est encore à gagner, alors rien n\'est affiché comme verrouillé.';

  @override
  String get profileRecent => 'Activité récente';

  @override
  String get profileRecentSoon => 'L\'historique détaillé arrivera avec les badges.';

  @override
  String get profileNoSubjects => 'Joue un peu et tes matières apparaîtront ici.';

  @override
  String get daysShort => 'j';

  @override
  String get helpTitle => 'Besoin d\'aide ?';

  @override
  String get helpSubtitle => 'Voici les questions qu\'on nous pose le plus souvent.';

  @override
  String get helpFaqTitle => 'Questions fréquentes';

  @override
  String get helpParentsTitle => 'Pour les parents';

  @override
  String get helpParentsBody => 'Une question technique, un problème de compte ? Passez par le site web.';

  @override
  String get aboutTagline => 'Apprendre en jouant, selon le programme du Québec.';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutCurriculum => 'Programme';

  @override
  String get aboutMadeIn => 'Fait au Québec 🍁';
  @override
  List<HelpEntry> get helpEntries => const [
        HelpEntry(question: 'Comment je gagne des pièces ?', answer: 'En terminant des exercices et en complétant des quêtes ! Plus tu joues, plus tu en gagnes.'),
        HelpEntry(question: 'C\'est quoi ma série ?', answer: 'C\'est le nombre de jours de suite où tu as joué. Termine au moins un exercice chaque jour pour ne pas la perdre.'),
        HelpEntry(question: 'Comment débloquer un nouveau bâtiment ?', answer: 'Chaque bâtiment du Village représente une matière. Plus tu avances dans son parcours (onglet Carte), plus sa barre de progression se remplit.'),
        HelpEntry(question: 'J\'ai perdu ma série, que faire ?', answer: 'Pas de panique ! Recommence aujourd\'hui — une nouvelle série démarre tout de suite.'),
        HelpEntry(question: 'J\'ai trouvé une erreur ou un problème', answer: 'Dis-le à un parent ou à ton enseignant — ils pourront nous contacter pour toi.'),
      ];

  @override
  String get villageYourSubjects => 'Tes matières';

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
  String get profileTotalXp => 'XP';

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

  @override
  String playXpEarned(int xp) => '+$xp XP!';

  @override
  String get navVillage => 'Village';

  @override
  String get navCarte => 'Map';

  @override
  String get navQuetes => 'Quests';

  @override
  String get navProgres => 'Progress';

  @override
  String get navProfil => 'Profile';

  @override
  String get navReglages => 'Settings';

  @override
  String get navHelp => 'Help & support';

  @override
  String get settingsEyebrow => 'Your space';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSub => 'Light or dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsSound => 'Sound and music';

  @override
  String get settingsVolume => 'Overall volume';

  @override
  String get settingsMusic => 'Background music';

  @override
  String get settingsSfx => 'Sound effects';

  @override
  String get settingsReadAloud => 'Read questions aloud';

  @override
  String get settingsReadAloudSub => 'Recommended for early readers';

  @override
  String get settingsExperience => 'Experience';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsReduceMotion => 'Reduce animations';

  @override
  String get settingsReduceMotionSub => 'For a calmer display';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsDailyReminders => 'Daily reminders';

  @override
  String get settingsDailyRemindersSub => 'A little hello if you haven\'t played';

  @override
  String get settingsQuestNotifications => 'New quests';

  @override
  String get settingsParentZone => 'Parent zone';

  @override
  String get settingsParentZoneBody => 'Some settings (account, subscription, privacy) are handled on the website, with a parent.';

  @override
  String get settingsParentZoneCta => 'Open the website';

  @override
  String get settingsAbout => 'About TutoLys';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get comingSoonTitle => 'This page is coming soon.';

  @override
  String get subjectMath => 'Mathematics';

  @override
  String get subjectFrancais => 'French';

  @override
  String get subjectAnglais => 'English';

  @override
  String get subjectScience => 'Science & tech';

  @override
  String get subjectUniversSocial => 'Social studies';

  @override
  String get subjectCulture => 'Quebec culture';

  @override
  String get villageSignTitle => '🍁 Maple Village';

  @override
  String get villageRecommendedLabel => 'RECOMMENDED ACTIVITY';

  @override
  String get villageContinuePath => 'Keep going on your path';

  @override
  String get villageContinueCta => 'Continue →';

  @override
  String get villageQuestsTitle => 'Today\'s quests';

  @override
  String get villageNoQuests => 'No quests today.';

  @override
  String get villageGreetingReady => 'Ready to play? 🎯';

  @override
  String get villageGreetingQuest => 'Your daily challenge is waiting 🎯';

  @override
  String get notBuiltYetSuffix => 'not built yet';

  @override
  String get comingSoonShort => 'soon';
  @override
  String greeting(String name) => name.isEmpty ? 'Hi!' : 'Hi $name!';

  @override
  String gradeLabel(int grade) => 'Grade $grade';

  @override
  String streakQuestTitle(int target) => '$target correct answers in a row';

  @override
  String get profileEyebrow => 'Your profile';

  @override
  String get profileStreakLabel => 'Current streak';

  @override
  String get profileBySubject => 'Progress by subject';

  @override
  String get profileBadges => 'Badges';

  @override
  String get profileBadgesSoon => 'Badges are coming soon. There is nothing to earn yet, so nothing is shown as locked.';

  @override
  String get profileRecent => 'Recent activity';

  @override
  String get profileRecentSoon => 'A detailed history will arrive with the badges.';

  @override
  String get profileNoSubjects => 'Play a little and your subjects will show up here.';

  @override
  String get daysShort => 'd';

  @override
  String get helpTitle => 'Need help?';

  @override
  String get helpSubtitle => 'Here are the questions we get asked most.';

  @override
  String get helpFaqTitle => 'Frequently asked';

  @override
  String get helpParentsTitle => 'For parents';

  @override
  String get helpParentsBody => 'A technical question, an account problem? Go through the website.';

  @override
  String get aboutTagline => 'Learning through play, following the Quebec curriculum.';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutCurriculum => 'Curriculum';

  @override
  String get aboutMadeIn => 'Made in Quebec 🍁';
  @override
  List<HelpEntry> get helpEntries => const [
        HelpEntry(question: 'How do I earn coins?', answer: 'By finishing exercises and completing quests! The more you play, the more you earn.'),
        HelpEntry(question: 'What is my streak?', answer: 'It\'s the number of days in a row you\'ve played. Finish at least one exercise each day to keep it.'),
        HelpEntry(question: 'How do I unlock a new building?', answer: 'Each building in the Village is a subject. The further you get along its path (the Map tab), the more its progress bar fills up.'),
        HelpEntry(question: 'I lost my streak, what now?', answer: 'Don\'t worry! Start again today — a new streak begins right away.'),
        HelpEntry(question: 'I found a mistake or a problem', answer: 'Tell a parent or your teacher — they can contact us for you.'),
      ];

  @override
  String get villageYourSubjects => 'Your subjects';

}

/// Lookup from the widget tree.
extension StringsContext on BuildContext {
  Strings get s => Strings.of(Localizations.localeOf(this));
}
