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
  String get validate => _t('Valider', 'Check');
  String get hint => _t('Indice', 'Hint');
  String get listen => _t('Écouter la question', 'Listen to the question');
  String get audioUnavailable => _t('Audio indisponible', 'Audio unavailable');
  String inARow(int n) => _t('$n en série', '$n in a row');
  String xp(int n) => '+$n';
  String questionOf(int i, int n) =>
      _t('Question $i sur $n', 'Question $i of $n');

  String get correctTitle => _t('Bravo !', 'Well done!');
  String get correctMessage => _t('Bonne réponse', 'Right answer');
  String get continueLabel => _t('Continuer', 'Continue');
  String get retryTitle => _t('Presque !', 'Almost!');
  String get retryMessage =>
      _t('Pas tout à fait — essaie encore.', 'Not quite — try again.');
  String get retryLabel => _t('Réessayer', 'Try again');
  String get movingOnTitle => _t('On continue', "Let's keep going");
  String get movingOnMessage => _t(
    'On regardera celle-ci une autre fois.',
    "We'll come back to this one another time.",
  );
  String get ungradedMessage => _t(
    'On passe à la suite — ce n\'est pas ta faute.',
    "Let's move on — that wasn't you.",
  );

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
}
