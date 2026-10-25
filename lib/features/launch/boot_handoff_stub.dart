import 'boot_handoff_types.dart';

/// Desktop and tests: there is no HTML stage before Flutter, so the loader
/// starts from the beginning.
BootHandoff? readBootHandoff() => null;

/// Desktop and tests: there is no HTML stage to tell.
void rememberBootLocale(String languageCode) {}
