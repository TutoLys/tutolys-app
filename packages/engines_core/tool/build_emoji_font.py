"""Rebuild fonts/TutolysEmoji.ttf: Noto Color Emoji cut to the emoji the
lesson content uses (UX review AM2 / N17, app ADR 0105).

Flutter web picks a monochrome fallback font for many emoji, so 🐟 drew as a
grey outline. The app now ships its own colour subset. When content adds an
emoji, `test/emoji_font_test.dart` fails; re-run this:

    ../../../tutolys-backend/.venv/bin/python tool/build_emoji_font.py \
        /usr/share/fonts/truetype/noto/NotoColorEmoji.ttf \
        ../../../tutolys-backend/content

It writes the font and `fonts/TutolysEmoji.codepoints`, the list the test
reads. Noto Color Emoji is SIL OFL 1.1 (fonts/OFL.txt).
"""
import pathlib
import subprocess
import sys

from fontTools.ttLib import TTFont

src, content = sys.argv[1], pathlib.Path(sys.argv[2])
here = pathlib.Path(__file__).resolve().parent.parent / 'fonts'
cmap = TTFont(src).getBestCmap()

cps = set()
for f in content.rglob('*.json'):
    for ch in f.read_text(encoding='utf-8'):
        c = ord(ch)
        if c >= 0x2000 and c in cmap:
            cps.add(c)
# Joiners, variation selectors and keycap parts: the sequences
# the content writes need them even when they never stand alone.
cps |= {0x200D, 0xFE0F, 0x20E3}
# Always in, used or not: ⚜️ is TutoLys's Québec symbol (never the maple
# leaf), so lessons can reach for it before the first one does.
cps |= {0x269C} & set(cmap)
cps = sorted(c for c in cps if c in cmap or c in (0x200D, 0xFE0F, 0x20E3))

out = here / 'TutolysEmoji.ttf'
subprocess.run(
    [
        sys.executable, '-m', 'fontTools.subset', src,
        '--unicodes=' + ','.join(f'U+{c:04X}' for c in cps),
        '--layout-features=*',
        '--no-hinting',
        f'--output-file={out}',
    ],
    check=True,
)
(here / 'TutolysEmoji.codepoints').write_text(
    ''.join(f'{c:04X}\n' for c in cps), encoding='utf-8'
)
print(f'{len(cps)} code points, {out.stat().st_size // 1024} KB')
