import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../data/local_db/feedback_queue.dart';
import '../pairing/pairing_controller.dart' show appVersion;
import '../profile/pin_gate.dart';
import 'feedback_sender.dart';

/// « Une suggestion ? Un bug ? » in Aide & support (work order F3, app ADR
/// 0104). The kid may write; only an adult's PIN sends, because a child
/// may type a name, a school or an address.
class FeedbackCard extends ConsumerWidget {
  const FeedbackCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VillagePalette.of(context);
    final t = context.s;
    final sender = ref.watch(feedbackSenderProvider);

    return Material(
      color: p.surface,
      borderRadius: VillageMetrics.mdAll,
      elevation: VillageColors.elevationSmall,
      shadowColor: p.shadowSmall,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 18, color: p.quebecBlue),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    t.feedbackTitle,
                    style: TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: p.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(
              t.feedbackBody,
              style: TextStyle(fontSize: 13, height: 1.45, color: p.inkMuted),
            ),
            const SizedBox(height: Space.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey('feedback-open'),
                onPressed: sender == null
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (_) => const FeedbackDialog(),
                      ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(t.feedbackOpen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The form: a feature to suggest or a bug, then the text. « Envoyer » asks for the
/// guardian PIN first, and only then queues and sends.
class FeedbackDialog extends ConsumerStatefulWidget {
  const FeedbackDialog({super.key, this.route = 'aide'});

  /// Where the message was written from, sent as context.
  final String route;

  @override
  ConsumerState<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<FeedbackDialog> {
  final _text = TextEditingController();
  FeedbackKind _kind = FeedbackKind.feature;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  int get _length => feedbackLength(_text.text);

  bool get _canSend => !_sending && _length > 0 && _length <= feedbackMaxLength;

  Future<void> _send() async {
    final t = context.s;
    final sender = ref.read(feedbackSenderProvider);
    if (sender == null) return;
    final feedbackContext = FeedbackContext(
      appVersion: appVersion,
      platform: FeedbackContext.currentPlatform(),
      locale: Localizations.localeOf(context).languageCode,
      route: widget.route,
    );
    final allowed = await requireGuardianPin(
      context,
      ref,
      confirmLabel: t.feedbackSend,
      createSubtitle: t.feedbackPinCreate,
      enterSubtitle: t.feedbackPinEnter,
    );
    if (!allowed || !mounted) return;
    setState(() => _sending = true);
    final outcome = await sender.submit(
      kind: _kind,
      text: _text.text,
      context: feedbackContext,
    );
    if (!mounted) return;
    final navigator = Navigator.of(context);
    VillageToast.show(
      context,
      outcome == FeedbackOutcome.sent ? t.feedbackSent : t.feedbackQueued,
      icon: Icons.check_circle_outline,
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final t = context.s;
    final over = _length > feedbackMaxLength;

    return AlertDialog(
      // Scrolls rather than overflows on a short screen or under a phone's
      // keyboard (AM12).
      scrollable: true,
      title: Text(t.feedbackTitle),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // AM12: stacked, full width, in the app's own face. As chips
            // side by side « Suggérer une fonctionnalité » was cut off.
            for (final (kind, label, icon) in [
              (
                FeedbackKind.feature,
                t.feedbackKindFeature,
                Icons.lightbulb_outline,
              ),
              (FeedbackKind.bug, t.feedbackKindBug, Icons.build_outlined),
            ]) ...[
              if (kind != FeedbackKind.feature)
                const SizedBox(height: Space.xs),
              _KindOption(
                key: ValueKey('feedback-kind-${kind.wire}'),
                label: label,
                icon: icon,
                selected: _kind == kind,
                onTap: _sending ? null : () => setState(() => _kind = kind),
              ),
            ],
            const SizedBox(height: Space.sm),
            TextField(
              key: const ValueKey('feedback-text'),
              controller: _text,
              enabled: !_sending,
              minLines: 4,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: t.feedbackHint,
                border: const OutlineInputBorder(),
                counterText: '$_length / $feedbackMaxLength',
                counterStyle: TextStyle(
                  // Amber, never red: the design's retry colour.
                  color: over ? p.retry : p.inkMuted,
                  fontWeight: over ? FontWeight.w700 : null,
                ),
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              t.feedbackPrivacyNote,
              style: TextStyle(fontSize: 12, color: p.inkMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          key: const ValueKey('feedback-send'),
          onPressed: _canSend ? _send : null,
          child: Text(t.feedbackSend),
        ),
      ],
    );
  }
}

/// One of the two kinds: a full-width row, selected like the app's pills.
class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = VillagePalette.of(context);
    final fg = selected ? p.quebecBlueBright : p.ink;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? p.navActiveFill : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: VillageMetrics.mdAll,
          side: BorderSide(
            color: selected ? p.quebecBlueBright : p.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const RoundedRectangleBorder(
            borderRadius: VillageMetrics.mdAll,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.sm,
                vertical: Space.xs,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: VillageType.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: fg,
                      ),
                    ),
                  ),
                  if (selected) Icon(Icons.check_rounded, size: 20, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
