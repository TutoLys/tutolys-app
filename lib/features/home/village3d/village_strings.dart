import '../../../core/i18n/strings.dart';

/// Every word the 3D scene shows besides the building labels, in the app's
/// language. The scene hard-codes none of them (BRIDGE.md lists the keys).
Map<String, String> village3dStrings(Strings t) => {
  'notStarted': t.pathNotStarted,
  'soon': t.pathSoon,
  'stageLabel': t.village3dStageLabel,
};
