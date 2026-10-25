/// The PFEQ's own grouping of strands into learning areas, which is what the
/// Carte titles each stretch of path with ("Arithmétique", "Géométrie"…).
///
/// Curriculum data, not UI copy: copied from
/// `tutolys-backend/reference/pfeq/learning_area_maps/*.json`, which carry
/// both languages. The local leaf cache has no strand or label column, but
/// every leaf's `stable_key` names its strand (TAXONOMY.md §4), so the join
/// happens here rather than needing a new field from the backend.
///
/// Français is incomplete on purpose. Its map predates the round-2 rebuild
/// (backend ADR 0006), which recovered three whole competencies and re-keyed
/// all 24 strands, so most français leaves match nothing here and fall into
/// one untitled stretch. Real strand labels belong on the curriculum
/// endpoint; guessing them from slugs would put unaccented French in front of
/// a child.
class LearningArea {
  const LearningArea({
    required this.labelFr,
    required this.labelEn,
    required this.strands,
  });

  final String labelFr;
  final String labelEn;

  /// Strand slugs, as they appear in a leaf's `stable_key`.
  final List<String> strands;
}

/// By backend subject code, in the ministry's own order.
const learningAreas = <String, List<LearningArea>>{
  'MATH': [
    LearningArea(
      labelFr: 'Arithmétique',
      labelEn: 'Arithmetic',
      strands: [
        'sens-et-ecriture-des-nombres',
        'sens-des-operations-sur-des-nombres',
        'operations-sur-des-nombres',
      ],
    ),
    LearningArea(
      labelFr: 'Géométrie',
      labelEn: 'Geometry',
      strands: ['geometrie'],
    ),
    LearningArea(
      labelFr: 'Mesure',
      labelEn: 'Measurement',
      strands: ['mesure'],
    ),
    LearningArea(
      labelFr: 'Statistique',
      labelEn: 'Statistics',
      strands: ['statistique'],
    ),
    LearningArea(
      labelFr: 'Probabilité',
      labelEn: 'Probability',
      strands: ['probabilite'],
    ),
  ],
  'FR': [
    LearningArea(
      labelFr: 'Écrire des textes variés',
      labelEn: 'Write a variety of texts',
      strands: [
        'competence-ecrire-des-textes-varies-section-lexique-connaissances',
        'competence-ecrire-des-textes-varies-section-lexique-pistes-pour-l-appropriation-des-connaissances',
        'competence-ecrire-des-textes-varies-section-lexique-utilisation-des-connaissances-en-ecriture',
        'competence-ecrire-des-textes-varies-section-orthographe-d-usage-connaissances',
        'competence-ecrire-des-textes-varies-section-orthographe-d-usage-pistes-pour-l-appropriation-des-connaissances',
        'competence-ecrire-des-textes-varies-section-orthographe-d-usage-utilisation-des-connaissances-en-ecriture',
        'competence-ecrire-des-textes-varies-section-conjugaison-connaissances',
        'competence-ecrire-des-textes-varies-section-conjugaison-pistes-pour-l-appropriation-des-connaissances',
        'competence-ecrire-des-textes-varies-section-conjugaison-utilisation-des-connaissances-en-ecriture',
        'competence-ecrire-des-textes-varies-section-accords-connaissances',
        'competence-ecrire-des-textes-varies-section-accords-pistes-pour-l-appropriation-des-connaissances',
        'competence-ecrire-des-textes-varies-section-accords-utilisation-des-connaissances-en-ecriture',
        'competence-ecrire-des-textes-varies-section-syntaxe-et-ponctuation-connaissances',
        'competence-ecrire-des-textes-varies-section-syntaxe-et-ponctuation-pistes-pour-l-appropriation-des-connaissances',
        'competence-ecrire-des-textes-varies-section-syntaxe-et-ponctuation-utilisation-des-connaissances-en-ecriture',
        'competence-ecrire-des-textes-varies-section-organisation-et-coherence-du-texte-connaissances',
        'competence-ecrire-des-textes-varies-section-organisation-et-coherence-du-texte-pistes-pour-l-appropriation-des-connaissances',
        'competence-ecrire-des-textes-varies-section-organisation-et-coherence-du-texte-utilisation-des-connaissances-en-ecriture',
      ],
    ),
  ],
  'EN': [
    LearningArea(
      labelFr: 'Conventions of Written and Media Language',
      labelEn: 'Conventions of Written and Media Language',
      strands: ['conventions-of-written-and-media-language'],
    ),
    LearningArea(
      labelFr: 'Language-Learning Processes',
      labelEn: 'Language-Learning Processes',
      strands: ['language-learning-processes'],
    ),
    LearningArea(
      labelFr: 'Text types, structures and features',
      labelEn: 'Text types, structures and features',
      strands: [
        'self-expressive-text-types',
        'narrative-and-literary-text-types',
        'information-based-text-types',
      ],
    ),
  ],
  'SCI': [
    LearningArea(
      labelFr: 'L’univers matériel',
      labelEn: 'The material universe',
      strands: ['l-univers-materiel'],
    ),
    LearningArea(
      labelFr: 'La Terre et l’espace',
      labelEn: 'Earth and space',
      strands: ['la-terre-et-l-espace'],
    ),
    LearningArea(
      labelFr: 'L’univers vivant',
      labelEn: 'The living universe',
      strands: ['l-univers-vivant'],
    ),
  ],
  'SOC': [
    LearningArea(
      labelFr: 'Connaissances liées à l’organisation d’une société sur son territoire',
      labelEn: 'Knowledge related to how a society is organized on its territory',
      strands: [
        'connaissances-liees-a-l-organisation-d-une-societe-sur-son-territoire',
      ],
    ),
    LearningArea(
      labelFr: 'Connaissances liées au changement dans une société sur son territoire',
      labelEn: 'Knowledge related to change in a society on its territory',
      strands: [
        'connaissances-liees-au-changement-dans-une-societe-sur-son-territoire',
      ],
    ),
    LearningArea(
      labelFr: 'Connaissances liées à la diversité des sociétés et de leur territoire',
      labelEn: 'Knowledge related to diversity of societies and their territories',
      strands: [
        'connaissances-liees-a-la-diversite-des-societes-et-de-leur-territoire',
      ],
    ),
    // Added by the round-4 rebuild (backend ADR 0025), which has no
    // learning-area map file; titled from the tree's own strand names.
    LearningArea(
      labelFr: 'Démarche de recherche et de traitement de l’information',
      labelEn: 'Researching and processing information',
      strands: [
        'demarche-de-recherche-et-de-traitement-de-l-information-en-geographie-et-en-histoire',
      ],
    ),
    LearningArea(
      labelFr: 'Techniques propres à la géographie et à l’histoire',
      labelEn: 'Geography and history techniques',
      strands: ['techniques-particulieres-a-la-geographie-et-a-l-histoire'],
    ),
  ],
  // Culture et citoyenneté québécoise (backend ADR 0025). No learning-area
  // map exists for it; the French titles are the tree's own strand names,
  // the five themes then the two competency strands, and the English is
  // ours, not the ministry's.
  'CCQ': [
    LearningArea(
      labelFr: 'Conscience de soi et construction identitaire',
      labelEn: 'Self-awareness and identity',
      strands: ['conscience-de-soi-et-construction-identitaire'],
    ),
    LearningArea(
      labelFr: 'Relations entre humains',
      labelEn: 'Relationships between people',
      strands: ['relations-entre-humains'],
    ),
    LearningArea(
      labelFr: 'Quête de sens',
      labelEn: 'Search for meaning',
      strands: ['quete-de-sens'],
    ),
    LearningArea(
      labelFr: 'Relations entre les humains et l’environnement',
      labelEn: 'People and the environment',
      strands: ['relations-entre-les-humains-et-l-environnement'],
    ),
    LearningArea(
      labelFr: 'Médias et vie numérique',
      labelEn: 'Media and digital life',
      strands: ['medias-et-vie-numerique'],
    ),
    LearningArea(
      labelFr: 'Exercer la compétence',
      labelEn: 'Practising the competency',
      strands: [
        'indicateurs-de-progression-de-la-competence',
        'elements-de-contenu-lies-a-l-exercice-de-la-competence',
      ],
    ),
  ],
};

/// The strand slug inside a `stable_key`, or null when it has none.
///
/// Reads both grammars: TAXONOMY.md §4's `subject/strand/b:A/…` and the
/// legacy `subject/strand/<slug>/block/…` the salvaged trees still use.
String? strandOf(String stableKey) {
  final parts = stableKey.split('/');
  if (parts.length < 2) return null;
  if (parts[1] == 'strand') return parts.length > 2 ? parts[2] : null;
  return parts[1];
}
