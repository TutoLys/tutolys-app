import 'package:flutter/widgets.dart';

/// The shell's copy, French first. Lives in the package (engines can't
/// reach the app's `Strings`), following the engines' own `t(fr:, en:)`
/// convention. Wording is the design's (`03-exercise-engines.html`).
class ShellStrings {
  const ShellStrings._(this._fr);

  factory ShellStrings.of(Locale locale) => locale.languageCode == 'fr'
      ? const ShellStrings._(true)
      : const ShellStrings._(false);

  final bool _fr;
  String _t(String fr, String en) => _fr ? fr : en;

  String get close => _t("Quitter l'exercice", 'Leave the exercise');
  String get stopTitle => _t('Tu veux arrêter ?', 'Do you want to stop?');
  String get stopMessage =>
      _t('Ta série n’est pas finie.', "Your set isn't finished.");
  String get stopLabel => _t('Arrêter', 'Stop');
  String get validate => _t('Valider', 'Check');
  String get hint => _t('Indice', 'Hint');

  /// How to play, for the boards a child can't guess (UX review G3).
  String? howTo(String engineKey) => switch (engineKey) {
    'pair_match' => _t(
      'Touche une carte, puis sa paire.',
      'Tap a card, then its match.',
    ),
    'compose_build' => _t(
      'Touche les tuiles pour remplir les cases.',
      'Tap the tiles to fill the boxes.',
    ),
    _ => null,
  };
  String get answerFirst =>
      _t('Choisis d’abord ta réponse !', 'Pick your answer first!');
  String get listen => _t('Écouter la question', 'Listen to the question');
  String get audioUnavailable => _t('Audio indisponible', 'Audio unavailable');
  // Not « en série »: that's the streak's name (UX review G13).
  String inARow(int n) => _t('$n de suite !', '$n in a row!');
  String xp(int n) => '+$n';
  String questionOf(int i, int n) =>
      _t('Question $i sur $n', 'Question $i of $n');

  String get correctTitle => _t('Bravo !', 'Well done!');
  String get correctMessage => _t('Bonne réponse', 'Right answer');
  String get continueLabel => _t('Continuer', 'Continue');
  String get retryTitle => _t('Presque !', 'Almost!');
  // Short, concrete and positive for a grade-1 reader (UX review G13).
  String get retryMessage => _t('Essaie encore.', 'Try again.');
  String get retryLabel => _t('Réessayer', 'Try again');
  String get partialMessage =>
      _t('Bien ! Change les autres.', 'Good! Change the others.');
  String get timeUpTitle => _t('Temps écoulé !', "Time's up!");
  String get timeUpMessage =>
      _t('Le temps est fini. On recommence !', "Time's up. Let's go again!");
  String get movingOnTitle => _t('On continue', "Let's keep going");
  String get movingOnMessage => _t(
    'On regardera celle-ci une autre fois.',
    "We'll come back to this one another time.",
  );
  String get ungradedMessage =>
      _t('On passe à la suite !', "On to the next one!");

  String get needsUpdate => _t(
    "Cette activité a besoin d'une mise à jour de l'application.",
    'This activity needs an app update.',
  );
  String get invalidContent =>
      _t('Cet exercice est incomplet.', 'This exercise is incomplete.');
  String get storageError => _t(
    "Impossible d'enregistrer ta réponse. Réessaie.",
    "Your answer couldn't be saved. Try again.",
  );

  String get doneTitle => _t('Exercice terminé !', 'Exercise complete!');
  String get perfectTitle => _t('Parfait !', 'Perfect!');
  String get xpEarnedLabel => _t('XP gagnés', 'XP earned');
  String get rightAnswersLabel => _t('bonnes réponses', 'right answers');
  String get firstTryLabel => _t('du premier coup', 'first try');
  String wellDone(String name) => _t('Bravo, $name !', 'Well done, $name!');
}
