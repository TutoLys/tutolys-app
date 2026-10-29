/// Off the web there is no browser store to reset, and no page to reload:
/// a failed open is retried by restarting the app.
bool get canRepairStorage => false;

Future<void> repairStorage(String name) async {}

void reloadApp() {}
