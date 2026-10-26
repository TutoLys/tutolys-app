import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../data/local_db/kid_local_data.dart';
import '../../data/sync/outbox_flusher_provider.dart';
import '../pairing/pairing_controller.dart';

/// Asks a guardian, already past the PIN, before the active kid is removed
/// from this device and everything of theirs here is erased (ADR 0037).
///
/// Says in plain words what's stored, then offers to send the unsent play
/// results first, to erase at once, or to cancel. Returns whether to go
/// ahead with the removal; the caller does it.
Future<bool> confirmRemoveKid(
  BuildContext context, {
  required String kidName,
}) async {
  final erase = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => RemoveKidDialog(kidName: kidName),
  );
  return erase ?? false;
}

enum _Phase { asking, sending, sendFailed }

class RemoveKidDialog extends ConsumerStatefulWidget {
  const RemoveKidDialog({required this.kidName, super.key});

  final String kidName;

  @override
  ConsumerState<RemoveKidDialog> createState() => _RemoveKidDialogState();
}

class _RemoveKidDialogState extends ConsumerState<RemoveKidDialog> {
  late final Future<({int unsentResults, int creations})> _summary;
  var _phase = _Phase.asking;

  @override
  void initState() {
    super.initState();
    final kidId = ref.read(activeKidIdProvider) ?? unpairedKidId;
    _summary = KidLocalData(
      ref.read(localDatabaseProvider),
      kidId: kidId,
    ).summary();
  }

  /// One go at uploading while the kid's token still works. On success
  /// the removal goes ahead; otherwise the guardian chooses again.
  Future<void> _sendThenErase() async {
    setState(() => _phase = _Phase.sending);
    final sent = await ref.read(outboxFlusherProvider).sendAllNow();
    if (!mounted) return;
    if (sent) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _phase = _Phase.sendFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return FutureBuilder(
      future: _summary,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final sending = _phase == _Phase.sending;
        return AlertDialog(
          title: Text(s.removeKidTitle(widget.kidName)),
          content: summary == null
              ? const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.removeKidIntro),
                    const SizedBox(height: 8),
                    Text('• ${s.removeKidUnsent(summary.unsentResults)}'),
                    Text('• ${s.removeKidCreations(summary.creations)}'),
                    if (sending) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Flexible(child: Text(s.removeKidSending)),
                        ],
                      ),
                    ],
                    if (_phase == _Phase.sendFailed) ...[
                      const SizedBox(height: 12),
                      Text(s.removeKidSendFailed),
                    ],
                  ],
                ),
          actions: summary == null
              ? [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(s.cancel),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: sending
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(s.cancel),
                  ),
                  TextButton(
                    onPressed: sending
                        ? null
                        : () => Navigator.of(context).pop(true),
                    child: Text(
                      _phase == _Phase.sendFailed
                          ? s.removeKidEraseAnyway
                          : s.removeKidEraseNow,
                    ),
                  ),
                  // Nothing unsent means nothing to send: one way to erase.
                  if (summary.unsentResults > 0)
                    FilledButton(
                      onPressed: sending ? null : _sendThenErase,
                      child: Text(
                        _phase == _Phase.sendFailed
                            ? s.retry
                            : s.removeKidSendThenErase,
                      ),
                    ),
                ],
        );
      },
    );
  }
}
