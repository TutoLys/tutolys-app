import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';

/// The village folk the creative engines use as partners and audience
/// (the Questions Maker's rule: characters only, never other children).
///
/// Each has a name in both languages and a colour, and is drawn in code as
/// a disc with an initial until portraits exist; a lesson may give an
/// `image_ref` portrait instead.
class VillageCharacter {
  const VillageCharacter(this.key, this.fr, this.en, this.color);
  final String key;
  final String fr;
  final String en;
  final Color color;

  String name(Locale locale) => locale.languageCode == 'fr' ? fr : en;

  static const all = [
    VillageCharacter('foxy', 'Foxy', 'Foxy', Color(0xFF2F6FDE)),
    VillageCharacter('lea', 'Léa', 'Léa', Color(0xFFE66BA8)),
    VillageCharacter('omar', 'Omar', 'Omar', Color(0xFF2FA35A)),
    VillageCharacter(
      'grand_maman',
      'Grand-maman',
      'Grandma',
      Color(0xFF8E4EC6),
    ),
    VillageCharacter(
      'enseignante',
      'l’enseignante',
      'the teacher',
      Color(0xFFF08A24),
    ),
    VillageCharacter(
      'boulanger',
      'le boulanger',
      'the baker',
      Color(0xFFB0793B),
    ),
    VillageCharacter(
      'facteur',
      'le facteur',
      'the mail carrier',
      Color(0xFF1F3C88),
    ),
    VillageCharacter(
      'journal',
      'le journal du village',
      'the village paper',
      Color(0xFF555B6E),
    ),
    VillageCharacter(
      'petits',
      'les petits',
      'the little ones',
      Color(0xFFF5C02B),
    ),
  ];

  static VillageCharacter? byKey(Object? key) {
    for (final c in all) {
      if (c.key == key) return c;
    }
    return null;
  }

  static Iterable<String> get keys => all.map((c) => c.key);
}

/// How a character feels about what the child did. Drawn as a face on the
/// portrait, and always said in words too (never the face alone).
enum CharacterMood { neutral, delighted, confused, putOff }

/// A character's portrait: their picture when the lesson gives one, else
/// a coloured disc with their initial and a mood mouth.
class CharacterPortrait extends StatelessWidget {
  const CharacterPortrait({
    required this.character,
    this.size = 56,
    this.mood = CharacterMood.neutral,
    this.imageRef,
    super.key,
  });

  final VillageCharacter character;
  final double size;
  final CharacterMood mood;
  final String? imageRef;

  @override
  Widget build(BuildContext context) {
    final disc = CustomPaint(
      size: Size.square(size),
      painter: _PortraitPainter(character, mood),
    );
    final ref = imageRef;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ref == null
            ? disc
            : ClipOval(
                child: ContentImage(ref: ref, fallback: disc),
              ),
      ),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.c, this.mood);
  final VillageCharacter c;
  final CharacterMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final centre = Offset(r, r);
    canvas.drawCircle(centre, r, Paint()..color = c.color);
    final tp = TextPainter(
      text: TextSpan(
        text: c.fr
            .replaceAll(RegExp(r'^(le |la |les |l’)'), '')
            .substring(0, 1)
            .toUpperCase(),
        style: TextStyle(
          fontFamily: VillageType.display,
          fontWeight: FontWeight.w800,
          fontSize: r * 0.8,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(r - tp.width / 2, r * 0.25));
    final mouth = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.1
      ..strokeCap = StrokeCap.round;
    final m = Rect.fromCenter(
      center: Offset(r, r * 1.45),
      width: r * 0.7,
      height: r * 0.35,
    );
    switch (mood) {
      case CharacterMood.delighted:
        canvas.drawArc(m, 0.2, 2.7, false, mouth);
      case CharacterMood.putOff:
        canvas.drawArc(m.shift(Offset(0, r * 0.15)), 3.4, 2.6, false, mouth);
      case CharacterMood.confused:
        final path = Path()..moveTo(m.left, m.center.dy);
        path.quadraticBezierTo(
          m.left + m.width * 0.25,
          m.top,
          m.center.dx,
          m.center.dy,
        );
        path.quadraticBezierTo(
          m.right - m.width * 0.25,
          m.bottom,
          m.right,
          m.center.dy,
        );
        canvas.drawPath(path, mouth);
      case CharacterMood.neutral:
        canvas.drawLine(m.centerLeft, m.centerRight, mouth);
    }
  }

  @override
  bool shouldRepaint(_PortraitPainter old) => old.c != c || old.mood != mood;
}

/// A character saying something: portrait, name, and a speech bubble.
class CharacterSays extends StatelessWidget {
  const CharacterSays({
    required this.character,
    required this.text,
    required this.locale,
    this.mood = CharacterMood.neutral,
    this.imageRef,
    this.trailing,
    super.key,
  });

  final VillageCharacter character;
  final String text;
  final Locale locale;
  final CharacterMood mood;
  final String? imageRef;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final bubble = Semantics(
      label: '${character.name(locale)} : $text',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: Radii.cardMd,
          border: Border.all(color: character.color, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              character.name(locale),
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: character.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              text,
              style: TextStyle(
                fontFamily: VillageType.display,
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: p.ink,
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CharacterPortrait(character: character, mood: mood, imageRef: imageRef),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bubble,
              // Outside the bubble's semantics: it's interactive.
              if (trailing != null) ...[const SizedBox(height: 8), trailing!],
            ],
          ),
        ),
      ],
    );
  }
}
