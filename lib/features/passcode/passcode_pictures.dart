import '../../core/i18n/strings.dart';

/// One of the nine pictures a passcode is made of.
///
/// The backend only ever sees a picture's [index] (0–8), so which art an
/// index shows is the app's business. Changing a picture here changes every
/// passcode that uses its index, so **never reorder this list**; swap art in
/// place only, and only for something a child would still recognise as the
/// same thing.
class PasscodePicture {
  const PasscodePicture(this.index, this.asset, this.name);

  final int index;
  final String asset;

  /// Read by a screen reader. A child who can't read picks by the picture.
  final String Function(Strings) name;
}

/// Picked from the app's own art so that no two look alike at a glance: a
/// grade-1 child has to find "the flame" again tomorrow. No kid avatars,
/// which would read as other children on a screen about who you are.
final passcodePictures = <PasscodePicture>[
  PasscodePicture(0, 'assets/images/asset-flame.webp', (s) => s.pictureFlame),
  PasscodePicture(1, 'assets/images/asset-chest.webp', (s) => s.pictureChest),
  PasscodePicture(2, 'assets/images/asset-coin.webp', (s) => s.pictureCoin),
  PasscodePicture(3, 'assets/images/asset-bell.webp', (s) => s.pictureBell),
  PasscodePicture(4, 'assets/images/asset-target.webp', (s) => s.pictureTarget),
  PasscodePicture(5, 'assets/images/asset-xpstar.webp', (s) => s.pictureStar),
  PasscodePicture(
    6,
    'assets/images/asset-mascot-welcome.webp',
    (s) => s.pictureFox,
  ),
  PasscodePicture(
    7,
    'assets/images/asset-bldg-math.webp',
    (s) => s.pictureMathHouse,
  ),
  PasscodePicture(
    8,
    'assets/images/asset-bldg-science.webp',
    (s) => s.pictureScienceHouse,
  ),
];

/// How many pictures, in order, make a passcode.
const passcodeLength = 3;
