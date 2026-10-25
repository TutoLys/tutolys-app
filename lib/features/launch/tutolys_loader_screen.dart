import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import 'widgets/launch_backdrop.dart';
import 'widgets/tutolys_animated_logo.dart';
import 'widgets/tutolys_loading_message_rotator.dart';
import 'widgets/tutolys_progress_bar.dart';

/// The launch loader: the living emblem, the wordmark, a real progress bar
/// and a line of copy under it.
///
/// Purely presentational — [progress] and [done] come from whoever knows
/// what startup is actually doing (`LaunchFlow`). Nothing here waits on a
/// timer or holds the screen up: when startup is quick, a child sees the
/// bar fill and the welcome line, and that is all.
///
/// Which line shows follows the same honesty as the bar:
/// - the mood lines (`launchMessages`) rotate on a timer while real
///   progress is below 80 %;
/// - "on y est presque" appears only past 80 %, "presque prêt" only past
///   92 %;
/// - "Bienvenue dans TutoLys !" only once [done] is true.
class TutolysLoaderScreen extends StatelessWidget {
  const TutolysLoaderScreen({
    required this.progress,
    this.done = false,
    this.firstMessage = 0,
    super.key,
  });

  final double progress;
  final bool done;

  /// Which mood line to open on — the one the web page's HTML loader was
  /// showing when it handed over, so the copy doesn't restart mid-launch.
  final int firstMessage;

  static const double almostAt = 0.8;
  static const double nearlyReadyAt = 0.92;

  /// The lines to rotate for this point in startup.
  static List<String> messagesFor(Strings s, {required double progress, required bool done}) {
    if (done) return [s.launchDone];
    if (progress >= nearlyReadyAt) return [s.launchNearlyReady];
    if (progress >= almostAt) return [s.launchAlmost];
    return s.launchMessages;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Material(
      color: LaunchBackdrop.night,
      child: LaunchBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              // One scale for the whole stack, from whichever dimension is
              // tighter, so a phone in landscape and a 4K monitor both get a
              // composition that fills about the middle half of the screen.
              final scale = math.min(box.maxHeight / 760, box.maxWidth / 420).clamp(0.62, 1.25);
              final logo = 200.0 * scale;
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TutolysAnimatedLogo(size: logo),
                    SizedBox(height: 28 * scale),
                    TutolysWordmark(fontSize: 54 * scale),
                    SizedBox(height: 40 * scale),
                    SizedBox(
                      width: math.min(320 * scale, box.maxWidth - 64),
                      child: TutolysProgressBar(
                        value: done ? 1 : progress,
                        height: 16 * scale,
                        semanticLabel: s.launchProgressLabel,
                      ),
                    ),
                    SizedBox(height: 20 * scale),
                    SizedBox(
                      width: math.min(420.0, box.maxWidth - 48),
                      // Room for two lines, so a long English line wraps
                      // without pushing the bar up.
                      height: 52 * scale,
                      child: TutolysLoadingMessageRotator(
                        messages: messagesFor(s, progress: progress, done: done),
                        initialIndex: firstMessage,
                        style: TextStyle(
                          fontFamily: VillageType.display,
                          fontWeight: FontWeight.w600,
                          fontSize: 19 * scale,
                          height: 1.25,
                          color: done ? VillageColors.goldPale : Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
