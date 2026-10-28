import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/breathing_mascot.dart';
import 'pairing_controller.dart';

/// The playing kid is paired but holds no seat (backend 403
/// `seat_required`): a family's plan or a school stopped covering them.
///
/// Calm and kid-sized (ADR 0037, revision 2026-10-28): who can fix it, and
/// what to do after. Never money, plans or prices: the kid's app must not
/// mention them. The pairing is kept, so the moment an adult adds a seat,
/// "Réessayer" (or coming back to the app) lets them in. With brothers or
/// sisters on the device, "Qui joue ?" lets one of them play meanwhile.
class NoSeatScreen extends ConsumerStatefulWidget {
  const NoSeatScreen({super.key});

  @override
  ConsumerState<NoSeatScreen> createState() => _NoSeatScreenState();
}

class _NoSeatScreenState extends ConsumerState<NoSeatScreen> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    await ref.read(sessionControllerProvider.notifier).ensureFreshToken();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = VillagePalette.of(context);
    final session = ref.watch(sessionControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.skyTop, p.skyBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Space.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BreathingMascot(height: 150, hoverLift: false),
                    const SizedBox(height: Space.md),
                    Text(
                      s.noSeatTitle,
                      key: const ValueKey('no-seat-title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: VillageType.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        height: 1.2,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      s.noSeatBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: VillageType.display,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        height: 1.4,
                        color: p.inkMuted,
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    FilledButton.icon(
                      key: const ValueKey('no-seat-retry'),
                      onPressed: _checking ? null : _retry,
                      icon: _checking
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(s.retry),
                      style: FilledButton.styleFrom(
                        backgroundColor: p.gold,
                        foregroundColor: p.ink,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.xl,
                          vertical: Space.sm,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: VillageType.display,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (session.choosesWhoPlays) ...[
                      const SizedBox(height: Space.sm),
                      TextButton.icon(
                        key: const ValueKey('no-seat-who'),
                        onPressed: ref
                            .read(sessionControllerProvider.notifier)
                            .chooseProfile,
                        icon: const Icon(Icons.people_alt_rounded),
                        label: Text(s.whoIsPlaying),
                        style: TextButton.styleFrom(
                          foregroundColor: p.quebecBlue,
                          textStyle: const TextStyle(
                            fontFamily: VillageType.display,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
