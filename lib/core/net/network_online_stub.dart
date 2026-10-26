/// Calls [onOnline] when the network comes back. Native has no such event
/// here; the recovery scheduler's backoff covers it.
void listenForNetworkOnline(void Function() onOnline) {}
