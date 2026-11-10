import '../../../core/i18n/strings.dart';

/// Every word the 3D scene shows besides the building labels and the fox's
/// line, in the app's language, keyed as BRIDGE.md lists them. A key left
/// out would fall back to the scene's French, so all 16 are sent.
/// `{label}` and `{pct}` are filled in by the scene.
Map<String, String> village3dStrings(Strings t) => {
  'stage.aria': t.village3dStageLabel,
  'labels.aria': t.village3dLabelsAria,
  'loading': t.village3dLoading,
  'pill.new': t.pathNotStarted,
  'pill.progress': t.village3dPillProgress,
  'pill.locked': t.pathSoon,
  'pill.aria.new': t.village3dPillAriaNew,
  'pill.aria.progress': t.village3dPillAriaProgress,
  'pill.aria.locked': t.village3dPillAriaLocked,
  'pill.aria.place': '{label}',
  'cam.aria': t.village3dCamAria,
  'cam.in': t.village3dCamIn,
  'cam.out': t.village3dCamOut,
  'cam.left': t.village3dCamLeft,
  'cam.right': t.village3dCamRight,
  'cam.home': t.village3dCamHome,
};

/// The keys BRIDGE.md lists: a test holds the map to exactly these.
const village3dStringKeys = {
  'stage.aria', 'labels.aria', 'loading', 'pill.new', 'pill.progress',
  'pill.locked', 'pill.aria.new', 'pill.aria.progress', 'pill.aria.locked',
  'pill.aria.place', 'cam.aria', 'cam.in', 'cam.out', 'cam.left',
  'cam.right', 'cam.home',
};
