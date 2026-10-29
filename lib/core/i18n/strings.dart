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

  // --- launch: loader and welcome -----------------------------------------
  /// The loader's lines while the app is still getting ready, in story
  /// order. Shown on a timer, so none of them may claim a specific step is
  /// happening — they set a mood, the bar carries the facts.
  List<String> get launchMessages;

  /// Shown only once real progress is past 80 %, never on a timer.
  String get launchAlmost;

  /// Shown only once real progress is past 92 %.
  String get launchNearlyReady;

  /// Shown only when startup has genuinely finished.
  String get launchDone;

  // --- boot stuck screen and technical log (ADR 0038) ----------------------
  String get bootStuckTitle;
  String get bootStuckBody;
  String get bootDetails;
  String bootStuckOn(String step);
  String get bootPreviousRun;
  String get diagJournalTitle;
  String get diagEmpty;
  String get mascotSingLabel;

  /// Screen-reader label for the launch progress bar.
  String get launchProgressLabel;

  String get welcomeTagline;
  String welcomeGreeting(String name);
  String get welcomeFoxLine;
  String get welcomeFoxLineNew;

  /// The greeting when several kids share the device: nobody named.
  String get welcomeHello;
  String get welcomeWhoToday;
  String get welcomePlay;
  String get welcomeStart;

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

  /// The Carte has nothing to show because nothing could be downloaded.
  String get pathEmptyOffline;

  /// The curriculum has no skills in this subject at the kid's grade.
  String pathEmptyAtGrade(int grade);

  /// The skills are there, every one locked: no lesson written yet.
  String get pathNoLessonsYet;

  /// The Carte's sync failed, so it shows cached lessons as of [at] (null:
  /// never synced here). A lesson published since then reads "soon".
  String pathStale(DateTime? at);
  String get pathLocked;

  /// A Carte node with no lesson yet (ADR 0032): skipped, not locked.
  String get pathSoon;

  /// A leaf whose lesson isn't on the device, offline (ADR 0093).
  String get pathNotDownloaded;
  String get pathNotDownloadedOffline;
  String get pathDownloading;
  String get pathDownloadFailed;

  /// The active node's card. French puts a space before "%", English does not.
  String pathInProgress(int pct);

  /// A node with several lessons: how many are finished, read with the orb.
  String pathLessonsDone(int done, int total);

  /// The active node's card when the kid has not played it yet — "0 %
  /// maîtrisé" would read as a score rather than a beginning.
  String get pathNotStarted;
  String lessonLanguage(String locale);

  // --- progrès -------------------------------------------------------------
  String progressLevel(int level);
  /// The level pill's tooltip: skills completed of the grade's (ADR 0033).
  String headerLevelTooltip(int completed, int total, int grade);

  /// The header's XP pill: points earned, beside the level.
  String headerXp(int xp);

  /// The card over the strand rows, e.g. "Mathématique — par compétence".
  String progressBySkill(String subject);
  String get progressStatusMastered;
  String get progressStatusLearning;
  String get progressStatusNew;

  /// The row for leaves no known learning area claims.
  String get progressOtherSkills;
  String get progressNothingYet;

  /// French puts a space before "%", English does not.
  String progressPercent(int pct);

  // --- profile -------------------------------------------------------------
  String profileGrade(int grade);
  String get profileBadgesComingSoon;
  String get profileSignOut;
  String profileSkillsMastered(int count);
  String profileStreakDays(int days);
  String get profileTotalXp;

  // --- pin gate ------------------------------------------------------------
  String get pinGateCreateTitle;
  String get pinGateCreateSubtitle;
  String get pinGateEnterTitle;
  String get pinGateEnterSubtitle;
  String pinGatePinLabel(int digits);
  String get pinGateConfirmPinLabel;
  String get pinGateMismatch;
  String pinGateTooShort(int digits);
  String get pinGateUpgradeTitle;
  String get pinGateUpgradeSubtitle;
  String get pinGateWrong;
  String get pinGateCreate;
  String get pinGateConfirmSignOut;

  // --- removing a kid from the device (ADR 0037) ----------------------------
  String removeKidTitle(String name);
  String get removeKidIntro;
  String removeKidUnsent(int count);
  String removeKidCreations(int count);
  String get removeKidSendThenErase;
  String get removeKidEraseNow;
  String get removeKidSending;
  String get removeKidSendFailed;
  String get removeKidEraseAnyway;

  // --- nav -----------------------------------------------------------------
  String get navHome;
  String get navPath;
  String get navProfile;

  // --- play --------------------------------------------------------------
  String get playBack;


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
  /// "Ma flamme": the evening reminder when the streak is at risk.
  String get settingsFlameReminders;
  String get settingsFlameRemindersSub;
  String get settingsParentZone;
  String get settingsParentZoneBody;
  String get settingsParentZoneCta;
  String get settingsParentZoneSoon;
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
  String get villageQuestsSeeAll;
  String get notificationsTitle;
  String get notificationsEmpty;
  String get notificationsEmptyHint;
  String get notificationDailyQuest;
  String get notificationStreakFreeze;

  /// A shield spent on a day that turned out to be played (offline play
  /// uploaded late) is given back (backend ADR 0060).
  String get notificationStreakFreezeRefunded;

  /// A tutoring session coming up (backend ADR 0119). The server's French
  /// message names the tutor and the time; English has no such parameters
  /// on the wire yet, so it says the same thing without them.
  String notificationTutoringSession(String serverMessage);

  /// Teacher-assigned work (backend ADR 0123): the Carte's tag, and the
  /// Quêtes card. Never names a classmate (#12).
  String get homeworkTag;
  String get homeworkTitle;
  String homeworkFrom(String organization);
  String homeworkDue(DateTime day);
  String get homeworkDone;
  String notificationsBellLabel(int unread);
  String notificationsAgo(Duration elapsed);
  String get villageNoQuests;
  String get villageGreetingReady;
  String get villageGreetingQuest;
  String get notBuiltYetSuffix;
  String get comingSoonShort;
  String villageSubjectSoon(String subject);

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
  String get profileTabSubjects;
  String get profileBadges;
  String get profileTabRecent;
  String get profileRecentEmpty;

  /// The day a badge was earned, [daysAgo] days before today.
  String profileRecentDay(int daysAgo);
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

  // --- quêtes --------------------------------------------------------------
  String get questsEyebrow;
  String get questsTitle;
  String questsStreakDays(int days);

  /// Under the streak number. The design's "come back tomorrow" only reads
  /// right once today is played, so there is a today variant for before.
  String questsStreakNextTomorrow(int goal);
  String questsStreakNextToday(int goal);
  String get questsStreakStart;
  String get questsStreakUnknown;
  String get questsStreakOpenHint;

  /// One letter per day, Monday first.
  List<String> get weekdayInitials;
  String monthYear(int year, int month);

  String get streakDetailTitle;
  String get streakDetailEyebrow;
  String streakDetailHeadline(int days);
  String get streakDetailNudge;
  String get streakDetailNudgeCta;
  String get streakDetailCalendar;
  String get streakDetailPrevMonth;
  String get streakDetailNextMonth;
  String get streakDetailGoal;
  String get streakDetailRewards;

  /// The design's "Bouclier de série" is the real streak freeze (backend
  /// ADR 0019) under the design's own name.
  String get streakShieldTitle;
  String get streakShieldBody;
  String streakShieldBalance(int count);
  String get streakShieldNone;

  /// A pill tab's place in its row, for a screen reader: "onglet 2 sur 5".
  String tabPosition(int index, int count);

  /// Learning reminders (ADR 0053): kind, short, never guilt. A grown-up
  /// may well be the one reading them aloud.
  String get reminderTitle;
  String get reminderLearnBody;
  String get reminderFlameBody;

  /// Several kids at once: no name on a shared lock screen.
  String get reminderSeveralBody;

  String get settingsReminderTime;
  String reminderTimeLabel(int minutes);
  String get settingsRemindersWhileRunning;
  String get settingsRemindersWebNote;
  String get settingsRemindersClassNote;
  String get settingsRemindersBlocked;
  String get remindersPinCreate;
  String get remindersPinEnter;

  /// When the next shield comes (backend ADR 0153).
  String streakShieldRechargeIn(int days);
  String get streakShieldPlayToRecharge;
  String get streakShieldDueSoon;
  String get streakTabPersonal;
  String get backToQuests;
  String get questsViewQuests;
  String get questsViewSerie;
  String get questsSeeStreak;

  /// A label only: the design's greyed-out tab. No social feature (#12).
  String get streakTabFriends;

  // --- quêtes: the full board (app ADR 0015, revised) ------------------------
  String questExercisesTitle(int target);
  String questMinutesTitle(int target);
  String questRewardXp(int xp);

  /// "N quêtes t'attendent" — the fox's line while quests are open.
  String villageGreetingQuests(int open);
  String get headerQuestsLabel;

  String get weeklyBadgeTitle;
  String weeklyBadgeBody(int target);
  String weeklyBadgeProgress(int done, int target);
  String get weeklyBadgeEarned;
  String get recentTitle;
  String get lockedLabel;

  /// The eight achievements, in the design's badge-grid order.
  String get achStreak3;
  String get achQuestMaster;
  String get achLevel10;
  String get achStreak7;
  String get achAllSubjects50;
  String get achLevel20;
  String get achQuests50;
  String get achExplorer;

  String get chestTitle;
  String get chestBody;
  String get chestBodyLocked;
  String get flameKeeperTitle;

  /// "Titre : " — French puts a space before the colon.
  String get flameKeeperTitlePrefix;
  String get flameKeeperBody;
  String get rewardObtained;
  String get rewardActive;
  String rewardDaysLeft(int days);

  String get avatarEdit;
  String get avatarPickerTitle;
  String get avatarStarters;
  String get avatarUnlockables;
  String get avatarSubjects;
  String get avatarRares;

  /// What unlocks a level avatar: "Niveau 5".
  String avatarAtLevel(int level);

  /// What unlocks a subject avatar, short enough for a tile's two lines:
  /// "5 compétences · Sciences".
  /// [subject] is a `pathSubjects` code.
  String avatarForSubject(String subject, int skills);

  /// Under a rare avatar not found yet, which shows as "?".
  String get avatarRareHint;

  /// The moment a perfect lesson reveals a rare avatar.
  String get avatarRareFound;

  /// The picker section of real historical figures.
  String get avatarHistorical;

  /// Under a historical figure not found yet.
  String get avatarHistoricalHint;

  /// Who a historical figure was, in one factual line; null for others.
  String? avatarCaption(String key);

  /// Read by screen readers on a locked avatar.
  String avatarLocked(String condition);
  String avatarName(String key);

  String get profileBadgesEarned;
  String get switchProfile;
  String get whoIsPlaying;
  String get notMe;

  // Picture passcode (B-A0.5): "who's playing?", never "log in".
  String get pictureFlame;
  String get pictureChest;
  String get pictureCoin;
  String get pictureBell;
  String get pictureTarget;
  String get pictureStar;
  String get pictureFox;
  String get pictureMathHouse;
  String get pictureScienceHouse;
  String passcodeIsItYou(String name);
  String get passcodePrompt;
  String get passcodeWrong;
  String get passcodeTooMany;
  String get passcodeUndo;
  String passcodeSlot(int position);
  String get passcodesTitle;
  String get passcodesBody;
  String get passcodeIsSet;
  String get passcodeNotSet;
  String get passcodeChoose;
  String get passcodeChange;
  String get passcodeRemove;
  String passcodeSetupTitle(String name);
  String get passcodeSetupPick;
  String get passcodeSetupConfirm;
  String get passcodeSetupMismatch;
  String get passcodeSaved;
  String get passcodeRemoved;
  String get passcodeNeedsInternet;
  String get pinGateContinue;
  String get passcodesPinCreate;
  String get passcodesPinEnter;
  String get pairingClassLink;
  String get pairingKidLink;
  String get pairingClassTitle;
  String get pairingClassSubtitle;
  String get pairingClassInvalid;
  String get pairingClassEmpty;
  String get pairingClassNotEntitled;

  /// No seat (backend 403 `seat_required`). Never about money: a child is
  /// told who can fix it, nothing more (ADR 0037, revision 2026-10-28).
  String get pairingNoSeat;
  String get noSeatTitle;
  String get noSeatBody;
  String whoIsPlayingClass(String className);
  String passcodeWaitTitle(String name);
  String get passcodeWaitBody;
  String get passcodeWaitAdult;
  String get passcodePromptTitle;
  String get passcodePromptBody;
  String get passcodePromptLater;
  String get passcodePromptChoose;
  String get addProfile;
  String get addProfileHint;
  String get addProfileCancel;

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
      'Demande ton code à la personne responsable de ton compte.';

  @override
  String get pairingConnect => 'Se connecter';

  @override
  String get pairingConnecting => 'Connexion…';

  @override
  String get pairingCodeInvalid =>
      "Ce code ne fonctionne pas. Demande-en un nouveau à la personne responsable de ton compte.";

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
  List<String> get launchMessages => const [
        'Préparation de ton aventure…',
        'On prépare le village pour toi…',
        'On rassemble tes activités…',
        'Foxy arrive avec tes défis…',
        'On installe ton parcours d’apprentissage…',
      ];

  @override
  String get launchAlmost => 'Tiens bon, on y est presque…';

  @override
  String get launchNearlyReady => 'Presque prêt…';

  @override
  String get launchDone => 'Bienvenue dans TutoLys !';

  @override
  String get bootStuckTitle => 'Le village prend son temps';

  @override
  String get bootStuckBody =>
      'Ça prend plus de temps que d’habitude. On réessaie ?';

  @override
  String get bootDetails => 'Détails';

  @override
  String bootStuckOn(String step) => 'Étape en attente : $step';

  @override
  String get bootPreviousRun => 'Session précédente';

  @override
  String get diagJournalTitle => 'Journal technique';

  @override
  String get diagEmpty => 'Aucune erreur enregistrée.';

  @override
  String get mascotSingLabel => 'Faire chanter TutoLys';

  @override
  String get launchProgressLabel => 'Chargement de TutoLys';

  @override
  String get welcomeTagline => 'Ton aventure d’apprentissage au Québec';

  @override
  String welcomeGreeting(String name) => 'Salut $name !';

  @override
  String get welcomeFoxLine => 'On repart à l’aventure ?';

  @override
  String get welcomeFoxLineNew => 'Viens découvrir le village avec moi !';

  @override
  String get welcomeHello => 'Salut !';

  @override
  String get welcomeWhoToday => 'Qui joue aujourd’hui ?';

  @override
  String get welcomePlay => 'Jouer';

  @override
  String get welcomeStart => 'Commencer l’aventure';

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
  String get pathEmptyOffline =>
      'Connecte-toi à Internet pour charger cette matière.';

  @override
  String pathEmptyAtGrade(int grade) =>
      "Il n'y a rien dans cette matière pour la ${gradeLabel(grade)}.";

  @override
  String get pathNoLessonsYet =>
      'Les activités de cette matière sont en préparation. Reviens bientôt !';

  @override
  String pathStale(DateTime? at) {
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', //
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
    ];
    if (at == null) {
      return 'Impossible de joindre TutoLys. Des activités peuvent manquer.';
    }
    final time = '${at.hour} h ${at.minute.toString().padLeft(2, '0')}';
    return 'Impossible de joindre TutoLys. Activités à jour au '
        '${at.day} ${months[at.month - 1]} à $time.';
  }

  @override
  String get pathLocked => 'Pas encore débloqué';

  @override
  String get pathSoon => 'Bientôt';

  @override
  String get pathNotDownloaded => 'Pas encore sur ton appareil';

  @override
  String get pathNotDownloadedOffline =>
      "Cette leçon n'est pas encore sur ton appareil. "
      'Reviens quand tu auras Internet !';

  @override
  String get pathDownloading => 'Je prépare ta leçon…';

  @override
  String get pathDownloadFailed =>
      "Oups, la leçon n'a pas pu venir. Réessaie dans un moment !";

  @override
  String pathInProgress(int pct) => 'En cours · $pct % maîtrisé';
  @override
  String pathLessonsDone(int done, int total) =>
      '$done leçon${done > 1 ? 's' : ''} sur $total terminée${done > 1 ? 's' : ''}';

  @override
  String get pathNotStarted => 'À découvrir';

  @override
  String lessonLanguage(String locale) =>
      locale.startsWith('en') ? 'Leçon en anglais' : 'Leçon en français';

  @override
  String progressLevel(int level) => 'Niv. $level';

  @override
  String headerLevelTooltip(int completed, int total, int grade) =>
      '$completed notions réussies sur $total en ${gradeLabel(grade)}';

  @override
  String headerXp(int xp) => '$xp XP';

  @override
  String progressBySkill(String subject) => '$subject — par compétence';

  @override
  String get progressStatusMastered => 'Maîtrisé';

  @override
  String get progressStatusLearning => 'En cours';

  @override
  String get progressStatusNew => 'À découvrir';

  @override
  String get progressOtherSkills => 'Autres compétences';

  @override
  String get progressNothingYet =>
      "Rien à montrer pour cette matière pour l'instant.";

  @override
  String progressPercent(int pct) => '$pct %';

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
  String get profileTotalXp => 'points XP';

  @override
  String get pinGateCreateTitle => 'Créer un NIP parent';

  @override
  String get pinGateCreateSubtitle =>
      'Crée un NIP à 6 chiffres pour que seul un adulte puisse déconnecter cet appareil.';

  @override
  String get pinGateEnterTitle => 'NIP parent';

  @override
  String get pinGateEnterSubtitle =>
      'Demande à un adulte d\'entrer le NIP pour déconnecter cet appareil.';

  @override
  String pinGatePinLabel(int digits) => 'NIP ($digits chiffres)';

  @override
  String get pinGateConfirmPinLabel => 'Confirme le NIP';

  @override
  String get pinGateMismatch => 'Les NIP ne correspondent pas.';

  @override
  String pinGateTooShort(int digits) => 'Le NIP doit avoir $digits chiffres.';

  @override
  String get pinGateUpgradeTitle => 'Choisis un nouveau NIP';

  @override
  String get pinGateUpgradeSubtitle =>
      'Le NIP parent a maintenant 6 chiffres. Choisis-en un nouveau pour continuer.';

  @override
  String get pinGateWrong => 'NIP incorrect.';

  @override
  String get pinGateCreate => 'Créer';

  @override
  String get pinGateConfirmSignOut => 'Déconnecter';

  @override
  String removeKidTitle(String name) =>
      name.isEmpty ? 'Retirer ce profil de l’appareil ?' : 'Retirer $name de l’appareil ?';

  @override
  String get removeKidIntro =>
      'Tout ce qui est gardé sur cet appareil pour ce profil sera effacé :';

  @override
  String removeKidUnsent(int count) => switch (count) {
    0 => 'tous ses résultats de jeu ont déjà été envoyés ;',
    1 => '1 résultat de jeu pas encore envoyé ;',
    _ => '$count résultats de jeu pas encore envoyés ;',
  };

  @override
  String removeKidCreations(int count) => switch (count) {
    0 => 'aucune création dans « Mes créations ».',
    1 => '1 création dans « Mes créations ».',
    _ => '$count créations dans « Mes créations ».',
  };

  @override
  String get removeKidSendThenErase => 'Envoyer puis effacer';

  @override
  String get removeKidEraseNow => 'Effacer maintenant';

  @override
  String get removeKidSending => 'Envoi des résultats…';

  @override
  String get removeKidSendFailed =>
      'L’envoi n’a pas marché. Si tu effaces quand même, les résultats '
      'pas encore envoyés seront perdus.';

  @override
  String get removeKidEraseAnyway => 'Effacer quand même';

  @override
  String get navHome => 'Accueil';

  @override
  String get navPath => 'Parcours';

  @override
  String get navProfile => 'Profil';

  @override
  String get playBack => 'Retour';


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
  String get settingsFlameReminders => 'Ma flamme';

  @override
  String get settingsFlameRemindersSub =>
      'Un petit mot le soir si ta flamme n\'a pas encore brillé aujourd\'hui';

  @override
  String get settingsParentZone => 'Zone parent';

  @override
  String get settingsParentZoneBody => 'Certains réglages (compte, abonnement, confidentialité) se font sur le site web, avec un parent.';

  @override
  String get settingsParentZoneCta => 'Ouvrir le site';

  @override
  String get settingsParentZoneSoon =>
      'Le site des parents arrive bientôt !';

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
  String get villageSignTitle => 'Village des Lys';

  @override
  String get villageRecommendedLabel => 'ACTIVITÉ RECOMMANDÉE';

  @override
  String get villageContinuePath => 'Continue ton parcours';

  @override
  String get villageContinueCta => 'Continuer →';

  @override
  String get villageQuestsTitle => 'Quêtes du jour';

  @override
  String get villageQuestsSeeAll => 'Voir toutes';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty => 'Rien de nouveau pour l’instant.';

  @override
  String get notificationsEmptyHint =>
      'Réussis le défi du jour pour en recevoir une !';

  @override
  String get notificationDailyQuest => 'Défi du jour réussi ! Bravo !';

  @override
  String get notificationStreakFreeze =>
      'Ton bouclier a protégé ta série.';

  @override
  String get notificationStreakFreezeRefunded =>
      "Tu avais joué ce jour-là : ton bouclier t'est rendu.";

  @override
  String notificationTutoringSession(String serverMessage) => serverMessage;

  @override
  String get homeworkTag => 'Devoir';

  @override
  String get homeworkTitle => 'De ton enseignant·e';

  @override
  String homeworkFrom(String organization) => 'De $organization';

  @override
  String homeworkDue(DateTime day) => 'Pour le ${day.day}/${day.month}';

  @override
  String get homeworkDone => 'Fait !';

  @override
  String notificationsBellLabel(int unread) => switch (unread) {
        0 => 'Notifications',
        1 => 'Notifications, 1 non lue',
        _ => 'Notifications, $unread non lues',
      };

  @override
  String notificationsAgo(Duration elapsed) {
    if (elapsed.inMinutes < 1) return 'à l’instant';
    if (elapsed.inHours < 1) return 'il y a ${elapsed.inMinutes} min';
    if (elapsed.inDays < 1) return 'il y a ${elapsed.inHours} h';
    if (elapsed.inDays == 1) return 'hier';
    return 'il y a ${elapsed.inDays} jours';
  }

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
  String villageSubjectSoon(String subject) => '$subject arrive bientôt !';
  @override
  String greeting(String name) => name.isEmpty ? 'Salut !' : 'Salut $name !';

  @override
  // « 1re », then « 2e », « 3e »…
  String gradeLabel(int grade) => '$grade${grade == 1 ? 're' : 'e'} année';

  @override
  String streakQuestTitle(int target) => '$target bonnes réponses de suite';

  @override
  String get profileEyebrow => 'Ton profil';

  @override
  String get profileStreakLabel => 'Série en cours';

  @override
  String get profileTabSubjects => 'Par matière';

  @override
  String get profileBadges => 'Badges';


  @override
  String get profileTabRecent => 'Récent';

  @override
  String get profileRecentEmpty =>
      'Termine une quête pour gagner ton premier badge.';

  @override
  String profileRecentDay(int daysAgo) => switch (daysAgo) {
        <= 0 => 'Aujourd’hui',
        1 => 'Hier',
        _ => 'Il y a $daysAgo jours',
      };

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
  String get aboutMadeIn => 'Fait au Québec';
  @override
  List<HelpEntry> get helpEntries => const [
        HelpEntry(question: 'Comment je gagne des XP ?', answer: 'Chaque bonne réponse te donne 1 XP. Quand tu termines une activité, tu gagnes un bonus, et encore un peu plus si tout était juste du premier coup ! Le défi du jour vaut 10 XP. Si tu rejoues une activité déjà terminée, tu gagnes un petit peu.'),
        HelpEntry(question: 'À quoi sert mon niveau ?', answer: 'Ton niveau monte à mesure que tu réussis de nouvelles notions de ton année scolaire. Il va jusqu\'à 99 !'),
        HelpEntry(question: 'C\'est quoi ma série ?', answer: 'C\'est le nombre de jours de suite où tu as joué. Termine au moins un exercice chaque jour pour ne pas la perdre.'),
        HelpEntry(question: 'Comment débloquer un nouveau bâtiment ?', answer: 'Chaque bâtiment du Village représente une matière. Plus tu avances dans son parcours (onglet Carte), plus sa barre de progression se remplit.'),
        HelpEntry(question: 'J\'ai perdu ma série, que faire ?', answer: 'Pas de panique ! Recommence aujourd\'hui — une nouvelle série démarre tout de suite.'),
        HelpEntry(question: 'J\'ai trouvé une erreur ou un problème', answer: 'Dis-le à un parent ou à ton enseignant — ils pourront nous contacter pour toi.'),
      ];

  @override
  String get villageYourSubjects => 'Tes matières';

  @override
  String get questsEyebrow => 'Aujourd\'hui et cette semaine';

  @override
  String get questsTitle => 'Tes quêtes';

  @override
  String questsStreakDays(int days) =>
      days == 1 ? '1 jour de suite' : '$days jours de suite';

  @override
  String questsStreakNextTomorrow(int goal) =>
      'Continue demain pour atteindre $goal !';

  @override
  String questsStreakNextToday(int goal) =>
      'Joue aujourd\'hui pour atteindre $goal !';

  @override
  String get questsStreakStart => 'Termine une leçon pour lancer ta série !';

  @override
  String get questsStreakUnknown =>
      'On ne peut pas lire ta série pour l\'instant.';

  @override
  String get questsStreakOpenHint => 'Voir le détail de ta série';

  @override
  List<String> get weekdayInitials => const ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  static const _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet',
    'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  @override
  String monthYear(int year, int month) => '${_months[month - 1]} $year';

  @override
  String get streakDetailTitle => 'Série';

  @override
  String get streakDetailEyebrow => 'La flamme de la série';

  @override
  String streakDetailHeadline(int days) =>
      days == 1 ? 'Série de 1 jour' : 'Série de $days jours';

  @override
  String get streakDetailNudge =>
      'Termine une leçon aujourd\'hui pour prolonger ta série !';

  @override
  String get streakDetailNudgeCta => 'Prolonger ma série →';

  @override
  String get streakDetailCalendar => 'Calendrier';

  @override
  String get streakDetailPrevMonth => 'Mois précédent';

  @override
  String get streakDetailNextMonth => 'Mois suivant';

  @override
  String get streakDetailGoal => 'Objectif de série';

  @override
  String get streakDetailRewards => 'Récompenses de série';

  @override
  String get streakShieldTitle => 'Bouclier de série';

  @override
  String get streakShieldBody =>
      'Protège ta série si tu manques une journée d\'entraînement.';

  @override
  String streakShieldBalance(int count) =>
      count == 1 ? '1 bouclier prêt' : '$count boucliers prêts';

  @override
  String get streakShieldNone => 'Tu en gagnes un chaque semaine.';

  @override
  String tabPosition(int index, int count) => 'onglet $index sur $count';

  @override
  String get reminderTitle => 'TutoLys';

  @override
  String get reminderLearnBody =>
      'Le renard a préparé une nouvelle leçon. On joue ?';

  @override
  String get reminderFlameBody =>
      'Ta flamme brille encore aujourd\'hui. Une petite leçon la garde allumée !';

  @override
  String get reminderSeveralBody => 'Qui veut jouer au village aujourd\'hui ?';

  @override
  String get settingsReminderTime => 'Heure du rappel';

  @override
  String reminderTimeLabel(int minutes) {
    final m = minutes % 60;
    return '${minutes ~/ 60} h${m == 0 ? '' : ' ${m.toString().padLeft(2, '0')}'}';
  }

  @override
  String get settingsRemindersWhileRunning =>
      'Sur cet ordinateur, seulement quand TutoLys est ouvert.';

  @override
  String get settingsRemindersWebNote =>
      'Les rappels arrivent sur l\'application installée, pas dans le navigateur.';

  @override
  String get settingsRemindersClassNote =>
      'Pas de rappels sur une tablette de classe.';

  @override
  String get settingsRemindersBlocked =>
      'Les notifications sont bloquées pour TutoLys dans les réglages de l\'appareil.';

  @override
  String get remindersPinCreate =>
      'Crée d\'abord un NIP parent à 6 chiffres : seul un adulte pourra '
      'activer les rappels ou choisir leur heure.';

  @override
  String get remindersPinEnter =>
      'Demande à un adulte d\'entrer le NIP pour gérer les rappels.';

  @override
  String streakShieldRechargeIn(int days) =>
      days == 1 ? 'Rechargé dans 1 jour' : 'Rechargé dans $days jours';

  @override
  String get streakShieldPlayToRecharge => 'Joue une leçon pour recharger';

  @override
  String get streakShieldDueSoon => 'Bientôt rechargé';


  @override
  String get streakTabPersonal => 'Personnelle';

  @override
  String get backToQuests => 'Retour aux quêtes';

  @override
  String get questsViewQuests => 'Mes quêtes';

  @override
  String get questsViewSerie => 'Ma série';

  @override
  String get questsSeeStreak => 'Voir ma série';

  @override
  String get streakTabFriends => 'Entre amis';

  @override
  String questExercisesTitle(int target) => 'Résous $target exercices';

  @override
  String questMinutesTitle(int target) => 'Joue $target minutes';

  @override
  String questRewardXp(int xp) => '+$xp XP';

  @override
  String villageGreetingQuests(int open) => open == 1
      ? '1 quête t\'attend aujourd\'hui 🎯'
      : '$open quêtes t\'attendent aujourd\'hui 🎯';

  @override
  String get headerQuestsLabel => 'quêtes';

  @override
  String get weeklyBadgeTitle => 'Badge de la semaine';

  @override
  String weeklyBadgeBody(int target) => 'Termine $target quêtes avant dimanche';

  @override
  String weeklyBadgeProgress(int done, int target) => '$done / $target quêtes';

  @override
  String get weeklyBadgeEarned => 'Badge obtenu !';

  @override
  String get recentTitle => 'Réussites récentes';

  @override
  String get lockedLabel => 'Verrouillé';

  @override
  String get achStreak3 => 'Série de 3 jours';

  @override
  String get achQuestMaster => 'Maître des quêtes';

  @override
  String get achLevel10 => 'Niveau 10';

  @override
  String get achStreak7 => 'Série de 7 jours';

  @override
  String get achAllSubjects50 => 'Toutes matières 50 %';

  @override
  String get achLevel20 => 'Niveau 20';

  @override
  String get achQuests50 => '50 quêtes';

  @override
  String get achExplorer => 'Explorateur';

  @override
  String get chestTitle => 'Coffre de série · 3 jours';

  @override
  String get chestBody => 'Bravo, tu as atteint une série de 3 jours !';

  @override
  String get chestBodyLocked => 'Atteins une série de 3 jours pour l\'ouvrir.';

  @override
  String get flameKeeperTitle => 'Gardien de la flamme';

  @override
  String get flameKeeperTitlePrefix => 'Titre : ';

  @override
  String get flameKeeperBody =>
      'Affiche ce titre sur ton profil pour montrer ta régularité.';

  @override
  String get rewardObtained => 'Récompense obtenue';

  @override
  String get rewardActive => 'Activé';

  @override
  String rewardDaysLeft(int days) =>
      days == 1 ? 'Encore 1 jour' : 'Encore $days jours';

  @override
  String get avatarEdit => 'Modifier l\'avatar';

  @override
  String get avatarPickerTitle => 'Choisis ton avatar';

  @override
  String get avatarStarters => 'Pour commencer';

  @override
  String get avatarUnlockables => 'À débloquer en jouant';

  @override
  String get avatarSubjects => 'Par matière';

  @override
  String get avatarRares => 'Raretés';

  @override
  String avatarAtLevel(int level) => 'Niveau $level';

  @override
  String avatarForSubject(String subject, int skills) {
    final short = switch (subject) {
      'MATH' => 'Maths',
      'FR' => 'Français',
      'EN' => 'Anglais',
      'SCI' => 'Sciences',
      'SOC' => 'Univers social',
      'CCQ' => 'Culture QC',
      _ => subject,
    };
    return '$skills compétences · $short';
  }

  @override
  String get avatarRareHint => 'Caché · leçon parfaite';

  @override
  String get avatarRareFound => 'Avatar rare trouvé !';

  @override
  String get avatarHistorical => 'Personnages historiques';

  @override
  String get avatarHistoricalHint => 'Caché · leçon de CCQ parfaite';

  @override
  String? avatarCaption(String key) => switch (key) {
        'hist_therese_casgrain' =>
          'A lutté pour le droit de vote des femmes au Québec',
        'hist_rene_levesque' => 'Premier ministre du Québec de 1976 à 1985',
        _ => null,
      };

  @override
  String avatarLocked(String condition) => 'Verrouillé : $condition';

  @override
  String avatarName(String key) => switch (key) {
        'camper_girl' => 'Campeuse',
        'camper_boy' => 'Campeur',
        'explorer_girl' => 'Exploratrice',
        'explorer_boy' => 'Explorateur',
        'scientist_girl' || 'scientist_boy' => 'Scientifique',
        'chemist_girl' || 'chemist_boy' => 'Chimiste',
        'knight_girl' => 'Chevalière',
        'knight_boy' => 'Chevalier',
        'fleur_knight_girl' => 'Chevalière à la fleur de lys',
        'fleur_knight_boy' => 'Chevalier à la fleur de lys',
        'mathematician_girl' => 'Mathématicienne',
        'mathematician_boy' => 'Mathématicien',
        'french_teacher_girl' || 'french_teacher_boy' => 'Prof de français',
        'english_girl' || 'english_boy' => 'Prof d\'anglais',
        'historian_girl' => 'Historienne',
        'historian_boy' => 'Historien',
        'tuque_girl' => 'Tuque d\'hiver',
        'hero_girl' => 'Super-héroïne',
        'hero_boy' => 'Super-héros',
        'captain_girl' || 'captain_boy' => 'Capitaine',
        'artist_girl' || 'artist_boy' => 'Artiste',
        'fox_hood' => 'Capuche de renard',
        'wizard_girl' => 'Magicienne',
        'wizard_boy' => 'Magicien',
        'astronaut_girl' || 'astronaut_boy' => 'Astronaute',
        'coder_girl' => 'Codeuse',
        'coder_boy' => 'Codeur',
        'mermaid' => 'Sirène',
        'hist_therese_casgrain' => 'Thérèse Casgrain',
        'hist_rene_levesque' => 'René Lévesque',
        'pirate' => 'Pirate',
        _ => 'Avatar',
      };

  @override
  String get profileBadgesEarned => 'Badges obtenus';

  @override
  String get switchProfile => 'Changer de profil';

  @override
  String get whoIsPlaying => 'Qui joue ?';

  @override
  String get notMe => 'Ce n\'est pas moi';

  @override
  String get pictureFlame => 'la flamme';

  @override
  String get pictureChest => 'le coffre';

  @override
  String get pictureCoin => 'la pièce';

  @override
  String get pictureBell => 'la cloche';

  @override
  String get pictureTarget => 'la cible';

  @override
  String get pictureStar => 'l\'étoile';

  @override
  String get pictureFox => 'le renard';

  @override
  String get pictureMathHouse => 'la maison des maths';

  @override
  String get pictureScienceHouse => 'la maison des sciences';

  @override
  String passcodeIsItYou(String name) => 'C\'est toi, $name ?';

  @override
  String get passcodePrompt => 'Touche tes 3 images, dans l\'ordre.';

  @override
  String get passcodeWrong => 'Oups ! Ce ne sont pas tes images. Essaie encore.';

  @override
  String get passcodeTooMany => 'Fais une petite pause, puis réessaie.';

  @override
  String get passcodeUndo => 'Effacer';

  @override
  String passcodeSlot(int position) => 'Image $position';

  @override
  String get passcodesTitle => 'Codes images';

  @override
  String get passcodesBody =>
      'Chaque enfant touche ses 3 images pour dire « c\'est moi ». Ce n\'est '
      'pas un mot de passe : ça garde les progrès de chacun à leur place.';

  @override
  String get passcodeIsSet => 'Code choisi';

  @override
  String get passcodeNotSet => 'Pas de code';

  @override
  String get passcodeChoose => 'Choisir';

  @override
  String get passcodeChange => 'Changer';

  @override
  String get passcodeRemove => 'Retirer';

  @override
  String passcodeSetupTitle(String name) => 'Code images de $name';

  @override
  String get passcodeSetupPick =>
      'Choisis 3 images différentes, dans l\'ordre.';

  @override
  String get passcodeSetupConfirm => 'Encore une fois, pour confirmer.';

  @override
  String get passcodeSetupMismatch =>
      'Ce n\'était pas le même ordre. On recommence.';

  @override
  String get passcodeSaved => 'Code enregistré.';

  @override
  String get passcodeRemoved => 'Code retiré.';

  @override
  String get passcodeNeedsInternet =>
      'Impossible pour l\'instant : vérifie la connexion Internet.';

  @override
  String get pinGateContinue => 'Continuer';

  @override
  String get passcodesPinCreate =>
      'Crée d\'abord un NIP parent à 6 chiffres : seul un adulte pourra '
      'changer les codes images.';

  @override
  String get passcodesPinEnter =>
      'Demande à un adulte d\'entrer le NIP pour gérer les codes images.';

  @override
  String get pairingClassLink =>
      'Ajouter une classe';

  @override
  String get pairingKidLink =>
      'Ajouter un enfant';

  @override
  String get pairingClassTitle =>
      'Code de la classe';

  @override
  String get pairingClassSubtitle =>
      'Entre le code que ton enseignant·e montre à la classe.';

  @override
  String get pairingClassInvalid =>
      'Ce code ne marche pas. Demande un nouveau code à ton enseignant·e.';

  @override
  String get pairingClassEmpty =>
      'Cette classe n\'a pas encore d\'élèves.';

  @override
  String get pairingClassNotEntitled =>
      'Demande à ton enseignant·e : l\'école doit d\'abord activer TutoLys.';

  @override
  String get pairingNoSeat =>
      'Ce profil n\'a pas encore de place. Demande à un parent de t\'ajouter.';

  @override
  String get noSeatTitle => 'Demande à un parent de t\'ajouter.';

  @override
  String get noSeatBody =>
      'Pour l\'instant, ton profil ne peut pas jouer. Quand un adulte t\'aura '
      'ajouté, touche « Réessayer ».';

  @override
  String whoIsPlayingClass(String className) =>
      'Classe : $className';

  @override
  String passcodeWaitTitle(String name) =>
      'Ton code images n\'est pas encore prêt, $name.';

  @override
  String get passcodeWaitBody =>
      'Demande à un adulte de le choisir avec toi.';

  @override
  String get passcodeWaitAdult =>
      'Je suis l\'adulte';

  @override
  String get passcodePromptTitle =>
      'Plusieurs enfants sur cet appareil';

  @override
  String get passcodePromptBody =>
      'Choisis un code images pour chacun : ainsi, chacun garde ses propres progrès.';

  @override
  String get passcodePromptLater =>
      'Plus tard';

  @override
  String get passcodePromptChoose =>
      'Choisir les codes';

  @override
  String get addProfile => 'Ajouter un profil';

  @override
  String get addProfileHint =>
      'Demande à un parent un code de jumelage pour ajouter un enfant.';

  @override
  String get addProfileCancel => 'Retour';

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
      'Ask the person in charge of your account for your code.';

  @override
  String get pairingConnect => 'Connect';

  @override
  String get pairingConnecting => 'Connecting…';

  @override
  String get pairingCodeInvalid =>
      "That code doesn't work. Ask the person in charge of your account for a new one.";

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
  List<String> get launchMessages => const [
        'Getting your adventure ready…',
        'Setting up the village for you…',
        'Gathering your activities…',
        'Foxy is on the way with your challenges…',
        'Laying out your learning path…',
      ];

  @override
  String get launchAlmost => 'Hang on, we’re nearly there…';

  @override
  String get launchNearlyReady => 'Almost ready…';

  @override
  String get launchDone => 'Welcome to TutoLys!';

  @override
  String get bootStuckTitle => 'The village is taking its time';

  @override
  String get bootStuckBody =>
      'This is taking longer than usual. Shall we try again?';

  @override
  String get bootDetails => 'Details';

  @override
  String bootStuckOn(String step) => 'Waiting on: $step';

  @override
  String get bootPreviousRun => 'Previous run';

  @override
  String get diagJournalTitle => 'Technical log';

  @override
  String get diagEmpty => 'No errors recorded.';

  @override
  String get mascotSingLabel => 'Make TutoLys sing';

  @override
  String get launchProgressLabel => 'Loading TutoLys';

  @override
  String get welcomeTagline => 'Your learning adventure in Québec';

  @override
  String welcomeGreeting(String name) => 'Hi $name!';

  @override
  String get welcomeFoxLine => 'Off on another adventure?';

  @override
  String get welcomeFoxLineNew => 'Come explore the village with me!';

  @override
  String get welcomeHello => 'Hi!';

  @override
  String get welcomeWhoToday => 'Who’s playing today?';

  @override
  String get welcomePlay => 'Play';

  @override
  String get welcomeStart => 'Start the adventure';

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
  String get pathEmptyOffline =>
      'Connect to the internet to load this subject.';

  @override
  String pathEmptyAtGrade(int grade) =>
      "There's nothing in this subject for ${gradeLabel(grade)}.";

  @override
  String get pathNoLessonsYet =>
      'Activities for this subject are on their way. Come back soon!';

  @override
  String pathStale(DateTime? at) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    if (at == null) {
      return "Couldn't reach TutoLys. Some lessons may be missing.";
    }
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    return "Couldn't reach TutoLys. Lessons as of "
        '${months[at.month - 1]} ${at.day}, $h:$m ${at.hour < 12 ? 'AM' : 'PM'}.';
  }

  @override
  String get pathLocked => 'Not unlocked yet';

  @override
  String get pathSoon => 'Soon';

  @override
  String get pathNotDownloaded => 'Not on your device yet';

  @override
  String get pathNotDownloadedOffline =>
      "This lesson isn't on your device yet. "
      'Come back when you have Internet!';

  @override
  String get pathDownloading => 'Getting your lesson ready…';

  @override
  String get pathDownloadFailed =>
      "Oops, the lesson couldn't come. Try again in a moment!";

  @override
  String pathInProgress(int pct) => 'In progress · $pct% mastered';
  @override
  String pathLessonsDone(int done, int total) =>
      '$done of $total lessons done';

  @override
  String get pathNotStarted => 'Up next';

  @override
  String lessonLanguage(String locale) =>
      locale.startsWith('en') ? 'Lesson in English' : 'Lesson in French';

  @override
  String progressLevel(int level) => 'Lvl $level';

  @override
  String headerLevelTooltip(int completed, int total, int grade) =>
      '$completed of $total skills done in ${gradeLabel(grade)}';

  @override
  String headerXp(int xp) => '$xp XP';

  @override
  String progressBySkill(String subject) => '$subject — by skill';

  @override
  String get progressStatusMastered => 'Mastered';

  @override
  String get progressStatusLearning => 'In progress';

  @override
  String get progressStatusNew => 'Not started';

  @override
  String get progressOtherSkills => 'Other skills';

  @override
  String get progressNothingYet => 'Nothing to show for this subject yet.';

  @override
  String progressPercent(int pct) => '$pct%';

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
  String get profileTotalXp => 'XP';

  @override
  String get pinGateCreateTitle => 'Create a parent PIN';

  @override
  String get pinGateCreateSubtitle =>
      'Set a 6-digit PIN so only a grown-up can sign out this device.';

  @override
  String get pinGateEnterTitle => 'Parent PIN';

  @override
  String get pinGateEnterSubtitle =>
      'Ask a grown-up to enter the PIN to sign out this device.';

  @override
  String pinGatePinLabel(int digits) => 'PIN ($digits digits)';

  @override
  String get pinGateConfirmPinLabel => 'Confirm PIN';

  @override
  String get pinGateMismatch => "PINs don't match.";

  @override
  String pinGateTooShort(int digits) => 'PIN must be $digits digits.';

  @override
  String get pinGateUpgradeTitle => 'Choose a new PIN';

  @override
  String get pinGateUpgradeSubtitle =>
      'The parent PIN now has 6 digits. Choose a new one to continue.';

  @override
  String get pinGateWrong => 'Incorrect PIN.';

  @override
  String get pinGateCreate => 'Create';

  @override
  String get pinGateConfirmSignOut => 'Sign out';

  @override
  String removeKidTitle(String name) =>
      name.isEmpty ? 'Remove this profile from the device?' : 'Remove $name from this device?';

  @override
  String get removeKidIntro =>
      'Everything kept on this device for this profile will be erased:';

  @override
  String removeKidUnsent(int count) => switch (count) {
    0 => 'all their play results have already been sent;',
    1 => '1 play result not sent yet;',
    _ => '$count play results not sent yet;',
  };

  @override
  String removeKidCreations(int count) => switch (count) {
    0 => 'no creations in “My creations”.',
    1 => '1 creation in “My creations”.',
    _ => '$count creations in “My creations”.',
  };

  @override
  String get removeKidSendThenErase => 'Send, then erase';

  @override
  String get removeKidEraseNow => 'Erase now';

  @override
  String get removeKidSending => 'Sending results…';

  @override
  String get removeKidSendFailed =>
      "Sending didn't work. If you erase anyway, the results not sent yet "
      'will be lost.';

  @override
  String get removeKidEraseAnyway => 'Erase anyway';

  @override
  String get navHome => 'Home';

  @override
  String get navPath => 'Path';

  @override
  String get navProfile => 'Profile';

  @override
  String get playBack => 'Back';


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
  String get settingsFlameReminders => 'My flame';

  @override
  String get settingsFlameRemindersSub =>
      'A little note in the evening if your flame hasn\'t glowed yet today';

  @override
  String get settingsParentZone => 'Parent zone';

  @override
  String get settingsParentZoneBody => 'Some settings (account, subscription, privacy) are handled on the website, with a parent.';

  @override
  String get settingsParentZoneCta => 'Open the website';

  @override
  String get settingsParentZoneSoon => 'The parents’ website is coming soon!';

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
  String get villageSignTitle => 'Lys Village';

  @override
  String get villageRecommendedLabel => 'RECOMMENDED ACTIVITY';

  @override
  String get villageContinuePath => 'Keep going on your path';

  @override
  String get villageContinueCta => 'Continue →';

  @override
  String get villageQuestsTitle => 'Today\'s quests';

  @override
  String get villageQuestsSeeAll => 'See all';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty => 'Nothing new for now.';

  @override
  String get notificationsEmptyHint =>
      'Finish today’s challenge to get one!';

  @override
  String get notificationDailyQuest => 'Daily challenge done! Well done!';

  @override
  String get notificationStreakFreeze => 'Your shield saved your streak.';

  @override
  String get notificationStreakFreezeRefunded =>
      'You played that day after all, so your shield is back.';

  @override
  String notificationTutoringSession(String serverMessage) =>
      'Your tutoring session is coming up soon.';

  @override
  String get homeworkTag => 'Homework';

  @override
  String get homeworkTitle => 'From your teacher';

  @override
  String homeworkFrom(String organization) => 'From $organization';

  @override
  String homeworkDue(DateTime day) => 'Due ${day.month}/${day.day}';

  @override
  String get homeworkDone => 'Done!';

  @override
  String notificationsBellLabel(int unread) => switch (unread) {
        0 => 'Notifications',
        1 => 'Notifications, 1 unread',
        _ => 'Notifications, $unread unread',
      };

  @override
  String notificationsAgo(Duration elapsed) {
    if (elapsed.inMinutes < 1) return 'just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} min ago';
    if (elapsed.inDays < 1) return '${elapsed.inHours} h ago';
    if (elapsed.inDays == 1) return 'yesterday';
    return '${elapsed.inDays} days ago';
  }

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
  String villageSubjectSoon(String subject) => '$subject is coming soon!';
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
  String get profileTabSubjects => 'By subject';

  @override
  String get profileBadges => 'Badges';


  @override
  String get profileTabRecent => 'Recent';

  @override
  String get profileRecentEmpty => 'Finish a quest to earn your first badge.';

  @override
  String profileRecentDay(int daysAgo) => switch (daysAgo) {
        <= 0 => 'Today',
        1 => 'Yesterday',
        _ => '$daysAgo days ago',
      };

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
  String get aboutMadeIn => 'Made in Québec';
  @override
  List<HelpEntry> get helpEntries => const [
        HelpEntry(question: 'How do I earn XP?', answer: 'Every right answer gives you 1 XP. When you finish an activity you get a bonus, and a little more if everything was right the first time! The daily challenge is worth 10 XP. Replaying an activity you already finished earns a little bit.'),
        HelpEntry(question: 'What is my level for?', answer: 'Your level goes up as you master new skills from your school year. It goes all the way to 99!'),
        HelpEntry(question: 'What is my streak?', answer: 'It\'s the number of days in a row you\'ve played. Finish at least one exercise each day to keep it.'),
        HelpEntry(question: 'How do I unlock a new building?', answer: 'Each building in the Village is a subject. The further you get along its path (the Map tab), the more its progress bar fills up.'),
        HelpEntry(question: 'I lost my streak, what now?', answer: 'Don\'t worry! Start again today — a new streak begins right away.'),
        HelpEntry(question: 'I found a mistake or a problem', answer: 'Tell a parent or your teacher — they can contact us for you.'),
      ];

  @override
  String get villageYourSubjects => 'Your subjects';

  @override
  String get questsEyebrow => 'Today and this week';

  @override
  String get questsTitle => 'Your quests';

  @override
  String questsStreakDays(int days) =>
      days == 1 ? '1 day in a row' : '$days days in a row';

  @override
  String questsStreakNextTomorrow(int goal) =>
      'Come back tomorrow to reach $goal!';

  @override
  String questsStreakNextToday(int goal) => 'Play today to reach $goal!';

  @override
  String get questsStreakStart => 'Finish a lesson to start your streak!';

  @override
  String get questsStreakUnknown => 'We can\'t read your streak right now.';

  @override
  String get questsStreakOpenHint => 'See your streak details';

  @override
  List<String> get weekdayInitials => const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];

  @override
  String monthYear(int year, int month) => '${_months[month - 1]} $year';

  @override
  String get streakDetailTitle => 'Streak';

  @override
  String get streakDetailEyebrow => 'Your streak flame';

  @override
  String streakDetailHeadline(int days) =>
      days == 1 ? '1-day streak' : '$days-day streak';

  @override
  String get streakDetailNudge =>
      'Finish a lesson today to keep your streak going!';

  @override
  String get streakDetailNudgeCta => 'Keep my streak →';

  @override
  String get streakDetailCalendar => 'Calendar';

  @override
  String get streakDetailPrevMonth => 'Previous month';

  @override
  String get streakDetailNextMonth => 'Next month';

  @override
  String get streakDetailGoal => 'Streak goal';

  @override
  String get streakDetailRewards => 'Streak rewards';

  @override
  String get streakShieldTitle => 'Streak shield';

  @override
  String get streakShieldBody =>
      'Protects your streak if you miss a day of practice.';

  @override
  String streakShieldBalance(int count) =>
      count == 1 ? '1 shield ready' : '$count shields ready';

  @override
  String get streakShieldNone => 'You earn one every week.';

  @override
  String tabPosition(int index, int count) => 'tab $index of $count';

  @override
  String get reminderTitle => 'TutoLys';

  @override
  String get reminderLearnBody =>
      'Your fox has a new lesson ready. Want to play?';

  @override
  String get reminderFlameBody =>
      'Your flame is still glowing today. One short lesson keeps it lit!';

  @override
  String get reminderSeveralBody => 'Who wants to play in the village today?';

  @override
  String get settingsReminderTime => 'Reminder time';

  @override
  String reminderTimeLabel(int minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).toString().padLeft(2, '0');
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m ${h < 12 ? 'AM' : 'PM'}';
  }

  @override
  String get settingsRemindersWhileRunning =>
      'On this computer, only while TutoLys is open.';

  @override
  String get settingsRemindersWebNote =>
      'Reminders come from the installed app, not the browser.';

  @override
  String get settingsRemindersClassNote => 'No reminders on a class tablet.';

  @override
  String get settingsRemindersBlocked =>
      'Notifications are turned off for TutoLys in the device settings.';

  @override
  String get remindersPinCreate =>
      'First create a 6-digit parent PIN: only a grown-up can turn reminders '
      'on or choose their time.';

  @override
  String get remindersPinEnter =>
      'Ask a grown-up to enter the PIN to manage reminders.';

  @override
  String streakShieldRechargeIn(int days) =>
      days == 1 ? 'Recharges in 1 day' : 'Recharges in $days days';

  @override
  String get streakShieldPlayToRecharge => 'Play a lesson to recharge';

  @override
  String get streakShieldDueSoon => 'Recharging soon';


  @override
  String get streakTabPersonal => 'Personal';

  @override
  String get backToQuests => 'Back to quests';

  @override
  String get questsViewQuests => 'My quests';

  @override
  String get questsViewSerie => 'My streak';

  @override
  String get questsSeeStreak => 'See my streak';

  @override
  String get streakTabFriends => 'With friends';

  @override
  String questExercisesTitle(int target) => 'Solve $target exercises';

  @override
  String questMinutesTitle(int target) => 'Play for $target minutes';

  @override
  String questRewardXp(int xp) => '+$xp XP';

  @override
  String villageGreetingQuests(int open) => open == 1
      ? '1 quest is waiting for you today 🎯'
      : '$open quests are waiting for you today 🎯';

  @override
  String get headerQuestsLabel => 'quests';

  @override
  String get weeklyBadgeTitle => 'Badge of the week';

  @override
  String weeklyBadgeBody(int target) => 'Finish $target quests by Sunday';

  @override
  String weeklyBadgeProgress(int done, int target) => '$done / $target quests';

  @override
  String get weeklyBadgeEarned => 'Badge earned!';

  @override
  String get recentTitle => 'Recent achievements';

  @override
  String get lockedLabel => 'Locked';

  @override
  String get achStreak3 => '3-day streak';

  @override
  String get achQuestMaster => 'Quest master';

  @override
  String get achLevel10 => 'Level 10';

  @override
  String get achStreak7 => '7-day streak';

  @override
  String get achAllSubjects50 => 'All subjects 50%';

  @override
  String get achLevel20 => 'Level 20';

  @override
  String get achQuests50 => '50 quests';

  @override
  String get achExplorer => 'Explorer';

  @override
  String get chestTitle => 'Streak chest · 3 days';

  @override
  String get chestBody => 'Well done, you reached a 3-day streak!';

  @override
  String get chestBodyLocked => 'Reach a 3-day streak to open it.';

  @override
  String get flameKeeperTitle => 'Keeper of the flame';

  @override
  String get flameKeeperTitlePrefix => 'Title: ';

  @override
  String get flameKeeperBody =>
      'Show this title on your profile to show how steady you are.';

  @override
  String get rewardObtained => 'Reward earned';

  @override
  String get rewardActive => 'Active';

  @override
  String rewardDaysLeft(int days) =>
      days == 1 ? '1 more day' : '$days more days';

  @override
  String get avatarEdit => 'Change avatar';

  @override
  String get avatarPickerTitle => 'Choose your avatar';

  @override
  String get avatarStarters => 'To start';

  @override
  String get avatarUnlockables => 'Unlock by playing';

  @override
  String get avatarSubjects => 'By subject';

  @override
  String get avatarRares => 'Rare finds';

  @override
  String avatarAtLevel(int level) => 'Level $level';

  @override
  String avatarForSubject(String subject, int skills) {
    final short = switch (subject) {
      'MATH' => 'Math',
      'FR' => 'French',
      'EN' => 'English',
      'SCI' => 'Science',
      'SOC' => 'Social studies',
      'CCQ' => 'Québec culture',
      _ => subject,
    };
    return '$skills skills · $short';
  }

  @override
  String get avatarRareHint => 'Hidden · perfect lesson';

  @override
  String get avatarRareFound => 'Rare avatar found!';

  @override
  String get avatarHistorical => 'Historical figures';

  @override
  String get avatarHistoricalHint => 'Hidden · perfect CCQ lesson';

  @override
  String? avatarCaption(String key) => switch (key) {
        'hist_therese_casgrain' =>
          'Fought for women\'s right to vote in Québec',
        'hist_rene_levesque' => 'Premier of Québec from 1976 to 1985',
        _ => null,
      };

  @override
  String avatarLocked(String condition) => 'Locked: $condition';

  @override
  String avatarName(String key) =>
      switch (key.replaceFirst(RegExp(r'_(girl|boy)$'), '')) {
        'camper' => 'Camper',
        'explorer' => 'Explorer',
        'scientist' => 'Scientist',
        'chemist' => 'Chemist',
        'knight' => 'Knight',
        'fleur_knight' => 'Fleur-de-lis knight',
        'mathematician' => 'Mathematician',
        'french_teacher' => 'French teacher',
        'english' => 'English teacher',
        'historian' => 'Historian',
        'tuque' => 'Winter tuque',
        'hero' => 'Superhero',
        'captain' => 'Captain',
        'artist' => 'Artist',
        'fox_hood' => 'Fox hood',
        'wizard' => 'Wizard',
        'astronaut' => 'Astronaut',
        'coder' => 'Coder',
        'mermaid' => 'Mermaid',
        'hist_therese_casgrain' => 'Thérèse Casgrain',
        'hist_rene_levesque' => 'René Lévesque',
        'pirate' => 'Pirate',
        _ => 'Avatar',
      };

  @override
  String get profileBadgesEarned => 'Badges earned';

  @override
  String get switchProfile => 'Switch profile';

  @override
  String get whoIsPlaying => 'Who\'s playing?';

  @override
  String get notMe => 'That\'s not me';

  @override
  String get pictureFlame => 'the flame';

  @override
  String get pictureChest => 'the chest';

  @override
  String get pictureCoin => 'the coin';

  @override
  String get pictureBell => 'the bell';

  @override
  String get pictureTarget => 'the target';

  @override
  String get pictureStar => 'the star';

  @override
  String get pictureFox => 'the fox';

  @override
  String get pictureMathHouse => 'the math house';

  @override
  String get pictureScienceHouse => 'the science house';

  @override
  String passcodeIsItYou(String name) => 'Is that you, $name?';

  @override
  String get passcodePrompt => 'Tap your 3 pictures, in order.';

  @override
  String get passcodeWrong => 'Oops! Those aren\'t your pictures. Try again.';

  @override
  String get passcodeTooMany => 'Take a little break, then try again.';

  @override
  String get passcodeUndo => 'Undo';

  @override
  String passcodeSlot(int position) => 'Picture $position';

  @override
  String get passcodesTitle => 'Picture codes';

  @override
  String get passcodesBody =>
      'Each child taps their 3 pictures to say "that\'s me". It isn\'t a '
      'password: it keeps everyone\'s progress in the right place.';

  @override
  String get passcodeIsSet => 'Code set';

  @override
  String get passcodeNotSet => 'No code';

  @override
  String get passcodeChoose => 'Choose';

  @override
  String get passcodeChange => 'Change';

  @override
  String get passcodeRemove => 'Remove';

  @override
  String passcodeSetupTitle(String name) => '$name\'s picture code';

  @override
  String get passcodeSetupPick => 'Choose 3 different pictures, in order.';

  @override
  String get passcodeSetupConfirm => 'Once more, to confirm.';

  @override
  String get passcodeSetupMismatch =>
      'That wasn\'t the same order. Let\'s start again.';

  @override
  String get passcodeSaved => 'Code saved.';

  @override
  String get passcodeRemoved => 'Code removed.';

  @override
  String get passcodeNeedsInternet =>
      'Not right now: check the internet connection.';

  @override
  String get pinGateContinue => 'Continue';

  @override
  String get passcodesPinCreate =>
      'First set a 6-digit parent PIN, so only a grown-up can change '
      'picture codes.';

  @override
  String get passcodesPinEnter =>
      'Ask a grown-up to enter the PIN to manage picture codes.';

  @override
  String get pairingClassLink =>
      'Add a class';

  @override
  String get pairingKidLink =>
      'Add a child';

  @override
  String get pairingClassTitle =>
      'Class code';

  @override
  String get pairingClassSubtitle =>
      'Enter the code your teacher is showing the class.';

  @override
  String get pairingClassInvalid =>
      'That code doesn\'t work. Ask your teacher for a new one.';

  @override
  String get pairingClassEmpty =>
      'This class has no learners yet.';

  @override
  String get pairingClassNotEntitled =>
      'Ask your teacher: the school has to turn TutoLys on first.';

  @override
  String get pairingNoSeat =>
      'This profile doesn\'t have a place yet. Ask a grown-up to add you.';

  @override
  String get noSeatTitle => 'Ask a grown-up to add you.';

  @override
  String get noSeatBody =>
      'Your profile can\'t play just now. Once a grown-up has added you, '
      'tap “Try again”.';

  @override
  String whoIsPlayingClass(String className) =>
      'Class: $className';

  @override
  String passcodeWaitTitle(String name) =>
      'Your picture code isn\'t ready yet, $name.';

  @override
  String get passcodeWaitBody =>
      'Ask a grown-up to choose it with you.';

  @override
  String get passcodeWaitAdult =>
      'I\'m the grown-up';

  @override
  String get passcodePromptTitle =>
      'Several children on this device';

  @override
  String get passcodePromptBody =>
      'Choose a picture code for each of them, so everyone keeps their own progress.';

  @override
  String get passcodePromptLater =>
      'Later';

  @override
  String get passcodePromptChoose =>
      'Choose codes';

  @override
  String get addProfile => 'Add a profile';

  @override
  String get addProfileHint =>
      'Ask a parent for a pairing code to add a child.';

  @override
  String get addProfileCancel => 'Back';

}

/// Lookup from the widget tree.
extension StringsContext on BuildContext {
  Strings get s => Strings.of(Localizations.localeOf(this));
}
